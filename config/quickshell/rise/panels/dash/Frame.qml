import QtQuick

// A grimoire panel: a hairline blood rule with a fainter one inset inside it,
// small square bosses at the corners, and the faintest red wash.
Rectangle {
    id: f
    required property var dash
    property bool bosses: true
    color: dash.surfaceContainer
    radius: 2
    border.color: dash.outlineVariant
    border.width: 1

    Rectangle {
        anchors.fill: parent
        anchors.margins: 4
        color: "transparent"
        radius: 1
        border.color: f.dash.outlineVariant
        border.width: 1
        opacity: 0.4
    }
    Repeater {
        model: f.bosses ? 4 : 0
        delegate: Rectangle {
            required property int index
            width: 5; height: 5
            x: (index % 2 === 0 ? 0 : f.width - width) + (index % 2 === 0 ? -2 : 2)
            y: (index < 2 ? 0 : f.height - height) + (index < 2 ? -2 : 2)
            color: f.dash.blood
            rotation: 45
        }
    }
}
