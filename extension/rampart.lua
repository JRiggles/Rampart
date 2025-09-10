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

if not GammaCorrection then
  GammaCorrection = "2.4" -- default value
end

-- helper functions for converting sRGB to/from OKLAB
local function srgbToLinear(c)
  if c <= 0.04045 then
    return c / 12.92
  else
    return ((c + 0.055) / 1.055) ^ tonumber(GammaCorrection)
  end
end

local function linearToSrgb(c)
  if c <= 0.0031308 then
    return c * 12.92
  else
    return 1.055 * (c ^ (1 / tonumber(GammaCorrection))) - 0.055
  end
end

local function srgbToOklab(r, g, b)
  -- convert sRGB to lRGB
  r, g, b = srgbToLinear(r), srgbToLinear(g), srgbToLinear(b)

  -- lRGB to LMS
  local l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
  local m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
  local s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b

  -- LMS to OKLAB
  local l_ = l ^ (1 / 3)
  local m_ = m ^ (1 / 3)
  local s_ = s ^ (1 / 3)

  local L = 0.2104542553 * l_ + 0.7936177850 * m_ + -0.0040720468 * s_
  local a = 1.9779984951 * l_ + -2.4285922050 * m_ + 0.4505937099 * s_
  local b_ = 0.0259040371 * l_ + 0.7827717662 * m_ + -0.8086757660 * s_

  return L, a, b_
end

local function oklabToSrgb(L, a, b)
  -- OKLAB to LMS
  local l_ = L + 0.3963377774 * a + 0.2158037573 * b
  local m_ = L + -0.1055613458 * a + -0.0638541728 * b
  local s_ = L + -0.0894841775 * a + -1.2914855480 * b

  local l = l_ ^ 3
  local m = m_ ^ 3
  local s = s_ ^ 3

  -- LMS to lRGB
  local r = 4.0767416621 * l + -3.3077115913 * m + 0.2309699292 * s
  local g = -1.2684380046 * l + 2.6097574011 * m + -0.3413193965 * s
  local b_ = -0.0041960863 * l + -0.7034186147 * m + 1.7076147010 * s

  -- lRGB to sRGB
  r, g, b_ = linearToSrgb(r), linearToSrgb(g), linearToSrgb(b_)

  -- clamp values to [0, 1]
  r = math.min(math.max(r, 0), 1)
  g = math.min(math.max(g, 0), 1)
  b_ = math.min(math.max(b_, 0), 1)

  return r, g, b_
end

local function getRandomColor()
  local r = math.random(0, 255)
  local g = math.random(0, 255)
  local b = math.random(0, 255)
  return Color {r = r, g = g, b = b}
end

-- Mixing Algorithms
local function perceptualLerp(color1, color2, t)
  -- convert sRGB to OKLAB
  local L1, a1, b1 = srgbToOklab(color1.red / 255, color1.green / 255, color1.blue / 255)
  local L2, a2, b2 = srgbToOklab(color2.red / 255, color2.green / 255, color2.blue / 255)
  -- interpolate in OKLAB space
  local L = L1 + (L2 - L1) * t
  local a = a1 + (a2 - a1) * t
  local b = b1 + (b2 - b1) * t
  -- convert back to RGB
  local r, g, b_ = oklabToSrgb(L, a, b)
  -- return Color object
  return Color {r = r * 255, g = g * 255, b = b_ * 255}
end

local function linLerp(color1, color2, t)
  local r = color1.red + (color2.red - color1.red) * t
  local g = color1.green + (color2.green - color1.green) * t
  local b = color1.blue + (color2.blue - color1.blue) * t
  -- return Color object
  return Color {r = r, g = g, b = b}
end

local function createColorPalette(color1, color2, steps, mixMode)
  local palette = {}
  steps = steps - 1 -- adjust steps to include both endpoints
  for i = 0, steps do
    local t = i / steps -- normalize t to be between 0 and 1
    if mixMode == "Perceptual" then
      palette[i + 1] = perceptualLerp(color1, color2, t)
    elseif mixMode == "Linear" then
      palette[i + 1] = linLerp(color1, color2, t)
    end
  end
  return palette
end

local function update(dlg)
  local data = dlg.data
  local ramp = createColorPalette(data.color1, data.color2, data.steps, data.mixMode)
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

  dlg:check {
    id = "advancedMode",
    label = "Advanced",
    selected = false,
    onclick = function()
      local data = dlg.data
      local isAdvanced = data.advancedMode
      dlg:modify {id = "mixMode", visible = isAdvanced}
      dlg:modify {id = "gammaCorrection", visible = isAdvanced}
    end
  }

  dlg:combobox {
    id = "mixMode",
    label = "Mix Mode",
    visible = false, -- only show when advanced mode is enabled
    option = "Perceptual",
    options = {"Perceptual", "Linear"}, -- TODO: spectral mixing
    onchange = function()
      local data = dlg.data
      dlg.data.mixMode = data.mixMode
      if data.mixMode == "Linear" then
        dlg:modify {id = "gammaCorrection", enabled = false}
      else
        dlg:modify {id = "gammaCorrection", enabled = true}
      end
      update(dlg)
    end
  }

  dlg:combobox {
    -- NOTE: slider widgets don't support floats, so combobox it is
    id = "gammaCorrection",
    label = "Gamma",
    visible = false, -- only show when advanced mode is enabled
    option = "2.2", -- default value
    -- NOTE: a gamma of 1.0 is linear, which is handled by the "Linear" mix mode
    options = {"1.2", "1.4", "1.6", "1.8", "2.0", "2.2", "2.4", "2.6", "2.8", "3.0"},
    onchange = function()
      local data = dlg.data
      dlg.data.gammaCorrection = data.gammaCorrection
      GammaCorrection = data.gammaCorrection -- update global variable
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
