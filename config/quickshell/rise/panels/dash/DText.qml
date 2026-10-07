import QtQuick

// Dashboard text: Cormorant Garamond, a book face (assets/fonts, loaded by Theme).
//   body 12/14/16 · title 14/16/22 (Medium) · headline 24/28/32 (Medium)
Text {
    font.family: "Cormorant Garamond"
    font.weight: Font.Medium
    font.pointSize: 12
    color: "white"
    renderType: Text.NativeRendering
    elide: Text.ElideRight
}
