--[[
MIT LICENSE
Copyright © 2025 John Riggles [sudo_whoami]

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]
-- stop complaining about unknown Aseprite API methods
---@diagnostic disable: undefined-global
-- ignore dialogs which are defined with local names for readablity, but may be unused
---@diagnostic disable: unused-local

local preferences = {} -- create a global table to store extension preferences

MINSPEPS = 2
MAXSTEPS = 32

local function getRandomColor()
  local r = math.random(0, 255)
  local g = math.random(0, 255)
  local b = math.random(0, 255)
  return Color {r = r, g = g, b = b}
end

local function lerpColor(color1, color2, t)
  local r = color1.red + (color2.red - color1.red) * t
  local g = color1.green + (color2.green - color1.green) * t
  local b = color1.blue + (color2.blue - color1.blue) * t
  return Color {r = r, g = g, b = b}
end

local function createColorPalette(color1, color2, steps)
  local palette = {}
  steps = steps - 1 -- adjust steps to include both endpoints
  for i = 0, steps do
    local t = i / steps -- normalize t to be between 0 and 1
    palette[i + 1] = lerpColor(color1, color2, t)
  end
  return palette
end

local function update(dlg)
  local data = dlg.data
  local ramp = createColorPalette(data.color1, data.color2, data.steps)
  dlg:modify {id = "rampPreview", colors = ramp}
end

local function updateSpritePalette(colors, mode)
  local sprite = app.activeSprite
  if not sprite then
    return
  end
  -- get the current palette
  local pal = sprite.palettes[1]
  if not pal then
    return
  end

  local startIndex
  if mode == "replace" then
    startIndex = 0
  else
    startIndex = #pal
  end

  local newSize = startIndex + #colors
  pal:resize(newSize) -- resize palette to fit new colors

  for i, color in ipairs(colors) do -- add new colors to the palette
    pal:setColor(startIndex + (i - 1), color)
  end
end

local function main()
  local dlg = Dialog("Rampart - Color ramp generator")
  dlg:color {
    id = "color1",
    color = getRandomColor(),
    onchange = function()
      local data = dlg.data
      dlg.data.color1 = data.color1
      update(dlg)
    end
  }
  dlg:color {
    id = "color2",
    color = getRandomColor(),
    onchange = function()
      local data = dlg.data
      dlg.data.color2 = data.color2
      update(dlg)
    end
  }

  dlg:slider {
    id = "steps",
    label = "Steps",
    min = MINSPEPS,
    max = MAXSTEPS,
    value = 8,
    onchange = function()
      local data = dlg.data
      dlg.data.steps = data.steps
    end,
    onrelease = function()
      update(dlg)
    end
  }

  dlg:shades {id = "rampPreview", label = "Preview", mode = "sort"}

  dlg:separator()

  dlg:button {
    id = "swapColors",
    text = "Swap colors",
    onclick = function()
      local data = dlg.data
      local temp = data.color1
      dlg:modify {id = "color1", color = data.color2}
      dlg:modify {id = "color2", color = temp}
      update(dlg)
    end
  }
  dlg:button {
    id = "randomize",
    text = "Randomize",
    onclick = function()
      dlg:modify {id = "color1", color = getRandomColor()}
      dlg:modify {id = "color2", color = getRandomColor()}
      dlg:modify {id = "steps", value = math.random(MINSPEPS, MAXSTEPS)}
      update(dlg)
    end
  }

  dlg:newrow()

  dlg:button {
    id = "appendPalette",
    text = "Add to palette",
    onclick = function()
      updateSpritePalette(dlg.data.rampPreview, "append")
    end
  }
  dlg:button {
    id = "replacePalette",
    text = "Replace palette",
    onclick = function()
      updateSpritePalette(dlg.data.rampPreview, "replace")
    end
  }

  update(dlg) -- initial update to show the ramp
  dlg:show()
end

-- Aseprite plugin API stuff...
---@diagnostic disable-next-line: lowercase-global
function init(plugin) -- initialize extension
  preferences = plugin.preferences -- update preferences global with plugin.preferences values

  plugin:newCommand {
    id = "rampart",
    title = "Generate Color Ramp",
    group = "palette_generation",
    onclick = main -- run main function
  }
end

---@diagnostic disable-next-line: lowercase-global
function exit(plugin)
  plugin.preferences = preferences -- save preferences
  return nil
end
