pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.ext.colors
import qs.ext.components
import qs.ext.modules.lock
import qs.ext.services as Services

// Themes panel, App style tab: GTK theme, Qt (Kvantum) style, icon theme,
// cursor and fonts for the whole desktop (GTK, Qt, fontconfig, Hyprland,
// ghostty) through dots-appearance. Each one follows the colour theme
// (config/themes/<name>/look.conf) until you pick your own; "Match theme"
// hands it back. Themes with a full kit name their own GTK/Qt themes.
//
// Keys (forwarded by the panel): ←→ category.
Item {
    id: tab

    property var st: null       // `dots-appearance state`
    property var lists: null    // `dots-appearance lists`
    property string cat: "gtk"
    property string query: ""

    readonly property var cats: [
        { id: "gtk", label: "GTK theme", icon: "web_asset", sizeKey: "" },
        { id: "kvantum", label: "Qt style", icon: "widgets", sizeKey: "" },
        { id: "icons", label: "Icons", icon: "apps", sizeKey: "" },
        { id: "cursor", label: "Cursor", icon: "arrow_selector_tool", sizeKey: "cursor_size" },
        { id: "font", label: "Interface font", icon: "text_fields", sizeKey: "font_size" },
        { id: "mono", label: "Monospace font", icon: "terminal", sizeKey: "mono_size" }
    ]
    readonly property var catInfo: cats.find(c => c.id === cat)

    function handleKey(event) {
        const i = cats.findIndex(c => c.id === cat);
        if (event.key === Qt.Key_Right)
            cat = cats[(i + 1) % cats.length].id;
        else if (event.key === Qt.Key_Left)
            cat = cats[(i + cats.length - 1) % cats.length].id;
        else
            return false;
        return true;
    }

    // ── state ────────────────────────────────────────────────────────────────
    function eff(key) { return st && st.effective[key] ? String(st.effective[key]) : ""; }
    function mine(key) { return !!(st && st.choice[key]); }
    function themeValue(key) {
        if (!st) return "";
        return String(st.look[key] || st.defaults[key] || "");
    }
    function source(key) {
        if (mine(key)) return "Yours";
        if (st && st.look[key]) return "Theme";
        return "Default";
    }
    function label(value) { return value !== "" ? value : "System default"; }
    // the colour theme ships its own GTK or Qt theme, not just colours
    readonly property bool themeKit: !!(st && (st.look.gtk || st.look.kvantum))

    function set(key, value) {
        if (setProc.running) {
            setProc.pending = [key, value];
            return;
        }
        setProc.command = tab.cmd(["set", key, value]);
        setProc.running = true;
    }

    function cmd(args) {
        return ["sh", "-c", "if command -v dots-appearance >/dev/null 2>&1; then exec dots-appearance \"$@\"; fi; "
            + "exec bash \"${DOTS_DIR:-$HOME/dots}/scripts/dots-appearance.sh\" \"$@\"", "sh"].concat(args);
    }

    function parse(text) {
        try { return JSON.parse(text); } catch (e) { return null; }
    }

    Process {
        command: tab.cmd(["state"])
        running: true
        stdout: StdioCollector { onStreamFinished: tab.st = tab.parse(this.text) || tab.st }
    }

    Process {
        command: tab.cmd(["lists"])
        running: true
        stdout: StdioCollector { onStreamFinished: tab.lists = tab.parse(this.text) }
    }

    Process {
        id: setProc
        property var pending: null
        stdout: StdioCollector { onStreamFinished: tab.st = tab.parse(this.text) || tab.st }
        onExited: {
            if (!pending) return;
            const p = pending;
            pending = null;
            tab.set(p[0], p[1]);
        }
    }

    // ── categories ───────────────────────────────────────────────────────────
    Column {
        id: side
        width: Math.min(280, tab.width * 0.3)
        height: parent.height
        spacing: 8

        Repeater {
            model: tab.cats

            ClickableRect {
                id: catCard
                required property var modelData
                readonly property bool current: tab.cat === modelData.id
                width: side.width
                height: 64
                radius: Services.DesktopTheme.rad(18)
                color: current ? Colors.primary_container : catCard.hovered ? Colors.surface_container_high : Colors.surface_container
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    tab.cat = modelData.id;
                    tab.query = "";
                }

                Behavior on color {
                    ColorAnimation { duration: 140 }
                }

                Glyph {
                    id: catIcon
                    x: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: catCard.modelData.icon
                    filled: catCard.current
                    font.pixelSize: 24
                    color: catCard.current ? Colors.on_primary_container : Colors.on_surface_variant
                }

                Column {
                    x: catIcon.x + catIcon.width + 12
                    width: catCard.width - x - 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Row {
                        width: parent.width
                        spacing: 8

                        StyledText {
                            text: catCard.modelData.label
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                            color: catCard.current ? Colors.on_primary_container : Colors.on_surface
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: srcText.implicitWidth + 10
                            height: 16
                            radius: Services.DesktopTheme.rad(8)
                            color: tab.mine(catCard.modelData.id) ? Colors.primary : Colors.withAlpha(Colors.outline_variant, 0.6)

                            StyledText {
                                id: srcText
                                anchors.centerIn: parent
                                text: tab.source(catCard.modelData.id)
                                font.pixelSize: 9
                                font.weight: Font.Bold
                                color: tab.mine(catCard.modelData.id) ? Colors.on_primary : Colors.on_surface_variant
                            }
                        }
                    }

                    StyledText {
                        width: parent.width
                        readonly property string size: catCard.modelData.sizeKey ? tab.eff(catCard.modelData.sizeKey) : ""
                        text: tab.st ? tab.label(tab.eff(catCard.modelData.id)) + (size !== "" && tab.eff(catCard.modelData.id) !== "" ? " · " + size : "") : "…"
                        elide: Text.ElideRight
                        font.pixelSize: 12
                        color: catCard.current ? Colors.withAlpha(Colors.on_primary_container, 0.8) : Colors.on_surface_variant
                    }
                }
            }
        }

        Item { width: 1; height: 4 }

        StyledText {
            width: side.width
            text: !tab.st || !tab.st.theme ? ""
                : "Colour theme: " + tab.st.theme + (tab.themeKit ? ", a full kit (its own GTK/Qt themes, icons and cursor)" : "")
                  + ". Anything you haven't picked follows it."
            wrapMode: Text.WordWrap
            font.pixelSize: 11
            color: Colors.on_surface_variant
        }

        ClickableRect {
            width: side.width
            height: 40
            visible: tab.st !== null && Object.keys(tab.st.choice).length > 0
            radius: Services.DesktopTheme.rad(14)
            color: hovered ? Colors.surface_container_high : Colors.surface_container
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                setProc.command = tab.cmd(["reset"]);
                setProc.running = true;
            }

            Row {
                anchors.centerIn: parent
                spacing: 6

                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "restart_alt"
                    font.pixelSize: 17
                    color: Colors.on_surface_variant
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Match the theme for everything"
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }
            }
        }

        StyledText {
            width: side.width
            text: "GTK apps and the cursor change at once; Qt and other apps on their next start."
            wrapMode: Text.WordWrap
            font.pixelSize: 11
            color: Colors.withAlpha(Colors.on_surface_variant, 0.8)
        }
    }

    // ── picker ───────────────────────────────────────────────────────────────
    Column {
        id: pane
        x: side.width + 16
        width: tab.width - x
        height: parent.height
        spacing: 10

        // search (fonts) and size chips
        Row {
            id: tools
            width: pane.width
            height: 36
            spacing: 10

            StyledTextField {
                id: search
                visible: tab.cat === "font" || tab.cat === "mono"
                width: Math.min(300, pane.width * 0.45)
                height: 36
                placeholderText: "Search fonts"
                text: tab.query
                onTextChanged: tab.query = text
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                visible: tab.catInfo.sizeKey !== ""
                text: tab.cat === "mono" ? "Terminal size" : "Size"
                font.pixelSize: 12
                color: Colors.on_surface_variant
            }

            Repeater {
                model: tab.cat === "cursor" ? [24, 32, 40, 48]
                    : tab.cat === "font" ? [9, 10, 11, 12, 13, 14]
                    : tab.cat === "mono" ? [11, 12, 13, 14, 15, 16] : []

                ClickableRect {
                    id: sizeChip
                    required property int modelData
                    readonly property bool current: tab.eff(tab.catInfo.sizeKey) === String(modelData)
                    anchors.verticalCenter: parent.verticalCenter
                    width: 38
                    height: 30
                    radius: Services.DesktopTheme.rad(15)
                    color: current ? Colors.primary : sizeChip.hovered ? Colors.surface_container_high : Colors.surface_container
                    cursorShape: Qt.PointingHandCursor
                    onClicked: tab.set(tab.catInfo.sizeKey, current && tab.mine(tab.catInfo.sizeKey) ? "" : String(modelData))

                    StyledText {
                        anchors.centerIn: parent
                        text: sizeChip.modelData
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        color: sizeChip.current ? Colors.on_primary : Colors.on_surface
                    }
                }
            }
        }

        // "Match theme": hands the key back to the colour theme
        ClickableRect {
            id: follow
            readonly property bool current: tab.st !== null && !tab.mine(tab.cat)
            width: pane.width
            height: 52
            radius: Services.DesktopTheme.rad(16)
            color: current ? Colors.primary_container : follow.hovered ? Colors.surface_container_high : Colors.surface_container
            border.width: current ? 2 : 0
            border.color: Colors.primary
            cursorShape: Qt.PointingHandCursor
            onClicked: tab.set(tab.cat, "")

            Glyph {
                id: followIcon
                x: 16
                anchors.verticalCenter: parent.verticalCenter
                text: "palette"
                filled: follow.current
                font.pixelSize: 22
                color: follow.current ? Colors.on_primary_container : Colors.on_surface_variant
            }

            Column {
                x: followIcon.x + followIcon.width + 12
                width: follow.width - x - 16
                anchors.verticalCenter: parent.verticalCenter

                StyledText {
                    text: "Match theme"
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    color: follow.current ? Colors.on_primary_container : Colors.on_surface
                }

                StyledText {
                    width: parent.width
                    text: tab.st ? tab.label(tab.themeValue(tab.cat)) + (tab.st.look[tab.cat] ? " — from " + tab.st.theme : " — the default") : ""
                    elide: Text.ElideRight
                    font.pixelSize: 11
                    color: follow.current ? Colors.withAlpha(Colors.on_primary_container, 0.8) : Colors.on_surface_variant
                }
            }
        }

        // quick picks: a short list of the best choices for this category
        // (dots-appearance PICKS), one click each
        Column {
            id: picks
            readonly property var items: tab.lists && tab.lists.picks && tab.lists.picks[tab.cat] ? tab.lists.picks[tab.cat] : []
            width: pane.width
            visible: items.length > 0
            height: visible ? implicitHeight : 0
            spacing: 6

            StyledText {
                text: "Quick picks"
                font.pixelSize: 11
                font.weight: Font.DemiBold
                color: Colors.on_surface_variant
            }

            Flow {
                width: parent.width
                spacing: 8

                Repeater {
                    model: picks.items

                    ClickableRect {
                        id: pick
                        required property string modelData
                        readonly property bool inUse: tab.eff(tab.cat) === modelData
                        readonly property bool isFont: tab.cat === "font" || tab.cat === "mono"
                        width: pickText.implicitWidth + 24
                        height: 32
                        radius: Services.DesktopTheme.rad(16)
                        color: inUse ? Colors.primary : pick.hovered ? Colors.surface_container_high : Colors.surface_container
                        border.width: inUse ? 0 : 1
                        border.color: Colors.withAlpha(Colors.outline_variant, 0.6)
                        cursorShape: Qt.PointingHandCursor
                        onClicked: tab.set(tab.cat, modelData)

                        Behavior on color {
                            ColorAnimation { duration: 140 }
                        }

                        StyledText {
                            id: pickText
                            anchors.centerIn: parent
                            text: pick.modelData === "KvGlass#" ? "KvGlass (theme colours)" : pick.modelData
                            font.family: pick.isFont ? pick.modelData : font.family
                            font.pixelSize: pick.isFont ? 14 : 12
                            font.weight: Font.DemiBold
                            color: pick.inUse ? Colors.on_primary : Colors.on_surface
                        }
                    }
                }
            }
        }

        Loader {
            width: pane.width
            height: pane.height - tools.height - follow.height - picks.height - (picks.visible ? 3 : 2) * pane.spacing
            sourceComponent: !tab.lists ? loading : tab.cat === "gtk" || tab.cat === "kvantum" ? nameGrid
                : tab.cat === "icons" ? iconGrid : tab.cat === "cursor" ? cursorGrid : fontList
        }
    }

    Component {
        id: loading

        StyledText {
            text: "Looking for installed themes and fonts…"
            font.pixelSize: 13
            color: Colors.on_surface_variant
        }
    }

    // a card for one choice: marked when it's yours, outlined when it's what
    // the theme gave you
    component Choice: ClickableRect {
        id: choice
        property string key
        property string value
        readonly property bool inUse: tab.eff(key) === value
        readonly property bool picked: inUse && tab.mine(key)
        radius: Services.DesktopTheme.rad(16)
        color: picked ? Colors.primary_container : choice.hovered ? Colors.surface_container_high : Colors.surface_container
        border.width: inUse ? 2 : 0
        border.color: Colors.primary
        cursorShape: Qt.PointingHandCursor
        onClicked: tab.set(key, value)

        Behavior on color {
            ColorAnimation { duration: 140 }
        }
    }

    // GTK and Kvantum themes: just names ("KvGlass#" is KvGlass in the
    // colour theme's colours)
    Component {
        id: nameGrid

        GridView {
            id: nameView
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            readonly property string key: tab.cat
            cellWidth: width / Math.max(1, Math.floor(width / 230))
            cellHeight: 60
            model: tab.lists && tab.lists[key] ? tab.lists[key] : []

            delegate: Item {
                id: nameCell
                required property string modelData
                width: nameView.cellWidth
                height: nameView.cellHeight

                Choice {
                    id: nameCard
                    anchors.fill: parent
                    anchors.margins: 5
                    key: nameView.key
                    value: nameCell.modelData

                    Glyph {
                        id: nameIcon
                        x: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: nameView.key === "gtk" ? "web_asset" : "widgets"
                        filled: nameCard.inUse
                        font.pixelSize: 20
                        color: nameCard.picked ? Colors.on_primary_container : Colors.on_surface_variant
                    }

                    StyledText {
                        x: nameIcon.x + nameIcon.width + 10
                        width: nameCard.width - x - 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: nameCell.modelData === "KvGlass#" ? "KvGlass (theme colours)" : nameCell.modelData.replace(/-/g, " ")
                        elide: Text.ElideRight
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: nameCard.picked ? Colors.on_primary_container : Colors.on_surface
                    }
                }
            }
        }
    }

    Component {
        id: iconGrid

        GridView {
            id: iconView
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            cellWidth: width / Math.max(1, Math.floor(width / 230))
            cellHeight: 92
            model: tab.lists ? tab.lists.icons : []

            delegate: Item {
                id: iconCell
                required property var modelData
                width: iconView.cellWidth
                height: iconView.cellHeight

                Choice {
                    id: iconCard
                    anchors.fill: parent
                    anchors.margins: 5
                    key: "icons"
                    value: iconCell.modelData.id

                    StyledText {
                        x: 14
                        y: 10
                        width: iconCard.width - 28
                        text: iconCell.modelData.name
                        elide: Text.ElideRight
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: iconCard.picked ? Colors.on_primary_container : Colors.on_surface
                    }

                    Row {
                        x: 14
                        y: 38
                        spacing: 8

                        Repeater {
                            model: iconCell.modelData.previews.slice(0, 6)

                            Image {
                                required property string modelData
                                width: 26
                                height: 26
                                source: "file://" + modelData
                                sourceSize: Qt.size(52, 52)
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                smooth: true
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: cursorGrid

        GridView {
            id: cursorView
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            cellWidth: width / Math.max(1, Math.floor(width / 230))
            cellHeight: 60
            model: tab.lists ? tab.lists.cursors : []

            delegate: Item {
                id: cursorCell
                required property string modelData
                width: cursorView.cellWidth
                height: cursorView.cellHeight

                Choice {
                    id: cursorCard
                    anchors.fill: parent
                    anchors.margins: 5
                    key: "cursor"
                    value: cursorCell.modelData

                    Glyph {
                        id: cursorIcon
                        x: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: "arrow_selector_tool"
                        filled: true
                        font.pixelSize: 20
                        // Bibata's colour, from its name
                        color: /Amber/.test(cursorCell.modelData) ? "#ffb400"
                            : /Ice/.test(cursorCell.modelData) ? "#f2f2f2"
                            : /Classic/.test(cursorCell.modelData) ? "#111111"
                            : Colors.on_surface_variant
                        style: Text.Outline
                        styleColor: /Ice/.test(cursorCell.modelData) ? "#555555" : "#f2f2f2"
                    }

                    StyledText {
                        x: cursorIcon.x + cursorIcon.width + 10
                        width: cursorCard.width - x - 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: cursorCell.modelData.replace(/-/g, " ")
                        elide: Text.ElideRight
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: cursorCard.picked ? Colors.on_primary_container : Colors.on_surface
                    }
                }
            }
        }
    }

    Component {
        id: fontList

        ListView {
            id: list
            clip: true
            spacing: 6
            boundsBehavior: Flickable.StopAtBounds
            readonly property string key: tab.cat
            model: {
                if (!tab.lists) return [];
                const all = key === "mono" ? tab.lists.monos : tab.lists.fonts;
                const q = tab.query.trim().toLowerCase();
                return q === "" ? all : all.filter(f => f.toLowerCase().includes(q));
            }

            delegate: Choice {
                id: fontRow
                required property string modelData
                width: list.width
                height: 54
                key: list.key
                value: modelData

                StyledText {
                    x: 16
                    y: 8
                    width: fontRow.width * 0.36
                    text: fontRow.modelData
                    elide: Text.ElideRight
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: fontRow.picked ? Colors.on_primary_container : Colors.on_surface_variant
                }

                Text {
                    x: 16
                    y: 26
                    width: fontRow.width - 32
                    text: list.key === "mono" ? "fn main() { let x = 0O1lI; } // -> != =>" : "The quick brown fox jumps over the lazy dog · 0123"
                    elide: Text.ElideRight
                    font.family: fontRow.modelData
                    font.pixelSize: 16
                    color: fontRow.picked ? Colors.on_primary_container : Colors.on_surface
                }
            }
        }
    }
}
