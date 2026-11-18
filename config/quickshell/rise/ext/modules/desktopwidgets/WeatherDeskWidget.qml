pragma ComponentBehavior: Bound
// After lucid's weather and sun widgets (github.com/Sn3akyy1/lucid, MIT), written for rise.
import QtQuick
import Quickshell.Io
import qs.ext.colors
import qs.ext.modules.lock
import qs.ext.services as Services

// Now, the next three days and the sun's hours, from wttr.in like the bar's
// weather panel (located from the network address, no account). Fetched when
// shown and every half hour; a failed fetch keeps the last report.
WidgetFrame {
    id: root

    property string temp: ""
    property string desc: ""
    property string place: ""
    property string sunrise: ""
    property string sunset: ""
    property var days: []
    readonly property bool imperial: Services.Rise.theme ? Services.Rise.theme.weatherImperial === true : false

    themeId: Services.DesktopTheme.enabled ? Services.DesktopTheme.theme : ""
    title: WidgetStyle.word("weather", themeId)
    seal: "天"

    function conv(c) {
        const n = parseFloat(c);
        return isNaN(n) ? "–" : Math.round(imperial ? n * 9 / 5 + 32 : n) + "°";
    }
    function parse(raw) {
        const d = JSON.parse(raw);
        const now = d.current_condition && d.current_condition[0];
        if (!now)
            return;
        temp = now.temp_C || "";
        desc = now.weatherDesc && now.weatherDesc[0] ? now.weatherDesc[0].value : "";
        const area = d.nearest_area && d.nearest_area[0];
        place = area && area.areaName && area.areaName[0] ? area.areaName[0].value : "";
        const w = d.weather || [];
        const astro = w[0] && w[0].astronomy && w[0].astronomy[0];
        sunrise = astro ? astro.sunrise : "";
        sunset = astro ? astro.sunset : "";
        days = w.slice(0, 3).map((day, i) => ({
            name: i === 0 ? "Today" : new Date(day.date + "T12:00:00").toLocaleDateString(Qt.locale(), "ddd"),
            min: day.mintempC,
            max: day.maxtempC
        }));
    }

    Process {
        id: fetch
        command: ["curl", "-fs", "--max-time", "8", "https://wttr.in?format=j1"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.parse(String(this.text || "").trim());
                } catch (e) {}
            }
        }
    }
    Timer {
        interval: 30 * 60 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: { fetch.running = false; fetch.running = true; }
    }

    Row {
        spacing: 14
        Text {
            text: root.temp === "" ? "…" : root.conv(root.temp)
            font.family: root.st.display
            font.pixelSize: 44
            font.weight: Font.Light
            color: root.ink
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Text {
                width: 170
                elide: Text.ElideRight
                text: root.desc
                font.family: root.st.font
                font.pixelSize: 15
                color: root.ink
            }
            Text {
                width: 170
                elide: Text.ElideRight
                text: root.place
                font.family: root.st.font
                font.pixelSize: 12
                color: Colors.withAlpha(root.ink, 0.6)
            }
        }
    }

    // the sun's hours
    Row {
        spacing: 16
        visible: root.sunrise !== ""
        Repeater {
            model: [{ icon: "wb_twilight", text: root.sunrise }, { icon: "bedtime", text: root.sunset }]
            Row {
                required property var modelData
                spacing: 5
                Glyph {
                    text: parent.modelData.icon
                    font.pixelSize: 17
                    color: root.accent
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: parent.modelData.text
                    font.family: root.st.mono
                    font.pixelSize: 13
                    color: root.ink
                }
            }
        }
    }

    // the next three days
    Row {
        spacing: 18
        Repeater {
            model: root.days
            Column {
                required property var modelData
                spacing: 2
                Text {
                    text: parent.modelData.name
                    font.family: root.st.font
                    font.pixelSize: 12
                    color: Colors.withAlpha(root.ink, 0.65)
                }
                Text {
                    text: root.conv(parent.modelData.min) + " / " + root.conv(parent.modelData.max)
                    font.family: root.st.mono
                    font.pixelSize: 13
                    color: root.ink
                }
            }
        }
    }
}
