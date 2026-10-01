import os
import signal
import subprocess
import sys

RUN = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
PIDFILE = os.path.join(RUN, "dots-say.pid")
VOICE = os.environ.get("DOTS_SAY_VOICE", "af_heart")
SPEED = float(os.environ.get("DOTS_SAY_SPEED", "1.0"))
RATE = 24000


def notify(*args):
    subprocess.run(["notify-send", "-a", "dots-say", "-h", "string:x-canonical-private-synchronous:dots-say", *args], check=False)


def running_pid():
    try:
        with open(PIDFILE) as f:
            pid = int(f.read().strip())
        with open(f"/proc/{pid}/cmdline", "rb") as f:
            if b"dots-say" in f.read():
                return pid
    except (OSError, ValueError):
        pass
    return None


def stop():
    pid = running_pid()
    if pid:
        os.kill(pid, signal.SIGTERM)
    return pid is not None


def read_text(args):
    if args:
        return " ".join(args)
    if not sys.stdin.isatty():
        return sys.stdin.read()
    for cmd in (["wl-paste", "--primary", "--no-newline"], ["wl-paste", "--no-newline"]):
        r = subprocess.run(cmd, capture_output=True, text=True, check=False)
        if r.returncode == 0 and r.stdout.strip():
            return r.stdout
    return ""


def speak(text):
    from kokoro import KPipeline

    pipeline = KPipeline(lang_code=VOICE[0], repo_id="hexgrad/Kokoro-82M")
    player = subprocess.Popen(
        ["pw-play", "--raw", "--format", "f32", "--rate", str(RATE), "--channels", "1", "-"],
        stdin=subprocess.PIPE,
    )

    def bye(*_):
        player.kill()
        sys.exit(0)

    signal.signal(signal.SIGTERM, bye)
    try:
        for _, _, audio in pipeline(text, voice=VOICE, speed=SPEED):
            if audio is None:
                continue
            data = audio.numpy() if hasattr(audio, "numpy") else audio
            player.stdin.write(data.astype("float32").tobytes())
            player.stdin.flush()
        player.stdin.close()
        player.wait()
    except BrokenPipeError:
        pass


def main():
    args = sys.argv[1:]
    if args[:1] == ["stop"]:
        stop()
        return
    toggle = args[:1] == ["toggle"]
    if toggle:
        args = args[1:]
        if stop():
            return
    text = read_text(args).strip()
    if not text:
        notify("Text to speech", "nothing selected")
        sys.exit(1)
    stop()
    with open(PIDFILE, "w") as f:
        f.write(str(os.getpid()))
    try:
        if toggle:
            notify("Speaking", text[:120])
        speak(text)
    finally:
        if running_pid() == os.getpid():
            os.unlink(PIDFILE)


if __name__ == "__main__":
    main()
