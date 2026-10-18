--[[
Reaction bar tile.

Left click shows the sticker, right click dismisses it. The tile only publishes
intent on the plugin state channel and the trigger service does the panel work,
so the behaviour matches the keybind path exactly. The tile also mirrors the
panel state by tinting its glyph while the sticker is on screen.
]]

barWidget.setGlyph("mood-smile")
barWidget.setGlyphColor("on_surface_variant")
barWidget.setTooltip(noctalia.tr("widget.tooltip"))

local function bump(key)
  noctalia.state.set(key, (noctalia.state.get(key) or 0) + 1)
end

function onClick()
  bump("trigger")
end

function onRightClick()
  bump("hide")
end

noctalia.state.watch("visible", function(value)
  barWidget.setGlyphColor(value == true and "primary" or "on_surface_variant")
end)
