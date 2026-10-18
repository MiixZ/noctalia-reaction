# Game Clip

One keypress, two behaviours: while a game is in focus it saves an instant
replay clip, and anywhere else it shows a reaction sticker. The replay buffer is
started and stopped together with the game, so the encoder does not run - and
does not cost GPU power, VRAM or RAM - during desktop work.

## Plugin

| Field | Value |
| --- | --- |
| ID | `miixz/game-clip` |
| Entries | Service: `service` |

## Requirements

- `gpu-screen-recorder` for the default recorder commands, plus the official
  `noctalia/screen_recorder` plugin enabled with **instant replay** on
  (Settings → Plugins → Screen Recorder). Any other recorder works too: point
  the commands at it.
- `hyprctl` on `PATH` for the default game detection (Hyprland). On another
  compositor set `game_command` to that compositor's window query.
- Optionally `miixz/reaction` for the sticker side; without it, set
  `sticker_command` to whatever you want the key to do outside games.

## Usage

Bind a key to the trigger. In Hyprland:

```lua
hl.bind(
    "CTRL + ALT + SHIFT + F10",
    hl.dsp.exec_cmd("noctalia msg plugin miixz/game-clip:service all trigger"),
    { description = "Save clip or show sticker" }
)
```

Press it while a game has focus → a clip is saved (the recorder shows its own
notification with the file path). Press it anywhere else → the reaction sticker
appears instead.

The watcher runs on its own: when the focused window starts to look like a game
it asks the recorder for `replay-start`, and when the game loses focus it asks
for `replay-stop`. There is nothing to enable at the start of a session.

## Settings

| Setting | Type | Default | Description |
| --- | --- | --- | --- |
| `game_command` | `string` | *(empty)* | Command that prints the focused window, JSON preferred. Empty uses `hyprctl -j activewindow`. |
| `game_classes` | `string_list` | `steam_app_`, `gamescope`, `.exe`, `proton`, `wine`, `heroic`, `lutris`, `bottles` | A window counts as a game when one of these strings appears in the command output, ignoring case. |
| `require_fullscreen` | `bool` | `true` | Only treat the window as a game when it is fullscreen or maximized. Ignored when the output carries no fullscreen state. |
| `poll_ms` | `int` | `2000` | How often the focused window is checked. |
| `manage_replay_buffer` | `bool` | `true` | Start the buffer when a game is focused and stop it otherwise. |
| `replay_start_command` | `string` | recorder `replay-start` | Runs when a game comes into focus. |
| `replay_stop_command` | `string` | recorder `replay-stop` | Runs when no game is in focus, and on plugin exit. |
| `clip_command` | `string` | recorder `replay-save` | Runs on trigger while a game is in focus. |
| `sticker_command` | `string` | `miixz/reaction` trigger | Runs on trigger with no game in focus. Empty disables it. |
| `notify_errors` | `bool` | `true` | Show a notification when a command fails. |

## IPC

| Command | Effect |
| --- | --- |
| `noctalia msg plugin miixz/game-clip:service all trigger` | The hotkey action: clip while gaming, sticker otherwise. |
| `noctalia msg plugin miixz/game-clip:service all refresh` | Re-read the focused window now instead of waiting for the next poll. |
| `noctalia msg plugin miixz/game-clip:service all status` | Notification with the last detection and the buffer state. |

## Notes

- Detection reads the focused window only. Nothing scans the process list, so a
  game that leaves the keyboard to another window stops the buffer until it is
  focused again.
- With the JSON of Hyprland, `fullscreen` is read as 1 = maximized,
  2 = fullscreen, 3 = both; any of them counts when `require_fullscreen` is on.
  Commands that print plain text are matched as-is and skip the fullscreen
  check, because there is nothing structured to read.
- The replay buffer needs a moment (about two seconds) to become ready after a
  game is detected. A trigger inside that window is not lost silently: it shows
  a "replay buffer is not running" notification instead of saving nothing.
- On exit the plugin stops the buffer **it** started. If you drive the recorder
  yourself, set `manage_replay_buffer = false` and the plugin leaves it alone.
- Saved clips (and normal recordings) land wherever the recorder puts them. With
  `noctalia/screen_recorder` that is its **Output Directory** setting
  (Settings → Plugins → Screen Recorder); `replay-save` takes no path of its own.
- Commands are spawned with the shell (`noctalia.runAsync` string form), so
  pipes and `sh` syntax are allowed in every command setting.
