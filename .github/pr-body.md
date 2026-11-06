<!-- noctalia-pr-template:v1 -->

## Plugin

- **Id:** `miixz/reaction`
- **Version:** {{VERSION}}
- [{{NEW}}] New plugin
- [{{UPDATE}}] Update to an existing plugin (version bumped in `plugin.toml`)

## What it does

A heads-up sticker overlay: show an image or animated GIF on top of everything
with a sound, then let it close itself. It can pick a single file or choose
randomly/sequentially from a folder of stickers, so one keypress can cycle
through a whole set of reaction GIFs.

The plugin ships three entries:

- `service` owns the trigger path and keeps GIF frame caches warm.
- `sticker` is the fallback panel when the transparent Python overlay cannot be
  used.
- `tile` is the optional bar widget.

## External dependencies

- `ffmpeg` (including `ffprobe`) — decode animated GIFs into cached PNG frames.
- `python3` with GTK 3 bindings (`python-gobject`) and `gtk-layer-shell` — run
  the transparent overlay companion `bin/reaction-overlay.py`.

Every dependency is declared in `dependencies` in `plugin.toml` and documented
in `README.md`.

## Testing

- [ ] Tested on Niri
- [x] Tested on Hyprland
- [ ] Tested on Sway
- [ ] Tested on another compositor:
- **Noctalia version tested against:** 5.2.1
- **Plugin API level:** 30

What was exercised:

- The plugin is installed and enabled on the author's Hyprland session with
  Noctalia 5.2.1. G3 triggers the sticker through `miixz/game-clip` when no game
  is focused.
- Single-file mode, folder mode with random selection, and sequential selection
  were tested with multiple GIFs and static images.
- Short GIFs loop to stay on screen for at least 1.5 s.
- The Python overlay runs when `python-gobject` and `gtk-layer-shell` are
  available; the panel fallback opens when they are not.
- `noctalia plugins lint` passes and the community repository validator passes.

## Screenshots / Videos

The thumbnail was generated with the official
[thumbnail generator](https://assets.noctalia.dev/plugins/thumbnail-generator.html).

## Checklist

- [x] The directory name matches the part of `id` after the `/` in `plugin.toml` exactly.
- [x] It ships `plugin.toml`, `README.md`, `thumbnail.webp`, and `translations/en.json`.
- [x] `README.md` follows the
      [README template](https://github.com/noctalia-dev/community-plugins/blob/main/README_TEMPLATE.md), documents
      every entry id and dependency, and includes exact panel IPC commands and launcher prefixes where applicable.
- [x] `thumbnail.webp` is present and relevant; for a new plugin I created it with the [thumbnail generator](https://assets.noctalia.dev/plugins/thumbnail-generator.html), and for an update I regenerated it with the generator if the visual identity or user-facing appearance changed.
- [x] `version` follows semver and is bumped in this PR; `plugin_api` is the oldest API level this plugin requires.
- [x] Every non-English translation in this PR uses a locale supported by Noctalia core, and I can read, write, and
      understand that language well enough to review and maintain it (no unreviewed machine/LLM translations).
- [x] I did not edit `catalog.toml`; CI generates it.
- [x] This PR touches exactly one plugin directory.

## Code review attestation

- [x] The code is readable and not obfuscated, minified, or generated.
- [x] It does not download and execute remote code.
- [x] Every network call, filesystem write, and spawned process is something the description above accounts for.
- [x] I have the right to publish this code under the `license` declared in `plugin.toml`.
