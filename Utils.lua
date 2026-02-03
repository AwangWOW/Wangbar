local _, addon = ...

CLASSWITHSECONDARY = {
  ["DEATHKNIGHT"] = true,
  ["DRUID"] = true,
  ["EVOKER"] = true,
  ["MAGE"] = true,
  ["MONK"] = true,
  ["PALADIN"] = true,
  ["PRIEST"] = true,
  ["ROGUE"] = true,
  ["SHAMAN"] = true,
  ["WARLOCK"] = true,
}
SPECWITHSECONDARY = {
  [268] = true,     -- Windwalker
  [269] = true,     -- Brewmaster
  [62] = true,      -- Arcane
  [1480] = true,    -- Devourer
  [262] = true,     -- Elemental
  [263] = true,     -- Enhancement
  [258] = true,     -- Shadow
}

-- Merge defaults into a table recursively.
function addon.CopyDefaults(dst, src)
  if dst == nil then dst = {} end
  for k, v in pairs(src) do
    if type(v) == "table" then
      if type(dst[k]) ~= "table" then dst[k] = {} end
      addon.CopyDefaults(dst[k], v)
    elseif dst[k] == nil then
      dst[k] = v
    end
  end
  return dst
end

function addon.HasSecondaryPower()
  local class = select(2, UnitClass("player"))
  print(class)
  if CLASSWITHSECONDARY[class] then
    if class == "ROGUE" or class == "EVOKER" or class == "DEATH KNIGHT" or class == "WARLOCK" or class == "PALADIN" then
      return true
    end
    local spec = GetSpecialization()
    local specID = GetSpecializationInfo(spec)
    if SPECWITHSECONDARY[specID] then
      print(spec)
      return true
    elseif class == "DRUID" then
      local form = GetShapeshiftFormID()
      print(form)
      if form == 1 then return true end
    end
  end
  return false
end