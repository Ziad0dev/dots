import QtQuick

// A one-line input in the Calendar note field's style. Enter emits accepted().
Rectangle {
    id: field
    required property var root
    property alias text: input.text
    property alias input: input
    property string placeholder: ""
    property var validator: null
    signal accepted()
    signal escaped()

    height: 26
    radius: root.tileRadius
    color: root.fillIdle
    border.width: 1
    border.color: input.activeFocus ? root.seal : root.sep

    TextInput {
        id: input
        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
        verticalAlignment: TextInput.AlignVCenter
        color: field.root.ink
        font.family: field.root.mono
        font.pixelSize: 11
        selectByMouse: true
        selectionColor: field.root.seal
        clip: true
        validator: field.validator
        Keys.onReturnPressed: field.accepted()
        Keys.onEnterPressed: field.accepted()
        Keys.onEscapePressed: field.escaped()
        UiText {
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text === ""
            text: field.placeholder
            color: field.root.sumi
            font: input.font
        }
    }
}
