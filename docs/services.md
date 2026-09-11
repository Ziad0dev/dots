# Services

## Ports

Nothing listens on the LAN except Jellyfin and mDNS. Everything else is loopback, the tailnet, or inside the VPN namespace.

| Service | Address | Reachable from |
|---|---|---|
| Jellyfin | `:8096` http, `:8920` https | LAN (`enp5s0`) and tailnet (`tailscale0`) |
| qBittorrent web UI | `:8081` in namespace `wg` | tailnet via port mapping; host at `http://192.168.15.1:8081` |
| Prowlarr | `:9696` in namespace `wg` | tailnet via port mapping; host at the namespace address |
| FlareSolverr | `127.0.0.1:8191` in namespace `wg` | Prowlarr only |
| Radarr / Sonarr | `:7878` / `:8989` | host only (firewall closed) |
| Audiobookshelf | `127.0.0.1:8000` | host |
| calibre-web | `127.0.0.1:8083` | host |
| llama.cpp units | `127.0.0.1:8080` | host |
| llama-fim | `127.0.0.1:8012` | host |
| Ollama | `127.0.0.1:11434` | host |
| MPD | `127.0.0.1:6600` (socket-activated) | host |
| hello-page | `127.0.0.1:8137` → `tailscale serve` on 443 | tailnet (HTTPS) |
| Avahi | `:5353/udp` | LAN |
| claude-vm | `127.0.0.1:2222` (ssh), `:5173`, `:3000` | host, while the VM runs |

## Media

`/mnt/media` is a 10 TB exFAT drive (`modules/media.nix`) mounted with the user as owner and gid 3000 (`media`), `dmask=0002` / `fmask=0113` so the whole media group can write. It's `nofail` + `x-systemd.automount`; every unit that touches it has `RequiresMountsFor = /mnt/media`, so services wait for the drive instead of writing into an empty mountpoint.

| Service | Notes |
|---|---|
| **Jellyfin** | NVENC. Decode: h264, hevc, hevc10, vp8, vp9, av1, mpeg2, vc1. Encode: HEVC on, AV1 off. Tone mapping on, transcode throttling on, CRF 21 (h264) / 26 (h265). `DeviceAllow` adds `nvidia0`, `nvidia-uvm(-tools)`, `nvidia-modeset`. `forceEncodingConfig = true` — encoding settings changed in the web UI are overwritten on restart; change them in Nix |
| **Radarr / Sonarr** | group `media`, `lib/hardening.nix` with `ReadWritePaths = /mnt/media` |
| **Audiobookshelf** | loopback only, group `media`, hardened |
| **calibre-web** | loopback only, library at `/mnt/media/books`, uploads disabled. `GOOGLE_BOOKS_API_KEY` (optional) comes from secretspec |
| **MPD** | user service (`home/profiles/linux-desktop.nix`), music at `/mnt/media/music`. Two outputs: PipeWire (default) and a bit-perfect ALSA output on `hw:CARD=G30` (disabled; switch with `mpc enable only 2`, back with `mpc enable only 1`). Clients: rmpc, mpdris2 for media keys |

## VPN namespace

`modules/vpn.nix`, using [VPN-Confinement](https://github.com/Maroka-chan/VPN-Confinement).

```
            tailnet 100.64.0.0/10
                    │  port mappings 8081, 9696
host ─── bridge ────┤
                    ▼
      ┌─ netns "wg" ── WireGuard (Mullvad) ── internet
      │   qbittorrent  :8081   torrent port 51413
      │   prowlarr     :9696
      │   flaresolverr 127.0.0.1:8191
      └─
```

- The namespace is built from `/etc/wireguard/mullvad.conf` (not in the repo). `wg-dns` runs before `wg.service` and rewrites the file's `DNS =` line to Mullvad's resolver `100.64.0.7`, so lookups inside the namespace never leave the tunnel.
- `accessibleFrom = [ tailnet ]` routes replies to tailnet clients back out of the bridge instead of into the tunnel.
- A firewall rule drops forwarded traffic to 8081/9696 unless it came in on `tailscale0` — the mappings are tailnet-only, not LAN.
- **qBittorrent** runs as its own system user in group `media`, saves to `/mnt/media/.incoming`, no UPnP, pauses at ratio 2 or after 24 h seeding, `MemoryHigh = 2G`. Web UI auth is skipped for the namespace subnet (`192.168.15.0/24`); the host reaches it at `http://192.168.15.1:8081`, which is what the bar's `dots-qbt` widget polls.
- **Prowlarr** is hardened with `lib/hardening.nix`.
- **FlareSolverr** gets a browser-friendly variant of the hardening (Chromium needs namespaces and devices) and waits for DNS inside the tunnel before starting.

Check confinement from inside the namespace:

```fish
sudo ip netns exec wg curl -s https://am.i.mullvad.net/connected
```

Mullvad for the host itself is separate (`modules/mullvad.nix`, the GUI and `dots-vpn` toggle).

## Local LLMs

`modules/llm.nix` + `modules/ollama.nix`. Models live on `/data/models`.

| Unit | Model | Port | For |
|---|---|---|---|
| `llama-cpp` | Qwen3.5-9B Q6_K | 8080 | general / coding / maths |
| `llama-sec` | WhiteRabbitNeo V3 7B Q5_K_M | 8080 | security |
| `llama-agent` | Qwen2.5-Coder-14B-Instruct Q4_K_M | 8080 | tool calling |
| `llama-gemma` | Gemma 4 12B Q4_K_M | 8080 | general, vision, audio |
| `llama-coder` | Gemma 4 26B-A4B MoE Q4_K_M | 8080 | coding / agentic — 10 expert layers on CPU, q8_0 KV cache |
| `llama-fim` | Qwen2.5-Coder-3B Q8_0 | 8012 | llama.vim fill-in-the-middle |
| `ollama` | `/data/models/ollama` | 11434 | trying models quickly |

How they behave:

- **Vulkan** build of llama.cpp (`llama-cpp-vulkan`) — cached, unlike the CUDA build. All layers on GPU (`-ngl 99`), 16k context, flash attention, `--jinja` chat templates.
- **One at a time.** Every llama unit `Conflicts=` every other llama unit, so starting one stops the last. Before starting, `free-gpu` asks Ollama to unload whatever it holds. Ollama keeps at most one model loaded and drops it after 5 minutes idle.
- **Never at boot.** `wantedBy` is forced empty on all of them, Ollama included.
- **No sudo.** A polkit rule lets your active local session start and stop these units.
- **Sandboxed.** The llama units run as `DynamicUser` with `ProtectHome`, `ProtectSystem=strict`, no capabilities and `MemoryDenyWriteExecute`. GGUF files must be world-readable.

```fish
systemctl start llama-coder      # swap models
dots-llm next                    # cycle, same as the bar widget
dots-llm off
gpu-check                        # which llama unit is up + ollama ps
gpu-free                         # stop all llama units
```

## Backups

`modules/backup.nix` — restic, `$HOME` → `/mnt/backup/restic`, daily (persistent, up to 1 h random delay).

- Excludes caches, Steam, flatpak and container storage, Downloads, Trash, and build junk (`node_modules`, `target`, `zig-cache`, `zig-out`, `.venv`, `.direnv`, `__pycache__`).
- Retention: 7 daily, 4 weekly, 6 monthly. Each run checks a random 5 % of pack data.
- Skips cleanly when the backup drive isn't mounted; runs at nice 19, idle I/O.
- Password at `/etc/restic/password`; the unit refuses to start if the file is empty.

```fish
sudo systemctl start restic-backups-home
journalctl -u restic-backups-home -e
sudo restic-home snapshots        # wrapper with repo + password preset
```

## Storage

| Mount | What | Mounted as |
|---|---|---|
| `/` | LUKS, ext4 | |
| `/data` | LUKS2 ext4, unlocked after root by keyfile (crypttab), `nofail` | games, models, VMs, replays |
| `/mnt/media` | exFAT 10 TB | user:media, group-writable, automount, visible in file managers |
| `/mnt/backup` | exFAT | root:root `0077`, automount (10 min idle), hidden from file managers |
| `/mnt/newvolume` | exFAT | user:users, automount (10 min idle) |

exFAT has no permissions, so ownership comes from mount options. udiskie ignores all three external drives by UUID — they belong to systemd — but still automounts real removable media. `dots-mounts` (the bar's storage alert) reports any of `/data /mnt/media /mnt/backup /mnt/newvolume` whose mount or automount unit isn't healthy.

`/data` directories are created by tmpfiles rules in the modules that use them: `/data/games` (gaming), `/data/models` and `/data/models/ollama` (LLM), `/data/vms` and `/data/vms/iso` (virt), `/data/replays` (recording).

## Flatpak

`modules/flatpak.nix` declares remotes and apps; the `flatpak-managed` user unit reconciles at login.

- Remotes: Flathub and NVIDIA's GeForce NOW repo.
- Apps: GeForce NOW, Foliate, Flatseal, Bottles, F3D, MeshLab, Blender, Simple Scan, Kdenlive, TeXstudio.
- It installs anything listed and **uninstalls any user app that isn't** — add apps here, not with `flatpak install`.
- GeForce NOW gets `SDL_VIDEODRIVER=x11`. The desktop profile exports `SDL_VIDEODRIVER=wayland` globally, flatpak inherits it, and SDL2's Wayland backend can't capture the mouse — aim breaks in-game without the override.

## hello-page

`modules/hello-page.nix` runs `~/the-page/app.py` (system python, as your user, heavily sandboxed, read-write only to that directory) on `127.0.0.1:8137`. `hello-page-serve` waits for tailscaled, then publishes it with `tailscale serve --bg --https 443`. Environment overrides go in `/var/lib/secrets/the-page.env`.

## Containers and VMs

- **Docker** runs rootless; `DOCKER_HOST` points at the user socket. Not started at boot.
- **Podman** is available alongside.
- **libvirt**: `qemu:///system`, images under `/data/vms`; virt-manager is preconfigured (autoconnect to system, SPICE, host-passthrough CPU, qcow2). The agent VM is separate — see [Development](development.md#agent-vm).
