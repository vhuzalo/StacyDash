local M = {}

local THEMES = {
  orange = { bg={ 92, 42,  2}, tile={120, 60, 10}, line={160, 86, 24}, dim={230,178,120}, accent={255,155, 35} },
  red    = { bg={100, 18, 18}, tile={130, 28, 28}, line={180, 50, 50}, dim={240,165,165}, accent={255, 95, 95} },
  yellow = { bg={ 54, 46,  2}, tile={ 74, 64, 12}, line={120,102, 26}, dim={210,200,125}, accent={250,210, 60} },
  blue   = { bg={  4, 20, 54}, tile={ 10, 32, 74}, line={ 28, 72,124}, dim={150,180,220}, accent={ 80,165,255} },
  pink   = { bg={145,  0, 83}, tile={184,  0,105}, line={255, 20,147}, dim={255,196,225}, accent={255,222,239} },
  green  = { bg={  6, 54, 22}, tile={ 12, 74, 34}, line={ 24,120, 58}, dim={150,215,175}, accent={ 60,220,120} },
  cyan   = { bg={  2, 44, 50}, tile={  8, 62, 70}, line={ 22,110,122}, dim={150,210,220}, accent={ 40,210,230} },
  purple = { bg={ 34, 12, 60}, tile={ 50, 22, 82}, line={ 92, 46,140}, dim={190,165,225}, accent={175,110,245} },
  teal   = { bg={  2, 46, 40}, tile={  8, 64, 56}, line={ 22,112,100}, dim={150,214,202}, accent={ 45,210,180} },
  lime   = { bg={ 30, 48,  2}, tile={ 44, 66,  8}, line={ 80,116, 22}, dim={200,220,140}, accent={170,225, 55} },
  reef   = { bg={  8, 22, 58}, tile={  8, 46, 50}, line={ 24, 96,104}, dim={150,190,218}, accent={ 70,200,230} },
  royal  = { bg={ 40, 16, 66}, tile={ 52, 40, 12}, line={112, 88, 28}, dim={202,172,228}, accent={180,120,248} },
  moss   = { bg={  8, 52, 26}, tile={ 46, 32, 16}, line={ 96, 68, 34}, dim={165,215,180}, accent={ 70,215,120} },
  ember  = { bg={ 70, 18, 10}, tile={ 92, 52,  8}, line={150, 88, 26}, dim={235,175,150}, accent={255,150, 50} },
  miami  = { bg={  4, 46, 52}, tile={ 62, 14, 46}, line={120, 44, 92}, dim={170,208,216}, accent={255, 95,180} },
}

local NAMES = {
  [2]="light", [4]="orange", [5]="red", [6]="yellow", [7]="blue",
  [8]="pink", [9]="green", [10]="cyan", [11]="purple", [12]="teal",
  [13]="lime", [14]="reef", [15]="royal", [16]="moss", [17]="ember",
  [18]="miami",
}

function M.nameForOption(value)
  return NAMES[tonumber(value) or 0] or "dark"
end

function M.colors(name)
  return THEMES[name]
end

return M
