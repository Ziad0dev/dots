// dots-pdf-annot — real PDF annotations via `mutool run` (mupdf JS).
//
//   mutool run dots-pdf-annot.js <mode> <in.pdf> <out.pdf> [args...]
//
// Coordinates taken from the command line are PDF points with the origin at the
// BOTTOM-LEFT of the page (same convention as pdfcpu and pyHanko).
//
// Modes
//   find <term> [pages]            (out.pdf is ignored: pass -)
//   mark <Highlight|Underline|StrikeOut|Squiggly> <term> [color] [pages]
//   note <page> <x> <y> <text>
//   freetext <page> <x> <y> <size> <text>
//   stamp <page> <x> <y> <width> <image>
//   redact-text <term> [pages]
//   redact-box <page> <x1,y1,x2,y2>
//
// Everything except redaction is saved incrementally: the original bytes stay
// untouched, so existing signatures remain cryptographically intact (a
// validator will still list the new annotations as later modifications).
// Redaction rewrites the file: the removed content must really be gone, not
// just covered, which also drops any signatures.

var mode = scriptArgs[0];
var src = scriptArgs[1];
var dst = scriptArgs[2];
var args = scriptArgs.slice(3);

var COLORS = {
  yellow: [1, 0.92, 0.2],
  green: [0.4, 0.9, 0.4],
  blue: [0.45, 0.75, 1],
  pink: [1, 0.55, 0.8],
  red: [0.95, 0.25, 0.25],
  orange: [1, 0.65, 0.2],
  purple: [0.75, 0.55, 1],
  black: [0, 0, 0],
};

function color(spec) {
  if (!spec) return COLORS.yellow;
  if (COLORS[spec]) return COLORS[spec];
  var m = /^#?([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})$/i.exec(spec);
  if (!m) throw new Error("unknown color: " + spec);
  return [parseInt(m[1], 16) / 255, parseInt(m[2], 16) / 255, parseInt(m[3], 16) / 255];
}

// "all" | "3" | "2-5" | "1,3,5-7" | "2-z"  ->  sorted 0-based page indexes
function pageList(spec, count) {
  if (!spec || spec === "all") spec = "1-z";
  var out = {};
  spec.split(",").forEach(function (part) {
    var m = /^(\d+|z)(?:-(\d+|z))?$/.exec(part.trim());
    if (!m) throw new Error("bad page spec: " + spec);
    var a = m[1] === "z" ? count : parseInt(m[1], 10);
    var b = m[2] ? (m[2] === "z" ? count : parseInt(m[2], 10)) : a;
    if (a < 1 || b < a || b > count) throw new Error("page out of range (1-" + count + "): " + part);
    for (var i = a; i <= b; i++) out[i - 1] = true;
  });
  return Object.keys(out).map(Number).sort(function (x, y) { return x - y; });
}

function pageOf(doc, n) {
  n = parseInt(n, 10);
  if (!(n >= 1 && n <= doc.countPages())) throw new Error("page out of range (1-" + doc.countPages() + "): " + n);
  return doc.loadPage(n - 1);
}

// bottom-left user space -> mupdf page space (top-left origin)
function flipY(page, y) {
  var b = page.getBounds();
  return b[3] - b[1] - Number(y);
}

function open(inc) {
  if (inc) {
    // work on a byte-for-byte copy so the original is never touched
    var buf = new Buffer();
    buf.writeBuffer(new Buffer(readFile(src)));
    buf.save(dst);
    return Document.openDocument(dst);
  }
  return Document.openDocument(src);
}

function finish(doc, inc) {
  if (inc && doc.canBeSavedIncrementally()) doc.save(dst, "incremental");
  else doc.save(dst, "garbage=compact,compress");
}

var doc, n;

if (mode === "find") {
  // find <in> - <term> [pages]  ->  one "page x1 y1 x2 y2" line per hit
  var fterm = args[0];
  if (!fterm) throw new Error("no search term given");
  doc = open(false);
  pageList(args[1], doc.countPages()).forEach(function (i) {
    var fpg = doc.loadPage(i);
    var h = fpg.getBounds();
    var ph = h[3] - h[1];
    fpg.search(fterm).forEach(function (quads) {
      quads.forEach(function (q) {
        var xs = [q[0], q[2], q[4], q[6]];
        var ys = [q[1], q[3], q[5], q[7]];
        print(
          i + 1 + " " +
            Math.min.apply(null, xs).toFixed(1) + " " +
            (ph - Math.max.apply(null, ys)).toFixed(1) + " " +
            Math.max.apply(null, xs).toFixed(1) + " " +
            (ph - Math.min.apply(null, ys)).toFixed(1)
        );
      });
    });
  });
} else if (mode === "mark") {
  var kind = args[0];
  var term = args[1];
  if (["Highlight", "Underline", "StrikeOut", "Squiggly"].indexOf(kind) < 0) throw new Error("bad kind: " + kind);
  if (!term) throw new Error("no search term given");
  var rgb = color(args[2]);
  doc = open(true);
  n = 0;
  pageList(args[3], doc.countPages()).forEach(function (i) {
    var page = doc.loadPage(i);
    var hits = page.search(term);
    hits.forEach(function (quads) {
      var a = page.createAnnotation(kind);
      a.setColor(rgb);
      a.setQuadPoints(quads);
      a.setContents("");
      a.update();
      n++;
    });
  });
  if (n === 0) throw new Error("no match for: " + term);
  finish(doc, true);
  print(n + " annotation(s)");
} else if (mode === "note") {
  doc = open(true);
  var p = pageOf(doc, args[0]);
  var nx = Number(args[1]);
  var ny = flipY(p, args[2]);
  var note = p.createAnnotation("Text");
  note.setRect([nx, ny - 20, nx + 20, ny]);
  note.setColor(COLORS.yellow);
  note.setContents(args.slice(3).join(" "));
  note.update();
  finish(doc, true);
  print("note added");
} else if (mode === "freetext") {
  doc = open(true);
  var fp = pageOf(doc, args[0]);
  var fx = Number(args[1]);
  var fy = flipY(fp, args[2]);
  var size = Number(args[3]);
  var text = args.slice(4).join(" ");
  var lines = text.split("\n");
  var longest = lines.reduce(function (m, l) { return Math.max(m, l.length); }, 1);
  var ft = fp.createAnnotation("FreeText");
  ft.setDefaultAppearance("Helv", size, [0, 0, 0]);
  ft.setRect([fx, fy - size * 1.4 * lines.length - 4, fx + longest * size * 0.55 + 8, fy]);
  ft.setBorderWidth(0);
  ft.setContents(text);
  ft.update();
  finish(doc, true);
  print("text added");
} else if (mode === "stamp") {
  doc = open(true);
  var sp = pageOf(doc, args[0]);
  var sx = Number(args[1]);
  var sy = flipY(sp, args[2]);
  var width = Number(args[3]);
  var img = new Image(args[4]);
  var height = (width * img.getHeight()) / img.getWidth();
  var st = sp.createAnnotation("Stamp");
  st.setRect([sx, sy - height, sx + width, sy]);
  st.setStampImage(img);
  st.update();
  finish(doc, true);
  print("image placed");
} else if (mode === "redact-text") {
  var needle = args[0];
  if (!needle) throw new Error("no search term given");
  doc = open(false);
  n = 0;
  pageList(args[1], doc.countPages()).forEach(function (i) {
    var rp = doc.loadPage(i);
    var found = 0;
    rp.search(needle).forEach(function (quads) {
      quads.forEach(function (q) {
        var r = rp.createAnnotation("Redact");
        r.setRect([
          Math.min(q[0], q[2], q[4], q[6]),
          Math.min(q[1], q[3], q[5], q[7]),
          Math.max(q[0], q[2], q[4], q[6]),
          Math.max(q[1], q[3], q[5], q[7]),
        ]);
        r.update();
        found++;
      });
    });
    if (found) {
      rp.applyRedactions(true, 2);
      n += found;
    }
  });
  if (n === 0) throw new Error("no match for: " + needle);
  finish(doc, false);
  print(n + " region(s) redacted");
} else if (mode === "redact-box") {
  doc = open(false);
  var bp = pageOf(doc, args[0]);
  var c = args[1].split(",").map(Number);
  if (c.length !== 4 || c.some(isNaN)) throw new Error("box must be x1,y1,x2,y2");
  var top = flipY(bp, c[3]);
  var bottom = flipY(bp, c[1]);
  var rb = bp.createAnnotation("Redact");
  rb.setRect([Math.min(c[0], c[2]), Math.min(top, bottom), Math.max(c[0], c[2]), Math.max(top, bottom)]);
  rb.update();
  bp.applyRedactions(true, 2);
  finish(doc, false);
  print("region redacted");
} else {
  throw new Error("unknown mode: " + mode);
}
