local M = {}

local PATH = "/flights-count.csv"
local MAX_BYTES = 32 * 1024
local MAX_ENTRIES = 200

local function trim(s)
  return string.match(s or "", "^%s*(.-)%s*$")
end

local function readAll(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local parts, total = {}, 0
  local ok = pcall(function()
    while true do
      local chunk = io.read(f, 1024)
      if chunk == nil or chunk == "" then break end
      total = total + #chunk
      if total > MAX_BYTES then break end
      parts[#parts+1] = chunk
      if #chunk < 1024 then break end
    end
  end)
  pcall(io.close, f)
  return ok and table.concat(parts) or nil
end

local function writeAll(path, content)
  content = content or ""
  local function writeFile(target)
    local f = io.open(target, "w")
    if not f then return false end
    local called, result = pcall(io.write, f, content)
    local closed = pcall(io.close, f)
    return called and result ~= nil and result ~= false and closed
  end

  local dirApi = dir
  local renameFn = type(dirApi) == "table" and dirApi.rename
                   or (type(os) == "table" and os.rename)
  local deleteFn = type(dirApi) == "table" and dirApi.del
                   or (type(os) == "table" and os.remove)
  local function renameFile(fromPath, toPath)
    if not renameFn then return false end
    local ok, result = pcall(renameFn, fromPath, toPath)
    return ok and (result == nil or result == true or result == 0)
  end
  local function deleteFile(target)
    if not deleteFn then return false end
    local ok, result = pcall(deleteFn, target)
    return ok and (result == nil or result == true or result == 0)
  end

  if renameFn then
    local tmp, backup = path .. ".tmp", path .. ".bak"
    deleteFile(tmp)
    if not writeFile(tmp) then deleteFile(tmp); return false end
    local existing = io.open(path, "r")
    if existing then pcall(io.close, existing) end
    local movedExisting = false
    if existing then
      deleteFile(backup)
      movedExisting = renameFile(path, backup)
      if not movedExisting then deleteFile(tmp); return false end
    end
    if renameFile(tmp, path) then
      if movedExisting then deleteFile(backup) end
      return true
    end
    if movedExisting then renameFile(backup, path) end
    deleteFile(tmp)
    return false
  end

  return writeFile(path)
end

local function modelKey(name)
  if type(name) ~= "string" or name == "" then return "__default__" end
  local value = trim(name)
  if value == "" then return "__default__" end
  return string.gsub(value, ",", " ")
end

function M.new(config)
  local self = {
    getModelName = assert(config.getModelName),
    getTimer = assert(config.getTimer),
    onModelChanged = config.onModelChanged,
    minimum = tonumber(config.minimum) or 60,
    cache = nil,
    count = 0,
    model = "__default__",
    armed = nil,
    saveError = false,
  }

  function self:setMinimum(seconds)
    seconds = tonumber(seconds) or 60
    if seconds < 0 then seconds = math.abs(seconds) end
    if seconds < 1 then seconds = 1 end
    self.minimum = seconds
  end

  function self:getCache()
    if self.cache then return self.cache end
    self.cache = {}
    local text = readAll(PATH)
    if not text or text == "" then return self.cache end
    local entries = 0
    for line in string.gmatch(text, "[^\r\n]+") do
      local normalized = trim(line)
      if normalized ~= "" and string.sub(normalized, 1, 1) ~= "#" then
        local key, value = string.match(normalized, "^%s*([^,]+)%s*,%s*([^,]+)")
        if key and value and key ~= "model_name" then
          self.cache[trim(key)] = tonumber(value) or 0
          entries = entries + 1
          if entries >= MAX_ENTRIES then break end
        end
      end
    end
    return self.cache
  end

  function self:save()
    local keys, out = {}, { "model_name,flight_count\n# api_ver=1\n" }
    for key in pairs(self:getCache()) do keys[#keys+1] = key end
    table.sort(keys)
    for _, key in ipairs(keys) do
      out[#out+1] = string.format("%s,%d\n", key, tonumber(self.cache[key]) or 0)
    end
    local ok = writeAll(PATH, table.concat(out))
    self.saveError = not ok
    return ok
  end

  function self:load(reset)
    self.model = modelKey(self.getModelName())
    self.count = self:getCache()[self.model] or 0
    self.armed = nil
    if reset and self.onModelChanged then self.onModelChanged() end
  end

  function self:getCount()
    return self.count
  end

  function self:hasSaveError()
    return self.saveError
  end

  function self:tick()
    local currentModel = modelKey(self.getModelName())
    if self.model ~= currentModel then
      self.model = currentModel
      self.count = self:getCache()[currentModel] or 0
      self.armed = nil
      if self.onModelChanged then self.onModelChanged() end
    end

    local timer = self.getTimer()
    if type(timer) ~= "table" then return end
    local value = tonumber(timer.value)
    if not value then return end
    local start = tonumber(timer.start) or 0
    local elapsed = start > 0 and (start - value) or value
    if elapsed < 0 then elapsed = 0 end

    if self.armed == nil then self.armed = elapsed < self.minimum end
    if elapsed < self.minimum then
      self.armed = true
    elseif self.armed then
      self.armed = false
      local cache = self:getCache()
      self.count = (cache[currentModel] or self.count or 0) + 1
      cache[currentModel] = self.count
      self:save()
    end
  end

  return self
end

return M
