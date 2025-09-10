EPSILON = 2.2204460492503130808472633361816 * 10 ^ -16.

local Math = require("math") -- import math library
local Luts = require("luts") -- import lookup tables

-- Define the class
Spectral = {}
Spectral.__index = Spectral  -- Set the metatable for Spectral

-- Constructor
function Spectral:new(color)  -- TODO: get color from user / Aseprite color picker as an object
  local instance = setmetatable({}, Spectral)
  instance.sRGB = color
  instance.lRGB = self.sRGB_to_lRGB(instance.sRGB)  -- convert to linear RGB
  instance.R = self.lRGB_to_R(instance.lRGB)  -- convert to reflectance
  instance.XYZ = self.R_to_XYZ(instance.R)
  return instance  -- Return the instance
end

function Spectral:sRGB_to_lRGB(color)
  -- sRGB to linear RGB conversion
  return { color.red / 255, color.green / 255, color.blue / 255 }
end

function Spectral:lRGB_to_R(lRGB)
  -- linear RGB to reflectance conversion
  local w = Math.min(lRGB.r, lRGB.g, lRGB.b)

  lRGB.r = lRGB.r - w
  lRGB.g = lRGB.g - w
  lRGB.b = lRGB.b - w

  local c = Math.min(lRGB.g, lRGB.b)
  local m = Math.min(lRGB.r, lRGB.b)
  local y = Math.min(lRGB.r, lRGB.g)
  local r = Math.max(0, Math.min(lRGB.r - lRGB.b, lRGB.r - lRGB.g))
  local g = Math.max(0, Math.min(lRGB.g - lRGB.b, lRGB.g - lRGB.r))
  local b = Math.max(0, Math.min(lRGB.b - lRGB.g, lRGB.b - lRGB.r))

  local R = {}

  for i = 1, #Luts.BASE_SPECTRA.W do
    R[i] = Math.max(
      EPSILON,
      w * Luts.BASE_SPECTRA.W[i] +
      c * Luts.BASE_SPECTRA.C[i] +
      m * Luts.BASE_SPECTRA.M[i] +
      y * Luts.BASE_SPECTRA.Y[i] +
      r * Luts.BASE_SPECTRA.R[i] +
      g * Luts.BASE_SPECTRA.G[i] +
      b * Luts.BASE_SPECTRA.B[i]
    )
  end
  return R
end

function Spectral:R_to_XYZ(R)
  -- multiply the vector table R with the CIE matrix to get the color in XYZ space
  -- TODO
end

function Spectral:mix(a, b)
  -- TODO
end

function Spectral:palette(a, b, size)
  local p = {}
  for i = 1, size do
    p[i] = Spectral:mix({a, size - i}, {b, i})
  end
  return p
end

return Spectral
