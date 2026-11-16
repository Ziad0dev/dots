pragma Singleton
pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import QtQuick

// Settings for the parts ported from dhrruvsharma/shell (the wallpaper
// picker's folder and Wallhaven filters), kept apart from rise's own
// settings.json in ~/.local/state/dots/shell/ext/settings.json.
Singleton {
    id: root

    // The wallpaper folder the picker lists (recursively; sub-folders are its
    // chips) and where Wallhaven downloads go (into a "wallhaven" sub-folder).
    property alias wallpaperDir: settingsAdapter.wallpaperDir
    // "" = rise draws the wallpaper (needed for desktop themes and videos);
    // any other command takes the file in place of `{}`.
    property alias wallpaperCommand: settingsAdapter.wallpaperCommand
    property alias wallhavenApiKey: settingsAdapter.wallhavenApiKey
    property alias wallhavenCategories: settingsAdapter.wallhavenCategories
    property alias wallhavenPurity: settingsAdapter.wallhavenPurity
    property alias wallhavenSorting: settingsAdapter.wallhavenSorting
    property alias wallhavenOrder: settingsAdapter.wallhavenOrder
    property alias wallhavenTopRange: settingsAdapter.wallhavenTopRange
    property alias wallhavenAtleast: settingsAdapter.wallhavenAtleast
    property alias wallhavenRatios: settingsAdapter.wallhavenRatios
    // The picker's sub-folder chip ("" = every folder).
    property alias wallpaperSubdir: settingsAdapter.wallpaperSubdir
    property alias musicVisOn: settingsAdapter.musicVisOn

    Timer {
        id: writeTimer
        interval: 100
        onTriggered: settingsFile.writeAdapter()
    }

    Timer {
        id: reloadTimer
        interval: 100
        onTriggered: settingsFile.reload()
    }

    FileView {
        id: settingsFile
        path: Quickshell.env("HOME") + "/.local/state/dots/shell/ext/settings.json"
        watchChanges: true
        onFileChanged: reloadTimer.restart()
        onAdapterUpdated: writeTimer.restart()
        onLoadFailed: error => {
            if (error == FileViewError.FileNotFound)
                writeTimer.restart();
        }

        adapter: JsonAdapter {
            id: settingsAdapter
            property string wallpaperDir: "~/Pictures/wallpapers"
            property string wallpaperCommand: ""
            property string wallpaperSubdir: ""
            property bool musicVisOn: true
            property string wallhavenApiKey: ""
            property string wallhavenCategories: "111"
            property string wallhavenPurity: "100"
            property string wallhavenSorting: "toplist"
            property string wallhavenOrder: "desc"
            property string wallhavenTopRange: "1M"
            property string wallhavenAtleast: "2560x1440"
            property string wallhavenRatios: ""
        }
    }
}
