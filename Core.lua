local ADDON_NAME, addon = ...
addon = addon or {}
local ADDON_TITLE = "Wangbar"
local ADDON_PREFIX = "|cff00ff88Wangbar|r"
addon.ADDON_TITLE = ADDON_TITLE
local f = CreateFrame("Frame", "SnapComboPointsFrame", UIParent, "BackdropTemplate")
local energyBorder = CreateFrame("Frame", "SnapEnergyBorder", UIParent, "BackdropTemplate")
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
local energyBar = CreateFrame(LSM.MediaType.STATUSBAR, "SnapEnergyBar", energyBorder)

addon.frames = {
  comboFrame = f,
  energyBorder = energyBorder,
  energyBar = energyBar,
}

local defaults = addon.defaults

local bars = {}
local lastAppliedWidth = nil
local unlocked = false
local editModeActive = false
local editModeHooked = false
local debugPanelVisible = false
local InCombatLockdown = _G.InCombatLockdown
local UpdateComboDisplay
local UpdateEnergyDisplay
local InitLSM
local ApplyFrameStyle
local InitMinimapButton
local ToggleDebugPanel
local CreateEditModePanel
local UpdateEditPanelFields
local ApplyFrameSizeAndPosition

-- Autosize watcher for external cooldown manager (e.g. EssentialCooldownViewer)
local autosizeWatcher = nil
local autosizeAccum = 0
local anchorFollower = nil
local anchorAccum = 0
local cdmSizeTarget = nil

local function DetachCDMSizeListener()
  if not cdmSizeTarget then return end
  if type(cdmSizeTarget.SetScript) == "function" then
    pcall(function() cdmSizeTarget:SetScript("OnSizeChanged", nil) end)
  end
  cdmSizeTarget = nil
end

local function AttachCDMSizeListener()
  local fr = GetCDMFrame()
  if not fr then return end
  if fr == cdmSizeTarget then return end
  -- detach previous
  DetachCDMSizeListener()
  -- try to attach OnSizeChanged handler to react immediately to size changes
  if type(fr.SetScript) == "function" then
    local ok, err = pcall(function()
      fr:SetScript("OnSizeChanged", function()
        local w = GetCDMWidth()
        if w and w > 0 then
          ApplyWidthFromCDM(w)
        end
      end)
    end)
    if ok then
      cdmSizeTarget = fr
    end
  end
end

local function GetCDMWidth()
  if type(SnapComboPointsDB) ~= "table" then return nil end
  local function findFirstExisting(names)
    for i = 1, #names do
      local n = names[i]
      if n and type(n) == "string" and n ~= "" then
        local obj = _G and _G[n]
        if obj and obj.GetWidth and type(obj.GetWidth) == "function" then
          return n, obj
        end
      end
    end
    return nil, nil
  end

  local function isUIParent(o)
    return o == UIParent
  end

  -- Candidate names: user-provided, standard, then ArcUI variations
  local userName = SnapComboPointsDB.autoSizeCDMName
  local standard = "EssentialCooldownViewer"
  local arcCandidates = {
    "ArcUI_CooldownManager",
    "Arc_CooldownManager",
    "ArcCooldowns",
    "ArcUI_EssentialCooldownViewer",
    "ArcUI_EssentialContainer",
    "ArcCDM",
    "ArcCooldownFrame",
    "ArcUICooldownFrame",
  }

  -- If user explicitly asked to use ArcUI, check those first
  if SnapComboPointsDB.autoSizeUseArcUI then
    local name, obj = findFirstExisting(arcCandidates)
    if name and obj then
      if isUIParent(obj) then
        return nil
      end
      local ok, w = pcall(obj.GetWidth, obj)
      if ok and type(w) == "number" and w > 0 then
        -- cache discovered name
        SnapComboPointsDB.autoSizeCDMName = name
        return w
      end
    end
    -- fallback to configured or standard
  end

  -- If auto-detect is enabled, search all candidates (user + standard + arc list)
  if SnapComboPointsDB.autoDetectCDM then
    local candidates = {}
    if userName and userName ~= "" then table.insert(candidates, userName) end
    table.insert(candidates, standard)
    for i = 1, #arcCandidates do table.insert(candidates, arcCandidates[i]) end
    local name, obj = findFirstExisting(candidates)
    if name and obj then
      -- If the detected object looks like a single icon, try to prefer a container/parent
      local function findContainerCandidate(o)
        if not o then return o end
        -- prefer frames with multiple children (safe calls)
        if type(o.GetNumChildren) == "function" then
          local ok, n = pcall(o.GetNumChildren, o)
          if ok and type(n) == "number" and n > 1 then
            return o
          end
        end
        -- climb up a few levels looking for a parent container
        local current = o
        for i = 1, 4 do
          if type(current.GetParent) == "function" then
            current = current:GetParent()
            if not current then break end
            if type(current.GetNumChildren) == "function" then
              local okc, nc = pcall(current.GetNumChildren, current)
              if okc and type(nc) == "number" and nc > 1 then
                return current
              end
            end
            -- also prefer a parent with a larger width
            if type(current.GetWidth) == "function" and type(o.GetWidth) == "function" then
              local okc, wc = pcall(current.GetWidth, current)
              local oko, wo = pcall(o.GetWidth, o)
              if okc and oko and type(wc) == "number" and type(wo) == "number" and wc > wo then
                return current
              end
            end
          else
            break
          end
        end
        return o
      end

      local candidate = findContainerCandidate(obj) or obj
      if isUIParent(candidate) then
        return nil
      end
      -- cache the discovered (or container) name when possible
      if candidate and candidate.GetName and candidate:GetName() then
        SnapComboPointsDB.autoSizeCDMName = candidate:GetName()
      else
        SnapComboPointsDB.autoSizeCDMName = name
      end
      local ok, w = pcall(function() return candidate:GetWidth() end)
      if ok and type(w) == "number" and w > 0 then
        return w
      end
    end
  else
    -- auto-detect disabled: use user-configured name then standard
    local candidates = { userName, standard }
    local name, obj = findFirstExisting(candidates)
    if name and obj then
      if isUIParent(obj) then
        return nil
      end
      local ok, w = pcall(function() return obj:GetWidth() end)
      if ok and type(w) == "number" and w > 0 then
        return w
      end
    end
  end

  return nil
end

-- Return the frame object for the cooldown manager (or nil)
local function GetCDMFrame()
  if type(SnapComboPointsDB) ~= "table" then return nil end
  -- Prefer cached name when available
  local name = SnapComboPointsDB.autoSizeCDMName
  if name and name ~= "" then
    local fobj = _G and _G[name]
    if fobj and type(fobj.GetWidth) == "function" then
      return fobj
    end
  end
  -- Fallback to detection via GetCDMWidth logic: reuse candidate search
  -- Candidate lists from GetCDMWidth
  local candidates = {}
  if SnapComboPointsDB.autoDetectCDM then
    if SnapComboPointsDB.autoSizeCDMName and SnapComboPointsDB.autoSizeCDMName ~= "" then table.insert(candidates, SnapComboPointsDB.autoSizeCDMName) end
    table.insert(candidates, "EssentialCooldownViewer")
    local arcCandidates = { "ArcUI_CooldownManager", "Arc_CooldownManager", "ArcCooldowns", "ArcUI_EssentialCooldownViewer", "ArcUI_EssentialContainer", "ArcCDM", "ArcCooldownFrame", "ArcUICooldownFrame" }
    for i = 1, #arcCandidates do table.insert(candidates, arcCandidates[i]) end
  else
    table.insert(candidates, SnapComboPointsDB.autoSizeCDMName)
    table.insert(candidates, "EssentialCooldownViewer")
  end
  for i = 1, #candidates do
    local n = candidates[i]
    if n and type(n) == "string" and n ~= "" then
      local obj = _G and _G[n]
      if obj and type(obj.GetWidth) == "function" then
        -- try to prefer container parents
        local function preferContainer(o)
          if not o then return o end
          if type(o.GetNumChildren) == "function" then
            local ok, nc = pcall(o.GetNumChildren, o)
            if ok and type(nc) == "number" and nc > 1 then return o end
          end
          if type(o.GetParent) == "function" then
            local cur = o:GetParent()
            if cur and type(cur.GetNumChildren) == "function" then
              local ok2, nc2 = pcall(cur.GetNumChildren, cur)
              if ok2 and type(nc2) == "number" and nc2 > 1 then return cur end
            end
          end
          return o
        end
        local chosen = preferContainer(obj)
        if chosen then
          if chosen.GetName and chosen:GetName() then
            SnapComboPointsDB.autoSizeCDMName = chosen:GetName()
          end
          return chosen
        end
      end
    end
  end
  return nil
end

local function AnchorToCDM()
  if not SnapComboPointsDB or not SnapComboPointsDB.anchorToCDM then return false end
  local cdm = GetCDMFrame()
  if not cdm then return false end

  -- Try to read absolute coordinates (left/right/top) from the CDM safely.
  local left, right, top
  local ok1, l = pcall(function() return cdm:GetLeft() end)
  local ok2, r = pcall(function() return cdm:GetRight() end)
  local ok3, t = pcall(function() return cdm:GetTop() end)
  if ok1 and type(l) == "number" then left = l end
  if ok2 and type(r) == "number" then right = r end
  if ok3 and type(t) == "number" then top = t end

  if not left or not right or not top then
    -- Fallback: anchor directly to the CDM (best-effort, may fail on some layouts)
    f:ClearAllPoints()
    local userX = tonumber(SnapComboPointsDB.x) or 0
    local userY = tonumber(SnapComboPointsDB.y) or 0
    f:SetPoint("TOPLEFT", cdm, "TOPLEFT", userX, userY)
    local energyGap = tonumber(SnapComboPointsDB.energyGap) or 0
    local energyYOffset = tonumber(SnapComboPointsDB.energyYOffset) or 0
    energyBorder:ClearAllPoints()
    energyBorder:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 0, -(energyGap + energyYOffset))
    f:EnableMouse(false)
    f:SetMovable(false)
    return true
  end

  local energyYOffset = tonumber(SnapComboPointsDB.energyYOffset) or 0
  local energyHeight = tonumber(SnapComboPointsDB.energyHeight) or (defaults and defaults.energyHeight) or 8

  -- Compute bottom Y coordinate for the energy border so its bottom aligns to CDM's top + offset
  local energyGap = tonumber(SnapComboPointsDB.energyGap) or 0
  local bottomY = top + energyYOffset
  local topY = bottomY + energyHeight

  -- Place the combo frame directly above where the energy border should be
  local userX = tonumber(SnapComboPointsDB.x) or 0
  local userY = tonumber(SnapComboPointsDB.y) or 0
  f:ClearAllPoints()
  f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left + userX, topY + userY)

  -- Anchor energyBorder to `f` so `energyGap` and `energyYOffset` behave as before
  energyBorder:ClearAllPoints()
  energyBorder:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 0, -(energyGap + energyYOffset))

  f:EnableMouse(false)
  f:SetMovable(false)
  return true
end

local function ApplyWidthFromCDM(width)
  if not width then return end
  width = math.floor(width + 0.5)
  -- Guard: avoid adopting a width larger than the UIParent (full-screen)
  local okScreen, screenW = pcall(function() return UIParent and UIParent:GetWidth() end)
  if okScreen and type(screenW) == "number" and screenW > 0 then
    local margin = 50
    if width >= screenW - margin then
      -- Ignore widths that are essentially full-screen (likely from UIParent)
      return
    end
  end
  if width < 1 then return end
  if lastAppliedWidth == width then return end
  SnapComboPointsDB.width = width
  f:SetWidth(width)
  energyBorder:SetWidth(width)
  lastAppliedWidth = width
  local comboPowerType = nil
  if addon.GetComboPowerType then
    comboPowerType = addon.GetComboPowerType()
  elseif GetComboPowerType then
    comboPowerType = GetComboPowerType()
  end
  local maxPower = 0
  if comboPowerType then
    maxPower = UnitPowerMax("player", comboPowerType) or 0
  end
  if maxPower > 0 then
    if addon.LayoutBars then
      addon.LayoutBars(maxPower)
    elseif LayoutBars then
      LayoutBars(maxPower)
    end
  end
end

local function StartAutoSizeWatcher()
  if autosizeWatcher then return end
  autosizeWatcher = CreateFrame("Frame")
  autosizeAccum = 0
  autosizeWatcher:SetScript("OnUpdate", function(self, elapsed)
    autosizeAccum = autosizeAccum + (elapsed or 0)
    local interval = tonumber(SnapComboPointsDB.autoSizeInterval) or 0.25
    if autosizeAccum < interval then return end
    autosizeAccum = 0
    local w = GetCDMWidth()
    if w then
      ApplyWidthFromCDM(w)
    end
  end)
  -- also try to attach a size-change listener for immediate updates
  pcall(AttachCDMSizeListener)
end

local function StopAutoSizeWatcher()
  if not autosizeWatcher then return end
  autosizeWatcher:SetScript("OnUpdate", nil)
  autosizeWatcher:Hide()
  autosizeWatcher = nil
  autosizeAccum = 0
  DetachCDMSizeListener()
end

local function StartAnchorFollower()
  if anchorFollower then return end
  anchorFollower = CreateFrame("Frame")
  anchorAccum = 0
  anchorFollower:SetScript("OnUpdate", function(self, elapsed)
    anchorAccum = anchorAccum + (elapsed or 0)
    local interval = tonumber(SnapComboPointsDB.autoSizeInterval) or 0.25
    if anchorAccum < interval then return end
    anchorAccum = 0
    if SnapComboPointsDB and SnapComboPointsDB.anchorToCDM then
      AnchorToCDM()
    end
  end)
end

local function StopAnchorFollower()
  if not anchorFollower then return end
  anchorFollower:SetScript("OnUpdate", nil)
  anchorFollower:Hide()
  anchorFollower = nil
  anchorAccum = 0
end

-- Public helper to force one-time width sync from detected CDM
addon.ForceApplyCDMWidth = function()
  if type(GetCDMWidth) ~= "function" or type(ApplyWidthFromCDM) ~= "function" then return end
  local w = GetCDMWidth()
  if w and w > 0 then
    ApplyWidthFromCDM(w)
  end
end

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

-- Export functions so other modules (options) can open the edit panel.
addon.ShowEditPanel = ShowEditPanel
addon.ToggleDebugPanel = ToggleDebugPanel

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
local IsEnhancement = addon.IsEnhancement

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
  if SnapComboPointsDB.hideWhileMounted then if IsMounted() then return false end end
  if SnapComboPointsDB.hideOutOfCombat and InCombatLockdown and not InCombatLockdown() then return false end
  if not SnapComboPointsDB.showOnlyWhenRelevant then return true end
  return IsRogue() or UsesChi() or (IsWindwalker and IsWindwalker()) or (IsFeral and IsFeral()) or (IsEnhancement and IsEnhancement())
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
    local pip = CreateFrame(LSM.MediaType.STATUSBAR, nil, f, "BackdropTemplate")
    local pipBackdrop = { bgFile = "Interface\\Buttons\\WHITE8x8" }
    local pipEdgeSize = tonumber(SnapComboPointsDB.pipBorderSize) or 0
    if pipEdgeSize > 0 then
      pipBackdrop.edgeFile = "Interface\\Buttons\\WHITE8x8"
      pipBackdrop.edgeSize = pipEdgeSize
    end
    pip:SetBackdrop(pipBackdrop)
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
    local fill = CreateFrame(LSM.MediaType.STATUSBAR, nil, pip)
    fill:SetStatusBarTexture(SnapComboPointsDB.texture)
    fill:SetMinMaxValues(0, 1)
    fill:SetValue(0, SnapComboPointsDB.smoothProgress and Enum.StatusBarInterpolation.ExponentialEaseOut or nil)
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

  local energyBackdrop = { bgFile = "Interface\\Buttons\\WHITE8x8" }
  local energyEdgeSize = tonumber(SnapComboPointsDB.energyBorderSize) or 0
  if energyEdgeSize > 0 then
    energyBackdrop.edgeFile = "Interface\\Buttons\\WHITE8x8"
    energyBackdrop.edgeSize = energyEdgeSize
  end
  energyBorder:SetBackdrop(energyBackdrop)
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
  -- If anchoring is enabled and we haven't initialized it for this profile yet,
  -- clear saved x/y so the bar appears on the CDM after reload. Do this only once.
  if SnapComboPointsDB.anchorToCDM and not SnapComboPointsDB._anchorInitialized then
    SnapComboPointsDB.x = 0
    SnapComboPointsDB.y = 0
    SnapComboPointsDB._anchorInitialized = true
  end
  local energyHeight = tonumber(SnapComboPointsDB.energyHeight) or defaults.energyHeight
  if width < 1 then width = defaults.width end
  if height < 1 then height = defaults.height end
  if energyHeight < 1 then energyHeight = defaults.energyHeight end
  SnapComboPointsDB.width = width
  SnapComboPointsDB.height = height
  SnapComboPointsDB.energyHeight = energyHeight

  f:SetSize(width, height)
  f:ClearAllPoints()
  -- If anchoring to CDM is enabled, AnchorToCDM will set points; otherwise use saved position
  if not SnapComboPointsDB.anchorToCDM then
    f:SetPoint(
      SnapComboPointsDB.point,
      UIParent,
      SnapComboPointsDB.relPoint,
      SnapComboPointsDB.x,
      SnapComboPointsDB.y
    )
  else
    -- try anchoring; if it fails, fall back to saved position
    local ok = AnchorToCDM()
    if not ok then
      f:SetPoint(
        SnapComboPointsDB.point,
        UIParent,
        SnapComboPointsDB.relPoint,
        SnapComboPointsDB.x,
        SnapComboPointsDB.y
      )
    end
  end

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
  -- If the saved width changed, force a relayout of combo pips so they match the new size.
  -- Start/stop autosize watcher if configured
  if SnapComboPointsDB.autoSizeToCDM then
    StartAutoSizeWatcher()
    local w = GetCDMWidth()
    if w then
      ApplyWidthFromCDM(w)
    end
  else
    StopAutoSizeWatcher()
  end
  -- Start/stop anchor follower if configured
  if SnapComboPointsDB.anchorToCDM then
    StartAnchorFollower()
  else
    StopAnchorFollower()
  end
  local comboPowerType = GetComboPowerType()
  local maxPower = UnitPowerMax("player", comboPowerType) or 0
  if lastAppliedWidth ~= width and maxPower > 0 then
    lastAppliedWidth = width
    LayoutBars(maxPower)
  end
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
  local current = UnitPower("player", comboPowerType)
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

  for i = 1, maxPower do
    local b = bars[i]
    if chargedLookup[i] then
      b.fill:SetValue(1, SnapComboPointsDB.smoothProgress and Enum.StatusBarInterpolation.ExponentialEaseOut or nil)
      if i <= current then
        b.fill:SetStatusBarColor(xr, xg, xb, xa or 1)
      else
        b.fill:SetStatusBarColor(xr * 0.5, xg * 0.5, xb * 0.5, xa or 1)
      end
    else
      local pr, pg, pb, pa
      if perPointEnabled and perPointColors and perPointColors[i] then
        pr, pg, pb, pa = unpack(perPointColors[i])
      end
      if i <= current then
        if pr then
          b.fill:SetValue(1, SnapComboPointsDB.smoothProgress and Enum.StatusBarInterpolation.ExponentialEaseOut or nil)
          b.fill:SetStatusBarColor(pr, pg, pb, pa or 1)
        elseif useHigh then
          b.fill:SetValue(1, SnapComboPointsDB.smoothProgress and Enum.StatusBarInterpolation.ExponentialEaseOut or nil)
          b.fill:SetStatusBarColor(hr, hg, hb, ha or 1)
        else
          b.fill:SetValue(1, SnapComboPointsDB.smoothProgress and Enum.StatusBarInterpolation.ExponentialEaseOut or nil)
          b.fill:SetStatusBarColor(cr, cg, cb, ca or 1)
        end
      else
        b.fill:SetValue(0, SnapComboPointsDB.smoothProgress and Enum.StatusBarInterpolation.ExponentialEaseOut or nil)  
        b.fill:SetStatusBarColor(cr*0.5, cg*0.5, cb*0.5, ca or 1)
      end
    end
    if SnapComboPointsDB.hideEmpty then
      b.pip:Hide()
    else
      b.pip:Show()
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

  local powerType = Enum.PowerType.Energy
  if IsEnhancement and IsEnhancement() and Enum.PowerType and Enum.PowerType.Maelstrom then
    powerType = Enum.PowerType.Maelstrom
  end

  local maxEnergy = UnitPowerMax("player", powerType) or 0
  if maxEnergy <= 0 then
    energyBar:Hide()
    energyBorder:Hide()
    return
  end

  local energy = UnitPower("player", powerType, true) or 0
  energyBar:SetMinMaxValues(0, maxEnergy, SnapComboPointsDB.smoothProgress and Enum.StatusBarInterpolation.ExponentialEaseOut or nil)
  energyBar:SetValue(energy, SnapComboPointsDB.smoothProgress and Enum.StatusBarInterpolation.ExponentialEaseOut or nil)
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

-- Register only the minimal slash command interface.
-- Remove all other console commands; only `/wang`, `/wangbar`, and `/wb` open the options.
SLASH_WANG1 = "/wang"
SLASH_WANG2 = "/wangbar"
SLASH_WANG3 = "/wb"
SlashCmdList.WANG = function()
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
      self:RegisterEvent("PLAYER_REGEN_ENABLED")
      self:RegisterEvent("PLAYER_REGEN_DISABLED")
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
