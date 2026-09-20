import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Omarchy Beam — a fullscreen overlay that turns the current clipboard into a
// scannable QR code, styled to match Omarchy's own Wi-Fi share card.
//
// The overlay never receives clipboard data through its payload. When it opens
// it runs `omarchy-beam --emit`, which reads the clipboard itself and prints a
// meta line plus a 0/1 module matrix. Every module is drawn as a native
// rectangle, so nothing is ever written to a temporary image file.
//
// Esc or a click on the scrim dismisses it. Re-summoning refreshes from the
// live clipboard.
Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null

  property bool opened: false

  // Locate the CLI next to this plugin so the overlay works straight from the
  // installed plugin directory, whether or not omarchy-beam is on PATH. An
  // explicit OMARCHY_BEAM_BIN wins for development.
  readonly property string beamBin: {
    var override = Quickshell.env("OMARCHY_BEAM_BIN")
    if (override && override.length > 0) return override
    var url = Qt.resolvedUrl("../bin/omarchy-beam")
    return String(url).replace(/^file:\/\//, "")
  }

  // Parsed state from omarchy-beam --emit.
  property string status: ""     // ok | empty | toolarge
  property string kind: ""       // url | text | email | tel | wifi
  property string label: ""      // "Scan to open", or a headline for empty/toolarge
  property string preview: ""
  property var qrRows: []
  property int qrSize: 0
  property bool loading: false
  property bool expectedStop: false
  property bool pendingShow: false

  readonly property bool showingQr: qrSize > 0 && status === "ok" && !loading
  readonly property bool showingMessage: !loading && !showingQr && status !== ""

  readonly property string fontFamily: Style.font.family

  function open(payloadJson) {
    root.opened = true
    generate()
    // The window is instantiated hidden, so the content's focus is evaluated
    // before the surface is mapped and Escape would land nowhere. Re-acquire
    // focus once mapped.
    Qt.callLater(function() {
      if (root.opened) keyCatcher.forceActiveFocus()
    })
  }

  function close() {
    root.opened = false
    root.pendingShow = false
    if (emitProc.running) {
      root.expectedStop = true
      emitProc.running = false
    }
    // Drop everything derived from the clipboard as soon as the card closes.
    root.status = ""
    root.kind = ""
    root.label = ""
    root.preview = ""
    root.qrRows = []
    root.qrSize = 0
    root.loading = false
  }

  function dismiss() {
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "beam")
    else close()
  }

  function toggle() {
    if (root.opened) dismiss()
    else open("{}")
  }

  function generate() {
    if (emitProc.running) {
      // A re-summon while a read is still in flight: the latest request wins.
      pendingShow = true
      if (!expectedStop) {
        expectedStop = true
        emitProc.running = false
      }
      return
    }
    status = ""
    kind = ""
    label = ""
    preview = ""
    qrRows = []
    qrSize = 0
    loading = true
    expectedStop = false
    emitProc.command = [root.beamBin, "--emit"]
    emitProc.running = true
  }

  function applyEmit(raw) {
    var parsed = Model.parseBeamOutput(raw)
    root.status = parsed.meta.status
    root.kind = parsed.meta.kind
    root.label = parsed.meta.label
    root.preview = parsed.meta.preview
    root.qrRows = parsed.matrix.rows
    root.qrSize = parsed.matrix.size
    // A payload the CLI called "ok" but whose matrix failed to parse cannot be
    // scanned; fail closed rather than show a broken code.
    if (root.status === "ok" && root.qrSize === 0) {
      root.status = "toolarge"
      root.label = "Could not build a QR code"
    }
  }

  Process {
    id: emitProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (!root.expectedStop) root.applyEmit(text)
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (!root.expectedStop && String(text || "").trim() !== "" && root.status === "") {
          root.status = "toolarge"
          root.label = "Beam is unavailable"
          root.preview = String(text).trim()
        }
      }
    }
    onExited: function(exitCode) {
      root.loading = false
      if (root.pendingShow) {
        root.pendingShow = false
        Qt.callLater(function() { root.generate() })
        return
      }
      if (root.expectedStop) return
      if (root.status === "") {
        root.status = "toolarge"
        root.label = "Beam is unavailable"
      }
    }
  }

  PanelWindow {
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omarchy-beam"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // Deep scrim so the card and QR carry contrast on any wallpaper or theme.
    Rectangle {
      anchors.fill: parent
      color: Qt.rgba(0, 0, 0, 0.72)

      MouseArea {
        anchors.fill: parent
        onClicked: root.dismiss()
      }
    }

    Item {
      id: keyCatcher
      anchors.fill: parent
      focus: true

      Keys.onEscapePressed: root.dismiss()

      Item {
        anchors.centerIn: parent
        width: card.implicitWidth
        height: card.implicitHeight
        // Shrink the whole card rather than clipping it at the screen edge.
        scale: Math.min(1,
          (keyCatcher.width - Style.space(32)) / Math.max(1, width),
          (keyCatcher.height - Style.space(32)) / Math.max(1, height))

        // The card itself. Uses the shared menu surface tokens so a theme that
        // styles the Omarchy menu styles Beam too.
        Rectangle {
          id: card
          anchors.fill: parent
          implicitWidth: content.implicitWidth + Style.space(56)
          implicitHeight: content.implicitHeight + Style.space(48)
          radius: Style.cornerRadius > 0 ? Style.cornerRadius + Style.space(6) : Style.space(12)
          color: Color.menu.background
          border.color: Color.menu.border
          border.width: Math.max(1, Style.space(1))

          // Swallow clicks inside the card so only the scrim dismisses.
          MouseArea { anchors.fill: parent; onClicked: {} }

          ColumnLayout {
            id: content
            anchors.centerIn: parent
            spacing: Style.space(14)

            // BEAM wordmark
            Text {
              textFormat: Text.PlainText
              text: "BEAM"
              color: Color.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 4
              horizontalAlignment: Text.AlignHCenter
              Layout.alignment: Qt.AlignHCenter
            }

            // The QR code. Every module is an integer-sized native rectangle on
            // a white canvas — crisp, no image files, no file-cache races. Only
            // the dark modules paint, so the white canvas keeps rounded corners;
            // the spec quiet zone is baked into the matrix by qrencode.
            Rectangle {
              id: qrCanvas
              readonly property int moduleSize: root.qrSize > 0
                ? Math.max(4, Math.floor(Style.space(240) / root.qrSize))
                : 0

              visible: root.showingQr
              width: root.qrSize * moduleSize
              height: width
              color: "white"
              radius: Style.cornerRadius
              Layout.alignment: Qt.AlignHCenter

              Grid {
                anchors.centerIn: parent
                columns: root.qrSize
                Repeater {
                  model: root.showingQr ? root.qrSize * root.qrSize : 0
                  Rectangle {
                    required property int index
                    readonly property int matrixRow: Math.floor(index / root.qrSize)
                    readonly property int matrixColumn: index % root.qrSize
                    width: qrCanvas.moduleSize
                    height: qrCanvas.moduleSize
                    color: root.qrRows[matrixRow].charAt(matrixColumn) === "1" ? "#111111" : "transparent"
                  }
                }
              }
            }

            // Loading spinner text
            Text {
              visible: root.loading
              text: "Reading clipboard…"
              color: Color.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              Layout.fillWidth: true
              horizontalAlignment: Text.AlignHCenter
            }

            // Headline for empty / too-large / error states (e.g. "Nothing to
            // Beam", "Too large to Beam").
            Text {
              textFormat: Text.PlainText
              visible: root.showingMessage
              text: root.label
              color: root.status === "empty" ? Color.foreground : Color.urgent
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              wrapMode: Text.Wrap
              horizontalAlignment: Text.AlignHCenter
              Layout.maximumWidth: Style.space(300)
              Layout.alignment: Qt.AlignHCenter
            }

            // Clipboard preview under the QR (sanitized + truncated by the CLI).
            // Plain text wraps across a few lines so it is readable and easy to
            // copy straight off the overlay; the other kinds are short single-
            // line identifiers.
            Text {
              readonly property bool isText: root.kind === "text"
              textFormat: Text.PlainText
              visible: (root.showingQr || root.showingMessage) && root.preview !== ""
              text: root.preview
              color: Color.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              wrapMode: isText ? Text.Wrap : Text.NoWrap
              elide: Text.ElideRight
              maximumLineCount: isText ? 4 : 1
              horizontalAlignment: Text.AlignHCenter
              Layout.maximumWidth: qrCanvas.width > 0 ? qrCanvas.width : Style.space(300)
              Layout.alignment: Qt.AlignHCenter
            }

            // Scan action, e.g. SCAN TO OPEN.
            Text {
              textFormat: Text.PlainText
              visible: root.showingQr && root.label !== ""
              text: root.label.toUpperCase()
              color: Color.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: true
              font.letterSpacing: 2
              horizontalAlignment: Text.AlignHCenter
              Layout.alignment: Qt.AlignHCenter
            }

            // Dismiss hint.
            Text {
              textFormat: Text.PlainText
              text: "Esc to close"
              color: Color.muted
              opacity: 0.8
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.letterSpacing: 1
              horizontalAlignment: Text.AlignHCenter
              Layout.alignment: Qt.AlignHCenter
            }
          }
        }
      }
    }
  }
}
