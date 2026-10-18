--[[
Reaction trigger service.

Keeps the sticker ready for the whole session and owns the trigger path:

* Warms the GIF frame cache. The panel runtime only exists while the panel is
  open, so preloading from there would always be one trigger late.
* Opens the sticker on `trigger`. A second trigger while it is on screen
  restarts it instead of closing it: a plain panel toggle would close it, and a
  closed plugin panel has no runtime to receive IPC at all.

Trigger sources: the bar tile (same process, over the plugin state channel) and
external callers such as a keybind:

    noctalia msg plugin miixz/reaction:service all trigger
]]

local PANEL_ID = "miixz/reaction:sticker"

local dataDir = noctalia.pluginDataDir() or ("/tmp/noctalia-reaction-" .. tostring(os.time()))

local Gif = require("./lib/gif.luau")

local clip = Gif.new({ dataDir = dataDir, onLog = noctalia.log })

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

local function isVisible()
  return noctalia.state.get("visible") == true
end

local function restart()
  noctalia.state.set("restart", (noctalia.state.get("restart") or 0) + 1)
end

local function show()
  if isVisible() then
    noctalia.log("reaction: show - already on screen, restarting")
    restart()
    return
  end
  noctalia.log("reaction: show - opening the panel")
  noctalia.togglePanel(PANEL_ID)
end

local function hide()
  if isVisible() then
    noctalia.log("reaction: hide - closing the panel")
    noctalia.togglePanel(PANEL_ID)
  end
end

function update()
  -- Extraction runs once and lands in the plugin data dir, so this settles into
  -- a cheap no-op a second after the plugin is enabled.
  local path = stickerPath()
  if path ~= "" and Gif.isGif(path) then
    clip:setSource(path, sizePx())
  end
end

function onIpc(event, _payload)
  if event == "trigger" or event == "show" then
    show()
  elseif event == "hide" or event == "close" then
    hide()
  elseif event == "status" then
    local path = stickerPath()
    local state = "idle"
    if clip:ready() then
      state = string.format("ready, %d ms", clip:durationMs())
    elseif clip:isLoading() then
      state = "extracting frames"
    end
    noctalia.notify(
      noctalia.tr("notify.status.title"),
      noctalia.tr("notify.status.body", {
        sticker = path == "" and noctalia.tr("status.unset") or path,
        state = state,
      })
    )
  end
end

-- Local callers (bar tile) publish intent here.
noctalia.state.watch("trigger", function()
  show()
end)

noctalia.state.watch("hide", function()
  hide()
end)

noctalia.setUpdateInterval(2000)
