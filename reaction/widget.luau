--[[
Reaction bar tile.

Left click shows the sticker and right click dismisses it. The tile drives the
panel directly: noctalia.togglePanel runs in process, while publishing an event
for the trigger service would race its startup (a state watch only fires on
changes, so an event sent before the service registered its watch is lost).

While the sticker is already on screen the tile asks for a restart instead of a
close, matching a second keypress: the open panel watches `restart` and starts
itself over from zero. The panel publishes `visible`, which tints the glyph.
]]

local PANEL_ID = "miixz/reaction:sticker"

local function bump(key)
  noctalia.state.set(key, (noctalia.state.get(key) or 0) + 1)
end

local function isVisible()
  return noctalia.state.get("visible") == true
end

local function tint(visible)
  barWidget.setGlyphColor(visible and "primary" or "on_surface_variant")
end

barWidget.setGlyph("mood-smile")
barWidget.setTooltip(noctalia.tr("widget.tooltip"))
tint(isVisible())

function onClick()
  if isVisible() then
    bump("restart")
    return
  end
  noctalia.togglePanel(PANEL_ID)
end

function onRightClick()
  if isVisible() then
    noctalia.togglePanel(PANEL_ID)
  end
end

noctalia.state.watch("visible", function(value)
  tint(value == true)
end)
