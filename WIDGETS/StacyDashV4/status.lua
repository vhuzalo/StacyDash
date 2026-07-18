local M = {}

local FLAG_NAMES = {
  [0]="NO GYRO",       [1]="FAIL SAFE",     [2]="RX FAIL SAFE",
  [3]="BAD RX RECOVERY", [4]="BOX FAIL SAFE", [5]="GOVERNOR",
  [7]="THROTTLE",      [8]="ANGLE",         [9]="BOOT GRACE",
  [10]="NO PREARM",    [11]="LOAD",         [12]="CALIBRATING",
  [13]="CLI",          [14]="CMS MENU",     [15]="BST",
  [16]="MSP",          [17]="PARALYZE",     [18]="GPS",
  [19]="RESC",         [20]="RPM FILTER",   [21]="REBOOT REQD",
  [22]="DSHOT BITBANG", [23]="ACC CAL",      [24]="MOTOR PROTO",
  [25]="ARM SWITCH",
}

function M.new(config)
  local self = {
    data = assert(config.data),
    frame = assert(config.frame),
    alerts = assert(config.alerts),
    getSensorNumber = assert(config.getSensorNumber),
    getNamed = assert(config.getNamed),
    getGovState = assert(config.getGovState),
    getHeliType = assert(config.getHeliType),
    ompType = assert(config.ompType),
    audioPath = config.audioPath or "/WIDGETS/StacyDashV4/audio/",
  }

  function self:isOmp()
    return self.getHeliType() == self.ompType
  end

  function self:getArmState()
    local value = self.frame.armState
    if value ~= nil then return value ~= false and value or nil end
    if self:isOmp() then
      self.data.armValid = false
      self.frame.armState = false
      return nil
    end
    value = self.getSensorNumber("arm")
    local whole = value ~= nil and math.floor(value) or nil
    local sane = whole ~= nil and value == whole and whole >= 0 and whole <= 3
    self.data.armValid = sane
    self.frame.armState = sane and whole or false
    return sane and whole or nil
  end

  function self:getArmingDisableFlags()
    local value = self.frame.armingFlags
    if value ~= nil then return value ~= false and value or nil end
    if self:isOmp() then
      self.data.armingFlagsValid = false
      self.frame.armingFlags = false
      return nil
    end
    value = self.getSensorNumber("armingDisable")
    if value == nil then
      -- getNamed() mirrors the telemetry resolver and may return value plus
      -- current/fresh/existence flags. Capture only the first result so the
      -- second boolean is not passed to tonumber() as its optional base.
      local raw = self.getNamed("Arming Disable")
      value = tonumber(raw)
    end
    local sane = value ~= nil and value >= 0 and value <= 4294967295
    self.data.armingFlagsValid = sane
    self.frame.armingFlags = sane and math.floor(value) or false
    return sane and math.floor(value) or nil
  end

  function self:getPidProfile()
    local value = self.frame.pidProfile
    if value ~= nil then return value ~= false and value or nil end
    if self:isOmp() then
      self.data.pidProfileValid = false
      self.frame.pidProfile = false
      return nil
    end
    value = self.getSensorNumber("pidProfile")
    local whole = value ~= nil and math.floor(value) or nil
    local sane = whole ~= nil and value == whole and whole >= 0 and whole <= 99
    self.data.pidProfileValid = sane
    self.frame.pidProfile = sane and whole or false
    return sane and whole or nil
  end

  function self:flagsText(flags)
    if flags == nil then return "" end
    local names = {}
    for index = 0, 25 do
      local mask = 2 ^ index
      if math.floor(flags / mask) % 2 == 1 then
        local name = FLAG_NAMES[index]
        if name then names[#names+1] = name end
      end
    end
    return table.concat(names, " · ")
  end

  function self:play(relativePath)
    if not playFile or not relativePath then return false end
    return pcall(playFile, self.audioPath .. relativePath)
  end

  function self:updateAudio()
    local arm = self:getArmState()
    if self.data.armValid then
      local state = (arm == 1 or arm == 3) and "ARMED" or "DISARMED"
      if self.alerts.lastArmAudioState ~= nil
         and state ~= self.alerts.lastArmAudioState then
        self:play(state == "ARMED" and "armed.wav" or "disarmed.wav")
      end
      self.alerts.lastArmAudioState = state
    else
      self.alerts.lastArmAudioState = nil
    end

    local governor = self.getGovState()
    local govAudio = {
      OFF="gov/off.wav", IDLE="gov/idle.wav",
      SPOOLUP="gov/spoolup.wav", ACTIVE="gov/active.wav",
    }
    local hasGovState = self.data.govValid or self.data.throttleValid
    if hasGovState and governor ~= "--" then
      if self.alerts.lastGovAudioState ~= nil
         and governor ~= self.alerts.lastGovAudioState then
        self:play(govAudio[governor])
      end
      self.alerts.lastGovAudioState = governor
    else
      self.alerts.lastGovAudioState = nil
    end

    local profile = self:getPidProfile()
    if self.data.pidProfileValid then
      if self.alerts.lastProfileAudioState ~= nil
         and profile ~= self.alerts.lastProfileAudioState and profile > 0 then
        self:play("profile.wav")
        if profile <= 6 then self:play("profile/" .. profile .. ".wav") end
      end
      self.alerts.lastProfileAudioState = profile
    else
      self.alerts.lastProfileAudioState = nil
    end
  end

  return self
end

return M
