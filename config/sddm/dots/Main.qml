import QtQuick

Item {
    id: root
    width: 1920
    height: 1080

    property color cBg: config.background || "#161616"
    property color cFg: config.foreground || "#f2f4f8"
    property color cAccent: config.accent || "#ee5396"
    property color cError: config.error || "#ee5396"
    property color cWarn: config.warn || "#ffe97b"
    property string uiFont: config.font || "JetBrainsMono Nerd Font"
    property string wallpaper: config.wallpaper || ""
    property string logo: config.logo || ""

    readonly property color cDim: mix(cFg, cBg, 0.35)
    readonly property color cMuted: mix(cFg, cBg, 0.60)
    readonly property color cSurface: mix(cBg, cFg, 0.08)

    property date now: new Date()
    property bool busy: false
    property bool failed: false
    property string message: ""
    property int currentSession: sessionModel.lastIndex
    property int currentUser: 0
    property string sessionName: ""
    property string userName: ""

    function mix(a, b, w) {
        return Qt.rgba(a.r + (b.r - a.r) * w,
                       a.g + (b.g - a.g) * w,
                       a.b + (b.b - a.b) * w, 1)
    }

    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a)
    }

    function loadOverride() {
        try {
            var x = new XMLHttpRequest()
            x.open("GET", "file:///var/lib/dots-theme/sddm.json", false)
            x.send()
            var j = JSON.parse(x.responseText)
            if (j.background) cBg = j.background
            if (j.foreground) cFg = j.foreground
            if (j.accent) cAccent = j.accent
            if (j.error) cError = j.error
            if (j.warn) cWarn = j.warn
        } catch (e) {
        }
    }

    function refresh() {
        var s = sessions.itemAt(currentSession)
        sessionName = s ? s.sname : ""
        var u = users.itemAt(currentUser)
        userName = u ? u.uname : ""
    }

    function cycleSession() {
        if (sessions.count < 2)
            return
        currentSession = (currentSession + 1) % sessions.count
        refresh()
    }

    function cycleUser() {
        if (users.count < 2)
            return
        currentUser = (currentUser + 1) % users.count
        refresh()
        pw.text = ""
        pw.forceActiveFocus()
    }

    function doLogin() {
        if (busy || pw.text.length === 0)
            return
        busy = true
        failed = false
        message = ""
        sddm.login(userName, pw.text, currentSession)
    }

    Component.onCompleted: {
        loadOverride()
        for (var i = 0; i < users.count; i++) {
            if (users.itemAt(i).uname === userModel.lastUser) {
                currentUser = i
                break
            }
        }
        refresh()
        pw.forceActiveFocus()
    }

    Repeater {
        id: sessions
        model: sessionModel
        Item {
            property string sname: model.name
        }
    }

    Repeater {
        id: users
        model: userModel
        Item {
            property string uname: model.name
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    Connections {
        target: sddm
        function onLoginSucceeded() {
            root.busy = false
        }
        function onLoginFailed() {
            root.busy = false
            root.failed = true
            root.message = "authentication failed"
            pw.text = ""
            pw.forceActiveFocus()
        }
        function onInformationMessage(msg) {
            root.message = msg
        }
    }

    Rectangle {
        anchors.fill: parent
        color: root.cBg
    }

    Image {
        anchors.fill: parent
        visible: root.wallpaper !== ""
        source: root.wallpaper
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 520
        height: 520
        radius: 26
        color: root.alpha(root.cBg, 0.85)
        border.width: 2
        border.color: root.alpha(root.cAccent, 0.35)
    }

    Column {
        anchors.centerIn: card
        width: card.width
        spacing: 0

        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.logo !== ""
            source: root.logo
            sourceSize.height: 118
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        Item {
            width: 1
            height: root.logo !== "" ? 22 : 0
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 0

            Text {
                text: Qt.formatDateTime(root.now, "HH")
                color: root.cFg
                font.family: root.uiFont
                font.pixelSize: 84
                font.weight: Font.Black
            }

            Text {
                text: Qt.formatDateTime(root.now, ":mm")
                color: root.cAccent
                font.family: root.uiFont
                font.pixelSize: 84
                font.weight: Font.ExtraLight
            }
        }

        Item {
            width: 1
            height: 12
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 300
            height: 2
            radius: 1
            color: root.alpha(root.cAccent, 0.6)
        }

        Item {
            width: 1
            height: 14
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(root.now, "dddd, dd MMMM")
            color: root.cDim
            font.family: root.uiFont
            font.pixelSize: 15
        }

        Item {
            width: 1
            height: 28
        }

        Rectangle {
            id: field
            anchors.horizontalCenter: parent.horizontalCenter
            width: 300
            height: 46
            radius: 12
            color: root.cSurface
            border.width: 2
            border.color: root.failed ? root.cError
                                      : capsOn ? root.cWarn
                                               : pw.activeFocus ? root.cAccent
                                                                : root.alpha(root.cMuted, 0.6)

            readonly property bool capsOn: typeof keyboard !== "undefined" && keyboard.capsLock

            Behavior on border.color {
                ColorAnimation {
                    duration: 120
                }
            }

            TextInput {
                id: pw
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                verticalAlignment: TextInput.AlignVCenter
                horizontalAlignment: TextInput.AlignHCenter
                echoMode: TextInput.Password
                passwordCharacter: "\u2022"
                passwordMaskDelay: 0
                clip: true
                enabled: !root.busy
                color: root.cFg
                font.family: root.uiFont
                font.pixelSize: 15
                selectByMouse: true
                onAccepted: root.doLogin()
                onTextChanged: root.failed = false
                Keys.onEscapePressed: text = ""
            }

            Text {
                anchors.centerIn: parent
                visible: pw.text.length === 0
                text: root.userName
                color: root.cMuted
                font.family: root.uiFont
                font.pixelSize: 15
            }
        }

        Item {
            width: 1
            height: 14
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.busy ? "…" : field.capsOn ? "caps lock" : root.message
            color: root.failed ? root.cError : field.capsOn ? root.cWarn : root.cMuted
            font.family: root.uiFont
            font.pixelSize: 12
        }
    }

    Row {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 26
        spacing: 16

        Text {
            text: root.userName
            color: users.count > 1 ? root.cDim : root.cMuted
            font.family: root.uiFont
            font.pixelSize: 12

            MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                enabled: users.count > 1
                cursorShape: Qt.PointingHandCursor
                onClicked: root.cycleUser()
            }
        }

        Text {
            text: "\uf0a9  " + root.sessionName
            color: sessions.count > 1 ? root.cDim : root.cMuted
            font.family: root.uiFont
            font.pixelSize: 12

            MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                enabled: sessions.count > 1
                cursorShape: Qt.PointingHandCursor
                onClicked: root.cycleSession()
            }
        }
    }

    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 26
        spacing: 22

        Repeater {
            model: [
                {
                    "glyph": "\uf186",
                    "show": sddm.canSuspend,
                    "act": "suspend"
                },
                {
                    "glyph": "\uf021",
                    "show": sddm.canReboot,
                    "act": "reboot"
                },
                {
                    "glyph": "\uf011",
                    "show": sddm.canPowerOff,
                    "act": "poweroff"
                }
            ]

            Text {
                required property var modelData
                visible: modelData.show
                text: modelData.glyph
                color: hover.containsMouse ? root.cAccent : root.cMuted
                font.family: root.uiFont
                font.pixelSize: 17

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }

                MouseArea {
                    id: hover
                    anchors.fill: parent
                    anchors.margins: -8
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (parent.modelData.act === "suspend")
                            sddm.suspend()
                        else if (parent.modelData.act === "reboot")
                            sddm.reboot()
                        else
                            sddm.powerOff()
                    }
                }
            }
        }
    }
}
