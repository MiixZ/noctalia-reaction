--[[
Sticker display router, shared by the trigger service and the bar tile.

The sticker is drawn by a companion process (bin/reaction-overlay.py) that
creates a transparent layer-shell surface: no theme card behind the image, it
floats above fullscreen windows and ignores input completely. This module owns
the whole show/hide path:

* It probes the companion once (python3 + GTK3 + gtk-layer-shell). The probe is
  optimistic until it answers.
* With the overlay, `show` plays the sound and (re)spawns the sticker; a second
  trigger while it is on screen replaces the running instance, which restarts
  the animation.
* Without it, everything falls back to the `miixz/reaction:sticker` panel: a
  shell-native surface that always paints the theme card. The panel plays its
  own sound and tracks its own visibility, so this module only toggles it.

Each entry script runs in its own Luau runtime (the service and the bar tile),
so every caller gets its own instance of this module and of the GIF clip. The
shared frame cache on disk keeps that cheap.
]]

local Gif = require("./gif.luau")

local PANEL_ID = "miixz/reaction:sticker"
local TAG = "miixz-reaction"

-- The overlay fades out over this long during its last moments on screen.
local FADE_MS = 250
local DEFAULT_HOLD_MS = 2500

-- Distance from the screen edge, in Noctalia logical pixels. Matches the
-- shell's floating-offset so the sticker is placed like other floating panels.
local MARGIN = 8

local dataDir = noctalia.pluginDataDir() or ("/tmp/noctalia-reaction-" .. tostring(os.time()))

local clip = Gif.new({ dataDir = dataDir, onLog = noctalia.log })

-- nil = not probed yet, true/false = companion usable or not.
local overlay = nil

-- Sound bank: one loaded sound per configured path.
local sound = { path = nil, name = nil, ready = false, pending = false }

local Sticker = {}

local function setting(key, fallback)
  local value = noctalia.getConfig(key)
  if value == nil then
    return fallback
  end
  return value
end

local function stickerPath()
  return setting("sticker_path", "")
end

local function sizePx()
  return math.max(64, math.floor(setting("size_px", 420)))
end

local function scriptPath()
  local dir = noctalia.pluginDir()
  if dir == nil or dir == "" then
    return nil
  end
  return dir .. "/bin/reaction-overlay.py"
end

local function soundPath()
  return setting("sound_path", "")
end

local function ensureSound()
  local path = soundPath()
  if path == "" or sound.path == path then
    return
  end

  sound.path = path
  sound.name = path:match("([^/]+)$") or "sticker"
  sound.ready = false
  sound.pending = false

  local accepted = noctalia.sound.load(sound.name, path, function(ok, err)
    if not ok then
      noctalia.log("reaction: could not load sound: " .. tostring(err))
      return
    end
    sound.ready = true
    if sound.pending then
      sound.pending = false
      noctalia.sound.play(sound.name)
    end
  end)

  if not accepted then
    noctalia.log("reaction: sound load request was rejected")
  end
end

local function playSound()
  local path = soundPath()
  if path == "" then
    return
  end

  ensureSound()

  -- The configured sound changed since it was loaded: the load callback plays
  -- the new sample instead of playing the wrong one now.
  if sound.path ~= path then
    return
  end

  if sound.ready then
    noctalia.sound.play(sound.name)
  else
    sound.pending = true
  end
end

-- One-off check that the companion can run. A missing python3 or a failed
-- import flips the whole module to the panel fallback.
local function probe()
  if overlay ~= nil then
    return overlay
  end

  local script = scriptPath()
  if script == nil or not noctalia.commandExists("python3") then
    overlay = false
    return false
  end

  overlay = true
  noctalia.runAsync({ "python3", script, "--probe" }, function(result)
    if result.exitCode ~= 0 then
      overlay = false
      noctalia.log("reaction: overlay unavailable, using the panel: " .. tostring(result.stderr))
    end
  end)
  return true
end

-- How long the sticker stays on screen: the GIF's measured duration plus
-- extra_ms, or hold_ms for still images and while the frames are extracting.
local function holdMs(path)
  if Gif.isGif(path) then
    clip:setSource(path, sizePx())
    if clip:ready() then
      return clip:durationMs() + math.max(0, math.floor(setting("extra_ms", 250)))
    end
  end
  return math.max(200, math.floor(setting("hold_ms", DEFAULT_HOLD_MS)))
end

function Sticker.isVisible()
  return noctalia.state.get("visible") == true
end

-- True only while the sticker is expected to be on screen. The panel also
-- flips `visible` by itself on open/close; when that happens without this
-- module recording an expiry, the panel's own state is trusted.
local function visibleNow()
  if not Sticker.isVisible() then
    return false
  end
  local untilMs = noctalia.state.get("visible_until") or 0
  return untilMs == 0 or noctalia.nowMs() <= untilMs
end

local function rememberVisible(hold)
  noctalia.state.set("visible", true)
  noctalia.state.set("visible_until", noctalia.nowMs() + hold)
end

function Sticker.show()
  local path = stickerPath()
  if path == "" then
    -- Nothing configured: the panel shows the setup hint (with its card).
    noctalia.togglePanel(PANEL_ID)
    return
  end

  local hold = holdMs(path)

  if probe() then
    playSound()
    local launched = noctalia.runAsync({
      "python3", scriptPath(),
      "--path", path,
      "--position", tostring(setting("sticker_position", "center")),
      "--size", tostring(sizePx()),
      "--duration", tostring(hold),
      "--fade", tostring(FADE_MS),
      "--opacity", tostring(setting("opacity", 1.0)),
      "--margin", tostring(MARGIN),
      "--tag", TAG,
    })
    if not launched then
      noctalia.log("reaction: could not launch the overlay")
      return
    end

    rememberVisible(hold)
    return
  end

  -- Panel fallback: the panel plays the sound and flips `visible` itself.
  if visibleNow() then
    noctalia.state.set("restart", (noctalia.state.get("restart") or 0) + 1)
  else
    noctalia.togglePanel(PANEL_ID)
  end
  rememberVisible(hold)
end

function Sticker.hide()
  if probe() then
    if Sticker.isVisible() then
      noctalia.runAsync({ "python3", scriptPath(), "--hide", "--tag", TAG })
    end
  elseif visibleNow() then
    noctalia.togglePanel(PANEL_ID)
  end

  noctalia.state.set("visible", false)
  noctalia.state.set("visible_until", 0)
end

-- Called from the service's update loop. Clears the bookkeeping this module
-- set once the sticker's time is over; the panel clears its own state when it
-- closes and the overlay simply stops existing.
function Sticker.tick()
  if not Sticker.isVisible() then
    return
  end

  local untilMs = noctalia.state.get("visible_until") or 0
  if untilMs > 0 and noctalia.nowMs() > untilMs then
    noctalia.state.set("visible", false)
    noctalia.state.set("visible_until", 0)
  end
end

return Sticker
