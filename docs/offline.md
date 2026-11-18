# Offline: knowledge, maps and AI without the internet

`flakes/offline` keeps a library, a planet map, local AI and a way to rebuild
this machine on local drives, so they all keep working with no internet. It's
a NixOS module (`zi.offline`), usable on its own as a flake
(`nixosModules.default`); `modules/offline.nix` turns it on for the desktop.
The idea is the same as Project N.O.M.A.D.'s offline survival server, built
from NixOS services instead of containers.

## What's on it

| Part | What | Where |
|---|---|---|
| Library | Kiwix: the sets below, served by kiwix-serve | spare drive (`/mnt/pool1/offline/kiwix`); the two biggest sets on the media drive |
| Maps | The Protomaps planet basemap (every street, ~140 GB), drawn by a MapLibre page that needs no network; place search (Photon) and directions by car, bicycle or foot (Valhalla) in the `navigation.regions` | map on the media drive (`/mnt/media/offline/maps`), search and routing data on the spare drive (`navigation/`) |
| AI | Open WebUI on Ollama, with an *Offline library* tool the models can call to search and read the library; `qwen3-vl` reads photos | models in `/var/lib/ollama` (NVMe: loading from a hard disk takes minutes) |
| Documents | The national crisis brochure (MCF, English and Swedish) and Hesperian's *Where There Is No Doctor* (2025), at `/docs/` | spare drive (`docs/`) |
| Phone apps | APKs a phone installs from the hub with no internet: Kiwix, CoMaps, Organic Maps, OsmAnd~, Meshtastic, Briar, KeePassDX, VLC, Termux, a file manager, F-Droid | spare drive (`apps/`) |
| Archive | A Nix binary cache of the running system and every flake input, a git bundle of this repo, copies of the models | spare drive (`/mnt/pool1/offline/{nix-cache,dots.bundle,models}`) |
| Desktop | Kiwix reader, CoMaps (offline maps with search and routing; download regions in the app), CyberChef | — |
| Comms | JS8Call, Fldigi, WSJT-X, CHIRP, Direwolf, SDR++, Gqrx, rtl-sdr, Meshtastic CLI, and the Meshtastic web client at port 8094 | — |

Library sets (`flakes/offline/catalog.nix`, sizes approximate):

| Set | Holds | Size |
|---|---|---|
| `survival` | Water treatment, food and home canning (USDA), field medicine, knots, the post-disaster library, prepper guides, Ready.gov, Learning Self-Reliance, US Army field manuals | 27 GB |
| `medical` | WikiMed, MDWiki, MedlinePlus, military medicine, medicine textbooks, NHS drug reference, WikiVet | 9 GB |
| `encyclopedia` | Wikipedia with pictures, Wiktionary, Wikivoyage, Wikibooks | 148 GB |
| `practical` | iFixit, Appropedia, energypedia, Q&A on DIY, electronics, gardening, cooking, outdoors, mechanics, radio | 14 GB |
| `science` | LibreTexts textbooks and science Q&A | 10 GB |
| `computing` | ArchWiki, Nix docs, Linux Q&A | 8 GB |
| `books-practical` / `books-all` | Project Gutenberg: the practical shelves, or all of it | 37 / 173 GB |
| `survivor-library` | Scanned books on pre-industrial skills and trades | 220 GB |
| `khan-academy` | Khan Academy, US curriculum (2023) | 180 GB |
| `swedish`, `arabic` | Wikipedia (and Wiktionary) in those languages | 17 / 19 GB |

The desktop keeps every set but `books-practical` (`books-all` covers it),
`khan-academy` and `arabic`: English and Swedish only. Add any other book by its Kiwix catalog id with
`zi.offline.kiwix.extraBooks`.

## Using it

Everything is on the hub, `http://<this machine>:8090/`, from this machine,
the LAN or the tailnet: the library at `/library/`, the map at `/maps/`,
documents at `/docs/`, phone apps at `/apps/`, CyberChef, the AI and
Meshtastic links, what the last sync left on disk, and the commands below.

- **Map**: type a place or an address in the search box (`lat, lon` works
  too). ↱ opens directions: search or click the map for the start and the
  end, then pick car, bicycle or foot. Search and directions cover the
  `navigation.regions` (Sweden, Norway, Finland, Denmark here); the map
  itself covers the planet.
- **Phones**: open `/apps/` on the phone, tap an app and let the browser
  install it. Kiwix and CoMaps then work on the phone alone: copy books from
  the library drive, and download CoMaps regions while there is internet.
- **Meshtastic**: the web client talks to a node over Wi-Fi from any device.
  Over USB or Bluetooth it needs a secure page, which on plain HTTP is only
  this machine's own browser at `http://localhost:8094/`.

- **AI**: Open WebUI at port 8091. The first account created becomes the
  admin, and anyone on the LAN can reach the page, so create yours first.
  Later sign-ups wait for the admin's approval. In a chat, turn on
  the *Offline library* tool from the chat's tools menu and the model looks
  answers up in the library instead of guessing. The tool leaves the Project
  Gutenberg books out unless the model asks for them: each is one document
  holding a whole book, so it matches nearly any search. For a photo (a
  label, a plant, a wound), attach it and pick `qwen3-vl:8b`; never trust it,
  or any model, to say a mushroom is safe to eat.
- **Downloads**: `offline-sync` checks for new releases monthly and the
  archive refreshes weekly. Run either now with
  `systemctl start --no-block offline-sync.service` or `offline-archive.service`
  (no sudo). Without `--no-block`, systemctl waits until the whole run is
  done, which can be hours; Ctrl+C on that wait doesn't stop the run.
  Every download resumes after an interruption and is checksum-verified.
  A switch leaves a running sync or archive alone; the new version takes over
  on the next run, or now with `systemctl restart --no-block offline-sync.service`
  (the download resumes).
  `offline-sync status` lists what's on disk and what's still missing. The
  first sync is about 790 GB (625 GB of books, 140 GB of map, the rest
  search and routing data, apps and documents), so it runs for a long time.
  It goes smallest first: documents and apps within minutes, then search and
  directions (the routing build takes a while), then the survival and
  medical books, the big books and the map last.

## When the internet is gone

Rebuild this machine from the offline cache:

```
sudo nixos-rebuild switch --offline --flake ~/dots#nixos \
  --option substituters file:///mnt/pool1/offline/nix-cache --option require-sigs false
```

Reinstall on a new disk: boot the dots installer, mount the spare drive at
the same place, then

```
git clone /mnt/pool1/offline/dots.bundle /mnt/etc/dots
nixos-install --flake /mnt/etc/dots#nixos \
  --option substituters file:///mnt/pool1/offline/nix-cache --option require-sigs false
```

`require-sigs false` is needed because paths built on this machine carry no
signature; whatever came from a binary cache keeps its signature.

## Hardware-specific values

None are in the repo. The module stores only paths and catalog ids. Machine
details (display modes, the DAC, power limits) live in `~/.config/dots-local/`
and `/var/lib/dots/`; see `~/.config/dots-local/README`.
