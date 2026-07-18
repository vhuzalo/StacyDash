local M = {}

function M.new(lvglApi, defaultColor)
  local self = { lvgl = assert(lvglApi), defaultColor=defaultColor, state = {} }

  function self:reset()
    self.state = {}
  end

  function self:remember(object, properties)
    local state = { visible=true }
    for key, value in pairs(properties or {}) do state[key] = value end
    self.state[object] = state
    return object
  end

  function self:set(object, properties)
    if not object or not properties then return end
    local previous = self.state[object]
    if not previous then previous = {}; self.state[object] = previous end
    local hasChanges = false
    for key, value in pairs(properties) do
      if previous[key] ~= value then
        previous[key] = value
        hasChanges = true
      end
    end
    if hasChanges and object.set then object:set(properties) end
  end

  function self:visible(object, visible)
    if not object then return end
    local previous = self.state[object]
    if not previous then previous = {}; self.state[object] = previous end
    visible = not not visible
    if previous.visible == visible then return end
    previous.visible = visible
    if visible then object:show() else object:hide() end
  end

  function self:label(x, y, width, text, font, color, align)
    local properties = {
      x=x, y=y, w=width, h=0, text=text or "", font=font,
      color=color or self.defaultColor, align=align or 0,
    }
    return self:remember(self.lvgl.label(properties), properties)
  end

  function self:setLabel(object, text, color, x, y, width, font, align)
    local properties = { text=tostring(text or "") }
    if color ~= nil then properties.color = color end
    if x ~= nil then properties.x = x end
    if y ~= nil then properties.y = y end
    if width ~= nil then properties.w = width end
    if font ~= nil then properties.font = font end
    if align ~= nil then properties.align = align end
    self:set(object, properties)
  end

  function self:rect(x, y, width, height, color, filled, rounded, thickness)
    local properties = {
      x=x, y=y, w=width, h=height, color=color, filled=filled and 1 or 0,
      rounded=rounded or 0, thickness=thickness or 1,
    }
    return self:remember(self.lvgl.rectangle(properties), properties)
  end

  function self:panel(x, y, width, height, background, border, rounded)
    return {
      fill=self:rect(x, y, width, height, background, true, rounded, 1),
      border=self:rect(x, y, width, height, border, false, rounded, 1),
    }
  end

  function self:setPanel(panel, background, border)
    self:set(panel.fill, { color=background })
    self:set(panel.border, { color=border })
  end

  return self
end

return M
