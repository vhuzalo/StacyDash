local played = {}
function playFile(path)
  played[#played + 1] = path
end

local data = {
  armValid = true,
  govValid = true,
  throttleValid = false,
  pidProfileValid = true,
}
local frame = { armState = 0, pidProfile = 1 }
local alerts = {}
local governor = "OFF"
local enabled = { arm = false, gov = false, profile = false }

local status = assert(loadfile("WIDGETS/StacyDashV4/status.lua"))().new({
  data = data,
  frame = frame,
  alerts = alerts,
  getSensorNumber = function() return nil end,
  getNamed = function() return nil end,
  getGovState = function() return governor end,
  getHeliType = function() return 1 end,
  ompType = 3,
  armVoiceEnabled = function() return enabled.arm end,
  govVoiceEnabled = function() return enabled.gov end,
  profileVoiceEnabled = function() return enabled.profile end,
})

status:updateAudio() -- initializes all three states without announcing them
frame.armState, governor, frame.pidProfile = 1, "IDLE", 2
status:updateAudio()
assert(#played == 0, "disabled voice categories must remain silent")

enabled.arm, enabled.gov, enabled.profile = true, true, true
status:updateAudio()
assert(#played == 0, "enabling voice must not replay the current states")

frame.armState, governor, frame.pidProfile = 0, "ACTIVE", 3
status:updateAudio()
assert(played[1]:match("disarmed%.wav$"), "arm transition voice missing")
assert(played[2]:match("gov/active%.wav$"), "governor transition voice missing")
assert(played[3]:match("profile%.wav$"), "profile prefix voice missing")
assert(played[4]:match("profile/3%.wav$"), "profile number voice missing")

enabled.arm = false
frame.armState = 1
status:updateAudio()
assert(#played == 4, "disabling one category must mute only that category")

print("status_audio_test: ok")
