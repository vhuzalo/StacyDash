local M = {}

function M.new(config)
  local self = {
    isEnabled = assert(config.isEnabled),
    armedColor = assert(config.armedColor),
    disarmedColor = assert(config.disarmedColor),
    mode = "",
    phase = -1,
  }

  function self:isAvailable()
    return type(LED_STRIP_LENGTH) == "number" and LED_STRIP_LENGTH > 0
           and type(setRGBLedColor) == "function"
           and type(applyRGBLedColors) == "function"
  end

  function self:solid(red, green, blue)
    for index = 0, LED_STRIP_LENGTH - 1 do
      setRGBLedColor(index, red, green, blue)
    end
    applyRGBLedColors()
  end

  function self:off()
    self:solid(0, 0, 0)
  end

  local function scaled(color, factor, minimum)
    local result = {}
    for channel = 1, 3 do
      local value = math.floor(color[channel] * factor + 0.5)
      if color[channel] > 0 then value = math.max(minimum or 0, value) end
      result[channel] = math.min(255, value)
    end
    return result
  end

  local function colorKey(mode, color)
    return mode .. ":" .. color[1] .. "," .. color[2] .. "," .. color[3]
  end

  function self:circulating(phase, baseColor)
    local halfLength = math.max(1, math.floor(LED_STRIP_LENGTH / 2))
    local colors = {}
    local intensities = { 1, 0.88, 0.69, 0.50, 0.31, 0.19 }
    for index = 1, #intensities do
      colors[index] = scaled(baseColor, intensities[index])
    end
    local background = scaled(baseColor, 0.03, 1)
    local travelLength = math.max(1, halfLength - 1)
    local cycleLength = math.max(1, travelLength * 2)
    local position = phase % cycleLength
    if position >= travelLength then position = cycleLength - position end

    for index = 0, LED_STRIP_LENGTH - 1 do
      setRGBLedColor(index, background[1], background[2], background[3])
    end
    for stripIndex = 0, 1 do
      local offset = stripIndex * halfLength
      for trailIndex = 1, #colors do
        local ledIndex = offset + position + trailIndex - 1
        if ledIndex < offset + halfLength and ledIndex < LED_STRIP_LENGTH then
          local color = colors[trailIndex]
          setRGBLedColor(ledIndex, color[1], color[2], color[3])
        end
      end
    end
    applyRGBLedColors()
  end

  function self:update(isArmed, hasDisableFlags)
    if not self:isAvailable() then return end

    if not self.isEnabled() then
      if self.mode ~= "OFF" then
        self.mode, self.phase = "OFF", -1
        self:off()
      end
      return
    end

    local armedColor = self.armedColor()
    local disarmedColor = self.disarmedColor()

    if hasDisableFlags then
      local phase = math.floor(((getTime and getTime()) or 0) / 2)
      local mode = colorKey("DISABLE", disarmedColor)
      if self.mode ~= mode or self.phase ~= phase then
        self.mode, self.phase = mode, phase
        self:circulating(phase, disarmedColor)
      end
    elseif isArmed then
      local mode = colorKey("ARMED", armedColor)
      if self.mode ~= mode then
        self.mode, self.phase = mode, -1
        self:solid(armedColor[1], armedColor[2], armedColor[3])
      end
    else
      local mode = colorKey("DISARMED", disarmedColor)
      if self.mode ~= mode then
        self.mode, self.phase = mode, -1
        self:solid(disarmedColor[1], disarmedColor[2], disarmedColor[3])
      end
    end
  end

  return self
end

return M
