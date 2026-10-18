# noctalia-reaction

Two small [Noctalia](https://docs.noctalia.dev) plugins that split one job: put a
sticker on screen when you ask for it, and keep a game clip ready for the moment
something worth sharing happens.

They are separate plugins on purpose. `miixz/reaction` only knows how to show a
sticker with a sound, so it is useful on its own and publishes cleanly.
`miixz/game-clip` only knows how to decide between "clip" and "sticker", and how
to keep the replay buffer alive while a game is in focus, so it works with any
recorder and any sticker provider.

Together they turn a single key into: **clip while gaming, reaction sticker
otherwise**.

```
keypress ──▶ miixz/game-clip ──▶ game in focus? ──▶ yes ──▶ recorder: replay-save
                                     │
                                     └────────────▶ no  ──▶ miixz/reaction: trigger
```

The replay buffer is not left running all session: `miixz/game-clip` starts it
when a game takes focus and stops it when the game is gone, so desktop work does
not pay for an idle encoder.

## Plugins

| Plugin | What it does | Entries |
| --- | --- | --- |
| [`reaction`](reaction/) | Sticker image or animated GIF with a sound, above fullscreen windows, self-closing | Panel `sticker`, bar widget `tile`, service `service` |
| [`game-clip`](game-clip/) | Watches the focused window; saves an instant replay while gaming, shows the sticker otherwise | Service `service` |

Each plugin directory has its own README with the settings, IPC commands and
notes.

## Install

Add this repository as a plugin source:

```sh
noctalia msg plugins source add miixz git https://github.com/MiixZ/noctalia-reaction
noctalia msg plugins list
```

Then enable the plugins you want (Settings → Plugins, or):

```sh
noctalia msg plugins enable miixz/reaction
noctalia msg plugins enable miixz/game-clip
```

For development, `make link` symlinks both plugins into
`~/.local/share/noctalia/plugins` so the working tree is what the shell loads;
`make install` copies them instead.

## Requirements

- Noctalia with plugin API 30 or later.
- `miixz/reaction`: `ffmpeg` for animated GIFs (`magick` works as a fallback).
- `miixz/game-clip`: `gpu-screen-recorder` plus the official
  `noctalia/screen_recorder` plugin with instant replay enabled for the default
  clip commands, and `hyprctl` for the default game detection. Both are
  configurable, so other recorders and compositors are a setting away.

## Example: one key on a gaming keyboard

Solaar translates the Logitech G-keys into modifier combinations, and Hyprland
binds that combination to the router:

```lua
hl.bind(
    "CTRL + ALT + SHIFT + F10",
    hl.dsp.exec_cmd("noctalia msg plugin miixz/game-clip:service all trigger"),
    { description = "Save clip or show sticker" }
)
```

In a game the key saves the last 60 seconds; on the desktop it opens the
sticker. Nothing else in the desktop changes.

## Layout

```
catalog.toml     index of the plugins in this repository (plugin sources)
reaction/        plugin id miixz/reaction, directory name matches the id suffix
game-clip/       plugin id miixz/game-clip
```

## License

MIT, see [LICENSE](LICENSE). Plugins in the Noctalia community store keep their
own copyright; this repository is the source of the two plugins above.
