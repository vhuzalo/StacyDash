-- Minimal EdgeTX/LVGL host simulation for the Betaflight telemetry contract.
LCD_W, LCD_H = 800, 480
BOLD, SMLSIZE, MIDSIZE, DBLSIZE = 1, 2, 4, 8
VALUE, BOOL, CHOICE, STRING, SOURCE = 0, 2, 10, 3, 1
RIGHT, CENTER, CENTERED = 16, 32, 32

local now = 0
local telemetry = {}
local labels = {}

lcd = {
  RGB = function(red, green, blue)
    return red * 65536 + green * 256 + blue
  end,
}

local function object(properties)
  local self = { properties = properties, visible = true }
  function self:set(changes)
    for key, value in pairs(changes) do self.properties[key] = value end
  end
  function self:show() self.visible = true end
  function self:hide() self.visible = false end
  return self
end

lvgl = {
  clear = function() labels = {} end,
  label = function(properties)
    local value = object(properties)
    labels[#labels + 1] = value
    return value
  end,
  rectangle = object,
  image = object,
  hline = function(properties) return object(properties) end,
  vline = function(properties) return object(properties) end,
}

model = {
  getInfo = function() return { name = "Betaflight Test" } end,
  getTimer = function() return { value = 90 } end,
}

getTime = function() return now end
getRSSI = function() return 0 end
getSourceName = function(source)
  return source == 101 and "SG" or tostring(source)
end
getFieldInfo = function(source)
  if source == 101 then return { id = source, name = "SG", desc = "Switch G" } end
  if type(source) == "string" and telemetry[source] ~= nil then
    return { id = source, name = source }
  end
  return nil
end
getSourceValue = function(source)
  if source == 101 then return 1024, true, true end
  local value = telemetry[source]
  if value == nil then return nil, false, false end
  return value, true, true
end
getValue = function(source)
  if source == 101 then return 1024 end
  return telemetry[source]
end

local function hasText(expected)
  for _, label in ipairs(labels) do
    if label.properties.text == expected then return true end
  end
  return false
end

local function assertText(expected)
  assert(hasText(expected), "missing LVGL label: " .. expected)
end

local function options(aircraftType)
  return {
    Theme = 1,
    TxBatt = 1,
    MinFlight = 60,
    HeliType = aircraftType,
    BattRsv = 20,
    BattVoice = 0,
    DispLED = 0,
    RxPackMin = "6.60",
    RxPackMax = "8.40",
    MotorSw = 101,
  }
end

telemetry = {
  RQLY = 95,
  RxBt = 16.4,
  Curr = 23.2,
  Capa = 321,
  ["Bat%"] = 55,
  ["tx-voltage"] = 8.0,
}

local dashboard = assert(loadfile("WIDGETS/StacyDashV4/main.lua"))()
assert(dashboard.options[4][4][4] == "Betaflight", "Betaflight must remain choice 4")
assert(dashboard.translate("HeliType") == "Aircraft Type")

local widget = dashboard.create({ w = 800, h = 480 }, options(4))
dashboard.update(widget, options(4))
dashboard.refresh(widget)
assertText("VBAT")
assertText("16.4")
assertText("min 16.4")
assertText("BATTERY · 16.4V · 321 mAh used")
assertText("43%") -- 55% with the configured 20% reserve

telemetry.RxBt = 15.9
now = 20
dashboard.refresh(widget)
assertText("15.9")
assertText("min 15.9")
assertText("BATTERY · 15.9V · 321 mAh used")

telemetry["Bat%"] = nil
now = 40
dashboard.refresh(widget)
assertText("BATTERY · 15.9V · 321 mAh used")
assertText("NO DATA")

telemetry["Bat%"] = 0
now = 60
dashboard.refresh(widget)
assertText("0%") -- zero is valid when a positive flight-pack voltage corroborates it

telemetry.RxBt = nil
now = 80
dashboard.refresh(widget)
assertText("NO DATA") -- a zero percentage alone may be an FC powered over USB

telemetry = {
  RQLY = 95,
  Hspd = 1850,
  Vcel = 3.95,
  ["Cel#"] = 6,
  Vbat = 23.7,
  Curr = 18,
  Capa = 400,
  ["Bat%"] = 70,
  ["tx-voltage"] = 8.0,
}
now = 100
dashboard.update(widget, options(1))
assertText("CELL")
assert(not hasText("VBAT"), "Electric profile must restore the CELL label")
assertText("1850")

print("betaflight_profile_test: ok")
