local M = {}

function M.new(config)
  local self = {
    isEnabled = assert(config.isEnabled),
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

  function self:circulatingRed(phase)
    local halfLength = math.max(1, math.floor(LED_STRIP_LENGTH / 2))
    local colors = {
      {255, 0, 0}, {224, 0, 0}, {176, 0, 0},
      {128, 0, 0}, {80, 0, 0}, {48, 0, 0},
    }
    local travelLength = math.max(1, halfLength - 1)
    local cycleLength = math.max(1, travelLength * 2)
    local position = phase % cycleLength
    if position >= travelLength then position = cycleLength - position end

    for index = 0, LED_STRIP_LENGTH - 1 do
      setRGBLedColor(index, 8, 0, 0)
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

    if hasDisableFlags then
      local phase = math.floor(((getTime and getTime()) or 0) / 2)
      if self.mode ~= "DISABLE" or self.phase ~= phase then
        self.mode, self.phase = "DISABLE", phase
        self:circulatingRed(phase)
      end
    elseif isArmed then
      if self.mode ~= "ARMED" then
        self.mode, self.phase = "ARMED", -1
        self:solid(0, 80, 255)
      end
    elseif self.mode ~= "DISARMED" then
      self.mode, self.phase = "DISARMED", -1
      self:solid(255, 0, 0)
    end
  end

  return self
end

return M
