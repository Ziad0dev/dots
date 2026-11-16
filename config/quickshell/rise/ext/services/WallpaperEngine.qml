pragma Singleton
pragma ComponentBehavior: Bound
// Ported from dhrruvsharma/shell (quickshell/services/WallpaperEngine.qml), GPL-3.0-or-later.
import Quickshell
import Quickshell.Io
import QtQuick
import qs.ext.settings

// The wallpaper, drawn by rise itself (modules/wallpaper/WallpaperLayer, with
// the desktop theme's layer over it) instead of awww. The dots theme stays
// the source of truth:
//   - set(path): the picker's choice. Shown at once, then handed to
//     `themectl bg set`, which records it, re-derives the auto theme's colours
//     and blurs the login greeter's copy; scripts/wallpaper-apply keeps the
//     still the lock screens read.
//   - show(path): display only. dots-set-wallpaper calls it over IPC
//     (`qs -c rise ipc call wallpaper display <path>`) for every wallpaper change
//     made elsewhere (themectl, a theme's own background) and draws with awww
//     only when this answers false.
// With a wallpaper command set (the picker's settings, e.g. `awww img {}`)
// another program draws the wallpaper instead: WallpaperLayer makes no
// windows, and set() runs the command with the file in place of `{}`.
Singleton {
    id: root

    // The wallpaper folder (the picker's setting), as an absolute path.
    readonly property string dir: expandHome(SettingsConfig.wallpaperDir).replace(/\/+$/, "") || Quickshell.env("HOME") + "/Pictures/wallpapers"
    // The folder with its links resolved (dots-current-wallpaper names the
    // real file), for matching the wallpaper on screen to a card.
    property string realDir: ""
    readonly property string link: Quickshell.env("HOME") + "/.cache/current_wallpaper"
    readonly property string sourceLink: Quickshell.env("HOME") + "/.cache/current_wallpaper_source"

    // The wallpaper command ("" when Quickshell draws the wallpaper).
    readonly property string command: SettingsConfig.wallpaperCommand.trim()
    readonly property bool external: command !== ""
    // Why the last run of the command failed ("" when it didn't).
    property string commandError: ""

    // Each run of the command: ok, or not with the reason.
    signal commandFinished(bool ok, string message)

    // Absolute path of the wallpaper on screen ("" until the link is read).
    property string current: ""
    // Bumped on every change; layers run their transition on it.
    property int serial: 0
    property bool ready: false

    signal changed(string path)

    // What a file is drawn as: "video", "animated" (GIF/WebP, which may
    // still be one frame) or "image".
    function kind(path) {
        const p = String(path ?? "").toLowerCase();
        if (/\.(mp4|webm|mkv|mov|m4v)$/.test(p))
            return "video";
        if (/\.(gif|webp)$/.test(p))
            return "animated";
        return "image";
    }

    // "~" and "~/…" to absolute paths.
    function expandHome(path) {
        const p = String(path ?? "").trim();
        if (p === "~" || p.startsWith("~/"))
            return Quickshell.env("HOME") + p.substring(1);
        return p;
    }

    // A path the other way round, for showing.
    function tildeHome(path) {
        const home = Quickshell.env("HOME");
        return path === home || path.startsWith(home + "/") ? "~" + path.substring(home.length) : path;
    }

    function resolve(path) {
        let p = expandHome(String(path ?? "").trim().replace(/^file:\/\//, ""));
        if (p.length > 0 && !p.startsWith("/"))
            p = dir + "/" + p;
        return p;
    }

    function set(path) {
        const p = resolve(path);
        if (!p)
            return;
        show(p);
        if (external)
            runCommand(p);
        Quickshell.execDetached(["themectl", "bg", "set", p]);
    }

    // Display only (see the top). True when rise is the one drawing it.
    function show(path) {
        const p = resolve(path);
        if (p && p !== current) {
            current = p;
            serial++;
            changed(p);
            apply.exec([Quickshell.shellPath("ext/scripts/wallpaper-apply"), p]);
        }
        return !external;
    }

    // The command as a script taking the file as $1: each `{}` becomes it,
    // quoted for wherever the `{}` stands (bare, in "…" or in '…'), and with
    // no `{}` the file goes last.
    function fileInCommand(cmd) {
        let out = "";
        let quote = "";
        let found = false;
        for (let i = 0; i < cmd.length; i++) {
            const c = cmd[i];
            if (c === "{" && cmd[i + 1] === "}") {
                found = true;
                i++;
                out += quote === "'" ? "'\"$1\"'" : quote === "\"" ? "$1" : "\"$1\"";
                continue;
            }
            if (c === "\\" && quote !== "'") {
                out += c + (cmd[i + 1] ?? "");
                i++;
                continue;
            }
            if (quote === "" && (c === "'" || c === "\""))
                quote = c;
            else if (c === quote)
                quote = "";
            out += c;
        }
        return found ? out : out + ' "$1"';
    }

    // Runs the wallpaper command on a file (see fileInCommand). A command still
    // running after two seconds is taken for a daemon (swaybg, mpvpaper) and
    // left running on its own; one that ends sooner reports how it went.
    function runCommand(path) {
        if (!external || !path)
            return;
        const cmd = fileInCommand(command);
        // Prints "<exit code>\t<last line of its errors>" when it's done.
        const script = 'err=$(mktemp)\n'
            + '{ ' + cmd + '\n} </dev/null >/dev/null 2>"$err" &\n'
            + 'pid=$!\n'
            + 'for i in $(seq 20); do kill -0 $pid 2>/dev/null || break; sleep 0.1; done\n'
            + 'if kill -0 $pid 2>/dev/null; then code=0; else wait $pid; code=$?; fi\n'
            + 'printf "%s\\t%s" "$code" "$(grep . "$err" | tail -n 1)"; rm -f "$err"\n';
        commandRun.exec(["sh", "-c", script, "sh", path]);
    }

    Process {
        id: commandRun
        stdout: StdioCollector {
            onStreamFinished: {
                const tab = text.indexOf("\t");
                const code = parseInt(text.substring(0, tab));
                const ok = code === 0;
                root.commandError = ok ? "" : text.substring(tab + 1).trim() || "exit code " + code;
                if (!ok)
                    console.warn("wallpaper command:", root.commandError);
                root.commandFinished(ok, root.commandError);
            }
        }
    }

    Process {
        id: apply
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    console.warn("wallpaper:", text.trim());
            }
        }
    }

    Process {
        running: true
        command: ["readlink", "-f", root.dir]
        stdout: StdioCollector {
            onStreamFinished: root.realDir = text.trim()
        }
    }

    // What the dots theme says is on screen (its state link).
    Process {
        running: true
        command: ["dots-current-wallpaper"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim();
                if (!root.current && p) {
                    root.current = p;
                    apply.exec([Quickshell.shellPath("ext/scripts/wallpaper-apply"), p]);
                    // Tools that don't remember (swaybg, hyprpaper) get
                    // last session's wallpaper back.
                    root.runCommand(p);
                }
                root.ready = true;
            }
        }
    }
}
