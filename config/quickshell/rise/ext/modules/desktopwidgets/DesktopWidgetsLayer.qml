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

    WidgetWindow {
        widgetId: "calendar"
        widget: Component { CalendarWidget {} }
    }

    WidgetWindow {
        widgetId: "progress"
        widget: Component { ProgressWidget {} }
    }

    WidgetWindow {
        widgetId: "timer"
        widget: Component { TimerWidget {} }
    }

    WidgetWindow {
        widgetId: "lyrics"
        widget: Component { LyricsWidget {} }
    }

    WidgetWindow {
        widgetId: "weather"
        widget: Component { WeatherDeskWidget {} }
    }

    WidgetWindow {
        widgetId: "glance"
        widget: Component { GlanceWidget {} }
    }

    WidgetWindow {
        widgetId: "network"
        widget: Component { NetworkDeskWidget {} }
    }

    WidgetWindow {
        widgetId: "devices"
        widget: Component { DevicesWidget {} }
    }

    WidgetWindow {
        widgetId: "note"
        wantsKeyboard: true
        widget: Component { NoteWidget {} }
    }

    WidgetWindow {
        widgetId: "todo"
        wantsKeyboard: true
        widget: Component { TodoWidget {} }
    }

    WidgetWindow {
        widgetId: "toggles"
        widget: Component { TogglesWidget {} }
    }

    WidgetWindow {
        widgetId: "shortcuts"
        widget: Component { ShortcutsWidget {} }
    }
}
