--[[
Game Clip service.

Roles:

1. Watcher - polls the focused window and keeps the replay buffer alive only
   while a game is in focus. The encoder stops with the game, so desktop work
   does not pay for GPU power, VRAM or RAM.
2. Router - a `trigger` saves an instant-replay clip when a game is in focus and
   shows a reaction sticker when it is not. The decision uses a fresh reading of
   the focused window, not the cached poll result.

Every command comes from the settings, so nothing is hard-wired: the defaults
drive the official noctalia/screen_recorder (instant replay over its service
IPC) and miixz/reaction.

    noctalia msg plugin miixz/game-clip:service all trigger
]]

local DEFAULT_GAME_COMMAND = "hyprctl -j activewindow"

local DEFAULT_CLASSES = {
  "steam_app_",
  "gamescope",
  ".exe",
  "proton",
  "wine",
  "heroic",
  "lutris",
  "bottles",
}

local DEFAULT_REPLAY_START = "noctalia msg plugin noctalia/screen_recorder:service all replay-start"
local DEFAULT_REPLAY_STOP = "noctalia msg plugin noctalia/screen_recorder:service all replay-stop"
local DEFAULT_CLIP = "noctalia msg plugin noctalia/screen_recorder:service all replay-save"
local DEFAULT_STICKER = "noctalia msg plugin miixz/reaction:service all trigger"

-- A detection command that never answers must not wedge the watcher.
local POLL_TIMEOUT_MS = 15000
local MAX_DESCRIPTION = 80

local function setting(key, fallback)
  local value = noctalia.getConfig(key)
  if value == nil then
    return fallback
  end
  return value
end

local function bool(key, fallback)
  local value = setting(key, fallback)
  if type(value) == "boolean" then
    return value
  end
  return fallback
end

local function trim(value)
  return (tostring(value or ""):gsub("^%s*(.-)%s*$", "%1"))
end

-- Settings that hold a command treat an empty value as "do nothing" on purpose.
local function command(key, fallback)
  local value = setting(key, fallback)
  if type(value) ~= "string" then
    return fallback
  end
  return trim(value)
end

local function gameCommand()
  local configured = command("game_command", "")
  if configured ~= "" then
    return configured
  end
  if noctalia.commandExists("hyprctl") then
    return DEFAULT_GAME_COMMAND
  end
  return ""
end

-- Last decision and the state we own.
local inGame = false
local focused = ""
local bufferRunning = false
local bufferOwned = false
local pollBusy = false
local pollStarted = 0
local pollInterval = 0
local lastFailure = ""

local function describe(text)
  if #text <= MAX_DESCRIPTION then
    return text
  end
  return text:sub(1, MAX_DESCRIPTION) .. "..."
end

local function reportFailure(what, result)
  local message = trim((result and result.stderr) or "")
  if message == "" then
    message = "exit code " .. tostring(result and result.exitCode or "?")
  end
  -- Log one line per distinct failure so a wedged command cannot spam the log.
  local line = what .. ": " .. message
  if line ~= lastFailure then
    lastFailure = line
    noctalia.log("game-clip: " .. line)
  end
  return message
end

local function notifyError(titleKey, bodyKey, subs)
  if not bool("notify_errors", true) then
    return
  end
  noctalia.notifyError(noctalia.tr(titleKey), noctalia.tr(bodyKey, subs))
end

-- Reads the focused window out of whatever the detection command printed.
-- JSON (Hyprland and friends) is parsed for the window fields and the
-- fullscreen state; any other output is matched as raw text.
local function describeWindow(output)
  local text = output or ""
  local fullscreen = nil

  local ok, decoded = pcall(noctalia.json.decode, text)
  if ok and type(decoded) == "table" then
    local parts = {}
    for _, key in ipairs({ "class", "initialClass", "app_id", "title", "name" }) do
      local value = decoded[key]
      if type(value) == "string" and value ~= "" then
        table.insert(parts, value)
      end
    end

    if #parts > 0 then
      text = table.concat(parts, " ")
    end

    local state = decoded.fullscreen
    if type(state) == "boolean" then
      fullscreen = state
    elseif type(state) == "number" then
      -- Hyprland: 1 maximized, 2 fullscreen, 3 both.
      fullscreen = state >= 1
    end

    local mode = decoded.fullscreen_mode -- sway reports an integer mode
    if fullscreen == nil and type(mode) == "number" then
      fullscreen = mode >= 1
    end
  end

  return text, fullscreen
end

local function matchesClasses(text)
  local haystack = string.lower(text)
  local classes = setting("game_classes", DEFAULT_CLASSES)
  if type(classes) ~= "table" or #classes == 0 then
    classes = DEFAULT_CLASSES
  end

  for _, entry in ipairs(classes) do
    local needle = string.lower(trim(entry))
    if needle ~= "" and string.find(haystack, needle, 1, true) then
      return true
    end
  end
  return false
end

local function decide(text, fullscreen)
  if not matchesClasses(text) then
    return false
  end
  if not bool("require_fullscreen", true) then
    return true
  end
  if fullscreen == nil then
    -- The detection command reports no fullscreen state, so the class match is
    -- all there is to go on.
    return true
  end
  return fullscreen == true
end

-- Runs the detection command. `onDone(text, fullscreen)` gets text = nil when
-- the command failed, which means "unknown, keep the previous decision".
local function detect(onDone)
  local cmd = gameCommand()
  if cmd == "" then
    noctalia.log("game-clip: no game_command set and hyprctl is missing; detection disabled")
    onDone(nil, nil)
    return
  end

  noctalia.runAsync(cmd, function(result)
    if result.exitCode ~= 0 then
      reportFailure("detection command failed", result)
      onDone(nil, nil)
      return
    end
    local text, fullscreen = describeWindow(result.stdout)
    onDone(text, fullscreen)
  end)
end

local function remember(text, fullscreen)
  if text == nil then
    return
  end
  focused = describe(trim(text))
  inGame = decide(focused, fullscreen)
end

local function setBuffer(wanted)
  if not bool("manage_replay_buffer", true) then
    return
  end
  if wanted == bufferRunning then
    return
  end

  bufferRunning = wanted
  bufferOwned = wanted

  local cmd = command(wanted and "replay_start_command" or "replay_stop_command",
    wanted and DEFAULT_REPLAY_START or DEFAULT_REPLAY_STOP)
  if cmd == "" then
    return
  end

  noctalia.runAsync(cmd, function(result)
    if result.exitCode ~= 0 then
      -- Let the next poll retry instead of believing a failed transition.
      bufferRunning = not wanted
      bufferOwned = false
      reportFailure(wanted and "could not start the replay buffer" or "could not stop the replay buffer", result)
      return
    end
    noctalia.log(wanted and "game-clip: replay buffer started" or "game-clip: replay buffer stopped")
  end)
end

local function poll()
  local now = noctalia.nowMs()
  if pollBusy then
    if now - pollStarted < POLL_TIMEOUT_MS then
      return
    end
    noctalia.log("game-clip: detection command timed out, retrying")
    pollBusy = false
  end

  pollBusy = true
  pollStarted = now

  detect(function(text, fullscreen)
    pollBusy = false
    remember(text, fullscreen)
    setBuffer(inGame)
  end)
end

local function trigger()
  detect(function(text, fullscreen)
    remember(text, fullscreen)

    if inGame then
      if bool("manage_replay_buffer", true) and not bufferRunning then
        noctalia.log("game-clip: replay buffer is not running, clip not saved")
        noctalia.notify(noctalia.tr("notify.buffer-cold.title"), noctalia.tr("notify.buffer-cold.body"))
        return
      end

      local cmd = command("clip_command", DEFAULT_CLIP)
      if cmd == "" then
        noctalia.log("game-clip: clip_command is empty, nothing to save")
        return
      end

      noctalia.log("game-clip: saving an instant replay clip")
      noctalia.runAsync(cmd, function(result)
        if result.exitCode ~= 0 then
          notifyError("notify.clip-failed.title", "notify.clip-failed.body", {
            error = reportFailure("clip command failed", result),
          })
        end
      end)
      return
    end

    local cmd = command("sticker_command", DEFAULT_STICKER)
    if cmd == "" then
      noctalia.log("game-clip: no game in focus and sticker_command is empty")
      return
    end

    noctalia.log("game-clip: no game in focus, showing the reaction sticker")
    noctalia.runAsync(cmd, function(result)
      if result.exitCode ~= 0 then
        notifyError("notify.sticker-failed.title", "notify.sticker-failed.body", {
          error = reportFailure("sticker command failed", result),
        })
      end
    end)
  end)
end

local function ensureInterval()
  local interval = math.max(250, math.floor(tonumber(setting("poll_ms", 2000)) or 2000))
  if interval ~= pollInterval then
    pollInterval = interval
    noctalia.setUpdateInterval(interval)
  end
end

function update()
  ensureInterval()
  poll()
end

function onIpc(event, _payload)
  if event == "trigger" or event == "toggle" then
    trigger()
  elseif event == "refresh" then
    poll()
  elseif event == "status" then
    noctalia.notify(noctalia.tr("notify.status.title"), noctalia.tr("notify.status.body", {
      game = inGame and (focused ~= "" and focused or noctalia.tr("status.yes")) or noctalia.tr("status.no"),
      buffer = bufferRunning and noctalia.tr("status.running") or noctalia.tr("status.stopped"),
    }))
  end
end

-- Stop the buffer we started when the plugin goes away, so disabling the plugin
-- does not leave an encoder running. A buffer started outside this plugin is
-- left alone.
function onExit(_signal, reason)
  if not (bufferOwned and bufferRunning) then
    return
  end

  bufferRunning = false
  bufferOwned = false

  local cmd = command("replay_stop_command", DEFAULT_REPLAY_STOP)
  if cmd == "" then
    return
  end
  noctalia.log("game-clip: stopping our replay buffer (" .. tostring(reason or "exit") .. ")")
  noctalia.runAsync(cmd, function() end)
end

-- Runtime start: fix the poll interval, announce it and take a first reading so
-- an already focused game is picked up immediately.
ensureInterval()
noctalia.log(string.format("game-clip: watching the focused window every %d ms", pollInterval))
poll()
