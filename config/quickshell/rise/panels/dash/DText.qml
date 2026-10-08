import QtQuick

// Dashboard / settings text. Body text is Alegreya Sans (a humanist sans from
// the calligraphic Alegreya family: readable at small sizes, at home next to
// blackletter); display sizes (18pt and up) keep Cormorant Garamond, the book
// face (assets/fonts, loaded by Theme). The size is read once on creation:
// reading it inside the family's binding would loop (both live in `font`).
//   body 12/14/16 · title 14/16/22 (Medium) · headline 24/28/32 (Medium)
Text {
    property bool display: false
    Component.onCompleted: display = font.pointSize >= 18 || font.pixelSize >= 24
    font.family: display ? "Cormorant Garamond" : "Alegreya Sans"
    font.weight: Font.Medium
    font.pointSize: 12
    color: "white"
    renderType: Text.NativeRendering
    elide: Text.ElideRight
}
