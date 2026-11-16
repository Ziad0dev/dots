import QtQuick

Item {
    id: rn

    property int value: 0
    property int digits: 2
    property color tint: "white"
    property string family: "monospace"
    property int pixelSize: 12
    property int weight: Font.Normal
    property string suffix: ""
    property bool rolling: true
    property int rollDuration: 380
    property int rollStagger: 55

    readonly property real cellW: Math.ceil(probe.implicitWidth)
    readonly property real cellH: Math.ceil(probe.implicitHeight)

    implicitWidth: rn.digits * rn.cellW + (rn.suffix === "" ? 0 : Math.ceil(suffixText.implicitWidth))
    implicitHeight: rn.cellH

    Text {
        id: probe
        visible: false
        text: "0"
        font.family: rn.family
        font.pixelSize: rn.pixelSize
        font.weight: rn.weight
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        Repeater {
            model: rn.digits

            delegate: Item {
                id: cell
                required property int index
                readonly property int place: rn.digits - 1 - cell.index
                readonly property int digit: Math.floor(Math.abs(rn.value) / Math.pow(10, cell.place)) % 10

                property real pos: cell.digit

                width: rn.cellW
                height: rn.cellH
                clip: true

                onDigitChanged: cell.roll()

                function roll() {
                    var t = cell.digit
                    while (t < cell.pos - 5) t += 10
                    while (t > cell.pos + 5) t -= 10
                    rollAnim.dest = t
                    rollAnim.restart()
                }

                function normalize() {
                    var v = cell.pos
                    while (v >= 10) v -= 10
                    while (v < 0) v += 10
                    cell.pos = v
                }

                SequentialAnimation {
                    id: rollAnim
                    property real dest: 0
                    PauseAnimation { duration: rn.rolling ? cell.place * rn.rollStagger : 0 }
                    NumberAnimation {
                        target: cell; property: "pos"
                        to: rollAnim.dest
                        duration: rn.rolling ? rn.rollDuration : 0
                        easing.type: Easing.OutBack; easing.overshoot: 1.05
                    }
                    ScriptAction { script: cell.normalize() }
                }

                Column {
                    y: -(cell.pos + 10) * rn.cellH
                    Repeater {
                        model: 30
                        delegate: Text {
                            required property int index
                            width: rn.cellW
                            height: rn.cellH
                            renderType: rn.rolling ? Text.QtRendering : Text.NativeRendering
                            text: String(index % 10)
                            color: rn.tint
                            font.family: rn.family
                            font.pixelSize: rn.pixelSize
                            font.weight: rn.weight
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }
        }

        Text {
            id: suffixText
            anchors.verticalCenter: parent.verticalCenter
            renderType: rn.rolling ? Text.QtRendering : Text.NativeRendering
            visible: rn.suffix !== ""
            text: rn.suffix
            color: rn.tint
            font.family: rn.family
            font.pixelSize: rn.pixelSize
            font.weight: rn.weight
        }
    }
}
