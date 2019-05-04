--

require("/scripts/util.lua")

local actions, conditions = { }, { }
local function nullfunc() end
local function action(id, ...) return (actions[id] or nullfunc)(...) end
local function condition(id, ...) return (conditions[id] or nullfunc)(...) end

-------------
-- actions --
-------------

function actions.pane(cfg)
  if type(cfg) ~= "table" then cfg = { config = cfg } end
  player.interact(cfg.type or "ScriptPane", cfg.config)
end

function actions.exec(script)
  if type(script) ~= "string" then return nil end
  _SBLOADED[script] = nil require(script) -- force execute every time
end

----------------
-- conditions --
----------------

function conditions.any(...)
  for _, c in pairs{...} do if condition(table.unpack(c)) then return true end end
  return false
end
function conditions.all(...)
  for _, c in pairs{...} do if not condition(table.unpack(c)) then return false end end
  return true
end

function conditions.admin() return player.isAdmin() end
function conditions.statPositive(stat) return status.statPositive(stat) end
function conditions.statNegative(stat) return not status.statPositive(stat) end
function conditions.species(species) return player.species() == species end

---------------
-- internals --
---------------

local colorSub = { -- color tag substitutions
  ["^essential;"] = "^#ffb133;",
  ["^admin;"] = "^#bf7fff;",
}

local function buildList()
  widget.clearListItems("scroll.list") -- clear out first
  local c = root.assetJson("/quickbar/icons.json")
  local items = { }
  
  for _, i in pairs(c.items) do -- dump in normal items
    if not i.condition or condition(table.unpack(i.condition)) then
      table.insert(items, i)
    end
  end
    
  -- and then translate legacy entries
  for _, i in pairs(c.priority) do
    table.insert(items, {
      label = "^#ffb133;" .. i.label,
      icon = i.icon,
      weight = -1100,
      action = { "pane", i.pane }
    })
  end
  if player.isAdmin() then
    for _, i in pairs(c.admin) do
      table.insert(items, {
        label = "^#bf7fff;" .. i.label,
        icon = i.icon,
        weight = -1000,
        action = { "pane", i.pane }
      })
    end
  end
  for _, i in pairs(c.normal) do
    table.insert(items, {
      label = i.label,
      icon = i.icon,
      action = { "pane", i.pane }
    })
  end
  
  -- sort by weight then alphabetically, ignoring caps and tags (and doing tag substitutions while we're here)
  for _, i in pairs(items) do
    i._sort = string.lower(string.gsub(i.label, "(%b^;)", ""))
    i.label = string.gsub(i.label, "(%b^;)", colorSub)
    i.weight = i.weight or 0
    --sb.logInfo("label: "..i.label.."\nsort: "..i._sort)
  end
  table.sort(items, function(a, b) return a.weight < b.weight or (a.weight == b.weight and a._sort < b._sort) end)
  
  -- and add items to pane list
  for idx = 1, #items do
    local i = items[idx]
    local l = "scroll.list." .. widget.addListItem("scroll.list")
    widget.setText(l .. ".label", i.label)
    local bc = l .. ".buttonContainer"
    widget.registerMemberCallback(bc, "click", function() action(table.unpack(i.action)) end)
    local btn = bc .. "." .. widget.addListItem(bc) .. ".button"
    widget.setButtonOverlayImage(btn, i.icon or "/items/currency/essence.png")
  end
end

function init()
  buildList()
end

function uninit()
  widget.clearListItems("scroll.list")
end
