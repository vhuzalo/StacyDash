local W, H = LCD_W or 800, LCD_H or 480
local SUPPORTED_LCD_W, SUPPORTED_LCD_H = 800, 480
local BOLD         = rawget(_G, "BOLD")         or BOLD         or 0
local SMLSIZE      = rawget(_G, "SMLSIZE")      or SMLSIZE      or 0
local MIDSIZE      = rawget(_G, "MIDSIZE")      or MIDSIZE      or 0
local DBLSIZE      = rawget(_G, "DBLSIZE")      or DBLSIZE      or 0
local VALUE  = rawget(_G, "VALUE")  or 0
local BOOL   = rawget(_G, "BOOL")   or 2
local CHOICE = rawget(_G, "CHOICE") or 10
local STRING = rawget(_G, "STRING") or 3
local SOURCE = rawget(_G, "SOURCE") or _G.SOURCE or 1
-- EdgeTX exposes these flags through its read-only global lookup table. The
-- public Lua name for CENTERED is CENTER, so rawget("CENTERED") silently
-- returned nil and made every intended centered/right-aligned label align left.
local RIGHT = rawget(_G, "RIGHT") or _G.RIGHT or 0
local CENTERED = rawget(_G, "CENTER") or rawget(_G, "CENTERED")
                 or _G.CENTER or _G.CENTERED or 0
local L
local C_BG, C_TEXT, C_DIM, C_LINE, C_TILE
local C_GREEN_BG, C_GREEN_BR
local C_YELLOW_BG, C_YELLOW_BR
local C_RED_BG,    C_RED_BR
local C_BLUE_BG,   C_BLUE_BR
local C_GREEN, C_YELLOW, C_RED, C_BLUE
local DEFAULT_ACCENT, C_ACCENT
local C_BLACK
local GOV_STATES = {
  [0]="OFF",      [1]="IDLE",     [2]="SPOOLUP",  [3]="RECOVERY",
  [4]="ACTIVE",   [5]="THR-OFF",  [6]="LOST-HS",
  [7]="AUTOROT",  [8]="BAILOUT",  [9]="BYPASS",
}
-- Only explicit, recognized states participate in the motor-alert gate. An
-- unknown future enum must never be interpreted as motor-off.
local GOV_RUNNING_STATE = {
  [2]=true, -- SPOOLUP
  [3]=true, -- RECOVERY
  [4]=true, -- ACTIVE
  [8]=true, -- BAILOUT
  [9]=true, -- BYPASS
}
local GOV_STOP_STATE = {
  [0]=true, -- OFF
  [5]=true, -- THR-OFF / lost throttle
  [7]=true, -- AUTOROT
}
local GOV_PAUSE_HOLD_STATE = {
  [0]=true, -- OFF
  [1]=true, -- IDLE after a previously validated stop
  [5]=true, -- THR-OFF / lost throttle
  [7]=true, -- AUTOROT
}
local GOV_LABELS = { AUTOROT="AUTO" }
local MODULE = {}
function MODULE.load(name)
  local path = "/WIDGETS/StacyDashV4/" .. name .. ".lua"
  local chunk = loadScript and loadScript(path)
  if not chunk and loadfile then chunk = loadfile("WIDGETS/StacyDashV4/" .. name .. ".lua") end
  assert(chunk, "Unable to load StacyDash module: " .. name)
  return chunk()
end
MODULE.flights = MODULE.load("flights")
MODULE.status = MODULE.load("status")
MODULE.themes = MODULE.load("themes")
MODULE.ui = MODULE.load("ui")
MODULE.leds = MODULE.load("leds")
local GOV_COLOR = {}
local GOV_FALLBACK = {}
local themeAccent = nil
-- Single-color themes (orange..lime): solid bg + tiles a lighter shade of the
-- SAME hue (the original monochromatic look). Two-tone themes (reef..miami):
-- solid bg paired with a DIFFERENT-hue tile. Both keep white text + status
-- colors legible. CHOICE values are 1-based. (bg = page background, tile = panel.)
local function applyTheme(name)
  local rgb = lcd.RGB
  themeAccent = nil
  if not C_GREEN then
    C_GREEN        = rgb( 34, 197,  94)
    C_YELLOW       = rgb(240, 180,  41)
    C_RED          = rgb(239,  68,  68)
    C_BLUE         = rgb( 50, 130, 235)
    DEFAULT_ACCENT = rgb( 95, 211, 188)
    C_ACCENT       = DEFAULT_ACCENT
    C_BLACK        = rgb(  0,   0,   0)
  end
  if name == "light" then
    C_BG        = rgb(255, 255, 255)
    C_TEXT      = rgb(  0,   0,   0)
    C_DIM       = rgb(110, 110, 110)
    C_LINE      = rgb(210, 210, 210)
    C_TILE      = rgb(242, 242, 242)
    C_GREEN_BG  = rgb(220, 245, 228)
    C_GREEN_BR  = rgb(160, 210, 178)
    C_YELLOW_BG = rgb(255, 243, 205)
    C_YELLOW_BR = rgb(230, 200, 100)
    C_RED_BG    = rgb(252, 225, 225)
    C_RED_BR    = rgb(230, 170, 170)
    C_BLUE_BG   = rgb(225, 238, 255)
    C_BLUE_BR   = rgb(170, 200, 235)
  else
    C_BG        = rgb(  0,   0,   0)
    C_TEXT      = rgb(255, 255, 255)
    C_DIM       = rgb(124, 134, 148)
    C_LINE      = rgb( 42,  45,  51)
    C_TILE      = rgb( 13,  14,  17)
    C_GREEN_BG  = rgb( 12,  42,  22)
    C_GREEN_BR  = rgb( 29,  77,  42)
    C_YELLOW_BG = rgb( 42,  33,  10)
    C_YELLOW_BR = rgb( 90,  67,  19)
    C_RED_BG    = rgb( 42,  13,  13)
    C_RED_BR    = rgb( 88,  27,  27)
    C_BLUE_BG   = rgb( 13,  31,  42)
    C_BLUE_BR   = rgb( 30,  66,  88)
    local ct = MODULE.themes.colors(name)
    if ct then
      C_BG   = rgb(ct.bg[1],   ct.bg[2],   ct.bg[3])
      C_TILE = rgb(ct.tile[1], ct.tile[2], ct.tile[3])
      C_LINE = rgb(ct.line[1], ct.line[2], ct.line[3])
      C_DIM  = rgb(ct.dim[1],  ct.dim[2],  ct.dim[3])
      themeAccent = rgb(ct.accent[1], ct.accent[2], ct.accent[3])
    end
  end
  GOV_COLOR.ACTIVE     = { fg=C_GREEN,  bg=C_GREEN_BG,  br=C_GREEN_BR  }
  GOV_COLOR.IDLE       = { fg=C_YELLOW, bg=C_YELLOW_BG, br=C_YELLOW_BR }
  GOV_COLOR.SPOOLUP    = { fg=C_YELLOW, bg=C_YELLOW_BG, br=C_YELLOW_BR }
  GOV_COLOR.RECOVERY   = { fg=C_YELLOW, bg=C_YELLOW_BG, br=C_YELLOW_BR }
  GOV_COLOR.OFF        = { fg=C_RED,    bg=C_RED_BG,    br=C_RED_BR    }
  GOV_COLOR["THR-OFF"] = { fg=C_RED,    bg=C_RED_BG,    br=C_RED_BR    }
  GOV_COLOR["LOST-HS"] = { fg=C_RED,    bg=C_RED_BG,    br=C_RED_BR    }
  GOV_COLOR.AUTOROT    = { fg=C_BLUE,   bg=C_BLUE_BG,   br=C_BLUE_BR   }
  GOV_COLOR.BAILOUT    = { fg=C_BLUE,   bg=C_BLUE_BG,   br=C_BLUE_BR   }
  GOV_COLOR.BYPASS     = { fg=C_BLUE,   bg=C_BLUE_BG,   br=C_BLUE_BR   }
  GOV_FALLBACK.fg = C_DIM
  GOV_FALLBACK.bg = C_TILE
  GOV_FALLBACK.br = C_LINE
end
-- Shared, SD-card-wide flight history. Keeping one authoritative root file
-- lets other dashboards use the same per-model counters without migration or
-- competing widget-local copies.
local TOPBAR_MIN_DUR_DEFAULT    = 60
local S = {
  rpmMax = 0,
  currMax = 0, tempMax = 0,
  becMin = nil, cellMin = nil, packMin = nil,
}
local D = {
  adjustedPercent = 0,
  hasBattData     = false,
  isLiHV          = false,
  capacity        = 0,
  minCellVoltage  = nil,
  voltage         = 0,
  cellsResolved   = 0,
  rxVoltage       = nil,
  rxCellVoltage   = nil,
  rxPercent       = 0,
  minRxVoltage    = nil,
  packVoltageValid= false,
  cellCountValid  = false,
  cellVoltageValid= false,
  batteryPercentValid = false,
  capacityValid   = false,
  currentValid    = false,
  tempValid       = false,
  becValid        = false,
  rpmValid        = false,
  tailRpmValid    = false,
  govValid        = false,
  govCurrentInvalid = false,
  throttleValid   = false,
  armValid        = false,
  armingFlagsValid= false,
  pidProfileValid = false,
}
local A = {
  displayPercent     = 0,
  displayPercentInit = false,
  battAlertPrevPct       = nil,
  battAlertPrevSource    = nil,
  battVoicePlayed        = {},
  battZeroReached        = false,
  deadVoiceNextTick      = 0,
  flightDeadVoiceLatched = false,
  flightDeadVoiceAcknowledged = false,
  flightDeadVoiceStartPosition = nil,
  motorSwitchPosition    = nil,
  motorSwitchLastPosition= nil,
  motorPausedPosition    = nil,
  motorGateCandidateFrom = nil,
  motorGateCandidateTo   = nil,
  motorGateCandidateTick = nil,
  govGateLastState       = nil,
  govGateRunningPosition = nil,
  govGateStopTick        = nil,
  govGateStopSince       = nil,
  electricRpmGateRunningPosition = nil,
  electricRpmGateZeroSince       = nil,
  ompGateRunningPosition = nil,
  ompGateZeroSince       = nil,
  flightBatteryAlertsPaused = false,
  batteryAlertPauseTick  = nil,
  motorPauseProof        = nil,
  battAlert5HapticPlayed = false,
  battAlert0HapticPlayed = false,
  battAlertNextTick      = 0,
  battHapticState        = 0,
  battHapticBurstCount   = 0,
  battHapticNextTick     = 0,
  battHapticEndTick      = 0,
  escTempAlertPlayed = false,
  becAlertPlayed     = false,
  liHvHighSamples       = 0,
  motorSourcePhysical   = false,
  motorSourceReadable   = false,
  motorConfigError      = "SET MOTOR SWITCH",
  linkAvailable          = false,
  linkSourceKnown        = false,
  linkSourceSeen         = false,
  battReplacementSince  = nil,
  rxLowSinceTick         = nil,
  rxLowHapticNext        = 0,
  rxDeadVoiceLatched     = false,
  rxDeadVoiceAcknowledged= false,
  rxDeadVoiceStartPosition = nil,
  rxDeadVoiceNextTick    = 0,
  escTempHighSince       = nil,
  becLowSince            = nil,
  lastDataTick = -1,
  lastArmAudioState = nil,
  lastGovAudioState = nil,
  lastProfileAudioState = nil,
}
local HELI_ELECTRIC, HELI_NITRO, HELI_OMPHOBBY, HELI_BETAFLIGHT = 1, 2, 3, 4
local OPT = {
  heliType     = HELI_ELECTRIC,
  battBarMode   = 0,
  reservePct    = 0,
  battVoice     = false,
  displayLeds   = false,
  rxPackMin     = 6.6,
  rxPackMax     = 8.4,
  rxPackValid   = true,
  bgTransparent = false,
}
MODULE.ledService = MODULE.leds.new({
  isEnabled = function() return OPT.displayLeds end,
})
local BATTERY_VOICE = {
  levels       = { 50, 40, 30, 20, 10, 0 },
  path         = "/WIDGETS/StacyDashV4/BatterySounds/",
  available    = {},
  initialDelay = 250,
  repeatDelay  = 220,
  replacementConfirm = 100, -- require a one-second rise before rearming for a new pack
}
BATTERY_VOICE.deadPath = BATTERY_VOICE.path .. "dead.wav"
-- Percentage clips are currently about 0.8-1.0s and dead.wav is ~1.18s.
-- These conservative delays keep files from continuously filling the EdgeTX
-- audio queue and leave clear silence between critical repetitions.
local SAFETY = {
  batteryAlertCooldown = 220, -- comfortably longer than the percentage clips
  batteryHapticThreshold = 10,
  batteryPercentUnit = rawget(_G, "UNIT_PERCENT") or 13,
  rxLowArmTicks = 200,        -- low receiver pack must persist for 2.0s
  rxLowHapticInterval = 20,   -- then buzz every 0.2s while it stays low
  escTempThreshold = 110,
  escTempRearm = 100,
  becAlertMinVoltage = 4.0, -- ignore USB leakage when no receiver pack is powered
  becVoltThreshold = 4.8,
  becVoltRearm = 5.0,
  alertConfirmTicks = 50,     -- ESC/BEC conditions must persist for 0.5s
  displayPercentAlpha = 0.15,
  rxPackMinAllowed = 4.0,
  rxPackMaxAllowed = 9.0,
  maxCellCount = 16,
  maxCellSanityV = 4.5,
  cellRedThreshold = 3.50,
  liHvDetectCellV = 4.22,
  liHvConfirmSamples = 10, -- one continuous second at the 10 Hz service rate
  govMotorCorrelationTicks = 150, -- switch/Gov events may arrive 1.5s apart
  govMotorStopConfirmTicks = 20,  -- require 0.2s of recognized stopped state
  electricMotorStopWindowTicks = 3000, -- allow a 30s Hspd coast-down
  electricMotorZeroConfirmTicks = 30, -- require 0.3s of displayed-zero Hspd
  electricMotorRunningRpm = 1, -- raw Hspd below 1 RPM matches displayed zero
  ompMotorStopWindowTicks = 3000, -- allow a 30s autorotation/spindown
  ompMotorZeroConfirmTicks = 30,   -- require 0.3s of current displayed-zero NR
  ompMotorRunningRpm = 1, -- raw NR below 1 RPM matches the displayed zero state
}
-- Source metadata distinguishes a missing zero from a live value. This matters
-- most for Smart Fuel: Bat%=0 is meaningful only when a flight pack is actually
-- present, while positive current values can stand on their own.
local txIsLiIon = false
local F = {}
local RESOLVED = {}
local function clearFrameCache()
  for k in pairs(F) do F[k] = nil end
end
-- Localize the hottest host globals so per-call lookups skip the global table.
local getValue = getValue
local getTime  = getTime
-- getTime(), cached once per frame. Alert paths ask for "now" repeatedly
-- within a single frame; this collapses those into one host call.
local function frameNow()
  local t = F.now
  if t ~= nil then return t end
  t = (getTime and getTime()) or 0
  F.now = t
  return t
end
local SRC = {}
local function getValSrc(srcId)
  if not srcId or srcId == 0 then return nil end
  local ok, v = pcall(getValue, srcId)
  if not ok or v == nil then return nil end
  if type(v) == "table" then v = v.value end
  return tonumber(v)
end
-- Parse an Rx-pack voltage typed as text ("6.60"), tolerant of whether EdgeTX
-- text entry offers a ".", and backward-compatible with the old integer scale:
--   <=15 -> volts as typed (6.6) ; 16-150 -> old tenths (66->6.6) ; >150 -> hundredths (660->6.6)
local function parseVolt(s, default)
  local str = string.match(tostring(s or ""), "^%s*(.-)%s*$")
  local validText = string.match(str, "^%d+$")
                    or string.match(str, "^%d+[.,]%d+$")
                    or string.match(str, "^[.,]%d+$")
  if not validText then return default end
  str = string.gsub(str, ",", ".")
  local v = tonumber(str)
  if not v or v <= 0 then return default end
  if v > 150 then return v / 100 end
  if v > 15  then return v / 10  end
  return v
end
local getFieldInfoFn = getFieldInfo
local getSourceNameFn = getSourceName
local function isPhysicalMotorSource(src)
  local id = tonumber(src)
  if not id or id == 0 then return false end

  local inspected = false
  if getFieldInfoFn then
    local ok, info = pcall(getFieldInfoFn, id)
    inspected = ok
    if ok and type(info) == "table" then
      local name = string.upper(tostring(info.name or ""))
      local desc = string.upper(tostring(info.desc or ""))
      if string.match(name, "^S[A-Z]$") or string.match(desc, "^SWITCH%s+[A-Z]") then
        return true
      end
    end
  end
  if getSourceNameFn then
    local ok, name = pcall(getSourceNameFn, id)
    inspected = inspected or ok
    if ok and string.match(string.upper(tostring(name or "")), "^S[A-Z]$") then
      return true
    end
  end

  -- Older supported firmwares may not expose source inspection. A configured,
  -- readable SOURCE is still safer than silently falling back to a channel.
  return not inspected
end
local function applyOptions(opts)
  local rawTheme = tonumber(opts and opts.Theme) or 0
  OPT.bgTransparent   = (rawTheme == 3)
  applyTheme(MODULE.themes.nameForOption(rawTheme))
  local rawBatt = tonumber(opts and opts.TxBatt) or 0
  txIsLiIon = (rawBatt == 2)
  local rawDur = tonumber(opts and (opts.MinFlight
                                    or opts["Min. Flight Time (sec)"]
                                    or opts.TopMinDur))
                 or TOPBAR_MIN_DUR_DEFAULT
  if rawDur < 0 then rawDur = math.abs(rawDur) end
  if rawDur < 1 then rawDur = 1 end
  if MODULE.flightService then MODULE.flightService:setMinimum(rawDur) end
  if opts then
    -- The Motor Switch is the only mapped source. Rotorflight Gov/Hspd or OMP
    -- NR telemetry validates what a movement means; other sensors auto-detect.
    SRC.motorSwitch = opts.MotorSw or opts["Motor Switch"] or 0
    -- Keep the persisted HeliType key and its first three indices stable.
    -- Betaflight is appended as value 4 for backward-compatible model settings.
    local bb = tonumber(opts.HeliType or opts["Aircraft Type"]
                        or opts["Heli Type"]) or 1
    if bb < 1 or bb > 4 then bb = 1 end
    OPT.heliType = bb
    OPT.battBarMode = (bb == HELI_NITRO) and 1 or 0
    OPT.reservePct  = tonumber(opts.BattRsv or opts["Batt Reserve %"]) or 0
    if OPT.reservePct < 0 then OPT.reservePct = 0 end
    if OPT.reservePct > 50 then OPT.reservePct = 50 end
    OPT.battVoice   = (opts.BattVoice == 1 or opts.BattVoice == true)
    OPT.displayLeds = (opts.DispLED == 1 or opts.DispLED == true)
    local parsedMin = parseVolt(opts.RxPackMin, nil)
    local parsedMax = parseVolt(opts.RxPackMax, nil)
    OPT.rxPackMin = parsedMin or 6.6
    OPT.rxPackMax = parsedMax or 8.4
    OPT.rxPackValid = parsedMin ~= nil and parsedMax ~= nil
                       and parsedMin >= SAFETY.rxPackMinAllowed
                       and parsedMax <= SAFETY.rxPackMaxAllowed
                       and (parsedMax - parsedMin) >= 0.1
  end
  A.motorSourcePhysical = isPhysicalMotorSource(SRC.motorSwitch)
  A.motorSourceReadable = A.motorSourcePhysical
                          and getValSrc(SRC.motorSwitch) ~= nil
  if not A.motorSourcePhysical then
    A.motorConfigError = "SELECT A PHYSICAL MOTOR SWITCH"
  elseif not A.motorSourceReadable then
    A.motorConfigError = "MOTOR SWITCH UNAVAILABLE"
  else
    A.motorConfigError = nil
  end
  C_ACCENT = themeAccent or DEFAULT_ACCENT
end
local modelImageName = nil
local modelImagePath = nil
local function trim(s) return string.match(s or "", "^%s*(.-)%s*$") end
local function sanitizeFsName(name)
  if not name then return nil end
  local s = (string.gsub(name, "[\\/:*?\"<>|]", "_"))
  return trim(s)
end
local function get(name)
  local source = name
  local sourceKey
  local sourceKnown = false
  if type(name) == "string" and getFieldInfoFn then
    sourceKey = "$" .. name
    local cached = RESOLVED[sourceKey]
    if cached ~= nil then
      source = cached
      sourceKnown = true
    else
      local infoOk, info = pcall(getFieldInfoFn, name)
      if infoOk and type(info) == "table" and info.id ~= nil then
        source = info.id
        RESOLVED[sourceKey] = source
        sourceKnown = true
      elseif infoOk then
        -- getValue(name) returns zero for a missing source. A successful
        -- metadata lookup returning nil lets us distinguish that from a live
        -- telemetry source whose legitimate value is zero.
        return nil, false, false, false
      end
    end
  end

  local sourceValueFn = rawget(_G, "getSourceValue") or _G.getSourceValue
  if type(sourceValueFn) == "function" then
    local ok, v, isCurrent, isFresh = pcall(sourceValueFn, source)
    if not ok or v == nil or isCurrent == false then
      -- Source ids can change after telemetry discovery. Re-resolve a stale id
      -- on the next sample instead of pinning the model to it indefinitely.
      if sourceKey then RESOLVED[sourceKey] = nil end
      return nil, false, isFresh == true, sourceKnown
    end
    if type(v) == "table" then v = v.value end
    if v == nil then return nil, false, isFresh == true, sourceKnown end
    return v, true, isFresh ~= false, true
  end

  local ok, v = pcall(getValue, source)
  if not ok or v == nil then return nil, false, false, sourceKnown end
  if type(v) == "table" then v = v.value end
  return v, true, true, true
end
local function getModelName()
  local v = F.modelName
  if v ~= nil then return v end
  local ok, info = pcall(model.getInfo)
  local n = (ok and info and info.name) or nil
  if not n or n == "" then n = "MODEL" end
  v = (string.gsub(n, ",", " "))
  F.modelName = v
  return v
end
-- Telemetry names are case-sensitive. Resolve each discovered source to its
-- numeric id, prefer getSourceValue() current-state reporting, and retain the
-- legacy getValue() path only as a compatibility fallback. Electric/Nitro use
-- the Rotorflight contract; OMPHOBBY uses the receiver's smaller contract.
local ROTORFLIGHT_SENSOR = {
  headspeed        = "Hspd",
  tailHeadspeed    = "Tspd",
  becVoltage       = "Vbec",
  cellVoltage      = "Vcel",
  cellCount        = "Cel#",
  -- The AMPS tile (and its session maximum) always reads Rotorflight's
  -- dedicated current sensor rather than the ESC telemetry source.
  current          = "Curr",
  capacity         = "Capa",
  -- Rotorflight publishes getBatteryChargeLevel() here. With Smart Fuel
  -- enabled, this is the FC's sag-compensated/rate-limited estimate.
  batteryPercent   = "Bat%",
  escTemperature   = "Tesc",
  governorMode     = "Gov",
  -- Used as a display fallback when Rotorflight is running without a governor.
  -- A valid Gov state remains authoritative whenever it is available.
  throttle         = "Thr",
  arm              = "ARM",
  armingDisable    = "ARMD",
  pidProfile       = "PID#",
  batteryProfile   = "BAT#",
  -- Pack voltage remains a separate input used to validate electric packs.
  packVoltage      = "Vbat",
}
local OMPHOBBY_SENSOR = {
  headspeed        = "NR",
  packVoltage      = "RxBt",
  current          = "Curr",
  capacity         = "Capa",
  batteryPercent   = "Bat%",
  escTemperature   = "Tmp",
}
local BETAFLIGHT_SENSOR = {
  -- CRSF/ELRS names published by Betaflight and discovered by EdgeTX. RxBt
  -- must represent total pack voltage (report_cell_voltage=OFF).
  packVoltage      = "RxBt",
  current          = "Curr",
  capacity         = "Capa",
  batteryPercent   = "Bat%",
}
local function activeSensorName(key)
  local sensors
  if OPT.heliType == HELI_OMPHOBBY then
    sensors = OMPHOBBY_SENSOR
  elseif OPT.heliType == HELI_BETAFLIGHT then
    sensors = BETAFLIGHT_SENSOR
  else
    sensors = ROTORFLIGHT_SENSOR
  end
  return sensors[key]
end
local function getSensorNumber(key)
  local name = activeSensorName(key)
  if not name then return nil end
  local v, current, fresh, exists = get(name)
  return tonumber(v), current, fresh, exists
end
-- Link quality is the one remaining name-variant fallback chain. Remember the
-- variant that resolves so later frames do not re-probe every candidate.
local NAMES = {
  lq = { "RQly", "RQLY", "LQ" },
}
local function resolveNamed(key)
  local names = NAMES[key]
  local cached = RESOLVED[key]
  if cached then
    local raw, _, _, exists = get(cached)
    if exists then A.linkSourceKnown = true end
    local v = tonumber(raw)
    if v ~= nil then return v end
    RESOLVED[key] = nil
  end
  for i = 1, #names do
    local raw, _, _, exists = get(names[i])
    if exists then A.linkSourceKnown = true end
    local v = tonumber(raw)
    if v ~= nil then
      RESOLVED[key] = names[i]
      return v
    end
  end
  return nil
end
local function getCellCount()
  local v = F.cellCount
  if v ~= nil then return v end
  if OPT.heliType == HELI_OMPHOBBY then
    -- OMP receivers do not stream cell count. Model names containing M2 are
    -- 3S; names containing M1 are 2S. Match case-insensitively anywhere.
    local modelName = string.upper(getModelName())
    if string.find(modelName, "M2", 1, true) then
      v = 3
    elseif string.find(modelName, "M1", 1, true) then
      v = 2
    else
      v = 0
    end
  else
    v = getSensorNumber("cellCount") or 0
  end
  v = math.floor(v + 0.5)
  D.cellCountValid = v >= 1 and v <= SAFETY.maxCellCount
  if not D.cellCountValid then v = 0 end
  F.cellCount = v
  return v
end
local function getPackVolt()
  local v = F.packVolt
  if v ~= nil then return v end
  v = getSensorNumber("packVoltage")
  D.packVoltageValid = v ~= nil and v > 0
                       and v <= SAFETY.maxCellCount * SAFETY.maxCellSanityV
  if not D.packVoltageValid then v = 0 end
  F.packVolt = v
  return v
end
local function getCellVoltage()
  local v = F.cellVoltage
  if v ~= nil then return v end
  if OPT.heliType == HELI_OMPHOBBY then
    local cells = getCellCount()
    local packVoltage = getPackVolt()
    v = cells > 0 and packVoltage > 0 and packVoltage / cells or nil
  else
    v = getSensorNumber("cellVoltage")
  end
  D.cellVoltageValid = v ~= nil and v > 0
                       and v <= SAFETY.maxCellSanityV
  if not D.cellVoltageValid then v = 0 end
  F.cellVoltage = v
  return v
end
local function getBatPct()
  local v = F.batPct
  if v ~= nil then return v end
  v = getSensorNumber("batteryPercent")
  D.batteryPercentValid = v ~= nil and v >= 0 and v <= 100
  if not D.batteryPercentValid then v = false end
  F.batPct = v
  return v
end
local function getCapa()
  local v = F.capa
  if v ~= nil then return v end
  v = getSensorNumber("capacity")
  D.capacityValid = v ~= nil and v >= 0 and v <= 100000
  if not D.capacityValid then v = 0 end
  F.capa = v
  return v
end
local function getCurr()
  local v = F.curr
  if v ~= nil then return v end
  v = getSensorNumber("current")
  local sane = v ~= nil and v >= -500 and v <= 1000
  if not sane then v = 0 end
  D.currentValid = sane
  F.curr = v
  return v
end
local function getTemp()
  local v = F.temp
  if v ~= nil then return v end
  v = getSensorNumber("escTemperature")
  local sane = v ~= nil and v >= -40 and v <= 250
  if not sane then v = 0 end
  D.tempValid = sane
  F.temp = v
  return v
end
local function getBec()
  local v = F.bec
  if v ~= nil then return v end
  v = getSensorNumber("becVoltage")
  local sane = v ~= nil and v > 0 and v <= 30
  D.becValid = sane
  if not D.becValid then v = 0 end
  F.bec = v
  return v
end
local function getRxBatt()
  local v = F.rxBatt
  if v ~= nil then return v end
  -- Nitro Rx pack voltage uses the same Vbec resolver as the BEC tile.
  v = getBec()
  F.rxBatt = v
  return v
end
local function getBattProfile()
  local v = F.battProfile
  if v ~= nil then return v end
  v = getSensorNumber("batteryProfile")
  if v and (v < 0 or v > 99) then v = nil end
  F.battProfile = v
  return v
end
local function getHeadspeed()
  local v = F.rpm
  if v ~= nil then return v end
  v = getSensorNumber("headspeed")
  local sane = v ~= nil and v >= 0 and v <= 100000
  if not sane then v = 0 end
  D.rpmValid = sane
  F.rpm = v
  return v
end
local function getTailRpm()
  local v = F.trpm
  if v ~= nil then return v end
  v = getSensorNumber("tailHeadspeed")
  local sane = v ~= nil and v >= 0 and v <= 100000
  if not sane then v = 0 end
  D.tailRpmValid = sane
  F.trpm = v
  return v
end
local function getGovernorMode()
  local cached = F.govNumber
  if cached ~= nil then return cached ~= false and cached or nil end
  if OPT.heliType == HELI_OMPHOBBY then
    D.govValid = false
    D.govCurrentInvalid = false
    F.govNumber = false
    return nil
  end
  local raw, current = getSensorNumber("governorMode")
  local whole = raw ~= nil and math.floor(raw) or nil
  local valid = whole ~= nil and raw == whole and GOV_STATES[whole] ~= nil
  D.govValid = valid
  -- Missing/stale Gov may use the independent Hspd proof. A current but
  -- malformed or unknown enum is different: it must block that fallback.
  D.govCurrentInvalid = current == true and raw ~= nil and not valid
  F.govNumber = valid and whole or false
  return valid and whole or nil
end
local function getThrottle()
  local v = F.throttle
  if v ~= nil then return v ~= false and v or nil end
  if OPT.heliType == HELI_OMPHOBBY then
    D.throttleValid = false
    F.throttle = false
    return nil
  end
  v = getSensorNumber("throttle")
  local sane = v ~= nil and v >= 0 and v <= 100
  D.throttleValid = sane
  F.throttle = sane and v or false
  return sane and v or nil
end
local function getGovState()
  local v = F.gov
  if v ~= nil then return v end
  if OPT.heliType == HELI_OMPHOBBY then
    v = "--"
  else
    local g = getGovernorMode()
    if g ~= nil then
      v = GOV_STATES[g]
    elseif D.govCurrentInvalid then
      -- A current but unknown Gov enum must remain visible as unavailable. It
      -- may represent a future state and must not be overwritten by throttle.
      v = "--"
    else
      local throttle = getThrottle()
      if throttle == nil then
        v = "--"
      elseif throttle <= 0 then
        v = "OFF"
      elseif throttle <= 50 then
        v = "SPOOLUP"
      else
        v = "ACTIVE"
      end
    end
  end
  F.gov = v
  return v
end
MODULE.statusService = MODULE.status.new({
  data = D,
  frame = F,
  alerts = A,
  getSensorNumber = getSensorNumber,
  getNamed = function(name) return get(name) end,
  getGovState = getGovState,
  getHeliType = function() return OPT.heliType end,
  ompType = HELI_OMPHOBBY,
})
local function getTxVolt()
  local v = F.txVolt
  if v ~= nil then return v end
  -- Capture only the source value. get() also returns current/fresh/existence
  -- metadata, which must not spill into tonumber() as its optional base.
  local raw = get("tx-voltage")
  v = tonumber(raw) or 0
  if v > 100 then v = v / 1000 end
  if v < 0 or v > 20 then v = 0 end
  F.txVolt = v
  return v
end
-- TX battery display endpoints for a 2S pack. Keep these separate from the
-- model battery settings: the top-bar gauge represents the radio battery.
local TX_LIPO_EMPTY_V = 7.0   -- 3.50 V/cell
local TX_LIPO_FULL_V  = 8.4   -- 4.20 V/cell
local TX_LIION_EMPTY_V = 6.2  -- 3.10 V/cell
local TX_LIION_FULL_V  = 8.4  -- 4.20 V/cell

local function txPctFromVolts(volts, isLiIon)
  if not volts or volts <= 0 then return nil end
  local emptyV = isLiIon and TX_LIION_EMPTY_V or TX_LIPO_EMPTY_V
  local fullV = isLiIon and TX_LIION_FULL_V or TX_LIPO_FULL_V
  local pct = ((volts - emptyV) / (fullV - emptyV)) * 100
  if pct < 0 then pct = 0 end
  if pct > 100 then pct = 100 end
  return pct
end
local function signalPercent(raw)
  local v = tonumber(raw)
  if v == nil then return nil end
  local pct
  if v < 0 then
    pct = ((v + 120) / 80) * 100
  elseif v <= 100 then
    pct = v
  elseif v <= 255 then
    pct = (v / 255) * 100
  else
    pct = 100
  end
  if pct < 0 then pct = 0 end
  if pct > 100 then pct = 100 end
  return pct
end
local function getRqly()
  local v = F.rqly
  if v ~= nil then return v end
  A.linkSourceKnown = false
  v = resolveNamed("lq")
  if v == nil then
    local rssi
    if getRSSI then
      local ok, r = pcall(getRSSI)
      if ok then rssi = tonumber(r) end
    end
    if rssi ~= nil and rssi ~= 0 then A.linkSourceKnown = true end
    if rssi == nil or rssi == 0 then
      local raw, _, _, exists = get("RSSI")
      if exists then A.linkSourceKnown = true end
      if raw ~= nil then rssi = tonumber(raw) end
    end
    v = signalPercent(rssi)
  end
  v = tonumber(v) or 0
  if v < 0 or v > 100 then v = signalPercent(v) or 0 end
  if v > 0 then A.linkSourceSeen = true end
  F.rqly = v
  return v
end
local function percentFromCellVoltage(cellVolts, isLiHV)
  if not cellVolts or cellVolts <= 0 then return 0 end
  local minV = 3.3
  local maxV = isLiHV and 4.35 or 4.2
  local pct = (cellVolts - minV) / (maxV - minV) * 100
  if pct < 0 then pct = 0 end
  if pct > 100 then pct = 100 end
  return pct
end
-- Rotorflight publishes its FC-side charge estimate as Bat%. In Electric mode
-- that value is authoritative even when Vcel is not configured. A positive
-- Bat% is sufficient evidence by itself; a zero also needs live Vcel or Vbat
-- so an FC powered over USB without a flight pack is shown as NO DATA instead
-- of an empty battery. OMPHOBBY keeps its stricter RxBt + M1/M2 contract.
local function selectFlightBatteryPercent(heliType, sensorPercent, sensorValid,
                                          voltagePercent, hasCellVoltage,
                                          hasPackVoltage)
  local raw = tonumber(sensorPercent)
  if heliType == HELI_ELECTRIC or heliType == HELI_BETAFLIGHT then
    local fcPercentUsable = sensorValid and raw ~= nil
                            and raw >= 0 and raw <= 100
                            and (raw > 0 or hasCellVoltage or hasPackVoltage)
    if fcPercentUsable then return raw, true, "fc" end
  elseif heliType == HELI_OMPHOBBY then
    local ompPercentUsable = hasCellVoltage and sensorValid and raw ~= nil
                             and raw >= 0 and raw <= 100
    if ompPercentUsable then return raw, true, "telemetry" end
  else
    return 0, false, nil
  end
  if voltagePercent ~= nil then return voltagePercent, true, "voltage" end
  return 0, false, nil
end
local function calculateAdjustedPercent(actual, reserve)
  if not actual or actual <= 0 then return 0 end
  reserve = reserve or 0
  if reserve >= 100 then return 0 end
  local usable = 100 - reserve
  local adj = ((actual - reserve) / usable) * 100
  if adj < 0 then adj = 0 end
  if adj > 100 then adj = 100 end
  return adj
end
function BATTERY_VOICE.play(path)
  if not playFile or not path then return false end
  local available = BATTERY_VOICE.available[path]
  if available == nil then
    local f = io.open(path, "r")
    available = f ~= nil
    BATTERY_VOICE.available[path] = available
    if f then pcall(io.close, f) end
  end
  if not available then return false end
  return pcall(playFile, path)
end
local function playBatteryRemainingAlert(level)
  local n = tonumber(level)
  if n == nil then return false end
  local customPath = BATTERY_VOICE.path .. tostring(math.floor(n)) .. "%.wav"
  if BATTERY_VOICE.play(customPath) then return true end
  if playNumber then
    return pcall(playNumber, n, SAFETY.batteryPercentUnit, 0)
  end
  return false
end
local function playBatteryHaptic()
  if not playHaptic then return end
  local modeNow = rawget(_G, "PLAY_NOW") or 0
  pcall(playHaptic, 15, 0, modeNow)
end
local function resetBatteryAlertState(scope)
  scope = scope or "all"
  if scope ~= "rx" then
    A.battAlertPrevPct       = nil
    A.battAlertPrevSource    = nil
    A.battVoicePlayed        = {}
    A.battZeroReached        = false
    A.deadVoiceNextTick      = 0
    A.flightDeadVoiceLatched = false
    A.flightDeadVoiceAcknowledged = false
    A.flightDeadVoiceStartPosition = nil
    A.battAlert5HapticPlayed = false
    A.battAlert0HapticPlayed = false
    A.battAlertNextTick      = 0
    A.battHapticState        = 0
    A.battHapticBurstCount   = 0
    A.battHapticNextTick     = 0
    A.battHapticEndTick      = 0
    A.battReplacementSince  = nil
    A.liHvHighSamples        = 0
    D.isLiHV                 = false
  end
  if scope ~= "flight" then
    A.rxLowSinceTick         = nil
    A.rxLowHapticNext        = 0
    A.rxDeadVoiceLatched     = false
    A.rxDeadVoiceAcknowledged= false
    A.rxDeadVoiceStartPosition = nil
    A.rxDeadVoiceNextTick    = 0
  end
  if scope == "all" then
    A.escTempAlertPlayed = false
    A.becAlertPlayed = false
    A.escTempHighSince = nil
    A.becLowSince = nil
  end
end
function BATTERY_VOICE.prime(percent, leaveZeroPending)
  local played = A.battVoicePlayed
  for _, level in ipairs(BATTERY_VOICE.levels) do
    -- Do not announce thresholds already passed when the widget starts or is
    -- reloaded in the middle of a flight. Zero is the safety exception: a
    -- widget that starts on a confirmed empty pack must still alert.
    if percent <= level and not (leaveZeroPending and level == 0) then
      played[level] = true
    end
  end
end
local function updateBatteryAlertState(percent, hasData, voiceEnabled, percentSource)
  if not hasData then return end
  if not A.linkAvailable then return end
  local p = tonumber(percent)
  if p == nil then return end
  if p < 0 then p = 0 end
  if p > 100 then p = 100 end
  local prev = tonumber(A.battAlertPrevPct)
  if prev == nil then
    local startsAtZero = p <= 0
    A.battAlertPrevPct = startsAtZero and 0.01 or p
    A.battAlertPrevSource = percentSource
    BATTERY_VOICE.prime(p, startsAtZero)
    return
  end
  local now = frameNow()
  local previousSource = A.battAlertPrevSource
  local sourceChanged = previousSource ~= nil and percentSource ~= nil
                        and previousSource ~= percentSource
  local replacementJump = false
  if not sourceChanged then
    if percentSource == "fc" and previousSource == "fc" then
      -- Rotorflight Smart Fuel is monotonic within a battery session. A
      -- sustained upward step therefore rearms alerts for the new FC session
      -- without any voltage/capacity-based pack classifier.
      replacementJump = (p - prev) >= 1
    else
      -- Voltage-derived/receiver percentages can rebound under reduced load,
      -- so retain the deliberately conservative legacy qualification.
      replacementJump = (p >= 95 and prev < 80)
                        or ((p - prev) >= 25 and p >= 60)
    end
  end
  if replacementJump then
    if A.battReplacementSince == nil then A.battReplacementSince = now end
    if (now - A.battReplacementSince) >= BATTERY_VOICE.replacementConfirm then
      resetBatteryAlertState("flight")
      A.battAlertPrevPct = p
      A.battAlertPrevSource = percentSource
      BATTERY_VOICE.prime(p)
    end
    return
  end
  A.battReplacementSince = nil
  local playedLevels = A.battVoicePlayed
  if voiceEnabled then
    if now >= (tonumber(A.battAlertNextTick) or 0) then
      local selectedLevel
      for i = #BATTERY_VOICE.levels, 1, -1 do
        local level = BATTERY_VOICE.levels[i]
        if not playedLevels[level] and p <= level then
          selectedLevel = level
          break
        end
      end
      if selectedLevel ~= nil then
        -- If telemetry skipped several thresholds, announce the current
        -- lowest one and retire the higher backlog. At 0%, this prevents old
        -- percentage clips from delaying the safety-critical dead warning.
        for _, level in ipairs(BATTERY_VOICE.levels) do
          if p <= level then playedLevels[level] = true end
        end
        playBatteryRemainingAlert(selectedLevel)
        A.battAlertNextTick = now + SAFETY.batteryAlertCooldown
        if selectedLevel == 0 then
          A.battZeroReached = true
          A.deadVoiceNextTick = now + BATTERY_VOICE.initialDelay
        end
      end
    end
  else
    -- Keep threshold state current while muted so enabling Battery Voice later
    -- does not announce a backlog of percentages already passed.
    for _, level in ipairs(BATTERY_VOICE.levels) do
      if p <= level then playedLevels[level] = true end
    end
  end
  if (not A.battAlert5HapticPlayed) and prev > SAFETY.batteryHapticThreshold
     and p <= SAFETY.batteryHapticThreshold then
    A.battHapticState      = 1
    A.battHapticBurstCount = 0
    A.battHapticNextTick   = now
    A.battAlert5HapticPlayed = true
  end
  if (not A.battAlert0HapticPlayed) and prev > 0 and p <= 0 then
    A.battHapticState      = 2
    A.battHapticNextTick   = now
    A.battHapticEndTick    = now + 500
    A.battAlert0HapticPlayed = true
  end
  A.battAlertPrevPct = p
  A.battAlertPrevSource = percentSource
end
function BATTERY_VOICE.updateDead(voiceEnabled)
  if not voiceEnabled or not A.battZeroReached then return end
  -- Once the pilot has heard dead.wav, a later movement of the configured
  -- physical Motor Switch acknowledges only this repeating voice. Movement
  -- before the first successful playback cannot pre-acknowledge the warning;
  -- percentage/haptic pausing remains telemetry-validated separately.
  if A.flightDeadVoiceLatched then
    local startPosition = A.flightDeadVoiceStartPosition
    local currentPosition = A.motorSwitchPosition
    if startPosition == nil and currentPosition ~= nil then
      A.flightDeadVoiceStartPosition = currentPosition
      startPosition = currentPosition
    end
    if startPosition ~= nil and currentPosition ~= nil
       and currentPosition ~= startPosition then
      A.flightDeadVoiceAcknowledged = true
      A.deadVoiceNextTick = 0
    end
  end
  if A.flightDeadVoiceAcknowledged then return end
  if not A.linkAvailable then return end
  local now = frameNow()
  if now < (tonumber(A.deadVoiceNextTick) or 0) then return end
  if BATTERY_VOICE.play(BATTERY_VOICE.deadPath)
     and not A.flightDeadVoiceLatched then
    A.flightDeadVoiceLatched = true
    A.flightDeadVoiceStartPosition = A.motorSwitchPosition
  end
  A.deadVoiceNextTick = now + BATTERY_VOICE.repeatDelay
end
local function updateBatteryHapticTick()
  if (A.battHapticState or 0) == 0 then return end
  if not A.linkAvailable then return end
  local now = frameNow()
  if now < (A.battHapticNextTick or 0) then return end
  if A.battHapticState == 1 then
    playBatteryHaptic()
    A.battHapticBurstCount = (A.battHapticBurstCount or 0) + 1
    if A.battHapticBurstCount >= 2 then
      A.battHapticState = 0
    else
      A.battHapticNextTick = now + 100
    end
  elseif A.battHapticState == 2 then
    if now >= (A.battHapticEndTick or 0) then
      A.battHapticState = 0
    else
      playBatteryHaptic()
      A.battHapticNextTick = now + 18
    end
  end
end
local function updateEscBecAlerts(escT, escValid, becV, becValid)
  if not A.linkAvailable then
    A.escTempHighSince = nil
    A.becLowSince = nil
    return
  end
  local now = frameNow()
  if escValid then
    if escT > SAFETY.escTempThreshold then
      if not A.escTempAlertPlayed then
        if A.escTempHighSince == nil then A.escTempHighSince = now end
        if (now - A.escTempHighSince) >= SAFETY.alertConfirmTicks then
          playBatteryHaptic()
          A.escTempAlertPlayed = true
          A.escTempHighSince = nil
        end
      end
    elseif A.escTempAlertPlayed and escT < SAFETY.escTempRearm then
      A.escTempAlertPlayed = false
      A.escTempHighSince = nil
    elseif not A.escTempAlertPlayed then
      A.escTempHighSince = nil
    end
  else
    A.escTempHighSince = nil
  end
  if becValid and becV >= SAFETY.becAlertMinVoltage then
    if becV < SAFETY.becVoltThreshold then
      if not A.becAlertPlayed then
        if A.becLowSince == nil then A.becLowSince = now end
        if (now - A.becLowSince) >= SAFETY.alertConfirmTicks then
          playBatteryHaptic()
          A.becAlertPlayed = true
          A.becLowSince = nil
        end
      end
    elseif A.becAlertPlayed and becV > SAFETY.becVoltRearm then
      A.becAlertPlayed = false
      A.becLowSince = nil
    elseif not A.becAlertPlayed then
      A.becLowSince = nil
    end
  else
    A.becLowSince = nil
  end
end
-- Nitro Rx pack low-voltage alert: if rx voltage sits at or below RxPackMin for
-- SAFETY.rxLowArmTicks (2s) continuously, buzz aggressively and latch the repeating
-- dead-battery voice warning. Caller only invokes this in Nitro mode.
function BATTERY_VOICE.updateRxDead(voiceEnabled, rx)
  if not rx or rx < SAFETY.becAlertMinVoltage then return end
  if not A.rxDeadVoiceLatched or A.rxDeadVoiceAcknowledged then return end
  if not A.linkAvailable then return end
  local startPosition = A.rxDeadVoiceStartPosition
  local currentPosition = A.motorSwitchPosition
  if startPosition == nil and currentPosition ~= nil then
    A.rxDeadVoiceStartPosition = currentPosition
    startPosition = currentPosition
  end
  if startPosition ~= nil and currentPosition ~= nil
     and currentPosition ~= startPosition then
    A.rxDeadVoiceAcknowledged = true
    A.rxDeadVoiceNextTick = 0
    return
  end
  if not voiceEnabled then return end
  local now = frameNow()
  if now < (tonumber(A.rxDeadVoiceNextTick) or 0) then return end
  BATTERY_VOICE.play(BATTERY_VOICE.deadPath)
  A.rxDeadVoiceNextTick = now + BATTERY_VOICE.repeatDelay
end
local function updateRxPackAlert(rx)
  if not OPT.rxPackValid then
    A.rxLowSinceTick = nil
    A.rxLowHapticNext = 0
    A.rxDeadVoiceLatched = false
    A.rxDeadVoiceAcknowledged = false
    A.rxDeadVoiceStartPosition = nil
    A.rxDeadVoiceNextTick = 0
    return
  end
  if not A.linkAvailable then
    if not A.rxDeadVoiceLatched then A.rxLowSinceTick = nil end
    A.rxLowHapticNext = 0
    return
  end
  local rxMin = OPT.rxPackMin
  local low = rx and rx >= SAFETY.becAlertMinVoltage
              and rxMin and rxMin > 0 and rx <= rxMin
  if not low then
    A.rxLowSinceTick = nil
    A.rxLowHapticNext = 0
    -- Once the Motor Switch has acknowledged a latched warning, recovery above
    -- the minimum rearms it for a future sustained low-voltage event. An
    -- unacknowledged warning remains latched until the switch is moved.
    if not A.rxDeadVoiceLatched or A.rxDeadVoiceAcknowledged then
      A.rxDeadVoiceLatched = false
      A.rxDeadVoiceAcknowledged = false
      A.rxDeadVoiceStartPosition = nil
      A.rxDeadVoiceNextTick = 0
    end
    return
  end
  local now = frameNow()
  -- Only movement after the warning has actually latched can acknowledge it.
  -- Movement during the two-second qualification period is normal control
  -- activity and must not silence an alert that has not started yet.
  if A.rxDeadVoiceLatched and A.rxDeadVoiceStartPosition ~= nil
     and A.motorSwitchPosition ~= nil
     and A.motorSwitchPosition ~= A.rxDeadVoiceStartPosition then
    A.rxDeadVoiceAcknowledged = true
    A.rxDeadVoiceNextTick = 0
  end
  if A.rxLowSinceTick == nil then
    A.rxLowSinceTick  = now
    A.rxLowHapticNext = now + SAFETY.rxLowArmTicks -- first buzz only after 2s sustained
    A.rxDeadVoiceStartPosition = nil
    A.rxDeadVoiceAcknowledged = false
  else
    if (now - A.rxLowSinceTick) >= SAFETY.rxLowArmTicks
       and not A.rxDeadVoiceLatched then
      A.rxDeadVoiceLatched = true
      A.rxDeadVoiceStartPosition = A.motorSwitchPosition
      A.rxDeadVoiceAcknowledged = false
      A.rxDeadVoiceNextTick = now
    end
    if not A.rxDeadVoiceAcknowledged
       and now >= (A.rxLowHapticNext or 0) then
      playBatteryHaptic()
      A.rxLowHapticNext = now + SAFETY.rxLowHapticInterval
    end
  end
end
local updateMotorAlertGate
local function tick(nowT)
  nowT = nowT or frameNow()
  A.lastDataTick = nowT
  local rq = getRqly()
  local linkReported = rq and rq > 0 or false
  A.linkAvailable = false
  -- Read the whole physical Motor Switch as a raw source (-1024/0/+1024 for a
  -- three-position switch). There is deliberately no channel fallback: an
  -- invalid mapping must remain visible and can never suppress/acknowledge an
  -- alert.
  local rawMotorPosition
  if A.motorSourcePhysical then
    rawMotorPosition = getValSrc(SRC.motorSwitch)
  end
  rawMotorPosition = tonumber(rawMotorPosition)
  A.motorSourceReadable = A.motorSourcePhysical and rawMotorPosition ~= nil
  if not A.motorSourcePhysical then
    A.motorConfigError = "SELECT A PHYSICAL MOTOR SWITCH"
  elseif not A.motorSourceReadable then
    A.motorConfigError = "MOTOR SWITCH UNAVAILABLE"
  else
    A.motorConfigError = nil
  end
  if rawMotorPosition == nil then
    A.motorSwitchPosition = nil
  elseif rawMotorPosition > 0 then
    A.motorSwitchPosition = 1
  elseif rawMotorPosition < 0 then
    A.motorSwitchPosition = -1
  else
    A.motorSwitchPosition = 0
  end
  local volt  = getPackVolt()
  local cells = getCellCount()
  local pctSensor = getBatPct()
  local capa  = getCapa()
  getCurr()
  local escT  = getTemp()
  local becV  = getBec()
  local cellVoltage = getCellVoltage()
  local headRpm = getHeadspeed()
  local governorMode = getGovernorMode()
  local armState = MODULE.statusService:getArmState()
  local armingFlags = MODULE.statusService:getArmingDisableFlags()
  MODULE.statusService:getPidProfile()
  MODULE.ledService:update(D.armValid and (armState == 1 or armState == 3),
                           armingFlags ~= nil and armingFlags > 0)
  local hasCellVoltage = D.cellVoltageValid and cellVoltage > 0
  local telemetryEvidence = hasCellVoltage or D.batteryPercentValid
                            or D.capacityValid or D.currentValid
                            or D.tempValid or D.becValid or D.rpmValid
                            or D.govValid
  -- A link source becomes authoritative after it has produced a live positive
  -- sample. Until then, current telemetry itself keeps safety alerts operating;
  -- this covers discovered-but-unpopulated link sensors without masking a real
  -- zero after the link source has proved itself.
  A.linkAvailable = linkReported
                    or (not A.linkSourceSeen and telemetryEvidence)
  D.voltage       = D.packVoltageValid and volt or 0
  D.cellsResolved = D.cellCountValid and cells or 0
  D.capacity      = capa or 0
  if hasCellVoltage and cellVoltage > SAFETY.liHvDetectCellV then
    A.liHvHighSamples = math.min(SAFETY.liHvConfirmSamples, A.liHvHighSamples + 1)
    if A.liHvHighSamples >= SAFETY.liHvConfirmSamples then D.isLiHV = true end
  elseif not D.isLiHV then
    A.liHvHighSamples = 0
  end
  if hasCellVoltage then
    if D.minCellVoltage == nil or cellVoltage < D.minCellVoltage then
      D.minCellVoltage = cellVoltage
    end
  end
  local voltagePct = hasCellVoltage
                     and percentFromCellVoltage(cellVoltage, D.isLiHV) or nil
  local hasPackVoltage = D.packVoltageValid and volt > 0
  local pct, hasPct, pctSource = selectFlightBatteryPercent(
    OPT.heliType, pctSensor, D.batteryPercentValid, voltagePct,
    hasCellVoltage, hasPackVoltage)
  local hadPct = D.hasBattData
  D.hasBattData = hasPct
  D.adjustedPercent = calculateAdjustedPercent(pct, OPT.reservePct)
  if not hasPct then
    A.displayPercent = 0
    A.displayPercentInit = false
  elseif pctSource == "fc" then
    -- Smart Fuel already performs its own sag compensation and rate limiting.
    -- Preserve the FC estimate exactly instead of applying a second filter.
    A.displayPercent = D.adjustedPercent
    A.displayPercentInit = true
  elseif not hadPct or not A.displayPercentInit then
    A.displayPercent     = D.adjustedPercent
    A.displayPercentInit = true
  else
    A.displayPercent = A.displayPercent
                       + (D.adjustedPercent - A.displayPercent)
                         * SAFETY.displayPercentAlpha
  end
  -- A raw switch move is never enough to silence a warning. Rotorflight must
  -- corroborate it with Gov or Hspd; OMPHOBBY uses stopped NR.
  updateMotorAlertGate(nowT, governorMode, headRpm)
  MODULE.statusService:updateAudio()
  -- Percentage voice/haptic alerts belong to the main flight pack shown by
  -- Electric and OMPHOBBY modes. Nitro displays an Rx-pack voltage bar, so it
  -- must never run or retain this electric flight-pack alert state machine.
  local voiceEnabled = OPT.battVoice
  if OPT.battBarMode == 0 then
    if not A.flightBatteryAlertsPaused then
      updateBatteryAlertState(D.adjustedPercent, hasPct, voiceEnabled, pctSource)
      BATTERY_VOICE.updateDead(voiceEnabled)
      updateBatteryHapticTick()
    end
  elseif A.battAlertPrevPct ~= nil or A.battZeroReached
         or (A.battHapticState or 0) ~= 0 then
    resetBatteryAlertState("flight")
  end
  updateEscBecAlerts(escT, D.tempValid, becV, D.becValid)
  if OPT.battBarMode == 1 then
    local rx = getRxBatt()
    updateRxPackAlert(rx)
    BATTERY_VOICE.updateRxDead(voiceEnabled, rx)
    if D.becValid and rx and rx > 0 then
      D.rxVoltage     = rx
      D.rxCellVoltage = rx / 2
      if rx > 0 then
        if D.minRxVoltage == nil or rx < D.minRxVoltage then
          D.minRxVoltage = rx
        end
      end
      local rxMin = OPT.rxPackMin
      local rxMax = OPT.rxPackMax
      if OPT.rxPackValid and rxMax > rxMin then
        local p = (rx - rxMin) / (rxMax - rxMin) * 100
        if p < 0 then p = 0 end
        if p > 100 then p = 100 end
        D.rxPercent = p
      else
        D.rxPercent = 0
      end
    else
      D.rxVoltage = nil; D.rxCellVoltage = nil; D.rxPercent = 0
    end
  end
end
local function statRpmMax()  return S.rpmMax or 0 end
local function statCurrMax() return S.currMax or 0 end
local function statTempMax() return S.tempMax or 0 end
local function statBecMin()  return S.becMin end
local function statCellMin() return S.cellMin end
local function statPackMin() return S.packMin end
-- model.getTimer(0) shared per frame: the flight counter and top-bar clock both
-- need it, so read it once. Returns the timer table, or false on failure.
local function getTimer0()
  local t = F.timer0
  if t ~= nil then return t end
  local ok, tt = pcall(model.getTimer, 0)
  t = (ok and tt) or false
  F.timer0 = t
  return t
end
local function getTimer1Secs()
  local v = F.timerSecs
  if v ~= nil then return v end
  local t = getTimer0()
  v = (t and t.value) or 0
  F.timerSecs = v
  return v
end
local function resetSessionStats()
  S.rpmMax  = 0
  S.currMax = 0
  S.tempMax = 0
  S.becMin  = nil
  S.cellMin = nil
  S.packMin = nil
end
local function resetSessionEvidence()
  for key in pairs(RESOLVED) do RESOLVED[key] = nil end
  A.linkAvailable = false
  A.linkSourceKnown = false
  A.linkSourceSeen = false
  D.packVoltageValid = false
  D.cellCountValid = false
  D.cellVoltageValid = false
  D.batteryPercentValid = false
  D.capacityValid = false
  D.currentValid = false
  D.tempValid = false
  D.becValid = false
  D.rpmValid = false
  D.tailRpmValid = false
  D.govValid = false
  D.govCurrentInvalid = false
  D.throttleValid = false
  D.armValid = false
  D.armingFlagsValid = false
  D.pidProfileValid = false
  D.hasBattData = false
  D.adjustedPercent = 0
  D.capacity = 0
  D.voltage = 0
  D.cellsResolved = 0
  D.isLiHV = false
  A.liHvHighSamples = 0
  A.displayPercent = 0
  A.displayPercentInit = false
  A.lastArmAudioState = nil
  A.lastGovAudioState = nil
  A.lastProfileAudioState = nil
  A.motorSwitchLastPosition = nil
  A.motorPausedPosition = nil
  A.motorGateCandidateFrom = nil
  A.motorGateCandidateTo = nil
  A.motorGateCandidateTick = nil
  A.govGateLastState = nil
  A.govGateRunningPosition = nil
  A.govGateStopTick = nil
  A.govGateStopSince = nil
  A.electricRpmGateRunningPosition = nil
  A.electricRpmGateZeroSince = nil
  A.ompGateRunningPosition = nil
  A.ompGateZeroSince = nil
  A.flightBatteryAlertsPaused = false
  A.batteryAlertPauseTick = nil
  A.motorPauseProof = nil
  D.minCellVoltage = nil
  D.minRxVoltage = nil
  resetBatteryAlertState()
end
MODULE.flightService = MODULE.flights.new({
  getModelName = getModelName,
  getTimer = getTimer0,
  minimum = TOPBAR_MIN_DUR_DEFAULT,
  onModelChanged = function()
    resetSessionStats()
    resetSessionEvidence()
  end,
})
local function shiftFlightBatteryAlertTimers(delta)
  if not delta or delta <= 0 then return end
  if (A.battAlertNextTick or 0) > 0 then
    A.battAlertNextTick = A.battAlertNextTick + delta
  end
  if (A.deadVoiceNextTick or 0) > 0 then
    A.deadVoiceNextTick = A.deadVoiceNextTick + delta
  end
  if (A.battHapticNextTick or 0) > 0 then
    A.battHapticNextTick = A.battHapticNextTick + delta
  end
  if (A.battHapticEndTick or 0) > 0 then
    A.battHapticEndTick = A.battHapticEndTick + delta
  end
  if A.battReplacementSince ~= nil then
    A.battReplacementSince = A.battReplacementSince + delta
  end
end
local function setFlightBatteryAlertsPaused(paused, now)
  paused = paused == true
  if paused == A.flightBatteryAlertsPaused then return end
  now = tonumber(now) or frameNow()
  if paused then
    A.flightBatteryAlertsPaused = true
    A.batteryAlertPauseTick = now
  else
    local started = tonumber(A.batteryAlertPauseTick)
    A.flightBatteryAlertsPaused = false
    A.batteryAlertPauseTick = nil
    if started and now > started then
      shiftFlightBatteryAlertTimers(now - started)
    end
  end
end
local function clearMotorGateCandidate()
  A.motorGateCandidateFrom = nil
  A.motorGateCandidateTo = nil
  A.motorGateCandidateTick = nil
  A.electricRpmGateZeroSince = nil
  A.ompGateZeroSince = nil
end
local function clearMotorGateEvidence()
  clearMotorGateCandidate()
  A.govGateLastState = nil
  A.govGateRunningPosition = nil
  A.govGateStopTick = nil
  A.govGateStopSince = nil
  A.electricRpmGateRunningPosition = nil
  A.ompGateRunningPosition = nil
end
local function releaseMotorAlertPause(now)
  setFlightBatteryAlertsPaused(false, now)
  A.motorPausedPosition = nil
  A.motorPauseProof = nil
  clearMotorGateEvidence()
end
local function resetMotorAlertGate(now)
  -- Losing or changing any gate input must fail loud: immediately restore
  -- flight-pack alerts and discard all prior movement/state correlation.
  releaseMotorAlertPause(now)
  A.motorSwitchLastPosition = nil
end
local function gateTickIsRecent(tick, now, limit)
  return tick ~= nil and now >= tick and (now - tick) <= limit
end
local function captureMotorSwitchCandidate(fromPosition, toPosition, now)
  A.motorGateCandidateFrom = fromPosition
  A.motorGateCandidateTo = toPosition
  A.motorGateCandidateTick = now
  A.electricRpmGateZeroSince = nil
  A.ompGateZeroSince = nil
end
local function pauseFlightBatteryAlerts(position, now, proof)
  clearMotorGateEvidence()
  A.motorPausedPosition = position
  A.motorPauseProof = proof
  setFlightBatteryAlertsPaused(true, now)
end
local function updateRotorflightMotorGate(now, position, switchChanged,
                                           governorMode, headRpm)
  local govUsable = D.govValid and governorMode ~= nil
  local rpmUsable = D.rpmValid and headRpm ~= nil
  if not govUsable and not rpmUsable then
    clearMotorGateEvidence()
    return
  end

  -- Gov correlation is intentionally short, but the independent Hspd proof
  -- needs enough time for an autorotation or normal rotor coast-down.
  if A.motorGateCandidateTick ~= nil
     and not gateTickIsRecent(A.motorGateCandidateTick, now,
                              SAFETY.electricMotorStopWindowTicks) then
    clearMotorGateCandidate()
  end

  if govUsable then
    local previousGov = A.govGateLastState
    if GOV_RUNNING_STATE[governorMode] then
      A.govGateStopTick = nil
      A.govGateStopSince = nil
      -- A switch move may reach Lua just before Gov leaves ACTIVE. Keep the
      -- last position proven by an unchanged running sample until correlation
      -- either succeeds or expires.
      if not switchChanged and A.motorGateCandidateTick == nil then
        A.govGateRunningPosition = position
      end
    elseif GOV_STOP_STATE[governorMode] then
      if previousGov ~= nil and GOV_RUNNING_STATE[previousGov] then
        A.govGateStopTick = now
        A.govGateStopSince = now
      end
    elseif governorMode ~= 1 or A.govGateStopTick == nil then
      -- IDLE may follow a sampled AUTOROT/THR-OFF/OFF transition before its
      -- confirmation time elapses. Retain that explicit stop evidence only;
      -- IDLE by itself still cannot initiate a pause.
      A.govGateStopTick = nil
      A.govGateStopSince = nil
    end

    local switchRecent = gateTickIsRecent(
      A.motorGateCandidateTick, now, SAFETY.govMotorCorrelationTicks)
    local govRecent = gateTickIsRecent(
      A.govGateStopTick, now, SAFETY.govMotorCorrelationTicks)
    local stopConfirmed = A.govGateStopSince ~= nil
                          and now >= A.govGateStopSince
                          and (now - A.govGateStopSince)
                              >= SAFETY.govMotorStopConfirmTicks
    if GOV_PAUSE_HOLD_STATE[governorMode] and switchRecent and govRecent
       and stopConfirmed
       and A.motorGateCandidateFrom == A.govGateRunningPosition
       and A.motorGateCandidateTo == position then
      pauseFlightBatteryAlerts(position, now, "gov")
      return
    end
    A.govGateLastState = governorMode
  else
    -- Do not let stale Gov transition state leak into the Hspd fallback.
    A.govGateLastState = nil
    A.govGateRunningPosition = nil
    A.govGateStopTick = nil
    A.govGateStopSince = nil
  end

  if not rpmUsable then
    A.electricRpmGateRunningPosition = nil
    A.electricRpmGateZeroSince = nil
    return
  end

  local rotorRunning = headRpm >= SAFETY.electricMotorRunningRpm
  if rotorRunning then
    A.electricRpmGateZeroSince = nil
    if A.motorGateCandidateTick == nil then
      A.electricRpmGateRunningPosition = position
    end
    return
  end

  -- A known running/unsafe or current-invalid Gov value overrides a zero Hspd;
  -- this prevents a lost RPM signal from being mistaken for motor-off. Missing
  -- or stale Gov is allowed because Hspd is an independent current proof.
  local govAllowsRpmStop = not D.govCurrentInvalid
                           and (not govUsable
                                or GOV_PAUSE_HOLD_STATE[governorMode])
  local candidateValid = govAllowsRpmStop
                         and gateTickIsRecent(
                           A.motorGateCandidateTick, now,
                           SAFETY.electricMotorStopWindowTicks)
                         and A.electricRpmGateRunningPosition ~= nil
                         and A.motorGateCandidateFrom
                             == A.electricRpmGateRunningPosition
                         and A.motorGateCandidateTo == position
  if not candidateValid then
    A.electricRpmGateZeroSince = nil
    return
  end
  if A.electricRpmGateZeroSince == nil then
    A.electricRpmGateZeroSince = now
  end
  if now >= A.electricRpmGateZeroSince
     and (now - A.electricRpmGateZeroSince)
         >= SAFETY.electricMotorZeroConfirmTicks then
    pauseFlightBatteryAlerts(position, now, "rpm")
  end
end
local function updateOmpMotorGate(now, position, headRpm)
  if not D.rpmValid or headRpm == nil then
    clearMotorGateEvidence()
    return
  end

  if A.motorGateCandidateTick ~= nil
     and not gateTickIsRecent(A.motorGateCandidateTick, now,
                              SAFETY.ompMotorStopWindowTicks) then
    clearMotorGateCandidate()
  end

  local rotorRunning = headRpm >= SAFETY.ompMotorRunningRpm
  if rotorRunning then
    A.ompGateZeroSince = nil
    if A.motorGateCandidateTick ~= nil
       and (A.motorGateCandidateFrom ~= A.ompGateRunningPosition
            or A.motorGateCandidateTo ~= position) then
      clearMotorGateCandidate()
    end
    -- Running NR can persist during rotor coast-down. Do not relabel the new
    -- switch position as running while a valid stop candidate is pending.
    if A.motorGateCandidateTick == nil then
      A.ompGateRunningPosition = position
    end
    return
  end

  local candidateValid = A.motorGateCandidateTick ~= nil
                         and A.ompGateRunningPosition ~= nil
                         and A.motorGateCandidateFrom
                             == A.ompGateRunningPosition
                         and A.motorGateCandidateTo == position
  if not candidateValid then
    A.ompGateZeroSince = nil
    return
  end
  if A.ompGateZeroSince == nil then A.ompGateZeroSince = now end
  if now >= A.ompGateZeroSince
     and (now - A.ompGateZeroSince) >= SAFETY.ompMotorZeroConfirmTicks then
    pauseFlightBatteryAlerts(position, now, "omp")
  end
end
updateMotorAlertGate = function(now, governorMode, headRpm)
  local position = A.motorSwitchPosition
  local switchUsable = A.motorSourcePhysical and A.motorSourceReadable
                       and position ~= nil
  if not switchUsable or not A.linkAvailable then
    resetMotorAlertGate(now)
    return
  end

  local previousPosition = A.motorSwitchLastPosition
  local switchChanged = previousPosition ~= nil
                        and previousPosition ~= position
  A.motorSwitchLastPosition = position

  -- Nitro's receiver-pack warning retains its independent post-latch switch
  -- acknowledgement. This gate only controls Electric/OMP flight-pack alerts.
  if OPT.battBarMode ~= 0 then
    releaseMotorAlertPause(now)
    return
  end

  if A.flightBatteryAlertsPaused then
    if switchChanged or position ~= A.motorPausedPosition then
      releaseMotorAlertPause(now)
      return
    end
    if OPT.heliType == HELI_ELECTRIC then
      if A.motorPauseProof == "rpm" then
        local govBlocksRpmHold = D.govCurrentInvalid
                                 or (D.govValid and governorMode ~= nil
                                     and not GOV_PAUSE_HOLD_STATE[governorMode])
        if govBlocksRpmHold or not D.rpmValid or headRpm == nil
           or headRpm >= SAFETY.electricMotorRunningRpm then
          releaseMotorAlertPause(now)
        end
      elseif not D.govValid or governorMode == nil
             or not GOV_PAUSE_HOLD_STATE[governorMode] then
        releaseMotorAlertPause(now)
      end
    elseif not D.rpmValid or headRpm == nil
           or headRpm >= SAFETY.ompMotorRunningRpm then
      releaseMotorAlertPause(now)
    end
    return
  end

  if switchChanged then
    local candidateFrom = previousPosition
    if OPT.heliType == HELI_ELECTRIC then
      candidateFrom = A.govGateRunningPosition
                      or A.electricRpmGateRunningPosition
                      or candidateFrom
    elseif OPT.heliType == HELI_OMPHOBBY
           and A.ompGateRunningPosition ~= nil then
      -- A three-position switch can cross its middle detent on a separate
      -- service tick. Keep the position proven by running telemetry as the
      -- origin so intermediate detents cannot erase a valid stop event.
      candidateFrom = A.ompGateRunningPosition
    end
    if candidateFrom ~= position then
      captureMotorSwitchCandidate(candidateFrom, position, now)
    else
      clearMotorGateCandidate()
    end
  end
  if OPT.heliType == HELI_ELECTRIC then
    updateRotorflightMotorGate(now, position, switchChanged, governorMode,
                               headRpm)
  elseif OPT.heliType == HELI_OMPHOBBY then
    updateOmpMotorGate(now, position, headRpm)
  else
    clearMotorGateEvidence()
  end
end
local function updateStats()
  if not A.linkAvailable then return end
  local r = getHeadspeed()
  if D.rpmValid and r > 0 then
    if r > S.rpmMax then S.rpmMax = r end
  end
  local c = getCurr()
  if D.currentValid and c > S.currMax then S.currMax = c end
  local t = getTemp()
  if D.tempValid and t > S.tempMax then S.tempMax = t end
  local b = getBec()
  if D.becValid and (S.becMin == nil or b < S.becMin) then S.becMin = b end
  local mc = getCellVoltage()
  if mc and mc > 0 and (S.cellMin == nil or mc < S.cellMin) then S.cellMin = mc end
  if OPT.heliType == HELI_BETAFLIGHT then
    local pv = getPackVolt()
    if D.packVoltageValid and pv > 0
       and (S.packMin == nil or pv < S.packMin) then
      S.packMin = pv
    end
  end
end

local DATA_INTERVAL_TICKS = 10 -- 10 Hz; telemetry and UI do not need frame-rate polling
local function serviceTelemetry(trackStats)
  local now = frameNow()
  local last = A.lastDataTick
  if last and last >= 0 and now >= last and (now - last) < DATA_INTERVAL_TICKS then
    return false
  end
  MODULE.flightService:tick()
  tick(now)
  if trackStats then updateStats() end
  return true
end
local function fileExists(path)
  local f = io.open(path, "r")
  if not f then return false end
  pcall(io.close, f)
  return true
end
local function resolveModelImagePath()
  local name = getModelName()
  if modelImageName == name then return modelImagePath end
  local sanitized = sanitizeFsName(name)
  if not sanitized or sanitized == "" then sanitized = "MODEL" end
  -- Never concatenate raw model text into an SD-card path. The sanitized name
  -- preserves normal names while preventing separators from escaping /IMAGES.
  local candidates = {
    "/IMAGES/" .. sanitized .. ".png",
    "/IMAGES/" .. sanitized .. ".bmp",
    "/WIDGETS/StacyDashV4/default.png",
  }
  candidates[#candidates+1] = "/IMAGES/default.png"
  candidates[#candidates+1] = "/IMAGES/defaultmodel.png"
  candidates[#candidates+1] = "/WIDGETS/StacyDashV4/Rotorflight.png"
  modelImagePath = nil
  for _, path in ipairs(candidates) do
    if fileExists(path) then modelImagePath = path; break end
  end
  modelImageName = name
  return modelImagePath
end

local FMT_CACHE = {}
local function fmtNum(slot, pattern, v)
  local c = FMT_CACHE[slot]
  if c and c.v == v then return c.s end
  local s = string.format(pattern, v)
  if c then c.v = v; c.s = s else FMT_CACHE[slot] = { v = v, s = s } end
  return s
end
local flightsCacheN, flightsCacheS = -1, ""
local function fmtFlights(count)
  if count ~= flightsCacheN then
    flightsCacheN = count
    flightsCacheS = string.format("%d %s", count, (count == 1) and "Flight" or "Flights")
  end
  return flightsCacheS
end
local function batColor(pct)
  if pct >= 50 then return C_GREEN end
  if pct >= 20 then return C_YELLOW end
  return C_RED
end
local function txBatColor(pct)
  -- Classify the estimated whole percentage so floating-point rounding at the
  -- voltage boundaries cannot turn an exact 50% green or an exact 30% yellow.
  local wholePct = math.floor((pct or 0) + 0.5)
  if wholePct >= 51 then return C_GREEN end
  if wholePct >= 31 then return C_YELLOW end
  return C_RED
end
local function cellVoltageColor(sessionMin)
  if sessionMin and sessionMin <= SAFETY.cellRedThreshold then return C_RED end
  return C_TEXT
end

-- Retained LVGL object references. Static chrome is created once in update();
-- refresh() only changes the handful of properties whose values moved.
local V = {}
local function setObject(obj, properties)
  MODULE.uiService:set(obj, properties)
end
local function setVisible(obj, visible)
  MODULE.uiService:visible(obj, visible)
end
local function setLabel(obj, text, color, x, y, w, font, align)
  MODULE.uiService:setLabel(obj, text, color, x, y, w, font, align)
end
local function newLabel(x, y, w, text, font, color, align)
  return MODULE.uiService:label(x, y, w or 0, text, font or 0,
                                color or C_TEXT, align)
end
local function newRect(x, y, w, h, color, filled, rounded, thickness)
  return MODULE.uiService:rect(x, y, w, h, color, filled, rounded, thickness)
end
local function newPanel(x, y, w, h, bg, border, rounded)
  return MODULE.uiService:panel(x, y, w, h, bg, border, rounded)
end
local function setPanel(panel, bg, border)
  MODULE.uiService:setPanel(panel, bg, border)
end

local SIG_HEIGHTS = { 6, 10, 14, 18 }
local function buildTopBar()
  local y, h = L.top.y, L.top.h
  local centerY = y + h / 2
  -- LVGL fonts carry more top leading than lcd.drawText(); compensate so the
  -- glyphs occupy the same top-bar baseline as the original dashboard.
  V.modelName = newLabel(L.top.x, y - 2, 260, "", SMLSIZE + BOLD, C_TEXT)
  V.timer = newLabel(W / 2 - 100, y - 9, 200, "", MIDSIZE + BOLD, C_TEXT, CENTERED)
  V.armState = newLabel(W / 2 + 100, y - 3, 200, "", SMLSIZE + BOLD,
                        C_TEXT, CENTERED)
  -- A compact vertical battery sits at the far right. Rotating the original
  -- glyph counter-clockwise puts its terminal on top and makes charge fill
  -- bottom-to-top. Signal quality occupies the space immediately to its left.
  local battW, battH = 20, 28
  local terminalW, terminalH = 10, 3
  local totalBattH = battH + terminalH + 1
  local battX = W - L.top.x - battW
  local battY = centerY - totalBattH / 2 + terminalH + 1
  local sigX = battX - 14 - 36
  V.signal = {}
  for i, bh in ipairs(SIG_HEIGHTS) do
    V.signal[i] = newRect(sigX + (i-1) * 10, centerY + 10 - bh, 6, bh,
                          C_LINE, true, 0, 0)
  end
  V.txBody = newPanel(battX, battY, battW, battH, C_TILE, C_DIM, 3)
  newRect(battX + (battW - terminalW) / 2, battY - terminalH - 1,
          terminalW, terminalH, C_DIM, true, 1, 0)
  V.txFill = newRect(battX + 2, battY + battH - 3,
                     battW - 4, 1, C_GREEN, true, 2, 0)
  lvgl.hline({ x=0, y=y + h + 2, w=W, h=1, color=C_LINE })
  V.txBodyW, V.txBodyH, V.txBodyY = battW, battH, battY
end

local function buildModelPanel()
  local p = L.pic
  local footerH = 28
  local imgH = p.h - footerH
  newPanel(p.x, p.y, p.w, p.h, C_TILE, C_LINE, p.r)
  local inset = p.r - 3
  V.modelImage = lvgl.image({
    x=p.x + inset, y=p.y + inset, w=p.w - inset * 2,
    h=imgH - inset * 2, fill=false,
    file=function() return resolveModelImagePath() or "" end,
    visible=function() return resolveModelImagePath() ~= nil end,
  })
  V.noImage = lvgl.label({
    x=p.x, y=p.y + imgH / 2 - 8, w=p.w, h=0,
    text="no model image", font=SMLSIZE, color=C_DIM, align=CENTERED,
    visible=function() return resolveModelImagePath() == nil end,
  })
  lvgl.hline({ x=p.x + 8, y=p.y + imgH, w=p.w - 16, h=1, color=C_LINE })
  V.flightCount = newLabel(p.x, p.y + p.h - footerH + 5, p.w, "",
                           SMLSIZE, C_TEXT, CENTERED)
end

local function buildGovernor()
  local g = L.gov
  V.govPanel = newPanel(g.x, g.y, g.w, g.h, C_TILE, C_LINE, g.r)
  newLabel(g.x, g.y + 14, g.w, "GOVERNOR", SMLSIZE + BOLD, C_ACCENT, CENTERED)
  V.govState = newLabel(g.x, g.y + 50, g.w, "", MIDSIZE + BOLD, C_TEXT, CENTERED)
end

local function buildHero()
  local hb = L.hero
  newPanel(hb.x, hb.y, hb.w, hb.h, C_TILE, C_LINE, hb.r)
  newLabel(hb.x + 14, hb.y + 3, 285, "HEADSPEED RPM",
           SMLSIZE + BOLD, C_DIM)
  V.rpm = newLabel(hb.x + 14, hb.y + 42, 230, "", DBLSIZE + BOLD, C_TEXT)
  local rx = hb.x + hb.w - 14
  local lx = rx - 170
  local ry, step = hb.y + 25, 30
  local labelW = 70
  newLabel(lx, ry, labelW, "max", SMLSIZE + BOLD, C_DIM)
  V.rpmMax = newLabel(lx + labelW, ry, 100, "", SMLSIZE + BOLD, C_YELLOW, RIGHT)
  newLabel(lx, ry + step * 2, labelW, "tail", SMLSIZE + BOLD, C_DIM)
  V.tailRpm = newLabel(lx + labelW, ry + step * 2, 100, "",
                       SMLSIZE + BOLD, C_TEXT, RIGHT)
end

local function buildTile(x, y, w, h, label, unit)
  newLabel(x + 10, y + 10, w - 20, label, SMLSIZE, C_DIM)
  newLabel(x + w - 45, y + 10, 35, unit, SMLSIZE, C_DIM, RIGHT)
  return {
    value = newLabel(x + 10, y + 54, w - 20, "", MIDSIZE + BOLD, C_TEXT),
    footer = newLabel(x + 10, y + h - 22, w - 20, "", SMLSIZE, C_DIM),
  }
end
local function buildTiles()
  local t = L.tiles
  local n = 4
  local w = math.floor((t.w - (n-1) * t.gap) / n)
  local becLabel = OPT.heliType == HELI_NITRO and "BATT" or "BEC"
  local voltageLabel = OPT.heliType == HELI_BETAFLIGHT and "VBAT" or "CELL"
  newPanel(t.x, t.y, t.w, t.h, C_TILE, C_LINE, t.r)
  for i = 1, n - 1 do
    local dx = t.x + (w + t.gap) * i - math.floor(t.gap / 2)
    lvgl.vline({ x=dx, y=t.y + 8, w=1, h=t.h - 16, color=C_LINE })
  end
  V.tiles = {
    buildTile(t.x,                         t.y, w, t.h, "AMPS",  "(A)"),
    buildTile(t.x + (w + t.gap),          t.y, w, t.h, voltageLabel, "(V)"),
    buildTile(t.x + (w + t.gap) * 2,      t.y, w, t.h, becLabel, "(V)"),
    buildTile(t.x + (w + t.gap) * 3,      t.y, w, t.h, "ESC T", "(°C)"),
  }
end

local function buildBottom()
  local b = L.bot
  local x, y, w = b.x, b.y, b.w
  local barY, barH = y + 26, 44
  V.bottom = {
    x=x, y=y, w=w, barY=barY, barH=barH,
    header=newLabel(x, y + 2, w, "", SMLSIZE, C_DIM),
    panel=newPanel(x, barY, w, barH, C_TILE, C_LINE, 5),
    fill=newRect(x + 2, barY + 2, 1, barH - 4, C_GREEN, true, 3, 0),
    center=newLabel(x, barY + 2, w, "", SMLSIZE + BOLD, C_BLACK, CENTERED),
  }
  local B = V.bottom
  if OPT.battBarMode == 1 then
    B.mode = "nitro"
    B.minimum = newLabel(x, barY + barH + 4, 220, "", SMLSIZE, C_DIM)
    B.range = newLabel(x + w - 220, barY + barH + 4, 220,
                       string.format("%.1fV - %.1fV", OPT.rxPackMin, OPT.rxPackMax),
                       SMLSIZE, C_DIM, RIGHT)
  else
    B.mode = "electric"
    local fy = barY + barH + 4
    B.ticks = {
      newLabel(x,              fy, 60, "0%",   SMLSIZE, C_DIM),
      newLabel(x + w*.25 - 30, fy, 60, "25%",  SMLSIZE, C_DIM, CENTERED),
      newLabel(x + w*.50 - 30, fy, 60, "50%",  SMLSIZE, C_DIM, CENTERED),
      newLabel(x + w*.75 - 30, fy, 60, "75%",  SMLSIZE, C_DIM, CENTERED),
      newLabel(x + w - 60,     fy, 60, "100%", SMLSIZE, C_DIM, RIGHT),
    }
  end
end

local function updateBottom()
  local B = V.bottom
  if not B then return end
  local configWarning
  local rxSettingsInvalid = B.mode == "nitro" and not OPT.rxPackValid
  if A.motorConfigError and rxSettingsInvalid then
    configWarning = A.motorConfigError .. " · CHECK RX PACK SETTINGS"
  elseif A.motorConfigError then
    configWarning = A.motorConfigError
  elseif rxSettingsInvalid then
    configWarning = "CHECK RX PACK SETTINGS"
  end
  if B.mode == "nitro" then
    local hasRx = OPT.rxPackValid and D.rxVoltage ~= nil and D.rxVoltage > 0
    local rxV, rxCV, pct = D.rxVoltage or 0, D.rxCellVoltage or 0, D.rxPercent or 0
    local header = hasRx
                   and string.format("Receiver Battery · %.2fV · %.2fV/cell", rxV, rxCV)
                   or "Receiver Battery · no data"
    setLabel(B.header,
             configWarning or header,
             configWarning and C_RED or C_DIM)
    local fillW = math.floor((B.w - 4) * pct / 100)
    setObject(B.fill, { w=math.max(1, fillW), h=B.barH - 4, color=batColor(pct) })
    setVisible(B.fill, hasRx and fillW > 0)
    setLabel(B.center, tostring(math.floor(pct)) .. "%", C_BLACK,
             B.x + 2, B.barY + 2, math.max(1, fillW), SMLSIZE + BOLD, CENTERED)
    setVisible(B.center, hasRx and fillW > 40)
    setLabel(B.minimum, D.minRxVoltage and string.format("min %.2fV", D.minRxVoltage)
                                          or "min --", C_DIM)
    setLabel(B.range,
             OPT.rxPackValid and string.format("%.1fV - %.1fV", OPT.rxPackMin, OPT.rxPackMax)
                             or "INVALID RANGE",
             OPT.rxPackValid and C_DIM or C_RED)
    return
  end

  local cells, volt = D.cellsResolved, D.voltage
  local capa = math.floor(D.capacity or 0)
  local usedText = D.capacityValid and string.format(" · %d mAh used", capa) or ""
  local prof = getBattProfile()
  local header
  if OPT.heliType == HELI_BETAFLIGHT and D.packVoltageValid then
    header = string.format("BATTERY · %.1fV", volt) .. usedText
  elseif not D.hasBattData and OPT.heliType == HELI_OMPHOBBY
     and getCellCount() == 0 then
    header = "BATTERY · ADD M1 OR M2 TO MODEL NAME"
  elseif not D.hasBattData then
    header = "BATTERY · no data"
  elseif cells > 0 and volt > 0 and prof and prof > 0 then
    header = string.format("BATTERY · P%d · %dS · %.1fV",
                           math.floor(prof), cells, volt) .. usedText
  elseif cells > 0 and volt > 0 then
    header = string.format("BATTERY · %dS · %.1fV", cells, volt) .. usedText
  elseif D.cellVoltageValid then
    header = string.format("BATTERY · %.2fV/cell", getCellVoltage()) .. usedText
  else
    -- Smart Fuel can remain fully usable when Vcel/Vbat are not configured.
    -- Do not invent a 0.00V/cell header for a valid FC-side percentage.
    header = "BATTERY" .. usedText
  end
  setLabel(B.header, configWarning or header, configWarning and C_RED or C_DIM)
  setPanel(B.panel, C_TILE, C_LINE)
  if not D.hasBattData then
    setVisible(B.fill, false)
    setLabel(B.center, "NO DATA", C_RED, B.x, B.barY + 2, B.w,
             SMLSIZE + BOLD, CENTERED)
    setVisible(B.center, true)
    for _, tickLabel in ipairs(B.ticks) do setVisible(tickLabel, false) end
  else
    local pct = A.displayPercentInit and A.displayPercent or D.adjustedPercent
    if pct < 0 then pct = 0 elseif pct > 100 then pct = 100 end
    local fillW = math.floor((B.w - 4) * pct / 100)
    setObject(B.fill, { w=math.max(1, fillW), h=B.barH - 4, color=batColor(pct) })
    setVisible(B.fill, fillW > 0)
    setLabel(B.center, tostring(math.floor(pct)) .. "%", C_BLACK,
             B.x + 2, B.barY + 2, math.max(1, fillW), SMLSIZE + BOLD, CENTERED)
    setVisible(B.center, fillW > 40)
    for _, tickLabel in ipairs(B.ticks) do setVisible(tickLabel, true) end
  end
end

local function updateUiState()
  if not V.modelName then return end
  local modelName = getModelName()
  setLabel(V.modelName, modelName, C_TEXT)
  local secs = getTimer1Secs()
  local mm = math.floor(math.abs(secs) / 60)
  local ss = math.abs(secs) - mm * 60
  setLabel(V.timer, string.format("%d:%02d", mm, ss), C_TEXT)

  local rq = getRqly()
  local bars = rq >= 80 and 4 or rq >= 60 and 3 or rq >= 40 and 2 or rq >= 20 and 1 or 0
  local sigColor = bars >= 3 and C_GREEN or bars == 2 and C_YELLOW or C_RED
  for i, bar in ipairs(V.signal) do
    setObject(bar, { color=(i <= bars) and sigColor or C_LINE })
  end

  local txPct = txPctFromVolts(getTxVolt(), txIsLiIon)
  if txPct then
    local fillH = math.floor((V.txBodyH - 4) * txPct / 100)
    local fillY = V.txBodyY + V.txBodyH - 2 - fillH
    setObject(V.txFill, { y=fillY, w=V.txBodyW - 4, h=math.max(1, fillH),
                          color=txBatColor(txPct) })
    setVisible(V.txFill, fillH > 0)
  else
    setVisible(V.txFill, false)
  end

  local flightText = fmtFlights(MODULE.flightService:getCount())
  local pidProfile = MODULE.statusService:getPidProfile()
  if D.pidProfileValid then
    flightText = flightText .. " · P" .. tostring(pidProfile)
  end
  local flightSaveError = MODULE.flightService:hasSaveError()
  if flightSaveError then flightText = flightText .. " · SAVE ERROR" end
  setLabel(V.flightCount, flightText, flightSaveError and C_RED or C_TEXT)
  local arm = MODULE.statusService:getArmState()
  local flagsText = MODULE.statusService:flagsText(
                      MODULE.statusService:getArmingDisableFlags())
  if flagsText ~= "" then
    -- Disable flags have visual priority, matching DBK: they replace the arm
    -- state in the same label instead of competing for top-bar space.
    setLabel(V.armState, flagsText, C_RED)
  elseif D.armValid then
    local armed = arm == 1 or arm == 3
    setLabel(V.armState, armed and "ARMED" or "DISARMED",
             armed and C_YELLOW or C_RED)
  else
    setLabel(V.armState, "NO ARM TELE", C_DIM)
  end
  local govState = getGovState()
  local govTheme = GOV_COLOR[govState] or GOV_FALLBACK
  setPanel(V.govPanel, govTheme.bg, govTheme.br)
  setLabel(V.govState, GOV_LABELS[govState] or govState, govTheme.fg)

  local rpm = getHeadspeed()
  if D.rpmValid then
    setLabel(V.rpm, tostring(math.floor(rpm)), C_TEXT)
    setLabel(V.rpmMax, fmtNum("rpmMax", "%d", math.floor(statRpmMax())), C_YELLOW)
  else
    setLabel(V.rpm, "--", C_DIM)
    setLabel(V.rpmMax, "--", C_DIM)
  end
  local tailRpm = getTailRpm()
  setLabel(V.tailRpm, D.tailRpmValid and tostring(math.floor(tailRpm)) or "--",
           D.tailRpmValid and C_TEXT or C_DIM)

  if OPT.battBarMode == 1 then
    setLabel(V.tiles[1].value, "--", C_DIM, nil, nil, nil, nil, CENTERED)
    setLabel(V.tiles[1].footer, "", C_DIM)
    local rxCell = D.rxCellVoltage
    local rxCellMin = D.minRxVoltage and (D.minRxVoltage / 2) or nil
    if rxCell and rxCell > 0 then
      setLabel(V.tiles[2].value, string.format("%.2f", rxCell), C_TEXT,
               nil, nil, nil, nil, 0)
    else
      setLabel(V.tiles[2].value, "--", C_DIM,
               nil, nil, nil, nil, CENTERED)
    end
    setLabel(V.tiles[2].footer,
             rxCellMin and string.format("min %.2f", rxCellMin) or "min --", C_DIM)
  else
    local curr = getCurr()
    if D.currentValid then
      setLabel(V.tiles[1].value, tostring(math.ceil(curr)), C_TEXT)
      setLabel(V.tiles[1].footer,
               fmtNum("currMax", "max %d", math.ceil(statCurrMax())), C_YELLOW)
    else
      setLabel(V.tiles[1].value, "--", C_DIM, nil, nil, nil, nil, CENTERED)
      setLabel(V.tiles[1].footer, "", C_DIM)
    end
    local cell = OPT.heliType == HELI_BETAFLIGHT and getPackVolt()
                 or getCellVoltage()
    local cellMin = OPT.heliType == HELI_BETAFLIGHT and statPackMin()
                    or statCellMin()
    local voltageValid = OPT.heliType == HELI_BETAFLIGHT
                         and D.packVoltageValid or D.cellVoltageValid
    if voltageValid and cell > 0 then
      local format = OPT.heliType == HELI_BETAFLIGHT and "%.1f" or "%.2f"
      local color = OPT.heliType == HELI_BETAFLIGHT and C_TEXT
                    or cellVoltageColor(cellMin)
      setLabel(V.tiles[2].value, string.format(format, cell),
               color, nil, nil, nil, nil, 0)
    else
      setLabel(V.tiles[2].value, "--", C_DIM,
               nil, nil, nil, nil, CENTERED)
    end
    setLabel(V.tiles[2].footer,
             voltageValid and cellMin
               and (OPT.heliType == HELI_BETAFLIGHT
                    and fmtNum("packMin", "min %.1f", cellMin)
                    or fmtNum("cellMin", "min %.2f", cellMin))
               or "min --", C_DIM)
  end
  local bec = getBec()
  local becColor = C_TEXT
  if bec and bec > 0 then
    if bec < 4.8 then becColor = C_RED elseif bec < 5.1 then becColor = C_YELLOW end
  end
  if D.becValid then
    setLabel(V.tiles[3].value, string.format("%.1f", bec), becColor)
    local becMin = statBecMin()
    setLabel(V.tiles[3].footer,
             becMin and fmtNum("becMin", "min %.1f", becMin) or "min --", C_DIM)
  else
    setLabel(V.tiles[3].value, "--", C_DIM, nil, nil, nil, nil, CENTERED)
    setLabel(V.tiles[3].footer, "", C_DIM)
  end
  if OPT.battBarMode == 1 then
    setLabel(V.tiles[4].value, "--", C_DIM, nil, nil, nil, nil, CENTERED)
    setLabel(V.tiles[4].footer, "", C_DIM)
  else
    local temp, tempMax = getTemp(), statTempMax()
    if D.tempValid then
      setLabel(V.tiles[4].value, tostring(math.floor(temp)), C_TEXT)
      setLabel(V.tiles[4].footer, fmtNum("tempMax", "max %d", math.floor(tempMax)),
               C_YELLOW)
    else
      setLabel(V.tiles[4].value, "--", C_DIM, nil, nil, nil, nil, CENTERED)
      setLabel(V.tiles[4].footer, "", C_DIM)
    end
  end
  updateBottom()
end

local function buildUi()
  if not lvgl then return end
  lvgl.clear()
  V = {}
  if not MODULE.uiService then MODULE.uiService = MODULE.ui.new(lvgl, C_TEXT) end
  MODULE.uiService:reset()
  if not OPT.bgTransparent then newRect(0, 0, W, H, C_BG, true, 0, 0) end
  buildTopBar()
  buildModelPanel()
  buildGovernor()
  buildHero()
  buildTiles()
  buildBottom()
  updateUiState()
end
local function buildUnsupportedUi()
  if not lvgl then return end
  lvgl.clear()
  V = {}
  if not MODULE.uiService then MODULE.uiService = MODULE.ui.new(lvgl, C_TEXT) end
  MODULE.uiService:reset()
  newRect(0, 0, W, H, C_BG, true, 0, 0)
  newLabel(0, math.floor(H / 2) - 18, W,
           "StacyDashV4 requires an 800x480 full-screen layout",
           MIDSIZE, C_RED, CENTERED)
end

local function refresh(widget, event, touchState)
  if not widget.supported then return end
  clearFrameCache()
  if serviceTelemetry(true) then updateUiState() end
end
local function background(widget)
  if not widget.supported then return end
  clearFrameCache()
  -- Session extrema are flight data too; keep them current while another page
  -- is visible instead of recording only the moments this dashboard is open.
  serviceTelemetry(true)
end
local function create(zone, options)
  -- Drop any stale frame cache (e.g. cached model name) before loading flights.
  clearFrameCache()
  if not L then
    L = {
      top  = { x=10, y=8, h=36 },
      pic  = { x=10,  y=56,  w=280, h=180, r=7 },
      gov  = { x=10,  y=246, w=280, h=108, r=7 },
      hero = { x=300, y=56,  w=490, h=140, r=7 },
      tiles= { x=300, y=206, w=490, h=148, r=7, gap=8 },
      bot  = { x=10, w=780, h=100, padBot=14, r=7 },
    }
    L.bot.y = H - L.bot.padBot - L.bot.h
  end
  MODULE.flightService:load(true)
  applyOptions(options)
  -- Dashboard state is intentionally module-wide. The supported deployment is
  -- one full-screen instance on an 800x480 color radio.
  local zoneW = tonumber(zone and zone.w) or W
  local zoneH = tonumber(zone and zone.h) or H
  return {
    zone = zone,
    options = options,
    supported = W == SUPPORTED_LCD_W and H == SUPPORTED_LCD_H
                and zoneW >= 760 and zoneH >= 420,
  }
end
local function update(widget, options)
  widget.options = options
  local previousHeliType = OPT.heliType
  local previousReserve = OPT.reservePct
  local previousRxMin = OPT.rxPackMin
  local previousRxMax = OPT.rxPackMax
  local previousRxValid = OPT.rxPackValid
  local previousMotorSource = SRC.motorSwitch
  applyOptions(options)
  local heliChanged = previousHeliType ~= OPT.heliType
  local reserveChanged = previousReserve ~= OPT.reservePct
  local rxSettingsChanged = previousRxMin ~= OPT.rxPackMin
                            or previousRxMax ~= OPT.rxPackMax
                            or previousRxValid ~= OPT.rxPackValid
  local motorChanged = previousMotorSource ~= SRC.motorSwitch

  if heliChanged then
    resetSessionStats()
    resetSessionEvidence()
  else
    if reserveChanged then
      -- Changing usable reserve changes percentage meaning, but a visual/theme
      -- edit must never erase live low-battery or Nitro warning state.
      resetBatteryAlertState("flight")
      A.displayPercent = 0
      A.displayPercentInit = false
    end
    if rxSettingsChanged then resetBatteryAlertState("rx") end
  end

  if motorChanged then
    resetMotorAlertGate(frameNow())
    if A.flightDeadVoiceLatched and not A.flightDeadVoiceAcknowledged then
      A.flightDeadVoiceStartPosition = nil
    end
    if A.rxDeadVoiceLatched and not A.rxDeadVoiceAcknowledged then
      A.rxDeadVoiceStartPosition = nil
    end
  end
  if heliChanged or reserveChanged then D.hasBattData = false end
  if heliChanged or rxSettingsChanged then
    D.rxVoltage = nil
    D.rxCellVoltage = nil
    D.rxPercent = 0
  end
  A.lastDataTick = -1
  clearFrameCache()
  if widget.supported then buildUi() else buildUnsupportedUi() end
end
-- The reverse-switch setting is unnecessary: the widget
-- detects movement of the whole switch and validates it against Gov/Hspd or NR.
-- Telemetry sensor sources are intentionally omitted: the widget auto-detects standard
-- Rotorflight sensor names (Hspd, Tspd, Vbec, Vcel, Cel#, Curr, Capa, Bat%,
-- Tesc, Gov, Thr, ARM, ARMD, PID#, BAT#, Vbat, and RQly). Nitro Rx pack
-- voltage uses Vbec only.
-- OMPHOBBY uses NR, RxBt, Curr, Capa, Bat%, and Tmp; its cell count comes
-- from M1/M2 in the model name, and it has no tail-RPM telemetry source.
-- Betaflight CRSF/ELRS uses RxBt, Curr, Capa, and Bat%; RxBt is total VBAT.
-- "Motor Switch" is a raw SOURCE so settings select the physical control (SG),
-- not one of its individual position conditions (SG up/middle/down). A movement
-- suppresses Electric/OMPHOBBY flight-pack alerts only after current aircraft
-- telemetry corroborates a stopped state; missing evidence fails loud. After
-- the first dead.wav playback, movement separately acknowledges only repeats.
local options = {
  { "Theme",    CHOICE, 1, { "Dark", "Light", "Transparent",
                             "Orange", "Red", "Yellow", "Blue", "Pink",
                             "Green", "Cyan", "Purple", "Teal", "Lime",
                             "Reef", "Royal", "Moss", "Ember", "Miami" } },
  { "TxBatt",   CHOICE, 1, { "LiPo", "Li-Ion" } },
  { "MinFlight", VALUE, TOPBAR_MIN_DUR_DEFAULT, -30, 120 },
  { "HeliType", CHOICE, 1, { "Electric", "Nitro", "OMPHOBBY", "Betaflight" } },
  { "BattRsv", VALUE, 20, 0, 50 },
  { "BattVoice", BOOL, 0 },
  { "DispLED", BOOL, 0 },
  { "RxPackMin", STRING, "6.60" },
  { "RxPackMax", STRING, "8.40" },
  { "MotorSw", SOURCE, 0 },
}
local OPTION_LABELS = {
  TxBatt   = "TX Battery",
  MinFlight= "Min. Flight Time (sec)",
  HeliType = "Aircraft Type",
  BattRsv  = "Batt Reserve %",
  BattVoice= "Battery Voice",
  DispLED   = "Display LEDs",
  RxPackMin= "Rx Pack Minimum",
  RxPackMax= "Rx Pack Maximum",
  MotorSw  = "Motor Switch",
}
local function translate(name, language)
  return OPTION_LABELS[name] or name
end
return {
  name       = "StacyDashV4",
  options    = options,
  create     = create,
  update     = update,
  refresh    = refresh,
  background = background,
  translate  = translate,
  useLvgl    = true,
}
