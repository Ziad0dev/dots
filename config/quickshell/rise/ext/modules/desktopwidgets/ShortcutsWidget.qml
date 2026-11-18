pragma ComponentBehavior: Bound
// After lucid's shortcuts widget (github.com/Sn3akyy1/lucid, MIT), written for rise.
import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.ext.colors
import qs.ext.services as Services

// App shortcuts on the desktop: the icon launches the app. The apps are the
// desktop-entry ids in `apps`; one that isn't installed is left out.
WidgetFrame {
    id: root

    property var apps: ["zen-beta", "com.mitchellh.ghostty", "nemo", "obsidian", "discord", "com.github.taiko2k.tauonmb"]
    // re-read when the app database (re)loads: it fills in after the widget starts
    readonly property var entries: {
        DesktopEntries.applications.values;
        return apps.map(id => DesktopEntries.byId(id)).filter(e => e !== null);
    }

    themeId: Services.DesktopTheme.enabled ? Services.DesktopTheme.theme : ""
    title: WidgetStyle.word("shortcuts", themeId)
    seal: "徑"

    Grid {
        columns: 3
        spacing: 12
        Repeater {
            model: root.entries
            Column {
                id: app
                required property var modelData
                spacing: 4
                width: 72
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 52
                    height: 52
                    radius: 14
                    color: Colors.withAlpha(root.ink, area.containsMouse ? 0.14 : 0.05)
                    IconImage {
                        anchors.centerIn: parent
                        implicitSize: 36
                        source: Quickshell.iconPath(app.modelData.icon, "application-x-executable")
                    }
                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: app.modelData.execute()
                    }
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: app.modelData.name
                    font.family: root.st.font
                    font.pixelSize: 11
                    color: Colors.withAlpha(root.ink, 0.75)
                }
            }
        }
    }
}
