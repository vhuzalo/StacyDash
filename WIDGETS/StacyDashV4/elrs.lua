local M = {}

local SENSOR_DEFS = {
  { key="rqly", aliases={"RQly", "RQLY", "LQ"}, min=0, max=100, stat="min" },
  { key="rssi1", aliases={"1RSS"}, min=-150, max=0, stat="min" },
  { key="rssi2", aliases={"2RSS"}, min=-150, max=0, stat="min" },
  { key="rsnr", aliases={"RSNR"}, min=-50, max=50, stat="min" },
  { key="rfmd", aliases={"RFMD"}, min=0, max=255 },
  { key="tpwr", aliases={"TPWR"}, min=0, max=10000, stat="max" },
  { key="ant", aliases={"ANT"}, min=0, max=1 },
  { key="tqly", aliases={"TQly", "TQLY"}, min=0, max=100, stat="min" },
  { key="trss", aliases={"TRSS"}, min=-150, max=0, stat="min" },
  { key="tsnr", aliases={"TSNR"}, min=-50, max=50, stat="min" },
}

local function rounded(value)
  if value >= 0 then return math.floor(value + 0.5) end
  return math.ceil(value - 0.5)
end

function M.new(config)
  local self = {
    getNamed=assert(config.getNamed), resolved={}, values={}, stats={},
    view={}, render=nil,
  }

  function self:reset()
    self.resolved, self.values, self.stats = {}, {}, {}
  end

  function self:read(definition)
    local cached = self.resolved[definition.key]
    if cached then
      local raw, current, _, exists = self.getNamed(cached)
      if exists then return tonumber(raw), current ~= false, true end
      self.resolved[definition.key] = nil
    end
    for index = 1, #definition.aliases do
      local name = definition.aliases[index]
      local raw, current, _, exists = self.getNamed(name)
      if exists then
        self.resolved[definition.key] = name
        return tonumber(raw), current ~= false, true
      end
    end
    return nil, false, false
  end

  function self:sample()
    for _, definition in ipairs(SENSOR_DEFS) do
      local value, current, exists = self:read(definition)
      local valid = current and value ~= nil
                    and value >= definition.min and value <= definition.max
      if definition.key == "ant" or definition.key == "rfmd" then
        valid = valid and value == math.floor(value)
      end
      self.values[definition.key] = {
        value=valid and value or nil, current=current, exists=exists, valid=valid,
      }
      if valid and definition.stat then
        local previous = self.stats[definition.key]
        if previous == nil
           or (definition.stat == "min" and value < previous)
           or (definition.stat == "max" and value > previous) then
          self.stats[definition.key] = value
        end
      end
    end
  end

  function self:value(key)
    local entry = self.values[key]
    return entry and entry.valid and entry.value or nil
  end

  function self:format(key, value)
    if value == nil then return "--" end
    if key == "rqly" or key == "tqly" then return tostring(rounded(value)) .. "%" end
    if key == "tpwr" then return tostring(value == 0 and 50 or rounded(value)) end
    if key == "ant" then return value == 0 and "A1" or "A2" end
    return tostring(rounded(value))
  end

  function self:footer(key, prefix)
    local value = self.stats[key]
    return prefix .. " " .. (value == nil and "--" or self:format(key, value))
  end

  function self:lqColor(value)
    local colors = self.render.colors
    if value == nil then return colors.dim end
    if value >= 80 then return colors.green end
    if value >= 50 then return colors.yellow end
    return colors.red
  end

  function self:build(render)
    self.render = render
    local lvgl, ui, c, f = render.lvgl, render.ui, render.colors, render.fonts
    lvgl.clear()
    ui:reset()
    self.view = {}
    local view = self.view
    if not render.transparent then ui:rect(0, 0, render.w, render.h, c.bg, true, 0, 0) end

    if render.buildTopBar then render.buildTopBar() end

    view.heroPanel = ui:panel(10, 56, 250, 298, c.tile, c.line, 7)
    ui:label(24, 76, 222, "UPLINK LQ", f.smallBold, c.accent, f.center)
    view.rqly = ui:label(24, 130, 222, "--", f.doubleBold, c.dim, f.center)
    view.rqlyMin = ui:label(24, 226, 222, "min --", f.small, c.dim, f.center)
    view.linkState = ui:label(24, 294, 222, "NO DATA", f.smallBold, c.dim, f.center)

    local function tile(x, y, width, height, label, unit)
      ui:panel(x, y, width, height, c.tile, c.line, 7)
      ui:label(x + 10, y + 8, width - 20, label, f.small, c.dim)
      ui:label(x + width - 54, y + 8, 44, unit or "", f.small, c.dim, f.right)
      return {
        value=ui:label(x + 10, y + 36, width - 20, "--", f.smallBold, c.dim, f.center),
        footer=ui:label(x + 10, y + height - 24, width - 20, "", f.small, c.dim, f.center),
      }
    end

    local x, y, gap, width, height = 270, 56, 8, 168, 91
    view.rssi1 = tile(x, y, width, height, "1RSS", "dBm")
    view.rssi2 = tile(x + width + gap, y, width, height, "2RSS", "dBm")
    view.rsnr = tile(x + (width + gap) * 2, y, width, height, "RSNR", "dB")
    view.rfmd = tile(x, y + height + gap, width, height, "RF MODE", "index")
    view.tpwr = tile(x + width + gap, y + height + gap, width, height, "TX POWER", "mW")
    view.ant = tile(x + (width + gap) * 2, y + height + gap, width, height, "RX ANTENNA", "")

    y, height = 256, 98
    view.tqly = tile(x, y, width, height, "TQly", "%")
    view.trss = tile(x + width + gap, y, width, height, "TRSS", "dBm")
    view.tsnr = tile(x + (width + gap) * 2, y, width, height, "TSNR", "dB")

    view.footerPanel = ui:panel(10, 366, 780, 96, c.tile, c.line, 7)
    ui:label(24, 382, 752, "LINK DIAGNOSTICS", f.smallBold, c.accent, f.center)
    view.summary = ui:label(24, 426, 752, "Waiting for ExpressLRS telemetry",
                            f.small, c.dim, f.center)
    self:updateUi()
  end

  function self:updateUi()
    if not self.render or not self.view.rqly then return end
    local ui, c, f, view = self.render.ui, self.render.colors, self.render.fonts, self.view
    local rqly = self:value("rqly")
    local rqlyColor = self:lqColor(rqly)
    ui:setLabel(view.rqly, self:format("rqly", rqly), rqlyColor)
    ui:setLabel(view.rqlyMin, self:footer("rqly", "min"), c.dim)
    local state = rqly == nil and "NO DATA" or rqly <= 0 and "NO LINK" or "LINK ACTIVE"
    ui:setLabel(view.linkState, state, rqly == nil and c.dim or rqly <= 0 and c.red or rqlyColor)

    local definitions = {
      {"rssi1", "min"}, {"rssi2", "min"}, {"rsnr", "min"},
      {"rfmd"}, {"tpwr", "max"}, {"ant"}, {"tqly", "min"},
      {"trss", "min"}, {"tsnr", "min"},
    }
    for _, item in ipairs(definitions) do
      local key, statPrefix = item[1], item[2]
      local value = self:value(key)
      local color = key == "tqly" and self:lqColor(value)
                    or (value ~= nil and c.text or c.dim)
      ui:setLabel(view[key].value, self:format(key, value), color)
      ui:setLabel(view[key].footer, statPrefix and self:footer(key, statPrefix) or "", c.dim)
    end

    local uplink = rqly ~= nil or self:value("rssi1") ~= nil or self:value("rsnr") ~= nil
    local downlink = self:value("tqly") ~= nil or self:value("trss") ~= nil
                     or self:value("tsnr") ~= nil
    local summary
    if uplink and downlink then summary = "UPLINK ACTIVE  ·  DOWNLINK ACTIVE"
    elseif uplink then summary = "UPLINK ACTIVE  ·  DOWNLINK NO DATA"
    elseif downlink then summary = "UPLINK NO DATA  ·  DOWNLINK ACTIVE"
    else summary = "Waiting for ExpressLRS telemetry" end
    ui:setLabel(view.summary, summary, (uplink or downlink) and c.text or c.dim,
                nil, nil, nil, f.small, f.center)
  end

  return self
end

return M
