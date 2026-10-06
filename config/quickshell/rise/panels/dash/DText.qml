import QtQuick

// Dashboard text: Google Sans Flex (Caelestia's face), sizes in points like its type scale.
//   body 12/14/16 · title 14/16/22 (Medium) · headline 24/28/32 (Medium)
Text {
    font.family: "Google Sans Flex"
    font.pointSize: 12
    color: "white"
    renderType: Text.NativeRendering
    elide: Text.ElideRight
}
