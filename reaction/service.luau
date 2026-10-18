--[[
Reaction trigger service.

Keeps the sticker ready for the whole session and owns the trigger path:

* Warms the GIF frame cache, so the transparent overlay process and the panel
  fallback both know the sticker's duration from the first trigger on.
* Routes `trigger` through the shared sticker module (lib/sticker.luau): the
  transparent overlay when its dependencies are present, the panel otherwise. A
  second trigger while the sticker is on screen restarts it instead of closing
  it.

Callers are external: a keybind, a script, or another plugin (miixz/game-clip
routes its trigger here when no game is focused):

    noctalia msg plugin miixz/reaction:service all trigger

The bar tile does not come through here: it calls the same shared module in
process, so a click works even in the moment this service is still starting.
]]

local dataDir = noctalia.pluginDataDir() or ("/tmp/noctalia-reaction-" .. tostring(os.time()))

local Gif = require("./lib/gif.luau")
local Sticker = require("./lib/sticker.luau")

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

local function show()
  noctalia.log("reaction: trigger")
  Sticker.show()
end

local function hide()
  noctalia.log("reaction: hide")
  Sticker.hide()
end

function update()
  -- Extraction runs once and lands in the plugin data dir, so this settles into
  -- a cheap no-op a second after the plugin is enabled.
  local path = stickerPath()
  if path ~= "" and Gif.isGif(path) then
    clip:setSource(path, sizePx())
  end
  Sticker.tick()
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

noctalia.setUpdateInterval(2000)
