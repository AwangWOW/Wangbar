local _, addon = ...

local AceGUI = LibStub("AceGUI-3.0", true)
if not AceGUI then
  return
end

local editPanel

local function UpdateEditPanelFields()
  if not editPanel or not editPanel.controls then return end
  editPanel.updating = true
  for _, ctrl in pairs(editPanel.controls) do
    local value = ctrl.get()
    ctrl.slider:SetValue(value)
    ctrl.edit:SetText(tostring(value))
  end
  editPanel.updating = false
end

local function CreateEditModePanel()
  if editPanel then return end

  local frame = AceGUI:Create("Frame")
  frame:SetTitle("Resource Bar Position")
  frame:SetStatusText("Wangbar")
  frame:SetLayout("Fill")
  frame:SetWidth(360)
  frame:SetHeight(220)
  frame.frame:SetFrameStrata("DIALOG")
  frame.frame:SetFrameLevel(100)
  frame.frame:SetClampedToScreen(true)
  frame.frame:Hide()
  frame:SetCallback("OnClose", function(widget)
    widget.frame:Hide()
  end)

  editPanel = frame
  editPanel.controls = {}

  local scroll = AceGUI:Create("ScrollFrame")
  scroll:SetLayout("List")
  scroll:SetFullWidth(true)
  scroll:SetFullHeight(true)
  frame:AddChild(scroll)
  editPanel.scroll = scroll

  local btnGroup = AceGUI:Create("SimpleGroup")
  btnGroup:SetLayout("Flow")
  btnGroup:SetFullWidth(true)

  local optionsBtn = AceGUI:Create("Button")
  optionsBtn:SetText("More Options")
  optionsBtn:SetWidth(120)
  optionsBtn:SetCallback("OnClick", function()
    if addon.OpenOptionsPanel then
      addon.OpenOptionsPanel()
    end
  end)

  btnGroup:AddChild(optionsBtn)
  
  local matchCdmBtn = AceGUI:Create("Button")
  matchCdmBtn:SetText("Match CDM Width")
  matchCdmBtn:SetWidth(140)
  matchCdmBtn:SetCallback("OnClick", function()
    if addon.ForceApplyCDMWidth then
      addon.ForceApplyCDMWidth()
      if addon.ApplyFrameStyle then addon.ApplyFrameStyle() end
      if addon.UpdateComboDisplay then addon.UpdateComboDisplay() end
      if addon.UpdateEnergyDisplay then addon.UpdateEnergyDisplay() end
    end
  end)
  btnGroup:AddChild(matchCdmBtn)
  scroll:AddChild(btnGroup)

  local function Clamp(value, minValue, maxValue, step)
    value = tonumber(value) or 0
    if step and step > 0 then
      value = math.floor(value / step + 0.5) * step
    end
    if minValue ~= nil then value = math.max(minValue, value) end
    if maxValue ~= nil then value = math.min(maxValue, value) end
    return value
  end

  local function ApplyLayoutChange(rebuild)
    addon.ApplyFrameSizeAndPosition()
    if rebuild then
      local comboPowerType = addon.GetSecondaryType()
      addon.LayoutBars(UnitPowerMax("player", comboPowerType) or 0)
    end
    addon.ApplyFrameStyle()
    addon.UpdateComboDisplay()
    addon.UpdateEnergyDisplay()
  end

  local function MakeNumberRow(parent, label, minValue, maxValue, step, getValue, setValue, rebuild, arrowRotation)
    local row = AceGUI:Create("SimpleGroup")
    row:SetLayout("Flow")
    row:SetFullWidth(true)

    local slider = AceGUI:Create("Slider")
    slider:SetLabel(label)
    slider:SetSliderValues(minValue, maxValue, step)
    slider:SetWidth(180)

    if slider.editbox then
      slider.editbox:Hide()
      slider.editbox:SetScript("OnKeyDown", nil)
      slider.editbox:SetScript("OnEnterPressed", nil)
    end

    local edit = AceGUI:Create("EditBox")
    edit:SetLabel(" ")
    edit:SetWidth(50)

    local minusBtn = AceGUI:Create("Button")
    minusBtn:SetText("")
    minusBtn:SetWidth(20)

    local plusBtn = AceGUI:Create("Button")
    plusBtn:SetText("")
    plusBtn:SetWidth(20)

    local function StyleArrow(button, rotation)
      if not button or not button.frame then return end
      local frame = button.frame
      frame:SetNormalTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up")
      frame:SetPushedTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Down")
      frame:SetHighlightTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Highlight")
      local normal = frame:GetNormalTexture()
      local pushed = frame:GetPushedTexture()
      local highlight = frame:GetHighlightTexture()
      if normal then normal:SetRotation(rotation) end
      if pushed then pushed:SetRotation(rotation) end
      if highlight then highlight:SetRotation(rotation) end
    end

    local leftRot = arrowRotation or math.rad(90)
    local rightRot = (arrowRotation == math.rad(0) and math.rad(180)) or math.rad(270)
    StyleArrow(minusBtn, leftRot)
    StyleArrow(plusBtn, rightRot)

    if minusBtn.frame then
      minusBtn.frame:SetScript("OnClick", function() minusBtn:Fire("OnClick") end)
    end
    if plusBtn.frame then
      plusBtn.frame:SetScript("OnClick", function() plusBtn:Fire("OnClick") end)
    end

    local ctrl = { slider = slider, edit = edit, get = getValue, set = setValue, step = step or 1, min = minValue, max = maxValue, rebuild = rebuild }
    editPanel.controls[label] = ctrl

    local function SyncEdit(value)
      if editPanel.updating then return end
      editPanel.updating = true
      edit:SetText(tostring(value))
      editPanel.updating = false
    end

    local function SyncSlider(value)
      if editPanel.updating then return end
      editPanel.updating = true
      slider:SetValue(value)
      editPanel.updating = false
    end

    slider:SetCallback("OnValueChanged", function(_, _, value)
      if editPanel.updating then return end
      value = Clamp(value, minValue, maxValue, step)
      SyncEdit(value)
      setValue(value)
      ApplyLayoutChange(rebuild)
    end)

    edit:SetCallback("OnEnterPressed", function()
      local value = Clamp(edit:GetText(), minValue, maxValue, step)
      SyncSlider(value)
      SyncEdit(value)
      setValue(value)
      ApplyLayoutChange(rebuild)
    end)

    if edit.editbox then
      edit.editbox:SetScript("OnKeyDown", function(_, key)
        if key ~= "UP" and key ~= "DOWN" then return end
        local delta = (key == "UP") and (step or 1) or -(step or 1)
        local current = Clamp(edit:GetText(), minValue, maxValue, step)
        local value = Clamp(current + delta, minValue, maxValue, step)
        SyncSlider(value)
        SyncEdit(value)
        setValue(value)
        ApplyLayoutChange(rebuild)
      end)
    end

    row:AddChild(slider)
    row:AddChild(edit)
    row:AddChild(minusBtn)
    row:AddChild(plusBtn)
    parent:AddChild(row)
    local initial = Clamp(getValue(), minValue, maxValue, step)
    SyncSlider(initial)
    SyncEdit(initial)

    local function Step(delta)
      local current = Clamp(edit:GetText(), minValue, maxValue, step)
      local value = Clamp(current + delta, minValue, maxValue, step)
      SyncSlider(value)
      SyncEdit(value)
      setValue(value)
      ApplyLayoutChange(rebuild)
    end

    minusBtn:SetCallback("OnClick", function() Step(-(step or 1)) end)
    plusBtn:SetCallback("OnClick", function() Step(step or 1) end)
  end

  local positionGroup = AceGUI:Create("InlineGroup")
  positionGroup:SetTitle("Position")
  positionGroup:SetLayout("List")
  positionGroup:SetFullWidth(true)

  local sizeGroup = AceGUI:Create("InlineGroup")
  sizeGroup:SetTitle("Size")
  sizeGroup:SetLayout("List")
  sizeGroup:SetFullWidth(true)

  local layoutGroup = AceGUI:Create("InlineGroup")
  layoutGroup:SetTitle("Layout")
  layoutGroup:SetLayout("List")
  layoutGroup:SetFullWidth(true)

  scroll:AddChild(positionGroup)
  scroll:AddChild(sizeGroup)
  scroll:AddChild(layoutGroup)

  MakeNumberRow(positionGroup, "X", -1000, 1000, 1, function() return SnapComboPointsDB.x or 0 end, function(v) SnapComboPointsDB.x = v end, false, math.rad(90))
  MakeNumberRow(positionGroup, "Y", -1000, 1000, 1, function() return SnapComboPointsDB.y or 0 end, function(v) SnapComboPointsDB.y = v end, false, math.rad(0))

  MakeNumberRow(sizeGroup, "Width", 1, 500, 1, function() return SnapComboPointsDB.width or 240 end, function(v) SnapComboPointsDB.width = v end, true, math.rad(90))
  MakeNumberRow(sizeGroup, "Height", 1, 200, 1, function() return SnapComboPointsDB.height or 14 end, function(v) SnapComboPointsDB.height = v end, true, math.rad(0))

  MakeNumberRow(layoutGroup, "Spacing", 0, 20, 1, function() return SnapComboPointsDB.spacing or 3 end, function(v) SnapComboPointsDB.spacing = v end, true, math.rad(90))
  MakeNumberRow(layoutGroup, "Energy Height", 1, 200, 1, function() return SnapComboPointsDB.energyHeight or 8 end, function(v) SnapComboPointsDB.energyHeight = v end, true, math.rad(0))


  local texGroup = AceGUI:Create("InlineGroup")
  texGroup:SetTitle("Texture")
  texGroup:SetLayout("Flow")
  texGroup:SetFullWidth(true)

  local texDrop = AceGUI:Create("Dropdown")
  texDrop:SetWidth(240)
  texGroup:AddChild(texDrop)
  scroll:AddChild(texGroup)

  local function EnsureTextureList(state)
    if addon.InitLSM then
      addon.InitLSM()
    end
    local list = addon.GetStatusbarList and addon.GetStatusbarList() or {}
    state.textureList = list
    local values = {}
    for i = 1, #list do
      values[list[i]] = list[i]
    end
    texDrop:SetList(values)
  end

  local function UpdateTextureLabel(state)
    local name = (state.textureTarget == "energy") and SnapComboPointsDB.energyTextureName or SnapComboPointsDB.textureName
    if name and name ~= "" then
      texDrop:SetValue(name)
      return
    end
    if state.textureList and state.textureList[1] then
      texDrop:SetValue(state.textureList[1])
    end
  end

  local function ApplyTextureSelection(state, name)
    if not name or name == "" then return end
    local path = addon.FetchStatusbar and addon.FetchStatusbar(name) or nil
    SnapComboPointsDB.textureName = name
    SnapComboPointsDB.energyTextureName = name
    if addon.ApplyComboTexture then
      addon.ApplyComboTexture(path)
    end
    if addon.ApplyEnergyTexture then
      addon.ApplyEnergyTexture(path)
    end
    if addon.UpdateComboDisplay then addon.UpdateComboDisplay() end
    if addon.UpdateEnergyDisplay then addon.UpdateEnergyDisplay() end
    texDrop:SetValue(name)
  end

  local function SelectTextureByName(state, name)
    EnsureTextureList(state)
    if not name then
      UpdateTextureLabel(state)
      return
    end
    texDrop:SetValue(name)
  end

  texDrop:SetCallback("OnValueChanged", function(_, _, value)
    ApplyTextureSelection(editPanel, value)
  end)

  editPanel.textureList = nil
  editPanel.textureTarget = "combo"
  editPanel.SelectTextureByName = SelectTextureByName
  editPanel.UpdateTextureLabel = UpdateTextureLabel
  editPanel.EnsureTextureList = EnsureTextureList
  editPanel.ApplyTextureSelection = ApplyTextureSelection

  editPanel.ClearAllPoints = function(self) self.frame:ClearAllPoints() end
  editPanel.SetPoint = function(self, ...) self.frame:SetPoint(...) end
  editPanel.SetAlpha = function(self, alpha) self.frame:SetAlpha(alpha) end
  editPanel.Show = function(self) self.frame:Show() end
  editPanel.Hide = function(self) self.frame:Hide() end
  editPanel.IsShown = function(self) return self.frame:IsShown() end

  addon.editPanel = editPanel
  addon.ApplyFrameSizeAndPosition()
  UpdateEditPanelFields()
  EnsureTextureList(editPanel)
  UpdateTextureLabel(editPanel)

  frame:DoLayout()
end

addon.CreateEditModePanel = CreateEditModePanel
addon.UpdateEditPanelFields = UpdateEditPanelFields
