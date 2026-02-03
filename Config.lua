local _, addon = ...

addon.defaults = {
  point = "CENTER",
  relPoint = "CENTER",
  x = 0,
  y = -0,
  width = 300,
  height = 14,
  spacing = 3,
  energyHeight = 14,
  energyGap = 4,
  energyYOffset = 0,
  energyEnabled = true,
  bg = {0, 0, 0, 0},
  border = {0, 0, 0, 0},
  bgTexture = "Interface\\Buttons\\WHITE8x8",
  bgTextureName = nil,
  hideContainer = true,
  color = {1, 1, 1, 1},                -- normal CP (white)
  charged = {1, 1, 1, 1},              
  perPointColorsEnabled = false,
  perPointColors = {
    {1, 1, 1, 1},
    {1, 1, 1, 1},
    {1, 1, 1, 1},
    {1, 1, 1, 1},
    {1, 1, 1, 1},
    {1, 1, 1, 1},
    {1, 1, 1, 1},
  },
  showOnlyWhenRelevant = true,
  -- Textures
  texture = "Interface\\TARGETINGFRAME\\UI-StatusBar",
  emptyTexture = "Interface\\TARGETINGFRAME\\UI-StatusBar",
  energyTexture = "Interface\\TARGETINGFRAME\\UI-StatusBar",
  textureName = nil,
  energyTextureName = nil,

  -- Colors
  bgColorName = "Default",
  emptyColor = {0, 0, 0, 1},            -- empty pip fill (black)
  energyColor = {1.0, 0.95, 0.2, 1},    -- energy bar
  energyBg = {0, 0, 0, 0.15},
  energyBorder = {0, 0, 0, 0.9},
  energyBorderSize = 1,

  -- Borders (per pip)
  pipBorderSize = 1,
  pipBorderColor = {0, 0, 0, 0.9},
  pipBgColor = {0, 0, 0, 0.6},
  pipShadowColor = {0, 0, 0, 0.6},
  pipShadowOffset = 1,

  -- Optional: border changes when active
  activeBorderColor = {0, 0, 0, 1},
  chargedBorderColor = {0.25, 0.5, 1.0, 1},

  -- Display style
  hideEmpty = false,
  showCount = true,
  countFont = "Fonts\\FRIZQT__.TTF",
  countFontName = nil,
  countFontSize = 12,
  countFontOutline = "OUTLINE",
  countColor = {1, 1, 1, 1},
  countShadowColor = {0, 0, 0, 1},
  countShadowOffset = 1,
  showEnergyCount = true,
  energyCountFont = "Fonts\\FRIZQT__.TTF",
  energyCountFontName = nil,
  energyCountFontSize = 12,
  energyCountFontOutline = "OUTLINE",
  energyCountColor = {1, 1, 1, 1},
  energyCountShadowColor = {0, 0, 0, 1},
  energyCountShadowOffset = 1,

  -- Conditional combo colors
  highComboEnabled = false,
  highComboPointsThreshold = 5,
  highComboColor = {1, 0.4, 0.4, 1},

  -- Auto-size to an external cooldown manager frame
    autoSizeToCDM = false,
  autoSizeCDMName = "EssentialCooldownViewer",
  autoDetectCDM = false,
  autoSizeUseArcUI = false,
    anchorToCDM = false,
  autoSizeInterval = 0.25,

  -- Minimap button
  minimap = {
    hide = false,
    angle = 225,
  },
}
