-- EdgeTX/LVGL host simulation for the internal ExpressLRS diagnostics view.
LCD_W, LCD_H = 800, 480
BOLD, SMLSIZE, MIDSIZE, DBLSIZE = 1, 2, 4, 8
VALUE, BOOL, CHOICE, STRING, SOURCE = 0, 2, 10, 3, 1
RIGHT, CENTER, CENTERED = 16, 32, 32
EVT_TOUCH_TAP, EVT_TOUCH_SLIDE = 101, 102

local now, labels, buttons = 0, {}, {}
local telemetry, current, elrsPosition = {}, {}, -1024

lcd = { RGB=function(red, green, blue) return red * 65536 + green * 256 + blue end }

local function object(properties)
  local self = { properties=properties, visible=true }
  function self:set(changes)
    for key, value in pairs(changes) do self.properties[key] = value end
  end
  function self:show() self.visible = true end
  function self:hide() self.visible = false end
  return self
end

lvgl = {
  clear=function() labels, buttons = {}, {} end,
  label=function(properties)
    local value = object(properties)
    labels[#labels + 1] = value
    return value
  end,
  rectangle=object, image=object,
  button=function(properties)
    local value = object(properties)
    buttons[#buttons + 1] = value
    return value
  end,
  hline=function(properties) return object(properties) end,
  vline=function(properties) return object(properties) end,
}

model = {
  getInfo=function() return { name="ELRS Test" } end,
  getTimer=function() return { value=125 } end,
}
getTime = function() return now end
getRSSI = function() return 0 end
getSourceName = function(source)
  if source == 1010 then return "SG" end
  if source == 2020 then return "SH" end
  return tostring(source)
end
getFieldInfo = function(source)
  if source == 1010 then return { id=source, name="SG", desc="Switch G" } end
  if source == 2020 then return { id=source, name="SH", desc="Switch H" } end
  if type(source) == "string" and telemetry[source] ~= nil then
    return { id=source, name=source }
  end
  return nil
end
getSourceValue = function(source)
  if source == 1010 then return 1024, true, true end
  if source == 2020 then return elrsPosition, true, true end
  if telemetry[source] == nil then return nil, false, false end
  if current[source] == false then return nil, false, false end
  return telemetry[source], true, true
end
getValue = function(source)
  if source == 1010 then return 1024 end
  if source == 2020 then return elrsPosition end
  return telemetry[source]
end

local function hasText(expected)
  for _, label in ipairs(labels) do
    if label.visible and label.properties.text == expected then return true end
  end
  return false
end
local function assertText(expected)
  assert(hasText(expected), "missing LVGL label: " .. expected)
end
local function pressAt(x, y)
  for index = #buttons, 1, -1 do
    local properties = buttons[index].properties
    if x >= properties.x and x <= properties.x + properties.w
       and y >= properties.y and y <= properties.y + properties.h
       and type(properties.press) == "function" then
      properties.press()
      return true
    end
  end
  return false
end

local function options(aircraftType)
  return {
    Theme=1, TxBatt=1, MinFlight=60, HeliType=aircraftType, BattRsv=20,
    BattVoice=0, DispLED=0, RxPackMin="6.60", RxPackMax="8.40", MotorSw=1010,
    ElrsSw=2020,
  }
end

telemetry = {
  RQly=96, ["1RSS"]=-61, ["2RSS"]=-65, RSNR=9, RFMD=7,
  TPWR=0, ANT=1, TQly=88, TRSS=-70, TSNR=6,
  Hspd=1800, Vcel=3.9, ["Cel#"]=6, Vbat=23.4, Curr=20,
  Capa=300, ["Bat%"]=70, ["tx-voltage"]=8.0,
}

local dashboard = assert(loadfile("WIDGETS/StacyDashV4/main.lua"))()
local widget = dashboard.create({ w=800, h=480 }, options(1))
dashboard.update(widget, options(1))
assertText("HEADSPEED RPM")

-- Only a tap in the signal hitbox opens diagnostics.
dashboard.refresh(widget, EVT_TOUCH_SLIDE, { x=730, y=20 })
assert(not hasText("UPLINK LQ"), "slide must not switch views")
assert(pressAt(730, 20), "signal must expose an LVGL press control")
dashboard.refresh(widget, 0, nil)
assertText("UPLINK LQ")
assertText("ELRS Test")
assertText("2:05")
assertText("NO ARM TELE")
assertText("96%")
assertText("min 96%")
assertText("-61")
assertText("-65")
assertText("9")
assertText("7")
assertText("50") -- TPWR=0 represents the CRSF 50 mW level.
assertText("A2")
assertText("88%")
assertText("UPLINK ACTIVE  ·  DOWNLINK ACTIVE")

-- Session extrema update without rebuilding the view.
telemetry.RQly, telemetry["1RSS"], telemetry.RSNR = 72, -82, 2
telemetry.TPWR, telemetry.TQly, telemetry.TRSS, telemetry.TSNR = 250, 60, -91, -2
now = 20
dashboard.refresh(widget, 0, nil)
assertText("72%")
assertText("min 72%")
assertText("min -82")
assertText("max 250")
assertText("min 60%")
assertText("min -91")
assertText("min -2")

-- A discovered but stale source shows no current value while retaining history.
current["1RSS"] = false
now = 40
dashboard.refresh(widget, 0, nil)
assertText("--")
assertText("min -82")
current["1RSS"] = true

-- Diagnostics remains available for every aircraft profile.
for aircraftType = 2, 4 do
  dashboard.update(widget, options(aircraftType))
  now = now + 20
  dashboard.refresh(widget, 0, nil)
  assertText("UPLINK LQ")
  assertText("72%")
end

-- An unrelated tap leaves the view unchanged; the configured switch returns.
dashboard.refresh(widget, EVT_TOUCH_TAP, { x=400, y=400 })
assertText("UPLINK LQ")
elrsPosition = 1024
now = now + 20
dashboard.refresh(widget, 0, nil)
assertText("HEADSPEED RPM")
assert(not hasText("UPLINK LQ"), "switch must restore the flight dashboard")

-- A configured physical switch toggles both directions without touch.
elrsPosition = -1024
now = now + 20
dashboard.refresh(widget, 0, nil)
assertText("UPLINK LQ")
elrsPosition = 1024
now = now + 20
dashboard.refresh(widget, 0, nil)
assertText("HEADSPEED RPM")

print("elrs_diagnostics_test: ok")
