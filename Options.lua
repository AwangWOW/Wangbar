local _, addon = ...

local AceConfig = LibStub("AceConfig-3.0", true)
local AceConfigDialog = LibStub("AceConfigDialog-3.0", true)

if not AceConfig or not AceConfigDialog then
  local title = (addon and (addon.ADDON_TITLE or "Wangbar")) or "Wangbar"
  print(title .. ": Ace libraries not found; options menu unavailable. go download ace3 from curseforge.com :)")
  return
end

local optionsPanel
local optionsRegistered = false

local borderColorOptions = {
  { key = "Black", value = {0, 0, 0, 1} },
  { key = "Dark", value = {0.2, 0.2, 0.2, 1} },
  { key = "White", value = {1, 1, 1, 1} },
  { key = "Red", value = {1, 0.15, 0.15, 1} },
  { key = "Orange", value = {1, 0.5, 0.1, 1} },
  { key = "Yellow", value = {1, 0.85, 0.2, 1} },
}
local borderColorValues = {}
for i = 1, #borderColorOptions do
  borderColorValues[borderColorOptions[i].key] = borderColorOptions[i].key
end

local function GetDB()
  return SnapComboPointsDB or addon.defaults or {}
end

local function FindBorderColorName(color)
  if type(color) ~= "table" then
    return borderColorOptions[1].key
  end
  for i = 1, #borderColorOptions do
    local option = borderColorOptions[i]
    local r, g, b, a = unpack(option.value)
    if r == color[1] and g == color[2] and b == color[3] and a == color[4] then
      return option.key
    end
  end
  return borderColorOptions[1].key
end

local function GetBorderColorValue(name)
  for i = 1, #borderColorOptions do
    if borderColorOptions[i].key == name then
      return borderColorOptions[i].value
    end
  end
  return borderColorOptions[1].value
end

local function RefreshCombo()
  if addon.LayoutBars and addon.GetComboPowerType then
    local comboPowerType = addon.GetComboPowerType()
    addon.LayoutBars(UnitPowerMax("player", comboPowerType) or 0)
  end
  if addon.UpdateComboDisplay then
    addon.UpdateComboDisplay()
  end
end

local function RefreshEnergy()
  if addon.ApplyFrameStyle then
    addon.ApplyFrameStyle()
  end
  if addon.UpdateEnergyDisplay then
    addon.UpdateEnergyDisplay()
  end
end

local function RefreshAll()
  if addon.ApplyFrameStyle then
    addon.ApplyFrameStyle()
  end
  if addon.ApplyFrameSizeAndPosition then
    addon.ApplyFrameSizeAndPosition()
  end
  RefreshCombo()
  RefreshEnergy()
end

local function GetFontList()
  if addon.InitLSM then
    addon.InitLSM()
  end
  local lsm = addon.GetLSM and addon.GetLSM() or nil
  local list = {}
  if lsm and lsm.List then
    list = lsm:List("font") or {}
    table.sort(list)
  end
  if #list == 0 then
    list = { "Default" }
  end
  local values = {}
  for i = 1, #list do
    values[list[i]] = list[i]
  end
  return values
end

local function SetFontByName(name)
  local db = GetDB()
  if not SnapComboPointsDB then return end
  if addon.InitLSM then
    addon.InitLSM()
  end
  local lsm = addon.GetLSM and addon.GetLSM() or nil
  if lsm and lsm.Fetch and name ~= "Default" then
    db.countFont = lsm:Fetch("font", name)
    db.countFontName = name
  else
    db.countFont = db.countFont or "Fonts\\FRIZQT__.TTF"
    db.countFontName = "Default"
  end
  if addon.ApplyFrameStyle then
    addon.ApplyFrameStyle()
  end
  if addon.UpdateComboDisplay then
    addon.UpdateComboDisplay()
  end
end

local function SetEnergyFontByName(name)
  local db = GetDB()
  if not SnapComboPointsDB then return end
  if addon.InitLSM then
    addon.InitLSM()
  end
  local lsm = addon.GetLSM and addon.GetLSM() or nil
  if lsm and lsm.Fetch and name ~= "Default" then
    db.energyCountFont = lsm:Fetch("font", name)
    db.energyCountFontName = name
  else
    db.energyCountFont = db.energyCountFont or "Fonts\\FRIZQT__.TTF"
    db.energyCountFontName = "Default"
  end
  if addon.ApplyFrameStyle then
    addon.ApplyFrameStyle()
  end
  if addon.UpdateEnergyDisplay then
    addon.UpdateEnergyDisplay()
  end
end


local function GetStatusbarValues()
  if addon.GetStatusbarList then
    local list = addon.GetStatusbarList() or {}
    local values = {}
    for i = 1, #list do
      values[list[i]] = list[i]
    end
    return values
  end
  return {}
end

local function BuildPerPointArgs()
  local args = {}
  local maxPoints = addon.GetMaxComboPoints and addon.GetMaxComboPoints() or 7
  if maxPoints < 1 then maxPoints = 7 end
  for i = 1, maxPoints do
    args["point" .. i] = {
      type = "color",
      name = "Point " .. i,
      order = i,
      hasAlpha = true,
      get = function()
        local db = GetDB()
        if type(db.perPointColors) ~= "table" then
          db.perPointColors = {}
        end
        if type(db.perPointColors[i]) ~= "table" then
          local nr, ng, nb, na = unpack(db.color or {1, 1, 1, 1})
          db.perPointColors[i] = { nr, ng, nb, na or 1 }
        end
        local r, g, b, a = unpack(db.perPointColors[i])
        return r, g, b, a or 1
      end,
      set = function(_, r, g, b, a)
        if not SnapComboPointsDB then return end
        local db = GetDB()
        if type(db.perPointColors) ~= "table" then
          db.perPointColors = {}
        end
        db.perPointColors[i] = { r, g, b, a or 1 }
        RefreshCombo()
      end,
    }
  end
  return args
end

local options = {
  type = "group",
  name = addon.ADDON_TITLE or "Wangbar",
  childGroups = "tab",
  args = {
    welcome = {
      type = "group",
      name = "Welcome",
      order = 0,
      args = {
        header = {
          type = "header",
          name = "Welcome to Wangbar",
          order = 0,
        },
        intro1 = {
          type = "description",
          name = "Wangbar is for the people.(Except this addon is made mostly for me, I will not implement all requests, especially if I myself would never use it.)\n\nWANGBAR WANGBAR WANGBAR WANGBAR WANGBAR WANGBAR WANGBAR WANGBAR WANGBAR! \n\nWangbar provides a compact combo-point bar with optional autosizing and anchoring to external cooldown managers.\n\nFeatures:\n- combo points can can change based on current combo point count (turns X color at Y combo point count) \n- coloring of combo points individually \n- Auto-size to external cooldown managers (EssentialCooldownViewer, ArcUI etc.)\n- Anchor to cooldown manager and follow its movement\n- User-adjustable X/Y offsets while anchored \n- Energy bar with configurable gap and offset \n- Match CDM width from Edit Panel",
          order = 1,
          width = "full",
        },
        recommend = {
          type = "header",
          name = "STRONGLY recommend anchoring this bar to your CDM — easiest to maintain!",
          order = 2,
        },
        gotoAutosize = {
          type = "execute",
          name = "Open Auto-size Settings",
          order = 3,
          width = "full",
          func = function()
            if addon and addon.EnsureOptionsPanel then
              addon.EnsureOptionsPanel()
            end
            AceConfigDialog:Open("Wangbar")
            AceConfigDialog:SelectGroup("Wangbar", "layoutText", "layout")
          end,
        },
        intro2 = {
          type = "description",
          name = "\n\nUse the tabs to customize appearance, behavior, and layout.\nFor quick adjustments, open the Edit Panel and use the 'Match CDM Width' button.\nTake some time to learn what this addon can do and what you can customize!\n\nEnjoy! Reach out on discord @awang with questions",
          order = 4,
          width = "full",
        },
      },
    },
    bars = {
      type = "group",
      name = "Coloring",
      order = 1,
      args = {
        
        comboHeader = {
          type = "header",
          name = "Combo Points",
          order = 1,
        },
        highComboEnabled = {
          type = "toggle",
          name = "Change color at combo point threshold",
          order = 2,
          get = function() return GetDB().highComboEnabled end,
          set = function(_, value)
            if not SnapComboPointsDB then return end
            SnapComboPointsDB.highComboEnabled = value and true or false
            RefreshCombo()
          end,
        },
        highComboPointsThreshold = {
          type = "range",
          name = "Combo point threshold",
          order = 3,
          min = 0,
          max = 10,
          step = 1,
          get = function() return GetDB().highComboPointsThreshold or 0 end,
          set = function(_, value)
            if not SnapComboPointsDB then return end
            SnapComboPointsDB.highComboPointsThreshold = value
            RefreshCombo()
          end,
        },
        highComboColor = {
          type = "color",
          name = "Threshold color",
          order = 4,
          hasAlpha = true,
          get = function()
            local r, g, b, a = unpack(GetDB().highComboColor or {1, 0.4, 0.4, 1})
            return r, g, b, a or 1
          end,
          set = function(_, r, g, b, a)
            if not SnapComboPointsDB then return end
            SnapComboPointsDB.highComboColor = { r, g, b, a or 1 }
            RefreshCombo()
          end,
        },
        color = {
          type = "color",
          name = "Normal combo point color",
          order = 5,
          hasAlpha = true,
          get = function()
            local r, g, b, a = unpack(GetDB().color or {1, 1, 1, 1})
            return r, g, b, a or 1
          end,
          set = function(_, r, g, b, a)
            if not SnapComboPointsDB then return end
            local db = GetDB()
            local orr, org, orb, ora = unpack(db.color or {1, 1, 1, 1})
            db.color = { r, g, b, a or 1 }
            if type(db.perPointColors) == "table" then
              for i = 1, #db.perPointColors do
                local pr, pg, pb, pa = unpack(db.perPointColors[i])
                if pr == orr and pg == org and pb == orb and (pa or 1) == (ora or 1) then
                  db.perPointColors[i] = { r, g, b, a or 1 }
                end
              end
            end
            RefreshCombo()
          end,
        },
        charged = {
          type = "color",
          name = "Charged combo point color",
          order = 6,
          hasAlpha = true,
          get = function()
            local r, g, b, a = unpack(GetDB().charged or {1, 1, 1, 1})
            return r, g, b, a or 1
          end,
          set = function(_, r, g, b, a)
            if not SnapComboPointsDB then return end
            SnapComboPointsDB.charged = { r, g, b, a or 1 }
            RefreshCombo()
          end,
        },
        energyHeader = {
          type = "header",
          name = "Energy Bar",
          order = 10,
        },
        energyEnabled = {
          type = "toggle",
          name = "Enable energy bar",
          order = 11,
          get = function() return GetDB().energyEnabled ~= false end,
          set = function(_, value)
            if not SnapComboPointsDB then return end
            SnapComboPointsDB.energyEnabled = value and true or false
            if addon.ApplyFrameSizeAndPosition then
              addon.ApplyFrameSizeAndPosition()
            end
            RefreshEnergy()
          end,
        },
        energyColor = {
          type = "color",
          name = "Energy bar color",
          order = 12,
          hasAlpha = true,
          get = function()
            local r, g, b, a = unpack(GetDB().energyColor or {1, 1, 1, 1})
            return r, g, b, a or 1
          end,
          set = function(_, r, g, b, a)
            if not SnapComboPointsDB then return end
            SnapComboPointsDB.energyColor = { r, g, b, a or 1 }
            RefreshEnergy()
          end,
        },
        perPointHeader = {
          type = "header",
          name = "Per-point Colors",
          order = 20,
        },
        perPointColorsEnabled = {
          type = "toggle",
          name = "Enable per-point colors",
          order = 21,
          get = function() return GetDB().perPointColorsEnabled end,
          set = function(_, value)
            if not SnapComboPointsDB then return end
            SnapComboPointsDB.perPointColorsEnabled = value and true or false
            if not SnapComboPointsDB.perPointColorsEnabled then
              local r, g, b, a = unpack(SnapComboPointsDB.color or {1, 1, 1, 1})
              if type(SnapComboPointsDB.perPointColors) ~= "table" then
                SnapComboPointsDB.perPointColors = {}
              end
              local maxPoints = addon.GetMaxComboPoints and addon.GetMaxComboPoints() or 7
              if maxPoints < 1 then maxPoints = 7 end
              for i = 1, maxPoints do
                SnapComboPointsDB.perPointColors[i] = { r, g, b, a or 1 }
              end
            end
            RefreshCombo()
          end,
        },
        points = {
          type = "group",
          name = "",
          inline = true,
          order = 22,
          args = BuildPerPointArgs(),
        },
        spacer_after_points = {
          type = "description",
          name = "\n",
          order = 995,
        },
        edit_mode_button = {
          type = "execute",
          name = "Open Edit Mode",
          order = 996,
          func = function()
            if addon and addon.ToggleDebugPanel then
              addon.ToggleDebugPanel()
            elseif addon and addon.ShowEditPanel then
              addon.ShowEditPanel()
            else
              print(((addon and (addon.ADDON_TITLE or "Wangbar")) or "Wangbar") .. ": Edit mode unavailable.")
            end
          end,
        },
        commands_help = {
          type = "description",
          name = "Slash commands: /wang, /wangbar, /wb\nUse any of the above in chat to open the options menu.",
          order = 999,
        },
      },
    },
    style = {
      type = "group",
      name = "Style",
      order = 2,
      args = {
        borders = {
          type = "group",
          name = "Borders",
          inline = true,
          order = 1,
          args = {
            pipBorderSize = {
              type = "range",
              name = "Combo point border size",
              order = 1,
              min = 0,
              max = 10,
              step = 1,
              get = function() return GetDB().pipBorderSize or 0 end,
              set = function(_, value)
                if not SnapComboPointsDB then return end
                SnapComboPointsDB.pipBorderSize = value
                RefreshCombo()
              end,
            },
            pipBorderColor = {
              type = "select",
              name = "Combo point border color",
              order = 2,
              values = borderColorValues,
              get = function() return FindBorderColorName(GetDB().pipBorderColor) end,
              set = function(_, value)
                if not SnapComboPointsDB then return end
                SnapComboPointsDB.pipBorderColor = GetBorderColorValue(value)
                RefreshCombo()
              end,
            },
            pipBgOpacity = {
              type = "range",
              name = "Combo point background opacity",
              order = 3,
              min = 0,
              max = 1,
              step = 0.05,
              get = function()
                local color = GetDB().pipBgColor or {0, 0, 0, 0}
                return color[4] or 0
              end,
              set = function(_, value)
                if not SnapComboPointsDB then return end
                local color = SnapComboPointsDB.pipBgColor or {0, 0, 0, 0}
                SnapComboPointsDB.pipBgColor = { color[1] or 0, color[2] or 0, color[3] or 0, value }
                if type(SnapComboPointsDB.emptyColor) == "table" then
                  local er, eg, eb = SnapComboPointsDB.emptyColor[1], SnapComboPointsDB.emptyColor[2], SnapComboPointsDB.emptyColor[3]
                  SnapComboPointsDB.emptyColor = { er or 0, eg or 0, eb or 0, value }
                end
                RefreshCombo()
                if addon.ApplyFrameStyle then
                  addon.ApplyFrameStyle()
                end
              end,
            },
            energyBorder = {
              type = "select",
              name = "Energy border color",
              order = 4,
              values = borderColorValues,
              get = function()
                return FindBorderColorName(GetDB().energyBorder)
              end,
              set = function(_, value)
                if not SnapComboPointsDB then return end
                SnapComboPointsDB.energyBorder = GetBorderColorValue(value)
                RefreshEnergy()
              end,
            },
            energyBorderSize = {
              type = "range",
              name = "Energy border size",
              order = 5,
              min = 0,
              max = 10,
              step = 1,
              get = function() return GetDB().energyBorderSize or 0 end,
              set = function(_, value)
                if not SnapComboPointsDB then return end
                SnapComboPointsDB.energyBorderSize = value
                RefreshEnergy()
                if addon.ApplyFrameSizeAndPosition then
                  addon.ApplyFrameSizeAndPosition()
                end
              end,
            },
            energyBgOpacity = {
              type = "range",
              name = "Energy background opacity",
              order = 6,
              min = 0,
              max = 1,
              step = 0.05,
              get = function()
                local color = GetDB().energyBg or {0,0,0,0}
                return color[4] or 0
              end,
              set = function(_, value)
                if not SnapComboPointsDB then return end
                local color = SnapComboPointsDB.energyBg or {0,0,0,0}
                SnapComboPointsDB.energyBg = { color[1] or 0, color[2] or 0, color[3] or 0, value }
                if addon.ApplyFrameStyle then
                  addon.ApplyFrameStyle()
                end
                RefreshEnergy()
              end,
            },
          },
        },
        textures = {
          type = "group",
          name = "Textures",
          inline = true,
          order = 2,
          args = {
            comboTexture = {
              type = "select",
              name = "Combo texture",
              order = 1,
              values = GetStatusbarValues,
              get = function() return GetDB().textureName or "" end,
              set = function(_, value)
                if not SnapComboPointsDB then return end
                local path = addon.FetchStatusbar and addon.FetchStatusbar(value) or nil
                SnapComboPointsDB.textureName = value
                SnapComboPointsDB.texture = path or SnapComboPointsDB.texture
                if addon.ApplyComboTexture then
                  addon.ApplyComboTexture(SnapComboPointsDB.texture)
                end
                RefreshCombo()
              end,
            },
            energyTexture = {
              type = "select",
              name = "Energy texture",
              order = 2,
              values = GetStatusbarValues,
              get = function() return GetDB().energyTextureName or "" end,
              set = function(_, value)
                if not SnapComboPointsDB then return end
                local path = addon.FetchStatusbar and addon.FetchStatusbar(value) or nil
                SnapComboPointsDB.energyTextureName = value
                SnapComboPointsDB.energyTexture = path or SnapComboPointsDB.energyTexture
                if addon.ApplyEnergyTexture then
                  addon.ApplyEnergyTexture(SnapComboPointsDB.energyTexture)
                end
                RefreshEnergy()
              end,
            },
          },
        },
      },
    },
    layoutText = {
      type = "group",
      name = "Layout & Text",
      order = 3,
      args = {
        layout = {
          type = "group",
          name = "Layout",
          inline = true,
          order = 1,
          args = {
            x = {
              type = "range",
              name = "X",
              order = 1,
              min = -1000,
              max = 1000,
              step = 1,
              get = function() return GetDB().x or 0 end,
              set = function(_, value)
                if not SnapComboPointsDB then return end
                SnapComboPointsDB.x = value
                RefreshAll()
              end,
            },
            y = {
              type = "range",
              name = "Y",
              order = 2,
              min = -1000,
              max = 1000,
              step = 1,
              get = function() return GetDB().y or 0 end,
              set = function(_, value)
                if not SnapComboPointsDB then return end
                SnapComboPointsDB.y = value
                RefreshAll()
              end,
            },
            width = {
              type = "range",
              name = "Width",
              order = 3,
              min = 1,
              max = 500,
              step = 1,
              get = function() return GetDB().width or 240 end,
              set = function(_, value)
                if not SnapComboPointsDB then return end
                SnapComboPointsDB.width = value
                RefreshAll()
              end,
            },
            height = {
              type = "range",
              name = "Combo Point Height",
              order = 4,
              min = 1,
              max = 200,
              step = 1,
              get = function() return GetDB().height or 14 end,
              set = function(_, value)
                if not SnapComboPointsDB then return end
                SnapComboPointsDB.height = value
                RefreshAll()
              end,
            },
            spacing = {
              type = "range",
              name = "Combo Point Spacing",
              order = 5,
              min = 0,
              max = 20,
              step = 1,
              get = function() return GetDB().spacing or 3 end,
              set = function(_, value)
                if not SnapComboPointsDB then return end
                SnapComboPointsDB.spacing = value
                RefreshAll()
              end,
            },
            energyHeight = {
              type = "range",
              name = "Energy Height",
              order = 6,
              min = 1,
              max = 200,
              step = 1,
              get = function() return GetDB().energyHeight or 8 end,
              set = function(_, value)
                if not SnapComboPointsDB then return end
                SnapComboPointsDB.energyHeight = value
                RefreshAll()
              end,
            },
            energyYOffset = {
              type = "range",
              name = "Energy Y Offset",
              order = 7,
              min = -100,
              max = 100,
              step = 1,
              get = function() return GetDB().energyYOffset or 0 end,
              set = function(_, value)
                if not SnapComboPointsDB then return end
                SnapComboPointsDB.energyYOffset = value
                RefreshAll()
              end,
            },
            autosizeHeader = {
              type = "header",
              name = "Auto-size",
              order = 8,
            },
            autoSizeToCDM = {
              type = "toggle",
              name = "Auto-size to Cooldown Manager",
              order = 9,
              get = function() return GetDB().autoSizeToCDM end,
              set = function(_, value)
                if not SnapComboPointsDB then return end
                SnapComboPointsDB.autoSizeToCDM = value and true or false
                -- clear any cached CDM name when toggling autosize to avoid stale references
                SnapComboPointsDB.autoSizeCDMName = ""
                if addon.ApplyFrameSizeAndPosition then
                  addon.ApplyFrameSizeAndPosition()
                end
              end,
            },
            anchorToCDM = {
              type = "toggle",
              name = "Anchor to Cooldown Manager",
              desc = "Anchor the bar to the detected cooldown manager so moving it also moves the bar.",
              order = 11,
              get = function() return GetDB().anchorToCDM end,
              set = function(_, value)
                if not SnapComboPointsDB then return end
                SnapComboPointsDB.anchorToCDM = value and true or false
                if value and not SnapComboPointsDB._anchorInitialized then
                  SnapComboPointsDB.x = 0
                  SnapComboPointsDB.y = 0
                  SnapComboPointsDB._anchorInitialized = true
                end
                if addon.ApplyFrameSizeAndPosition then
                  addon.ApplyFrameSizeAndPosition()
                end
              end,
            },
            autoDetectCDM = {
              type = "toggle",
              name = "Auto-detect cooldown frame",
              desc = "Try to automatically find the cooldown manager frame (recommended).",
              order = 10,
              get = function() return GetDB().autoDetectCDM end,
              set = function(_, value)
                if not SnapComboPointsDB then return end
                SnapComboPointsDB.autoDetectCDM = value and true or false
                -- clear cached candidate to force fresh detection
                SnapComboPointsDB.autoSizeCDMName = ""
                if addon.ApplyFrameSizeAndPosition then
                  addon.ApplyFrameSizeAndPosition()
                end
              end,
            },
            autoSizeUseArcUI = {
              type = "toggle",
              name = "ArcUI compatibility",
              desc = "If you use ArcUI, enable this to prefer ArcUI cooldown frames.",
              order = 11,
              get = function() return GetDB().autoSizeUseArcUI end,
              set = function(_, value)
                if not SnapComboPointsDB then return end
                SnapComboPointsDB.autoSizeUseArcUI = value and true or false
                -- clear cached candidate when changing ArcUI preference
                SnapComboPointsDB.autoSizeCDMName = ""
                if addon.ApplyFrameSizeAndPosition then
                  addon.ApplyFrameSizeAndPosition()
                end
              end,
            },
            autoSizeInterval = {
              type = "range",
              name = "Poll interval (s)",
              order = 12,
              min = 0.05,
              max = 2,
              step = 0.05,
              get = function() return tonumber(GetDB().autoSizeInterval) or 0.25 end,
              set = function(_, value)
                if not SnapComboPointsDB then return end
                SnapComboPointsDB.autoSizeInterval = tonumber(value) or 0.25
                if addon.ApplyFrameSizeAndPosition then
                  addon.ApplyFrameSizeAndPosition()
                end
              end,
            },
          },
        },
        text = {
          type = "group",
          name = "Combo Point Text",
          inline = true,
          order = 2,
          args = {
            showCount = {
              type = "toggle",
              name = "Enable combo count",
              order = 1,
              get = function() return GetDB().showCount end,
              set = function(_, value)
                if not SnapComboPointsDB then return end
                SnapComboPointsDB.showCount = value and true or false
                if addon.UpdateComboDisplay then
                  addon.UpdateComboDisplay()
                end
              end,
            },
            countFontName = {
              type = "select",
              name = "Font",
              order = 2,
              values = GetFontList,
              get = function() return GetDB().countFontName or "Default" end,
              set = function(_, value)
                SetFontByName(value)
              end,
            },
            countFontSize = {
              type = "range",
              name = "Size",
              order = 3,
              min = 6,
              max = 72,
              step = 1,
              get = function() return GetDB().countFontSize or 12 end,
              set = function(_, value)
                if not SnapComboPointsDB then return end
                SnapComboPointsDB.countFontSize = value
                if addon.ApplyFrameStyle then
                  addon.ApplyFrameStyle()
                end
                if addon.UpdateComboDisplay then
                  addon.UpdateComboDisplay()
                end
              end,
            },
            countColor = {
              type = "color",
              name = "Text color",
              order = 4,
              hasAlpha = true,
              get = function()
                local r, g, b, a = unpack(GetDB().countColor or {1, 1, 1, 1})
                return r, g, b, a or 1
              end,
              set = function(_, r, g, b, a)
                if not SnapComboPointsDB then return end
                SnapComboPointsDB.countColor = { r, g, b, a or 1 }
                if addon.ApplyFrameStyle then
                  addon.ApplyFrameStyle()
                end
                if addon.UpdateComboDisplay then
                  addon.UpdateComboDisplay()
                end
              end,
            },
          },
        },
        energyText = {
          type = "group",
          name = "Energy Text",
          inline = true,
          order = 3,
          args = {
            showEnergyCount = {
              type = "toggle",
              name = "Enable energy count",
              order = 1,
              get = function() return GetDB().showEnergyCount end,
              set = function(_, value)
                if not SnapComboPointsDB then return end
                SnapComboPointsDB.showEnergyCount = value and true or false
                if addon.UpdateEnergyDisplay then
                  addon.UpdateEnergyDisplay()
                end
              end,
            },
            energyCountFontName = {
              type = "select",
              name = "Font",
              order = 2,
              values = GetFontList,
              get = function() return GetDB().energyCountFontName or "Default" end,
              set = function(_, value)
                SetEnergyFontByName(value)
              end,
            },
            energyCountFontSize = {
              type = "range",
              name = "Size",
              order = 3,
              min = 6,
              max = 72,
              step = 1,
              get = function() return GetDB().energyCountFontSize or 12 end,
              set = function(_, value)
                if not SnapComboPointsDB then return end
                SnapComboPointsDB.energyCountFontSize = value
                if addon.ApplyFrameStyle then
                  addon.ApplyFrameStyle()
                end
                if addon.UpdateEnergyDisplay then
                  addon.UpdateEnergyDisplay()
                end
              end,
            },
            energyCountColor = {
              type = "color",
              name = "Text color",
              order = 4,
              hasAlpha = true,
              get = function()
                local r, g, b, a = unpack(GetDB().energyCountColor or {1, 1, 1, 1})
                return r, g, b, a or 1
              end,
              set = function(_, r, g, b, a)
                if not SnapComboPointsDB then return end
                SnapComboPointsDB.energyCountColor = { r, g, b, a or 1 }
                if addon.ApplyFrameStyle then
                  addon.ApplyFrameStyle()
                end
                if addon.UpdateEnergyDisplay then
                  addon.UpdateEnergyDisplay()
                end
              end,
            },
          },
        },
      },
    },
  },
}

local function EnsureOptionsPanel()
  if optionsRegistered then return end
  AceConfig:RegisterOptionsTable("Wangbar", options)
  optionsPanel = AceConfigDialog:AddToBlizOptions("Wangbar", addon.ADDON_TITLE or "Wangbar")
  optionsRegistered = true
end

local function OpenOptionsPanel()
  EnsureOptionsPanel()
  AceConfigDialog:Open("Wangbar")
end

addon.OpenOptionsPanel = OpenOptionsPanel
addon.EnsureOptionsPanel = EnsureOptionsPanel

if C_Timer and C_Timer.After then
  C_Timer.After(0, EnsureOptionsPanel)
else
  EnsureOptionsPanel()
end