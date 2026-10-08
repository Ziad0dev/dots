pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

// rise: chat with the local model that's running (after dhrruvsharma/shell's
// OllamaService, which only spoke Ollama). Whatever dots-llm has up — a
// llama.cpp server on :8080 or Ollama on :11434 — is talked to over the
// OpenAI-compatible API (/v1/models, /v1/chat/completions, streamed as SSE),
// so one panel covers every backend in modules/llm.nix and ollama.nix. With
// none up, the panel can wake one (systemctl start, allowed by llm.nix's
// polkit rule). The conversation lives here, so closing the panel keeps it.
Singleton {
    id: root

    // dots-llm's backends that chat (llama-fim only completes code)
    readonly property var units: ["llama-cpp", "llama-uncensored", "llama-hermes", "llama-sec", "llama-agent", "llama-gemma", "llama-coder", "ollama"]
    property var unitInfo: ({})         // unit -> description
    property string backend: ""          // the running unit, "" = none
    property bool waking: false          // started, waiting for it to answer
    property bool ready: false           // /v1/models answered
    property var models: []
    property string model: ""

    readonly property string baseUrl: backend === "ollama" ? "http://127.0.0.1:11434/v1" : "http://127.0.0.1:8080/v1"

    // [{ role: "user" | "assistant" | "error", content, thinking }]
    // (`thinking`: what a reasoning model streams before its answer)
    property var messages: []
    property bool streaming: false
    property string error: ""

    function refresh() {
        statusProc.running = true;
    }

    function wake(unit) {
        if (units.indexOf(unit) < 0)
            return;
        error = "";
        waking = true;
        ready = false;
        Quickshell.execDetached(["sh", "-c", "dots-llm off; systemctl start \"$1.service\"", "sh", unit]);
        backend = unit;
        waitTimer.tries = 0;
        waitTimer.restart();
    }

    function sleep() {
        cancel();
        Quickshell.execDetached(["dots-llm", "off"]);
        backend = "";
        ready = false;
        models = [];
    }

    function clear() {
        cancel();
        messages = [];
        error = "";
    }

    function send(text) {
        text = String(text || "").trim();
        if (!text || streaming || !ready)
            return;
        const history = messages.filter(m => m.role !== "error").map(m => ({ role: m.role, content: m.content }));
        history.push({ role: "user", content: text });
        messages = messages.concat([{ role: "user", content: text }, { role: "assistant", content: "", thinking: "" }]);
        streaming = true;
        error = "";
        const body = JSON.stringify({ model: model || "default", messages: history, stream: true });
        // The body goes in as an argument ($2), so it needs no quoting. Only
        // the `data:` lines are passed on: SSE puts a blank line after each,
        // and SplitParser dropped the line after every blank one.
        chatProc.command = ["bash", "-c", "set -o pipefail; curl -sN --fail-with-body -X POST \"$1/chat/completions\" -H 'Content-Type: application/json' --data-binary \"$2\" | grep --line-buffered '^data:'",
            "bash", baseUrl, body];
        chatProc.running = true;
    }

    function cancel() {
        if (chatProc.running)
            chatProc.running = false;
        streaming = false;
    }

    function _append(token, thought) {
        const next = messages.slice();
        const last = next[next.length - 1];
        next[next.length - 1] = {
            role: "assistant",
            content: last.content + (thought ? "" : token),
            thinking: (last.thinking || "") + (thought ? token : "")
        };
        messages = next;
    }

    // which backend is up, and their descriptions (once)
    Process {
        id: statusProc
        command: ["sh", "-c", "dots-llm status; for u in \"$@\"; do printf '%s\\t%s\\n' \"$u\" \"$(systemctl show -p Description --value \"$u.service\" 2>/dev/null)\"; done", "sh"].concat(root.units)
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                const status = (lines.shift() || "").trim();
                const info = {};
                for (const l of lines) {
                    const tab = l.indexOf("\t");
                    if (tab > 0)
                        info[l.substring(0, tab)] = l.substring(tab + 1);
                }
                root.unitInfo = info;
                if (root.waking)
                    return;
                root.backend = root.units.indexOf(status) >= 0 ? status : "";
                if (root.backend)
                    modelsProc.running = true;
                else
                    root.ready = false;
            }
        }
    }

    // the backend's models: answering means it's loaded and listening
    Process {
        id: modelsProc
        command: ["curl", "-sf", "-m", "3", root.baseUrl + "/models"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const ids = (JSON.parse(text).data || []).map(m => m.id);
                    root.models = ids;
                    if (ids.indexOf(root.model) < 0)
                        root.model = ids[0] || "";
                    root.ready = true;
                    root.waking = false;
                } catch (e) {
                    root.ready = false;
                }
            }
        }
    }

    // after a wake: poll until it answers (loading weights takes a while)
    Timer {
        id: waitTimer
        property int tries: 0
        interval: 1500
        repeat: true
        onTriggered: {
            if (root.ready || tries++ > 120) {
                stop();
                if (!root.ready) {
                    root.waking = false;
                    root.error = root.backend + " didn't answer; is the model there?";
                }
                return;
            }
            modelsProc.running = true;
        }
    }

    Process {
        id: chatProc
        stdout: SplitParser {
            onRead: line => {
                if (!line.startsWith("data:"))
                    return;
                const data = line.substring(5).trim();
                if (data === "[DONE]")
                    return;
                try {
                    const delta = JSON.parse(data).choices?.[0]?.delta ?? {};
                    if (delta.reasoning_content)
                        root._append(delta.reasoning_content, true);
                    if (delta.content)
                        root._append(delta.content, false);
                } catch (e) {}
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim()) root.error = text.trim()
        }
        onExited: code => {
            root.streaming = false;
            const last = root.messages[root.messages.length - 1];
            if (code !== 0 && last && last.role === "assistant" && last.content === "" && !last.thinking) {
                const next = root.messages.slice(0, -1);
                next.push({ role: "error", content: root.error || "The oracle is silent (curl exit " + code + ")" });
                root.messages = next;
            }
        }
    }
}
