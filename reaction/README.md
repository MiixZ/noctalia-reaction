# Reaction

Shows a sticker image or animated GIF with a sound on top of everything, as a
heads-up overlay, and closes itself when it is done. It is the "cheer for me"
button: one keypress, a Chitoge jumps on screen and a sound plays, then the
screen is yours again.

## Plugin

| Field | Value |
| --- | --- |
| ID | `miixz/reaction` |
| Entries | Panel: `sticker`; Bar widget: `tile`; Service: `service` |

## Requirements

- `ffmpeg` for animated GIFs (`magick` from ImageMagick works as a fallback;
  static images need neither).
- A sticker file of your own. The plugin ships none.

## Usage

Show the sticker from anywhere, for example from a Hyprland keybind, a script or
another plugin:

```sh
noctalia msg plugin miixz/reaction:service all trigger
```

Triggering again while the sticker is on screen restarts it instead of closing
it. To dismiss it early:

```sh
noctalia msg plugin miixz/reaction:service all hide
```

The bar tile does the same thing: left click shows the sticker (and restarts it
while it is on screen), right click dismisses it. Add it from
**Settings → Bar**, it renders a `mood-smile` glyph that tints with the primary
colour while the sticker is up.

The panel can also be driven directly, which is the plain open/close toggle:

```sh
noctalia msg panel-toggle miixz/reaction:sticker
```

### How long it stays

An animated GIF stays on screen for its own duration plus `extra_ms`. A static
image stays for `hold_ms`. Either way the sticker fades out in the last 250 ms.

## Settings

| Setting | Type | Default | Description |
| --- | --- | --- | --- |
| `sticker_path` | `file` | *(empty)* | PNG, JPEG, WebP, SVG or animated GIF to show. |
| `sound_path` | `file` | *(empty)* | Sound played when the sticker appears. |
| `size_px` | `int` | `420` | Sticker box in logical pixels. The panel is 448 px, so up to 420 px fills the card. |
| `opacity` | `double` | `1.0` | Maximum sticker opacity, before the fade-out. |
| `hold_ms` | `int` | `2500` | How long a static sticker stays on screen. |
| `extra_ms` | `int` | `250` | Extra time on screen after an animated GIF has finished. |

## IPC

| Command | Effect |
| --- | --- |
| `noctalia msg plugin miixz/reaction:service all trigger` | Show the sticker, or restart it when it is already on screen. |
| `noctalia msg plugin miixz/reaction:service all hide` | Dismiss it. |
| `noctalia msg plugin miixz/reaction:service all status` | Notification with the configured sticker and its state. |

## Notes

- The sticker is a **panel**, not a desktop widget: desktop widgets live on the
  bottom layer and hide behind any window, which is useless for a reaction that
  must land on top of a game.
- Noctalia panels always paint the theme's rounded card behind their content, so
  the sticker sits inside a themed card. `size_px` defaults to 420 because the
  card is 448 px with 14 px of padding per side; a larger sticker would be
  clipped.
- The panel declares `keyboard_focus = "none"` and
  `dismiss_on_outside_click = false`, so it never takes the keyboard away from
  the application in use and clicks pass through to it.
- Animated GIFs are unpacked into frames by the trigger service, once, into the
  plugin data directory (`.../plugins/data/miixz/reaction/gif-cache`). The cache
  is keyed by file, size and modification time.
- The trigger service runs for the whole session so the frames are ready before
  the first press; a first-time extraction of a large GIF would otherwise be
  visible as a late sticker.
