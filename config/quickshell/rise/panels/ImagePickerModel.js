function nameForPath(path) {
  return String(path || "").split("/").pop().replace(/\.[^/.]+$/, "")
}
function labelForPath(path) {
  return nameForPath(path).replace(/[-_]+/g, " ").replace(/\b\w/g, function (m) { return m.toUpperCase() })
}

function loadRows(rows) {
  var images = [], seen = {}, paths = String(rows || "").split("\n")
  for (var i = 0; i < paths.length; i++) {
    var row = paths[i]; if (!row) continue
    var columns = row.split("\t"), path = columns[0]; if (!path) continue
    var fileName = path.split("/").pop(); if (seen[fileName]) continue
    seen[fileName] = true
    var name  = fileName.replace(/\.[^/.]+$/, "")
    var label = name.replace(/[-_]+/g, " ").replace(/\b\w/g, function (m) { return m.toUpperCase() })
    images.push({
      filePath: path,
      fileName: fileName,
      thumbnailPath: columns[1] || path,
      dir: columns[2] || "",
      name: name,
      label: label,
      search: (name + "\u0000" + label).toLowerCase()
    })
  }
  return images
}

function searchKeyFor(img) {
  if (!img) return ""
  if (img.search !== undefined) return img.search
  var p = String(img.filePath || "")
  return (nameForPath(p) + "\u0000" + labelForPath(p)).toLowerCase()
}

var _cImages = null, _cFilter = null, _cList = [], _cPos = []

function _index(images, filterText) {
  var f = String(filterText || "")
  if (_cImages === images && _cFilter === f) return _cList
  var list = [], pos = []
  if (Array.isArray(images)) {
    var needle = f.toLowerCase()
    for (var i = 0; i < images.length; i++) {
      pos[i] = list.length
      if (!needle || searchKeyFor(images[i]).indexOf(needle) !== -1) list.push(i)
    }
  }
  _cImages = images; _cFilter = f; _cList = list; _cPos = pos
  return list
}

function itemMatches(images, index, filterText) {
  if (!Array.isArray(images) || index < 0 || index >= images.length) return false
  var needle = String(filterText || "").toLowerCase(); if (!needle) return true
  return searchKeyFor(images[index]).indexOf(needle) !== -1
}

function matchList(images, filterText) { return _index(images, filterText) }
function matchCount(images, filterText) { return _index(images, filterText).length }

function firstMatchingIndex(images, filterText) {
  var l = _index(images, filterText)
  return l.length > 0 ? l[0] : -1
}
function filteredPosition(images, index, filterText) {
  _index(images, filterText)
  var p = _cPos[index]
  return p === undefined ? 0 : p
}
function selectedFilteredPosition(images, selectedIndex, filterText) {
  if (!filterText) return selectedIndex
  return itemMatches(images, selectedIndex, filterText)
      ? filteredPosition(images, selectedIndex, filterText) : 0
}
function indexForSelectedImage(images, selectedImage) {
  for (var i = 0; i < images.length; i++) if (images[i].filePath === selectedImage) return i
  return 0
}
function nextSelectedIndexForFilter(images, selectedIndex, filterText) {
  if (itemMatches(images, selectedIndex, filterText)) return selectedIndex
  return firstMatchingIndex(images, filterText)
}
