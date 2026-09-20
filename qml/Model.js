// Parses the output of `omarchy-beam --emit`:
//
//   meta<TAB>status<TAB>kind<TAB>label<TAB>preview
//   <row0 of 0/1 modules>
//   <row1 ...>
//
// status is ok | empty | toolarge. For empty/toolarge there is no matrix and
// `label` carries the headline (e.g. "Nothing to Beam"), `preview` an optional
// detail line. The preview sits last and is pre-sanitized by the CLI to contain
// no tabs, so splitting on TAB is safe. A malformed matrix returns size 0
// rather than rendering a code that cannot scan.

function parseBeamOutput(raw) {
  var lines = String(raw || "").split(/\r?\n/)
  var meta = { status: "empty", kind: "", label: "Nothing to Beam", preview: "" }

  // Find the meta header (first non-empty line). Anything before it is noise.
  var i = 0
  while (i < lines.length && lines[i] === "") i++

  if (i < lines.length && lines[i].indexOf("meta\t") === 0) {
    var fields = lines[i].split("\t")
    meta.status = fields[1] || "empty"
    meta.kind = fields[2] || ""
    meta.label = fields[3] || ""
    meta.preview = fields.slice(4).join("\t")
    i++
  }

  var body = []
  for (; i < lines.length; i++) {
    if (lines[i] !== "") body.push(lines[i])
  }

  return { meta: meta, matrix: parseQrMatrix(body) }
}

function parseQrMatrix(lines) {
  if (lines.length === 0) return { rows: [], size: 0 }

  var size = lines[0].length
  if (size !== lines.length) return { rows: [], size: 0 }

  for (var i = 0; i < lines.length; i++) {
    if (lines[i].length !== size || !/^[01]+$/.test(lines[i])) return { rows: [], size: 0 }
  }

  return { rows: lines, size: size }
}

if (typeof module !== "undefined") {
  module.exports = {
    parseBeamOutput: parseBeamOutput,
    parseQrMatrix: parseQrMatrix
  }
}
