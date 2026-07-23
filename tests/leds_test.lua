LED_STRIP_LENGTH = 12

local now = 0
local applied = 0
local leds = {}

function getTime() return now end
function setRGBLedColor(index, red, green, blue)
  leds[index] = { red, green, blue }
end
function applyRGBLedColors() applied = applied + 1 end

local armedColor = { 10, 120, 230 }
local disarmedColor = { 200, 80, 40 }
local module = assert(loadfile("WIDGETS/StacyDashV4/leds.lua"))()
local service = module.new({
  isEnabled = function() return true end,
  armedColor = function() return armedColor end,
  disarmedColor = function() return disarmedColor end,
})

service:update(true, false)
assert(applied == 1, "armed color was not applied")
assert(leds[0][1] == 10 and leds[0][2] == 120 and leds[0][3] == 230,
       "armed color differs from the configured color")

armedColor = { 20, 130, 240 }
service:update(true, false)
assert(applied == 2, "changing the armed color did not refresh a stable state")
assert(leds[0][1] == 20 and leds[0][2] == 130 and leds[0][3] == 240,
       "updated armed color was not applied")

service:update(false, false)
assert(leds[0][1] == 200 and leds[0][2] == 80 and leds[0][3] == 40,
       "disarmed color differs from the configured color")

now = 4
service:update(false, true)
local hasFullColor, hasDimColor = false, false
for index = 0, LED_STRIP_LENGTH - 1 do
  local color = leds[index]
  if color[1] == 200 and color[2] == 80 and color[3] == 40 then
    hasFullColor = true
  elseif color[1] < 200 and color[2] < 80 and color[3] < 40 then
    hasDimColor = true
  end
end
assert(hasFullColor and hasDimColor,
       "disable animation must use bright and dim variants of disarmed color")

print("leds_test: ok")
