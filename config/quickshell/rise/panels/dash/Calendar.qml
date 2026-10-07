import QtQuick
import "../../modules"
import "Occult.js" as Occult

// Month calendar, Monday first. Wheel or the chevrons page months; the title or
// a middle click comes back to today, which sits on a "sunny" shape.
Item {
    id: cal
    required property var dash

    property date viewDate: new Date()
    readonly property int year: viewDate.getFullYear()
    readonly property int month: viewDate.getMonth()
    readonly property bool onToday: month === dash.now.getMonth() && year === dash.now.getFullYear()
    // 42 cells: the trailing days of last month, this month, the leading days of next
    readonly property var cells: {
        var first = new Date(year, month, 1)
        var lead = (first.getDay() + 6) % 7
        var out = []
        for (var i = 0; i < 42; i++) {
            var d = new Date(year, month, 1 - lead + i)
            out.push({ day: d.getDate(), inMonth: d.getMonth() === month, weekend: i % 7 >= 5,
                       today: d.toDateString() === cal.dash.now.toDateString() })
        }
        return out
    }
    implicitHeight: header.height + 4 + dow.height + 4 + grid.height

    // page slide: out in the direction of travel, then in from the other side
    property real slide: 0
    property real fade: 1
    function page(delta) {
        pageAnim.dir = delta === 0 ? (viewDate < new Date() ? -1 : 1) : delta
        pageAnim.dest = delta === 0 ? new Date() : new Date(year, month + delta, 1)
        pageAnim.restart()
    }
    SequentialAnimation {
        id: pageAnim
        property int dir: 1
        property date dest: new Date()
        ParallelAnimation {
            Anim { target: cal; property: "slide"; to: -24 * pageAnim.dir; kind: "exit"; ms: 120 }
            Anim { target: cal; property: "fade"; to: 0; ms: 120 }
        }
        ScriptAction { script: { cal.viewDate = pageAnim.dest; cal.slide = 24 * pageAnim.dir } }
        ParallelAnimation {
            Anim { target: cal; property: "slide"; to: 0; kind: "spatial"; ms: 380 }
            Anim { target: cal; property: "fade"; to: 1; ms: 240 }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.MiddleButton
        onClicked: cal.page(0)
        onWheel: function (w) { cal.page(w.angleDelta.y > 0 ? -1 : 1) }
    }

    Item {
        id: header
        width: parent.width; height: 34
        Chevron { anchors.left: parent.left; icon: "chevron_left"; onClicked: cal.page(-1) }
        Rectangle {
            anchors.centerIn: parent
            width: title.implicitWidth + 32; height: 30
            radius: 2
            color: cal.dash.blood
            opacity: cal.onToday ? 0 : titleMa.pressed ? 0.16 : titleMa.containsMouse ? 0.1 : 0
            Behavior on opacity { Anim { ms: 120 } }
        }
        Row {
            id: title
            anchors.centerIn: parent
            spacing: 10
            opacity: cal.fade
            transform: Translate { x: cal.slide }
            GText {
                anchors.baseline: yearText.baseline
                text: Qt.formatDate(cal.viewDate, "MMMM")
                color: cal.dash.bone
                font.pointSize: 18
            }
            DText {
                id: yearText
                text: Occult.roman(cal.year)
                color: cal.dash.bloodText
                font.pointSize: 12; font.letterSpacing: 2
            }
        }
        MouseArea {
            id: titleMa
            anchors.centerIn: parent
            width: title.implicitWidth + 32; height: 30
            hoverEnabled: true
            enabled: !cal.onToday
            cursorShape: Qt.PointingHandCursor
            onClicked: cal.page(0)
        }
        Chevron { anchors.right: parent.right; icon: "chevron_right"; onClicked: cal.page(1) }
    }

    Row {
        id: dow
        y: header.height + 4
        width: parent.width; height: 20
        Repeater {
            model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
            delegate: DText {
                required property var modelData
                required property int index
                width: dow.width / 7
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                color: index >= 5 ? cal.dash.tertiary : cal.dash.ash
                font.pointSize: 11; font.italic: true
            }
        }
    }

    Grid {
        id: grid
        y: dow.y + dow.height + 4
        width: parent.width
        columns: 7
        rowSpacing: 3
        readonly property real cellW: width / 7
        opacity: cal.fade
        transform: Translate { x: cal.slide }
        Repeater {
            model: cal.cells
            delegate: Item {
                id: cell
                required property var modelData
                width: grid.cellW; height: 26
                // today: a thin blood ring, a lozenge on top
                Rectangle {
                    anchors.centerIn: parent
                    width: 27; height: 27; radius: width / 2
                    visible: cell.modelData.today
                    color: Qt.rgba(cal.dash.blood.r, cal.dash.blood.g, cal.dash.blood.b, 0.16)
                    border.color: cal.dash.blood; border.width: 1.5
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: -3; width: 5; height: 5; rotation: 45
                        color: cal.dash.blood
                    }
                }
                DText {
                    anchors.centerIn: parent
                    text: cell.modelData.day
                    color: cell.modelData.today ? cal.dash.bone
                         : cell.modelData.weekend ? cal.dash.tertiary : cal.dash.onSurface
                    opacity: cell.modelData.inMonth || cell.modelData.today ? 1 : 0.32
                    font.pointSize: 12
                    font.weight: cell.modelData.today ? Font.Bold : Font.Medium
                }
            }
        }
    }

    component Chevron: Item {
        id: ch
        property string icon
        signal clicked()
        width: 30; height: 30
        anchors.verticalCenter: parent.verticalCenter
        Rectangle {
            anchors.fill: parent
            radius: 2
            color: cal.dash.blood
            opacity: chMa.pressed ? 0.24 : chMa.containsMouse ? 0.12 : 0
        }
        DText {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -2
            text: ch.icon === "chevron_left" ? "‹" : "›"
            color: chMa.containsMouse ? cal.dash.bloodText : cal.dash.ash
            font.pointSize: 20
        }
        MouseArea {
            id: chMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ch.clicked()
        }
    }
}
