import QtQuick
import Quickshell
import Quickshell.Services.Pam

Scope {
    id: root
    signal unlocked()

    property string currentText: ""
    property bool unlockInProgress: false
    property bool showFailure: false

    onCurrentTextChanged: showFailure = false

    property string errorText: ""

    function tryUnlock() {
        if (currentText === "" || unlockInProgress) return
        unlockInProgress = true
        if (!pam.start()) {
            unlockInProgress = false
            showFailure = true
            errorText = "PAM unavailable — press Ctrl+Alt+F2"
        }
    }

    PamContext {
        id: pam

        // security.pam.services.quickshell-lock in modules/lockscreen.nix
        config: "quickshell-lock"

        onPamMessage: {
            if (this.responseRequired) this.respond(root.currentText)
        }

        onCompleted: result => {
            if (result === PamResult.Success) {
                root.unlocked()
            } else {
                root.currentText = ""
                root.showFailure = true
                root.errorText = result === PamResult.Error
                    ? "PAM error — press Ctrl+Alt+F2"
                    : "incorrect password"
            }
            root.unlockInProgress = false
        }
    }
}
