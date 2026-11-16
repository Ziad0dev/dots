pragma ComponentBehavior: Bound
// Ported from dhrruvsharma/shell (quickshell/modules/desktopwidgets/DesktopWidgetsLayer.qml), GPL-3.0-or-later.
import QtQuick
import Quickshell

// The desktop widgets, each in its own draggable surface (WidgetWindow).
// Which are on and where they sit: services/DesktopWidgets. The visualizer
// lives in modules/cava/CavaWidget.qml.
Scope {
    WidgetWindow {
        widgetId: "clock"
        widget: Component { ClockWidget {} }
    }

    WidgetWindow {
        widgetId: "music"
        widget: Component { MusicWidget {} }
    }

    WidgetWindow {
        widgetId: "sysmon"
        widget: Component { SysmonWidget {} }
    }

    WidgetWindow {
        widgetId: "quote"
        widget: Component { QuoteWidget {} }
    }
}
