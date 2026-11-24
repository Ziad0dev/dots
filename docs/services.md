# Services

## Ports

On the LAN only Jellyfin, the Soulseek listener and mDNS are admitted; on the tailnet only Jellyfin, the page and the VPN namespace's port mappings. Other services use loopback or the VPN namespace; Radarr and Sonarr bind wildcard sockets but the host firewall admits them only from the VPN namespace bridge.

| Service | Address | Reachable from |
|---|---|---|
| Jellyfin | `:8096` http, `:8920` https; `tailscale serve` on 8443 | LAN (`enp5s0`) and tailnet (`tailscale0`) |
| soulseek-rs | `:2234` | LAN (router port forward) |
| qBittorrent web UI | `:8081` in namespace `wg` | tailnet via port mapping; host at `http://192.168.15.1:8081` (only Sonarr, Radarr and your user) |
| Prowlarr | `:9696` in namespace `wg` | tailnet via port mapping; host at the namespace address |
| FlareSolverr | `127.0.0.1:8191` in namespace `wg` | Prowlarr only |
| Radarr / Sonarr | `*:7878` / `*:8989` | host; firewall admits the VPN namespace bridge only |
| Bazarr | `127.0.0.1:6767` | host |
| Audiobookshelf | `127.0.0.1:8000` | host |
| calibre-web | `127.0.0.1:8083` | host |
| llama.cpp units | `127.0.0.1:8080` | host |
| llama-fim | `127.0.0.1:8012` | host |
| Ollama | `127.0.0.1:11434` | host |
| MPD | `127.0.0.1:6600` (socket-activated) | host |
| hello-page | `127.0.0.1:8137` → `tailscale serve` on 443 | tailnet (HTTPS) |
| Avahi | `:5353/udp` | LAN |

## Media

`/mnt/media` is an exFAT drive (`modules/media.nix`) mounted with the user as owner and gid 3000 (`media`), `dmask=0002` / `fmask=0113` so the whole media group can write. It's `nofail` + `x-systemd.automount`; every unit that touches it has `RequiresMountsFor = /mnt/media`, so services wait for the drive instead of writing into an empty mountpoint.

| Service | Notes |
|---|---|
| **Jellyfin** | NVENC. Decode: h264, hevc, hevc10, vp8, vp9, av1, mpeg2, vc1. Encode: HEVC on, AV1 off. Tone mapping on, transcode throttling on, CRF 21 (h264) / 26 (h265). `DeviceAllow` adds `nvidia0`, `nvidia-uvm(-tools)`, `nvidia-modeset`. `forceEncodingConfig = true` — encoding settings changed in the web UI are overwritten on restart; change them in Nix |
| **Radarr / Sonarr** | group `media`, `lib/hardening.nix` with `ReadWritePaths = /mnt/media` |
| **Bazarr** | `modules/subtitles.nix`. Downloads missing English subtitles for everything Sonarr and Radarr manage and saves them as `.en.srt` next to the video; an embedded English track counts as present. Group `media`, the nixpkgs sandbox. Its settings come from Nix (`services.bazarr.settings`, applied at every start, so web-UI edits to those keys don't stick). Sources that need no account: gestdown, yifysubtitles, bsplayer, subtitlecat, subf2m (sent a browser User-Agent, which it requires). Sources with a free account or key each switch on by themselves once their keys are in `secrets/nixos.yaml`, and each has its own daily limit: OpenSubtitles.com (`opensubtitles-username` and `opensubtitles-password`, 20 downloads a day, hash matching), subdl (`subdl-api-key`, from subdl.com) and SubSource (`subsource-api-key`, from subsource.net). Bazarr reads them through `LoadCredential`, and changing one restarts it. An episode needs a 66% match (series, season and episode; Bazarr's default 90% also needs the year, which bare `Show.S01E01.mkv` files rarely get), and anything below 90% is re-timed to the audio with ffsubsync. Bazarr runs at the lowest CPU and disk priority, since syncing decodes the audio. `bazarr-setup` (root oneshot, loopback only) creates the English language profile and hands Bazarr the Sonarr/Radarr API keys from their `config.xml`. It runs at boot, not on a switch (`restartIfChanged = false`): saving settings makes Bazarr reconnect to the *arrs before it replies, which can take minutes, so it posts each setting once and checks or retries at the next run; `bazarr-search` (timer, 10 min after start) kicks off the first missing-subtitle search, later ones run every 6 h. The web UI is locked on purpose (form login, no password can match): unauthenticated, its page gives the API key to anything on loopback, and the key can set a post-processing command. To log in, put the MD5 of a password in sops as `bazarr-ui-password` (`python3 -c 'import getpass,hashlib;print(hashlib.md5(getpass.getpass().encode()).hexdigest())'`) and switch; the user is `admin`. Remove the key to lock it again. Post-processing is pinned off |
| **Audiobookshelf** | loopback only, group `media`, hardened |
| **calibre-web** | loopback only, library at `/mnt/media/books`, uploads disabled. `GOOGLE_BOOKS_API_KEY` (optional) comes from secretspec |
| **MPD** | user service (`home/profiles/linux-desktop.nix`), music at `/mnt/media/music`. Two outputs: PipeWire (default) and a bit-perfect ALSA output from `~/.config/dots-local/mpd.conf` (it names the DAC, so it stays out of the repo; disabled; switch with `mpc enable only 2`, back with `mpc enable only 1`). Clients: rmpc, mpdris2 for media keys |

## Download bufferbloat

`modules/sqm.nix` (`dots.sqm.enable`, `dots.sqm.download`). A download that fills the line built a queue upstream, and everything else waited behind it: on the gigabit line, pings went from 5 ms idle to about 69 ms on average and 221 ms at worst. The gateway's Smart Queues fixed the latency but capped the line at about 730 Mb/s (its CPU can't shape a gigabit), so they're off, and this machine shapes its own downloads instead: incoming internet traffic is redirected to an IFB device (`ifb-sqm`) and shaped with CAKE a little below the line rate, which keeps the queue here, short and fair.

- Only internet traffic is shaped: private source addresses (`dots.sqm.lanSubnets`: the LAN, IoT and guest VLANs, media clients) pass at full speed. Upload stays on the default `fq_codel`; it showed no bufferbloat.
- The rate must sit below the line's real download speed, or nothing improves. Retune it after a plan change: run a speed test with the unit stopped, set `download` to about 95 %, switch, and check that latency under load stays near idle.
- It protects this machine's own traffic. Another device saturating the line still adds latency for everyone.
- `systemctl status dots-sqm`, `tc -s qdisc show dev ifb-sqm` (drops and delays), `sudo systemctl stop dots-sqm` removes the shaping until the next boot or switch.

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

- The namespace uses `/etc/wireguard/mullvad.conf` (not in the repo). The current SOPS file declares only the Restic password; add the Mullvad secret as described in [Secrets](secrets.md), or provision the WireGuard file manually. Until that file exists, the WireGuard namespace services are skipped. `wg-dns` runs before `wg.service` and rewrites its `DNS =` line to Mullvad's resolver `100.64.0.7` so lookups inside the namespace stay in the tunnel.
- IPv6 is disabled inside `wg` after the namespace starts. This fixed uIndex: FlareSolverr solved the Cloudflare challenge, but Prowlarr's follow-up request still failed until both used IPv4.
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

`modules/llm.nix` + `modules/ollama.nix`. llama.cpp models live in `/var/lib/dots/models`; Ollama stores its models in `/var/lib/ollama`.

| Unit | Model | Port | For |
|---|---|---|---|
| `llama-cpp` | Qwen3.5-9B Q6_K | 8080 | general / coding / maths |
| `llama-uncensored` | Huihui Qwen3.5-9B abliterated Q6_K | 8080 | uncensored general |
| `llama-hermes` | Hermes 4 14B IQ4_XS | 8080 | steerable general, 8k context |
| `llama-sec` | WhiteRabbitNeo V3 7B Q5_K_M | 8080 | security |
| `llama-agent` | Qwen2.5-Coder-14B-Instruct Q4_K_M | 8080 | tool calling |
| `llama-gemma` | Gemma 4 12B Q4_K_M | 8080 | general, vision, audio |
| `llama-coder` | Gemma 4 26B-A4B MoE Q4_K_M | 8080 | coding / agentic — 10 expert layers on CPU, q8_0 KV cache |
| `llama-fim` | Qwen2.5-Coder-3B Q8_0 | 8012 | llama.vim fill-in-the-middle |
| `ollama` | Qwen3.6 35B-A3B (OMP default), Qwen3.5 9B, Qwen2.5-Coder 14B + 7B, Devstral Small 2 24B; other models on demand | 11434 | local coding agents and trying models quickly |

How they behave:

- **CUDA** build of llama.cpp for every GPU generation nixpkgs targets, downloaded prebuilt from the NixOS CUDA cache (`cache.nixos-cuda.org`, trusted in `modules/llm.nix`). Layer and MoE-expert placement is left to llama-server's `--fit`, which sizes it to the VRAM free when the unit starts; 16k context unless noted, flash attention, `--jinja` chat templates.
- **One at a time.** Every llama unit `Conflicts=` every other llama unit, so starting one stops the last. Before starting, `free-gpu` asks Ollama to unload whatever it holds. Ollama keeps at most one model loaded and drops it after 5 minutes idle.
- **Never at boot.** `wantedBy` is forced empty on all the llama units. Ollama does start at boot, but holds no VRAM until a model is requested.
- **No sudo.** A polkit rule lets your active local session start and stop these units.
- **Sandboxed.** The llama units run as `DynamicUser` with `ProtectHome`, `ProtectSystem=strict`, no capabilities and `MemoryDenyWriteExecute`. GGUF files must be world-readable.
- llama.cpp's model directory is created for your user. Download or copy GGUF files there; the services do not download them. Ollama creates and manages its own model files. It serves a 128k default context (`OLLAMA_CONTEXT_LENGTH`) with a q8 KV cache, spilling what does not fit in VRAM to the CPU.

OMP is the local coding agent; Claude stays in Claude Code. OMP discovers
every Ollama model by itself, so `config/omp/models.yml` declares no
providers. `config/omp/config.yml` (linked live to `~/.omp/agent/`) gives
every role the Qwen3.6 35B-A3B MoE, falling back to Qwen3.5 9B: Ollama holds
one model at a time, and a second role model would reload on every commit
message or subagent. OMP compacts at 48k tokens, well under Ollama's 128k
context. Pick another model with `omp --model ollama/<name>`.

`omp-local` starts OMP with Qwen3.5 9B, which fits in VRAM and loads fastest.
`claude-local` starts Claude Code on the same model through Ollama's
Anthropic-compatible API, capped at 32k context so it compacts early. For the
heavier coding model, run `omp --model ollama/devstral-small-2:24b` or
`env CLAUDE_CODE_MAX_CONTEXT_TOKENS=32768 ollama launch claude --model devstral-small-2:24b`.

Inkling 2 Mini (`inkling-2-mini`) needs an Ollama that supports it on Linux.
Ollama 0.40.17 supports it on Apple silicon only. Once a release with PC
support reaches nixpkgs, add `inkling-2-mini` to `loadModels` in
`modules/ollama.nix`, switch, and point `modelRoles.default` at
`ollama/inkling-2-mini`. It is about 20 GB, so expect part of it on the CPU.

```fish
systemctl start llama-coder      # swap models
dots-llm next                    # cycle, same as the bar widget
dots-llm off
gpu-check                        # which llama unit is up + ollama ps
gpu-free                         # stop all llama units, unload Ollama models
```

## Backups

`modules/backup.nix` — restic, `$HOME`, quiesced media/download application state, and the Secure Boot keys → `/mnt/backup/restic-new`, daily (persistent, up to 1 h random delay).

- Before each run, `scripts/restic-snapshot.sh` records which of Sonarr, Radarr, Prowlarr, qBittorrent, Jellyfin, Audiobookshelf, and calibre-web are active, stops them, and copies their state into root-only `/var/lib/restic-backup-staging`. It restarts only the previously active services before Restic starts, so upload/prune/check time causes no application downtime.
- A failed stop or copy skips Restic and restores the recorded services. Initially inactive services stay inactive. Restic never reads a partially copied staging tree.
- Application databases, configuration, qBittorrent `BT_backup`, and service backup directories are retained; caches, artwork, metadata, and logs are filtered during staging.

- Excludes caches, Steam and other game libraries, replay recordings, flatpak and container storage, Downloads, Trash, and build junk (`node_modules`, `target`, `zig-cache`, `zig-out`, `.venv`, `.direnv`, `__pycache__`).
- Retention: 7 daily, 4 weekly, 6 monthly. Each run checks a random 5 % of pack data.
- Skips cleanly when the backup drive isn't mounted or writable; runs at nice 19, idle I/O.
- Password at `/etc/restic/password`; the unit refuses to start if the file is empty.

For recovery, restore the Restic snapshot to a temporary target, stop the application, then `rsync -aHAX --numeric-ids` its staged directory back to the live path. Staged names match `/var/lib` except `prowlarr`, which restores to `/var/lib/private/prowlarr`; the other six restore to `/var/lib/<staged-name>`. Preserve the staged numeric owners and permissions, and do not restore over a running service.

```fish
sudo systemctl start restic-backups-home
journalctl -u restic-backups-home -e
sudo restic -r /mnt/backup/restic-new -p /etc/restic/password snapshots
```

## Storage

| Mount | What | Mounted as |
|---|---|---|
| `/` | LUKS, ext4 | |
| `/mnt/media` | exFAT | user:media, group-writable, automount, visible in file managers |
| `/mnt/backup` | Independent exFAT backup drive, configured by its own UUID | root:root `0077`, automount (10 min idle), hidden from file managers |
| `/mnt/pool1` | ext4 spare drive | owned by the user, automount (10 min idle), visible in file managers |

exFAT has no permissions, so ownership comes from mount options. udiskie ignores both external exFAT drives by UUID — they belong to systemd — but still automounts real removable media. `dots-mounts` (the bar's storage alert) reports whether `/mnt/media`, `/mnt/backup` and `/mnt/pool1` are healthy. If the backup drive is replaced, update its UUID in `modules/storage.nix`.

Games and wallpaper folders are created in your home directory. Replay captures go to `~/Videos/Replays`. llama.cpp's model files belong in `/var/lib/dots/models`; VM images and installer ISOs use `/var/lib/libvirt/images` and `/var/lib/libvirt/isos`. Restore or download those files separately after reinstalling. Ollama manages models under `/var/lib/ollama` when you start it.

## Flatpak

`home/flatpak.nix` declares remotes, apps and overrides with [nix-flatpak](https://github.com/gmodena/nix-flatpak); its `flatpak-managed-install` user unit applies them (user installation) after each switch. Being a home-manager unit, only your user runs it — the SDDM greeter's user manager never sees it.

- Remotes: Flathub.
- Apps: Foliate, Flatseal, Bottles, F3D, MeshLab, Blender, Simple Scan, Kdenlive, TeXstudio — each **pinned to a commit**, so a switch installs exactly that build. To bump one, `flatpak remote-info --user --log <origin> <appId>`, then paste the commit. Runtimes are whatever the pinned app requires.
- `uninstallUnmanaged`: it **uninstalls any user app that isn't listed** — add apps there, not with `flatpak install`.
- `modules/flatpak.nix` keeps only `flatpak-nvidia-gl`, which installs `GL.nvidia-<driver>` / `GL32.nvidia-<driver>` for the loaded driver (from `/sys/module/nvidia/version`; the name carries the version, so it can't be declared). Old extensions are swept by the weekly `flatpak-prune`.

## hello-page

`modules/hello-page.nix` runs the store-owned source in `pkgs/hello-page` with system Python as your user on `127.0.0.1:8137`. Mutable state stays in `~/the-page`; the sandbox makes home read-only except for the database, config, content, and backups. `hello-page-serve` waits for tailscaled, then publishes it with `tailscale serve --bg --https 443`. Environment overrides go in `/var/lib/secrets/the-page.env`.

## Containers and VMs

- **Docker** runs rootless; `DOCKER_HOST` points at the user socket. Not started at boot.
- **Podman** is available alongside.
- **libvirt**: `qemu:///system`, images under `/var/lib/libvirt/images` and installer ISOs under `/var/lib/libvirt/isos`; virt-manager is preconfigured (autoconnect to system, SPICE, host-passthrough CPU, qcow2). Your user isn't in the `libvirtd` group, so connecting to `qemu:///system` goes through a polkit password prompt. Restore VM images and ISOs manually after reinstalling.
