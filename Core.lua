local ADDON_NAME, addon = ...
addon = addon or {}
local ADDON_TITLE = "Wangbar"
local ADDON_PREFIX = "|cff00ff88Wangbar|r"
addon.ADDON_TITLE = ADDON_TITLE
local f = CreateFrame("Frame", "SnapComboPointsFrame", UIParent, "BackdropTemplate")
local energyBorder = CreateFrame("Frame", "SnapEnergyBorder", UIParent, "BackdropTemplate")
local energyBar = CreateFrame("StatusBar", "SnapEnergyBar", energyBorder)
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

addon.frames = {
  comboFrame = f,
  energyBorder = energyBorder,
  energyBar = energyBar,
}

local defaults = addon.defaults

local bars = {}
local unlocked = false
local editModeActive = false
local editModeHooked = false
local debugPanelVisible = false
local UpdateComboDisplay
local UpdateEnergyDisplay
local InitLSM
local ApplyFrameStyle
local InitMinimapButton
local ToggleDebugPanel
local CreateEditModePanel
local UpdateEditPanelFields
local ApplyFrameSizeAndPosition

-- Silence chat output.
local function Print()
end

local minimapIcon
local minimapButton
local minimapInitialized = false
local editButton

-- Open the addon options panel.
local function OpenOptionsPanel()
  if addon.OpenOptionsPanel then
    addon.OpenOptionsPanel()
  else
    Print("Options panel unavailable.")
  end
end

-- Create/register the minimap button (LibDBIcon or fallback).
InitMinimapButton = function()
  if minimapInitialized then return end
  if not LibStub then return end
  local LDB = LibStub("LibDataBroker-1.1", true)
  local DBIcon = LibStub("LibDBIcon-1.0", true)
  if not LDB or not DBIcon then
    local function CreateFallbackMinimapButton()
      if minimapButton then return end
      minimapButton = CreateFrame("Button", "WangbarMinimapButton", Minimap)
      minimapButton:SetSize(32, 32)
      minimapButton:SetFrameStrata("MEDIUM")
      minimapButton:SetFrameLevel(8)

      minimapButton:SetNormalTexture("Interface\\Icons\\Ability_Rogue_SliceDice")
      minimapButton:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
      minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
      minimapButton:GetHighlightTexture():SetBlendMode("ADD")

      local normal = minimapButton:GetNormalTexture()
      normal:SetTexCoord(0.07, 0.93, 0.07, 0.93)

      minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
      minimapButton:RegisterForDrag("LeftButton")

      local function UpdatePosition()
        local angle = SnapComboPointsDB.minimap.angle or 225
        local radius = 80
        local rad = math.rad(angle)
        local x = 52 - radius * math.cos(rad)
        local y = radius * math.sin(rad) - 52
        minimapButton:SetPoint("TOPLEFT", Minimap, "TOPLEFT", x, y)
      end

      minimapButton:SetScript("OnDragStart", function()
        minimapButton:SetScript("OnUpdate", function()
          local mx, my = Minimap:GetCenter()
          local cx, cy = GetCursorPosition()
          local scale = Minimap:GetEffectiveScale()
          cx, cy = cx / scale, cy / scale
          local dx, dy = cx - mx, cy - my
          local angle = math.deg(math.atan2(dy, dx))
          SnapComboPointsDB.minimap.angle = angle
          UpdatePosition()
        end)
      end)

      minimapButton:SetScript("OnDragStop", function()
        minimapButton:SetScript("OnUpdate", nil)
      end)

      minimapButton:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
          ToggleDebugPanel()
        else
          OpenOptionsPanel()
        end
      end)

      minimapButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(ADDON_TITLE)
        GameTooltip:AddLine("Left-click: Options", 1, 1, 1)
        GameTooltip:AddLine("Right-click: Edit panel", 1, 1, 1)
        GameTooltip:Show()
      end)

      minimapButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
      end)

      if SnapComboPointsDB.minimap.hide then
        minimapButton:Hide()
      else
        minimapButton:Show()
        UpdatePosition()
      end
      minimapInitialized = true
    end

    CreateFallbackMinimapButton()
    return
  end

  if not minimapIcon then
    minimapIcon = LDB:NewDataObject("Wangbar", {
      type = "launcher",
      text = ADDON_TITLE,
      icon = "Interface\\Icons\\Ability_Rogue_SliceDice",
      OnClick = function(_, button)
        if button == "RightButton" then
          ToggleDebugPanel()
        else
          OpenOptionsPanel()
        end
      end,
      OnTooltipShow = function(tooltip)
        tooltip:AddLine(ADDON_TITLE)
        tooltip:AddLine("Left-click: Options", 1, 1, 1)
        tooltip:AddLine("Right-click: Edit panel", 1, 1, 1)
      end,
    })
  end

  DBIcon:Register("Wangbar", minimapIcon, SnapComboPointsDB.minimap)
  minimapInitialized = true
end

-- Toggle the edit/debug panel and edit mode.
ToggleDebugPanel = function()
  Print("/arrbpanel invoked")
  debugPanelVisible = not debugPanelVisible
  if debugPanelVisible then
    if C_EditMode and C_EditMode.EnterEditMode then
      C_EditMode.EnterEditMode()
    elseif EditModeManagerFrame and EditModeManagerFrame.Show then
      EditModeManagerFrame:Show()
    end
    CreateEditModePanel()
    f:Show()
    f:SetAlpha(1)
    if SnapComboPointsDB.energyEnabled ~= false then
      energyBorder:Show()
      energyBorder:SetAlpha(1)
      energyBar:Show()
    end
    Print("Panel shown (debug).")
  else
    if C_EditMode and C_EditMode.ExitEditMode then
      C_EditMode.ExitEditMode()
    elseif EditModeManagerFrame and EditModeManagerFrame.Hide then
      EditModeManagerFrame:Hide()
    end
    if addon.editPanel then addon.editPanel:Hide() end
    Print("Panel hidden (debug).")
  end
end

local function ShowEditPanel()
  CreateEditModePanel()
  local panel = addon.editPanel
  if panel then
    panel:Show()
    panel:SetAlpha(1)
    if not panel.frame or not panel.frame:IsUserPlaced() then
      panel:ClearAllPoints()
      panel:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
      if panel.frame then
        panel.frame:SetUserPlaced(true)
      end
    end
    UpdateEditPanelFields()
    if panel.DoLayout then
      panel:DoLayout()
    end
    if panel.scroll and panel.scroll.DoLayout then
      panel.scroll:DoLayout()
    end
    if C_Timer and C_Timer.After then
      C_Timer.After(0, UpdateEditPanelFields)
    end
    panel.EnsureTextureList(panel)
    panel.textureTarget = "combo"
    panel.SelectTextureByName(panel, SnapComboPointsDB.textureName)
    if panel.UpdateTextureLabel then
      panel.UpdateTextureLabel(panel)
    end
  end
end

local function EnsureEditButton()
  if editButton then return end
  editButton = CreateFrame("Button", "WangbarEditButton", f, "UIPanelButtonTemplate")
  editButton:SetSize(44, 18)
  editButton:SetText("Edit")
  editButton:SetPoint("LEFT", f, "RIGHT", 6, 0)
  editButton:SetScript("OnClick", function()
    ShowEditPanel()
  end)
  editButton:Hide()
end

local fallbackStatusbars = {
  { name = "Default", path = "Interface\\TARGETINGFRAME\\UI-StatusBar" },
  { name = "Flat", path = "Interface\\Buttons\\WHITE8x8" },
  { name = "Raid-Bar", path = "Interface\\RAIDFRAME\\Raid-Bar-Resource-Fill" },
  { name = "Tooltip", path = "Interface\\Tooltips\\UI-Tooltip-Background" },
}

local fallbackStatusbarMap = {}
for i = 1, #fallbackStatusbars do
  fallbackStatusbarMap[fallbackStatusbars[i].name] = fallbackStatusbars[i].path
end

local fallbackBackgrounds = {
  { name = "Solid", path = "Interface\\Buttons\\WHITE8x8" },
  { name = "Tooltip", path = "Interface\\Tooltips\\UI-Tooltip-Background" },
}

local fallbackBackgroundMap = {}
for i = 1, #fallbackBackgrounds do
  fallbackBackgroundMap[fallbackBackgrounds[i].name] = fallbackBackgrounds[i].path
end

-- Initialize LibSharedMedia if available.
InitLSM = function()
  if not LSM and LibStub then
    LSM = LibStub("LibSharedMedia-3.0", true)
  end
end

-- Return a shallow copy of a list.
local function CopyList(src)
  local dst = {}
  for i = 1, #src do
    dst[i] = src[i]
  end
  return dst
end

-- ---------- Utils ----------
local CopyDefaults = addon.CopyDefaults
local IsRogue = addon.IsRogue
local IsWindwalker = addon.IsWindwalker
local IsFeral = addon.IsFeral

-- Check if the player uses Chi power.
local function UsesChi()
  return (UnitPowerMax("player", Enum.PowerType.Chi) or 0) > 0
end

-- Resolve the combo power type (Combo Points or Chi).
local function GetComboPowerType()
  if UsesChi() or (IsWindwalker and IsWindwalker()) then
    return Enum.PowerType.Chi, "CHI"
  end
  return Enum.PowerType.ComboPoints, "COMBO_POINTS"
end

-- Get the current max combo points (fallback to 7).
local function GetMaxComboPoints()
  local powerType = GetComboPowerType()
  local maxPower = UnitPowerMax("player", powerType) or 0
  if maxPower <= 0 then
    maxPower = 7
  end
  return maxPower
end

-- Determine whether the bars should be visible.
local function ShouldShow()
  if editModeActive then return true end
  if not SnapComboPointsDB.showOnlyWhenRelevant then return true end
  return IsRogue() or UsesChi() or (IsWindwalker and IsWindwalker()) or (IsFeral and IsFeral())
end

UpdateEditPanelFields = function()
  if addon.UpdateEditPanelFields then
    addon.UpdateEditPanelFields()
  end
end

-- Clear all combo point bars.
local function ClearBars()
  for i = 1, #bars do
    bars[i].fill:Hide()
    bars[i].fill:SetParent(nil)
    bars[i].pip:Hide()
    bars[i].pip:SetParent(nil)
    bars[i] = nil
  end
end

-- Rebuild the combo point bars for a given max.
local function LayoutBars(maxPower)
  ClearBars()

  local inset = 1
  local width = SnapComboPointsDB.width - inset * 2
  local height = SnapComboPointsDB.height - inset * 2
  local spacing = SnapComboPointsDB.spacing

  local totalSpacing = spacing * (maxPower - 1)
  local pipWidth = math.floor((width - totalSpacing) / maxPower)

  for i = 1, maxPower do
    -- Outer frame = border + background
    local pip = CreateFrame("Frame", nil, f, "BackdropTemplate")
    pip:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8x8",
      edgeFile = "Interface\\Buttons\\WHITE8x8",
      edgeSize = SnapComboPointsDB.pipBorderSize,
    })
    pip:SetBackdropColor(unpack(SnapComboPointsDB.pipBgColor))
    pip:SetBackdropBorderColor(unpack(SnapComboPointsDB.pipBorderColor))
    pip:SetHeight(height)
    pip:ClearAllPoints()

    if i == 1 then
      pip:SetPoint("TOPLEFT", f, "TOPLEFT", inset, -inset)
      pip:SetWidth(pipWidth)
    elseif i == maxPower then
      pip:SetPoint("TOPLEFT", bars[i-1].pip, "TOPRIGHT", spacing, 0)
      pip:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -inset, inset)
    else
      pip:SetPoint("TOPLEFT", bars[i-1].pip, "TOPRIGHT", spacing, 0)
      pip:SetWidth(pipWidth)
    end

    -- Inner statusbar = fill
    local fill = CreateFrame("StatusBar", nil, pip)
    fill:SetStatusBarTexture(SnapComboPointsDB.texture)
    fill:SetMinMaxValues(0, 1)
    fill:SetValue(0)
    fill:SetAllPoints(pip)

    local shadow = pip:CreateTexture(nil, "BACKGROUND")
    shadow:SetColorTexture(unpack(SnapComboPointsDB.pipShadowColor))
    shadow:SetPoint("TOPLEFT", pip, "TOPLEFT", -SnapComboPointsDB.pipShadowOffset, SnapComboPointsDB.pipShadowOffset)
    shadow:SetPoint("BOTTOMRIGHT", pip, "BOTTOMRIGHT", SnapComboPointsDB.pipShadowOffset, -SnapComboPointsDB.pipShadowOffset)

    local insetFill = SnapComboPointsDB.pipBorderSize or 0
    fill:ClearAllPoints()
    if insetFill > 0 then
      fill:SetPoint("TOPLEFT", pip, "TOPLEFT", insetFill, -insetFill)
      fill:SetPoint("BOTTOMRIGHT", pip, "BOTTOMRIGHT", -insetFill, insetFill)
    else
      fill:SetAllPoints(pip)
    end

    bars[i] = {
      pip = pip,
      fill = fill,
      shadow = shadow,
    }
  end
end


-- Apply colors, borders, and text styles.
ApplyFrameStyle = function()
  local bg = SnapComboPointsDB.bg
  local border = SnapComboPointsDB.border
  local bgAlpha = bg and bg[4] or 0
  local borderAlpha = border and border[4] or 0
  if SnapComboPointsDB.hideContainer then
    f:SetBackdrop(nil)
  elseif bgAlpha > 0 or borderAlpha > 0 then
    f:SetBackdrop({
      bgFile = SnapComboPointsDB.bgTexture or "Interface\\Buttons\\WHITE8x8",
      edgeFile = "Interface\\Buttons\\WHITE8x8",
      edgeSize = 1,
    })
    f:SetBackdropColor(unpack(bg))
    f:SetBackdropBorderColor(unpack(border))
  else
    f:SetBackdrop(nil)
  end

  if not f.countText then
    if not f.countTextFrame then
      f.countTextFrame = CreateFrame("Frame", nil, f)
    end
    f.countTextFrame:SetAllPoints(f)
    f.countTextFrame:SetFrameLevel(f:GetFrameLevel() + 10)
    f.countText = f.countTextFrame:CreateFontString(nil, "OVERLAY")
    f.countText:SetPoint("CENTER", f.countTextFrame, "CENTER", 0, 0)
  end
  f.countText:SetDrawLayer("OVERLAY", 7)
  f.countText:SetAlpha(1)
  f.countText:SetFont(SnapComboPointsDB.countFont, SnapComboPointsDB.countFontSize, SnapComboPointsDB.countFontOutline)
  local tcr, tcg, tcb, tca = unpack(SnapComboPointsDB.countColor or {1, 1, 1, 1})
  f.countText:SetTextColor(tcr, tcg, tcb, tca or 1)
  f.countText:SetShadowColor(unpack(SnapComboPointsDB.countShadowColor))
  f.countText:SetShadowOffset(SnapComboPointsDB.countShadowOffset, -SnapComboPointsDB.countShadowOffset)

  for i = 1, #bars do
    if bars[i] and bars[i].pip then
      bars[i].pip:SetBackdropColor(unpack(SnapComboPointsDB.pipBgColor))
      bars[i].pip:SetBackdropBorderColor(unpack(SnapComboPointsDB.pipBorderColor))
      if bars[i].shadow then
        bars[i].shadow:SetColorTexture(unpack(SnapComboPointsDB.pipShadowColor))
        bars[i].shadow:ClearAllPoints()
        bars[i].shadow:SetPoint("TOPLEFT", bars[i].pip, "TOPLEFT", -SnapComboPointsDB.pipShadowOffset, SnapComboPointsDB.pipShadowOffset)
        bars[i].shadow:SetPoint("BOTTOMRIGHT", bars[i].pip, "BOTTOMRIGHT", SnapComboPointsDB.pipShadowOffset, -SnapComboPointsDB.pipShadowOffset)
      end
    end
  end

  energyBorder:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = SnapComboPointsDB.energyBorderSize or 1,
  })
  energyBorder:SetBackdropColor(unpack(SnapComboPointsDB.energyBg or SnapComboPointsDB.pipBgColor))
  energyBorder:SetBackdropBorderColor(unpack(SnapComboPointsDB.energyBorder))
  energyBar:SetStatusBarTexture(SnapComboPointsDB.energyTexture)
  energyBar:SetFrameLevel(energyBorder:GetFrameLevel() + 1)

  if not energyBar.countText then
    if not energyBar.countTextFrame then
      energyBar.countTextFrame = CreateFrame("Frame", nil, energyBar)
    end
    energyBar.countTextFrame:SetAllPoints(energyBar)
    energyBar.countTextFrame:SetFrameLevel(energyBar:GetFrameLevel() + 10)
    energyBar.countText = energyBar.countTextFrame:CreateFontString(nil, "OVERLAY")
    energyBar.countText:SetPoint("CENTER", energyBar.countTextFrame, "CENTER", 0, 0)
  end
  energyBar.countText:SetDrawLayer("OVERLAY", 7)
  energyBar.countText:SetAlpha(1)
  energyBar.countText:SetFont(SnapComboPointsDB.energyCountFont, SnapComboPointsDB.energyCountFontSize, SnapComboPointsDB.energyCountFontOutline)
  local ecr, ecg, ecb, eca = unpack(SnapComboPointsDB.energyCountColor or {1, 1, 1, 1})
  energyBar.countText:SetTextColor(ecr, ecg, ecb, eca or 1)
  energyBar.countText:SetShadowColor(unpack(SnapComboPointsDB.energyCountShadowColor))
  energyBar.countText:SetShadowOffset(SnapComboPointsDB.energyCountShadowOffset, -SnapComboPointsDB.energyCountShadowOffset)
end

-- Get the list of statusbar textures.
local function GetStatusbarList()
  if LSM and LSM.List then
    local list = LSM:List("statusbar")
    if list and #list > 0 then
      local copy = CopyList(list)
      table.sort(copy)
      return copy
    end
  end
  local list = {}
  for i = 1, #fallbackStatusbars do
    list[i] = fallbackStatusbars[i].name
  end
  return list
end

-- Get the list of background textures.
local function GetBackgroundList()
  if LSM and LSM.List then
    local list = LSM:List("background")
    if list and #list > 0 then
      local copy = CopyList(list)
      table.sort(copy)
      return copy
    end
  end
  local list = {}
  for i = 1, #fallbackBackgrounds do
    list[i] = fallbackBackgrounds[i].name
  end
  return list
end

-- Fetch a background texture path by name.
local function FetchBackground(name)
  if LSM and LSM.Fetch then
    return LSM:Fetch("background", name)
  end
  return fallbackBackgroundMap[name]
end

-- Fetch a statusbar texture path by name.
local function FetchStatusbar(name)
  if LSM and LSM.Fetch then
    return LSM:Fetch("statusbar", name)
  end
  return fallbackStatusbarMap[name]
end

-- Apply the combo bar texture to all pips.
local function ApplyComboTexture(path)
  if not path then return end
  SnapComboPointsDB.texture = path
  for i = 1, #bars do
    if bars[i] and bars[i].fill then
      bars[i].fill:SetStatusBarTexture(path)
    end
  end
end

-- Apply the energy bar texture.
local function ApplyEnergyTexture(path)
  if not path then return end
  SnapComboPointsDB.energyTexture = path
  energyBar:SetStatusBarTexture(path)
end

addon.GetStatusbarList = GetStatusbarList
addon.FetchStatusbar = FetchStatusbar
addon.ApplyComboTexture = ApplyComboTexture
addon.ApplyEnergyTexture = ApplyEnergyTexture

-- Apply frame size/position from saved settings.
ApplyFrameSizeAndPosition = function()
  addon.ApplyFrameSizeAndPosition = ApplyFrameSizeAndPosition
  addon.LayoutBars = LayoutBars
  addon.InitLSM = InitLSM
  addon.GetLSM = function() return LSM end

  addon.GetComboPowerType = GetComboPowerType
  addon.InitMinimapButton = InitMinimapButton
  local width = tonumber(SnapComboPointsDB.width) or defaults.width
  local height = tonumber(SnapComboPointsDB.height) or defaults.height
  local energyHeight = tonumber(SnapComboPointsDB.energyHeight) or defaults.energyHeight
  if width < 1 then width = defaults.width end
  if height < 1 then height = defaults.height end
  if energyHeight < 1 then energyHeight = defaults.energyHeight end
  SnapComboPointsDB.width = width
  SnapComboPointsDB.height = height
  SnapComboPointsDB.energyHeight = energyHeight

  f:SetSize(width, height)
  f:ClearAllPoints()
  f:SetPoint(
    SnapComboPointsDB.point,
    UIParent,
    SnapComboPointsDB.relPoint,
    SnapComboPointsDB.x,
    SnapComboPointsDB.y
  )

  energyBorder:SetSize(width, energyHeight)
  energyBorder:ClearAllPoints()
  local energyGap = tonumber(SnapComboPointsDB.energyGap) or 0
  local energyYOffset = tonumber(SnapComboPointsDB.energyYOffset) or 0
  energyBorder:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 0, -(energyGap + energyYOffset))

  local inset = tonumber(SnapComboPointsDB.energyBorderSize) or 0
  energyBar:ClearAllPoints()
  if inset > 0 then
    energyBar:SetPoint("TOPLEFT", energyBorder, "TOPLEFT", inset, -inset)
    energyBar:SetPoint("BOTTOMRIGHT", energyBorder, "BOTTOMRIGHT", -inset, inset)
  else
    energyBar:SetAllPoints(energyBorder)
  end

  -- Leave edit panel position alone (AceGUI handles its own placement)
end

-- Create the edit mode panel if needed.
CreateEditModePanel = function()
  if addon.CreateEditModePanel then
    addon.CreateEditModePanel()
  end
end

-- Update combo point bar visibility and colors.
UpdateComboDisplay = function()
  if not ShouldShow() then
    f:Hide()
    energyBorder:Hide()
    return
  end

  local comboPowerType = GetComboPowerType()
  local current = UnitPower("player", comboPowerType) or 0
  local maxPower = UnitPowerMax("player", comboPowerType) or 0

  if maxPower <= 0 then
    f:Hide()
    return
  end

  if #bars ~= maxPower then
    LayoutBars(maxPower)
  end

  local charged
  if comboPowerType == Enum.PowerType.ComboPoints then
    charged = GetUnitChargedPowerPoints("player")
  end
  local chargedLookup = {}
  if charged then
    for _, idx in ipairs(charged) do
      chargedLookup[idx] = true
    end
  end

  local cr, cg, cb, ca = unpack(SnapComboPointsDB.color)
  local xr, xg, xb, xa = unpack(SnapComboPointsDB.charged)
  local hr, hg, hb, ha = unpack(SnapComboPointsDB.highComboColor)
  local threshold = SnapComboPointsDB.highComboPointsThreshold or 0
  local useHigh = SnapComboPointsDB.highComboEnabled and current >= threshold
  local perPointEnabled = SnapComboPointsDB.perPointColorsEnabled
  local perPointColors = SnapComboPointsDB.perPointColors

  local er, eg, eb, ea = unpack(SnapComboPointsDB.emptyColor)

  -- Snap updates: no smoothing, just 0/1 and show/hide
  for i = 1, maxPower do
    local b = bars[i]
    if i <= current then
      b.fill:SetValue(1)
      if chargedLookup[i] then
        b.fill:SetStatusBarColor(xr, xg, xb, xa or 1)
      else
        local pr, pg, pb, pa
        if perPointEnabled and perPointColors and perPointColors[i] then
          pr, pg, pb, pa = unpack(perPointColors[i])
        end
        if pr then
          b.fill:SetStatusBarColor(pr, pg, pb, pa or 1)
        elseif useHigh then
          b.fill:SetStatusBarColor(hr, hg, hb, ha or 1)
        else
          b.fill:SetStatusBarColor(cr, cg, cb, ca or 1)
        end
      end
      b.pip:Show()
    else
      if SnapComboPointsDB.hideEmpty then
        b.fill:SetValue(0)
        b.pip:Hide()
      else
        b.fill:SetValue(1)
        b.fill:SetStatusBarColor(er, eg, eb, ea or 1)
        b.pip:Show()
      end
    end
  end

  if f.countText then
    if SnapComboPointsDB.showCount then
      f.countText:SetText(current)
      f.countText:Show()
    else
      f.countText:Hide()
    end
  end

  f:Show()
end

local function FormatShortNumber(value)
  if type(issecretvalue) == "function" and issecretvalue(value) then
    return ""
  end
  value = tonumber(value) or 0
  if value >= 1000000 then
    local v = value / 1000000
    local text = string.format("%.1fm", v)
    text = text:gsub("%.0m", "m")
    return text
  elseif value >= 1000 then
    local v = math.floor((value / 1000) + 0.5)
    return string.format("%dk", v)
  end
  return tostring(value)
end


-- Update energy bar visibility and values.
UpdateEnergyDisplay = function()
  if not ShouldShow() then
    energyBorder:Hide()
    return
  end

  if SnapComboPointsDB.energyEnabled == false then
    energyBorder:Hide()
    energyBar:Hide()
    return
  end

  local maxEnergy = UnitPowerMax("player", Enum.PowerType.Energy) or 0
  if maxEnergy <= 0 then
    energyBar:Hide()
    energyBorder:Hide()
    return
  end

  local energy = UnitPower("player", Enum.PowerType.Energy, true) or 0
  energyBar:SetMinMaxValues(0, maxEnergy)
  energyBar:SetValue(energy)
  local er, eg, eb, ea = unpack(SnapComboPointsDB.energyColor)
  energyBar:SetStatusBarColor(er, eg, eb, ea or 1)
  if energyBar.countText then
    if SnapComboPointsDB.showEnergyCount then
      energyBar.countText:SetText(energy)
      energyBar.countText:Show()
    else
      energyBar.countText:Hide()
    end
  end
  energyBorder:Show()
  energyBar:Show()
end

addon.UpdateComboDisplay = UpdateComboDisplay
addon.UpdateEnergyDisplay = UpdateEnergyDisplay
addon.ApplyFrameStyle = ApplyFrameStyle
addon.ApplyFrameSizeAndPosition = ApplyFrameSizeAndPosition
addon.LayoutBars = LayoutBars
addon.InitLSM = InitLSM
addon.GetLSM = function() return LSM end
addon.GetComboPowerType = GetComboPowerType
addon.GetMaxComboPoints = GetMaxComboPoints
addon.InitMinimapButton = InitMinimapButton

-- ---------- Drag / slash commands ----------
-- Enable/disable drag to move the bar.
local function SetUnlocked(state, suppressPrint)
  unlocked = state
  f:EnableMouse(state)
  f:SetMovable(state)
  f:RegisterForDrag("LeftButton")

  if state then
    f:SetScript("OnMouseUp", function(self, button)
      if button == "RightButton" and not editModeActive then
        ToggleDebugPanel()
      end
    end)
  else
    f:SetScript("OnMouseUp", nil)
  end

  if state then
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self)
      self:StopMovingOrSizing()
      local point, _, relPoint, x, y = self:GetPoint(1)
      SnapComboPointsDB.point = point
      SnapComboPointsDB.relPoint = relPoint
      SnapComboPointsDB.x = math.floor(x + 0.5)
      SnapComboPointsDB.y = math.floor(y + 0.5)
      if addon.editPanel and addon.editPanel:IsShown() then
        UpdateEditPanelFields()
      end
      Print("Saved position.")
    end)
    if not suppressPrint then
      Print("Unlocked. Drag to move. /arrb lock when done.")
    end
  else
    f:SetScript("OnDragStart", nil)
    f:SetScript("OnDragStop", nil)
    if not suppressPrint then
      Print("Locked.")
    end
  end
end

-- Check if edit mode is active.
local function IsEditModeActive()
  if EditModeManagerFrame and EditModeManagerFrame:IsShown() then
    return true
  end
  if C_EditMode and C_EditMode.IsEditModeActive then
    local ok, active = pcall(C_EditMode.IsEditModeActive)
    if ok and active then return true end
  end
  return false
end

-- Sync addon state with edit mode state.
local function SyncEditMode()
  local active = IsEditModeActive()
  if active == editModeActive then return end
  editModeActive = active
  SetUnlocked(active, true)
  if active then
    CreateEditModePanel()
    UpdateEditPanelFields()
    local panel = addon.editPanel
    if panel then
      panel.EnsureTextureList(panel)
      panel.textureTarget = "combo"
      panel.SelectTextureByName(panel, SnapComboPointsDB.textureName)
      if panel.UpdateTextureLabel then
        panel.UpdateTextureLabel(panel)
      end
      ApplyFrameSizeAndPosition()
      f:Show()
    end
    EnsureEditButton()
    editButton:Show()
  else
    debugPanelVisible = false
    if addon.editPanel then
      addon.editPanel:Hide()
    end
    if editButton then
      editButton:Hide()
    end
  end
  UpdateComboDisplay()
  UpdateEnergyDisplay()
end

-- Hook edit mode show/hide events.
local function HookEditModeManager()
  if editModeHooked then return end
  if not EditModeManagerFrame then return end
  EditModeManagerFrame:HookScript("OnShow", SyncEditMode)
  EditModeManagerFrame:HookScript("OnHide", SyncEditMode)
  editModeHooked = true
end

SLASH_AWANGSROGUERESOURCEBAR1 = "/arrb"
SLASH_AWANGSROGUERESOURCEBAR2 = "/cp"
SLASH_AWANGSROGUERESOURCEBAR3 = "/wb"
SLASH_AWANGSROGUERESOURCEBARPANEL1 = "/arrbpanel"
SLASH_AWANGSROGUERESOURCEBARPANEL2 = "/cppanel"

-- Handle slash command input.
local function HandleSlash(msg)
  msg = (msg or ""):lower()
  local cmd, a, b = msg:match("^(%S+)%s*(%S*)%s*(%S*)$")

  if cmd == "" then
    OpenOptionsPanel()
    return
  end

  if cmd == "unlock" then
    SetUnlocked(true)
  elseif cmd == "lock" then
    SetUnlocked(false)
  elseif cmd == "width" and a ~= "" then
    SnapComboPointsDB.width = tonumber(a) or SnapComboPointsDB.width
    ApplyFrameSizeAndPosition()
    local comboPowerType = GetComboPowerType()
    LayoutBars(UnitPowerMax("player", comboPowerType) or 0)
    UpdateComboDisplay()
    UpdateEnergyDisplay()
  elseif cmd == "height" and a ~= "" then
    SnapComboPointsDB.height = tonumber(a) or SnapComboPointsDB.height
    ApplyFrameSizeAndPosition()
    local comboPowerType = GetComboPowerType()
    LayoutBars(UnitPowerMax("player", comboPowerType) or 0)
    UpdateComboDisplay()
    UpdateEnergyDisplay()
  elseif cmd == "energyheight" and a ~= "" then
    SnapComboPointsDB.energyHeight = tonumber(a) or SnapComboPointsDB.energyHeight
    ApplyFrameSizeAndPosition()
    UpdateEnergyDisplay()
  elseif cmd == "energygap" and a ~= "" then
    SnapComboPointsDB.energyGap = tonumber(a) or SnapComboPointsDB.energyGap
    ApplyFrameSizeAndPosition()
    UpdateEnergyDisplay()
  elseif cmd == "texture" and a ~= "" then
    local tex = a
    SnapComboPointsDB.textureName = nil
    SnapComboPointsDB.texture = tex
    for i = 1, #bars do
      if bars[i] and bars[i].fill then
        bars[i].fill:SetStatusBarTexture(tex)
      end
    end
    UpdateComboDisplay()
  elseif cmd == "energytexture" and a ~= "" then
    local tex = a
    SnapComboPointsDB.energyTextureName = nil
    SnapComboPointsDB.energyTexture = tex
    energyBar:SetStatusBarTexture(tex)
    UpdateEnergyDisplay()
  elseif cmd == "x" and a ~= "" then
    SnapComboPointsDB.x = tonumber(a) or SnapComboPointsDB.x
    ApplyFrameSizeAndPosition()
  elseif cmd == "y" and a ~= "" then
    SnapComboPointsDB.y = tonumber(a) or SnapComboPointsDB.y
    ApplyFrameSizeAndPosition()
  elseif (cmd == "pos" or cmd == "setpos") and a ~= "" and b ~= "" then
    SnapComboPointsDB.x = tonumber(a) or SnapComboPointsDB.x
    SnapComboPointsDB.y = tonumber(b) or SnapComboPointsDB.y
    ApplyFrameSizeAndPosition()
  elseif cmd == "toggle" then
    SnapComboPointsDB.showOnlyWhenRelevant = not SnapComboPointsDB.showOnlyWhenRelevant
    UpdateComboDisplay()
    UpdateEnergyDisplay()
    Print("showOnlyWhenRelevant =", SnapComboPointsDB.showOnlyWhenRelevant)
  elseif cmd == "panel" then
    ToggleDebugPanel()
  end
end

SlashCmdList.AWANGSROGUERESOURCEBAR = HandleSlash

SlashCmdList.AWANGSROGUERESOURCEBARPANEL = ToggleDebugPanel

SLASH_WANGBAR1 = "/wb"
SlashCmdList.WANGBAR = function()
  OpenOptionsPanel()
end

-- ---------- Events ----------
f:SetScript("OnEvent", function(self, event, ...)
  if event == "ADDON_LOADED" then
    local name = ...
    if name == ADDON_NAME then
      if type(AwangsRogueResourceBarDB) ~= "table" and type(SnapComboPointsDB) == "table" then
        AwangsRogueResourceBarDB = SnapComboPointsDB
      end

      SnapComboPointsDB = CopyDefaults(AwangsRogueResourceBarDB, defaults)
      AwangsRogueResourceBarDB = SnapComboPointsDB

      InitLSM()

      ApplyFrameStyle()
      ApplyFrameSizeAndPosition()
      SetUnlocked(false)

      -- Register events after init
      self:RegisterEvent("PLAYER_ENTERING_WORLD")
      self:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
      self:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
      self:RegisterUnitEvent("UNIT_MAXPOWER", "player")
      self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
      self:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
      if C_EditMode and C_EditMode.IsEditModeActive then
        self:RegisterEvent("EDIT_MODE_ENTER")
        self:RegisterEvent("EDIT_MODE_EXIT")
      end

      HookEditModeManager()
      SyncEditMode()
      UpdateComboDisplay()
      UpdateEnergyDisplay()
      return
    end

    -- Another addon loaded; LSM might be available now
    InitLSM()
    if addon.editPanel and addon.editPanel.EnsureTextureList then
      addon.editPanel.EnsureTextureList(addon.editPanel)
      addon.editPanel.SelectTextureByName(addon.editPanel, SnapComboPointsDB.textureName)
    end
    return
  end

  if event == "PLAYER_ENTERING_WORLD" then
    if not minimapInitialized then
      C_Timer.After(0, InitMinimapButton)
    end
    HookEditModeManager()
    SyncEditMode()
  elseif event == "EDIT_MODE_LAYOUTS_UPDATED" or event == "EDIT_MODE_ENTER" or event == "EDIT_MODE_EXIT" then
    SyncEditMode()
  end

  if event == "UNIT_POWER_UPDATE" or event == "UNIT_POWER_FREQUENT" then
    local unit, powerType = ...
    if unit ~= "player" then return end
    -- Only redraw for combo points for performance + snappiness
    local _, comboPowerToken = GetComboPowerType()
    if powerType == comboPowerToken then
      UpdateComboDisplay()
    elseif powerType == "ENERGY" then
      UpdateEnergyDisplay()
    end
    return
  end

  -- Anything else that could change max/visibility/layout
  UpdateComboDisplay()
  UpdateEnergyDisplay()
end)

f:RegisterEvent("ADDON_LOADED")
