import Quickshell
import Quickshell.Wayland

ShellRoot {
    LockTheme { id: lockTheme }

    LockContext {
        id: lockContext
        onUnlocked: {
            lock.locked = false
            Qt.quit()
        }
    }

    WlSessionLock {
        id: lock
        locked: true

        WlSessionLockSurface {
            LockSurface {
                anchors.fill: parent
                context: lockContext
                theme: lockTheme
            }
        }
    }
}
