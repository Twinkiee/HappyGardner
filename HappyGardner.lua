-----------------------------------------------------------------------------------------------
-- Client Lua Script for HappyGardner
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"

-----------------------------------------------------------------------------------------------
-- HappyGardner Module Definition
-----------------------------------------------------------------------------------------------
local HappyGardner = {}
local eventsActive = false
local N_FERTILE_GROUND_STRING_ID = 423296
local N_FERTILE_GROUND_UNKNOWN_STRING_ID = 108
local N_FERTILE_GROUND_MAX_DISTANCE = 14
local N_SEED_ITEM_TYPE = 213
local N_HOUSE_PLOT_ID = 1136
local N_INVALID_DISTANCE = 5000
local N_BAG_SQUARE_SIZE = 45
local N_BAG_WINDOWS_SQUARE_SIZE = N_BAG_SQUARE_SIZE + 2
local STR_FERTILE_GROUND_TYPE = "HousingPlant"
local STR_FERTILE_GROUND_TABLE_UNIT = "unit"
local STR_FERTILE_GROUND_TABLE_TIME = "blocktime"

local fnSortSeedsFirst = function(itemLeft, itemRight)

  if itemLeft == itemRight then
    return 0
  end
  if itemLeft and itemRight == nil then
    return -1
  end
  if itemLeft == nil and itemRight then
    return 1
  end


  local strLeftItemType = itemLeft:GetItemType()
  local strRightItemType = itemRight:GetItemType()

  if strLeftItemType == N_SEED_ITEM_TYPE then
    if strRightItemType == N_SEED_ITEM_TYPE then
      if itemLeft:GetStackCount() <= itemRight:GetStackCount() then
        return -1
      else
        return 1
      end
    else
      return -1
    end
  elseif strRightItemType == N_SEED_ITEM_TYPE then
    return 1
  end

  return 0
end

function HappyGardner:CloseSeedBagWindow()
  self.wndMain:Close()
  self.nToPlantFertileGroundId = 0
end

function HappyGardner:ToggleEventHandlers(activate)
  if (activate == true) then
    Apollo.RegisterEventHandler("UnitCreated", "OnUnitCreated", self)
    Apollo.RegisterEventHandler("UpdateInventory", "OnUpdateInventory", self)
    self.eventsActive = true
  else
    Apollo.RemoveEventHandler("UnitCreated", self)
    Apollo.RemoveEventHandler("UpdateInventory", self)
    self.eventsActive = false
  end
end

function HappyGardner:OnLoad()

  self.tKnownFertileGround = {}
  self.arPreloadUnits = {}

  Apollo.RegisterEventHandler("SubZoneChanged", "OnSubZoneChanged", self)
  Apollo.RegisterEventHandler("ChangeWorld", "OnChangeWorld", self)
  self:ToggleEventHandlers(true)

  self.xmlDoc = XmlDoc.CreateFromFile("HappyGardner.xml")
  self.xmlDoc:RegisterCallback("OnDocLoaded", self)
end

-----------------------------------------------------------------------------------------------
-- HappyGardner OnDocLoaded
-----------------------------------------------------------------------------------------------
function HappyGardner:OnDocLoaded()

  if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
    self.wndMain = Apollo.LoadForm(self.xmlDoc, "HappyGardnerForm", nil, self)
    if self.wndMain == nil then
      Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
      return
    end
    Apollo.RegisterEventHandler("WindowManagementReady", "OnWindowManagementReady", self)
    self.wndMain:Show(false, true)

    self.nLastZoneId = 0
    self.unit = 0
    self.toplant = 0
    self.wndSeedBag = self.wndMain:FindChild("MainBagWindow")
    self.wndSeedBag:SetSquareSize(N_BAG_SQUARE_SIZE, N_BAG_SQUARE_SIZE)

    Apollo.RegisterSlashCommand("hg", "OnHappyGardner", self)

    self.wndSeedBag:SetSort(true)
    self.wndSeedBag:SetItemSortComparer(fnSortSeedsFirst)
    self.wndSeedBag:SetNewItemOverlaySprite("")

    self.timerDisplaySeedBag = ApolloTimer.Create(1, true, "OnDisplaySeedBagTimer", self)
    self.timerEnableSeedBag1 = ApolloTimer.Create(0.2, false, "OnEnableSeedBagTimer", self)
    self.timerEnableSeedBag2 = ApolloTimer.Create(0.5, false, "OnEnableSeedBagTimer", self)
  end
end

function HappyGardner:OnEnableSeedBagTimer()
  self.wndSeedBag:Enable(not self.wndSeedBag:IsEnabled())
  -- self.wndSeedBag:SetStyle("IgnoreMouse", false)
end

function HappyGardner:OnWindowManagementReady()
  Event_FireGenericEvent("WindowManagementRegister", { wnd = self.wndMain, strName = "HappyGardner" })
  Event_FireGenericEvent("WindowManagementAdd", { wnd = self.wndMain, strName = "HappyGardner" })

  if (self.nLastZoneId == 0) then
    self:OnSubZoneChanged(GameLib.GetCurrentZoneId())
  end
end

-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
-- e.g. local kiExampleVariableMax = 999

-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function HappyGardner:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self

  -- initialize variables here

  return o
end

function HappyGardner:Init()
  local bHasConfigureFunction = false
  local strConfigureButtonText = ""
  local tDependencies = {-- "UnitOrPackageName",
  }

  Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end

-----------------------------------------------------------------------------------------------
-- HappyGardner OnLoad
-----------------------------------------------------------------------------------------------
function HappyGardner:OnHappyGardner(bForceUpdate)

  if (self.wndMain:IsVisible() and not bForceUpdate) then
    return
  end

  local nSeedCount = 0
  local tInventoryItems = GameLib.GetPlayerUnit():GetInventoryItems()
  for _, itemInventory in ipairs(tInventoryItems) do
    if itemInventory then
      local item = itemInventory.itemInBag
      if (item:GetItemType() == N_SEED_ITEM_TYPE) then
        nSeedCount = nSeedCount + 1
      end
    end
  end

  local bIsMainWindowVisible = self.wndMain:IsVisible()
  if (nSeedCount < 1 and bIsMainWindowVisible) then
    self:CloseSeedBagWindow()
    return
  end

  if (not bIsMainWindowVisible and nSeedCount > 0) then

    self.wndMain:Show(true, true)
    self.timerDisplaySeedBag:Start()
  end

  local wndBag = self.wndMain:FindChild("MainBagWindow")

  local nLeft, nTop, _, nBottom = self.wndMain:GetAnchorOffsets()
  self.wndMain:SetAnchorOffsets(nLeft, nTop, (nLeft) + (nSeedCount * N_BAG_WINDOWS_SQUARE_SIZE + N_BAG_WINDOWS_SQUARE_SIZE), nBottom)

  wndBag:SetBoxesPerRow(nSeedCount)
end

function HappyGardner:OnMouseButtonDown()

  if (not self.wndSeedBag:IsEnabled()) then
    return
  end

  local unitTarget = GameLib.GetTargetUnit()
  if unitTarget and self:IsFertileGround(unitTarget:GetName()) then
    self.nValidFertileGroundId = unitTarget:GetId()
  end

  if (self.nValidFertileGroundId == 0) then

    local nFertileGroundId = self:GetValidFertileGroundUnitId()
    if (nFertileGroundId > 0) then
      self.nValidFertileGroundId = nFertileGroundId
    else
      return
    end
  end
  --Print(self.nValidFertileGroundId)
  self.tKnownFertileGround[self.nValidFertileGroundId][STR_FERTILE_GROUND_TABLE_TIME] = GameLib.GetGameTime()
  GameLib.SetTargetUnit(self.tKnownFertileGround[self.nValidFertileGroundId][STR_FERTILE_GROUND_TABLE_UNIT])
  self.nValidFertileGroundId = 0
  self.timerEnableSeedBag1:Start()
  self.timerEnableSeedBag2:Start()
end

function HappyGardner:OnChangeWorld()
  if (not self.eventsActive) then
    self:ToggleEventHandlers(true)
  end
end

function HappyGardner:OnSubZoneChanged(nZoneId, pszZoneName)

  -- Print("nZoneId: " .. tostring(nZoneId) .. "; self.nLastZoneId: " .. self.nLastZoneId)

  if (nZoneId == 0) then
    return
  end

  if (nZoneId == N_HOUSE_PLOT_ID and self.nLastZoneId ~= N_HOUSE_PLOT_ID) then
    if (not self.eventsActive) then
      self:ToggleEventHandlers(true)
    end
    self.timerDisplaySeedBag:Start()

  elseif (nZoneId ~= N_HOUSE_PLOT_ID) then

    self.tKnownFertileGround = {}
    self:ToggleEventHandlers(false)
    self.timerDisplaySeedBag:Stop()
  end
  self.nLastZoneId = nZoneId
end

function HappyGardner:OnUpdateInventory()

  if (self.nValidFertileGroundId == 0) then
    local nValidFertileGroundId = self:GetValidFertileGroundUnitId()
    if (nValidFertileGroundId > 0) then
      self.nValidFertileGroundId = nValidFertileGroundId
    end
  end

  if (self.nValidFertileGroundId and self.nValidFertileGroundId > 0) then
    self:OnHappyGardner(true)
  end
end

function HappyGardner:IsFertileGround(strName)

  return strName == Apollo.GetString(N_FERTILE_GROUND_STRING_ID) -- or strName == Apollo.GetString(N_FERTILE_GROUND_UNKNOWN_STRING_ID)
end


function HappyGardner:OnUnitCreated(unit)

  if ((unit) and (self:IsFertileGround(unit:GetName())) and (unit:GetType() == STR_FERTILE_GROUND_TYPE) and (self.tKnownFertileGround[unit:GetId()] == nil)) then
    self.tKnownFertileGround[unit:GetId()] = {}
    self.tKnownFertileGround[unit:GetId()][STR_FERTILE_GROUND_TABLE_UNIT] = unit
  end
end

function HappyGardner:DistanceToUnit(unit)

  local unitPlayer = GameLib.GetPlayerUnit()

  if (not unitPlayer) then return N_INVALID_DISTANCE end

  local posPlayer = unitPlayer:GetPosition()

  if (posPlayer) then
    local posTarget = unit:GetPosition()
    if posTarget then

      local nDeltaX = posTarget.x - posPlayer.x
      local nDeltaY = posTarget.y - posPlayer.y
      local nDeltaZ = posTarget.z - posPlayer.z

      return math.sqrt(math.pow(nDeltaX, 2) + math.pow(nDeltaY, 2) + math.pow(nDeltaZ, 2))
    else
      return N_INVALID_DISTANCE
    end
  else
    return N_INVALID_DISTANCE
  end
end

function HappyGardner:GetValidFertileGroundUnitId()
  local nCurrentTime, nDistanceFromFertileGround, unitFertileGround, nFertileGroundTime = GameLib.GetGameTime()

  for nFertileGroundUnitId, tFertileGroundInfo in pairs(self.tKnownFertileGround) do
    unitFertileGround = tFertileGroundInfo[STR_FERTILE_GROUND_TABLE_UNIT]
    nFertileGroundTime = tFertileGroundInfo[STR_FERTILE_GROUND_TABLE_TIME]
    nDistanceFromFertileGround = self:DistanceToUnit(unitFertileGround)

    if (nDistanceFromFertileGround < N_FERTILE_GROUND_MAX_DISTANCE and (not nFertileGroundTime or nCurrentTime - nFertileGroundTime > 1) and self:IsFertileGround(unitFertileGround:GetName())) then
      return nFertileGroundUnitId
    end
  end
  return 0
end

function HappyGardner:OnDisplaySeedBagTimer()

  if (not GameLib.GetPlayerUnit()) then return end

  local nFertileGroundUnitId = self:GetValidFertileGroundUnitId()

  if (nFertileGroundUnitId > 0) then
    self.nValidFertileGroundId = nFertileGroundUnitId
    self:OnHappyGardner(false)
  elseif (self.wndMain:IsVisible()) then
    self:CloseSeedBagWindow()
  end
end


-----------------------------------------------------------------------------------------------
-- HappyGardner Functions
-----------------------------------------------------------------------------------------------
-- Define general functions here


-----------------------------------------------------------------------------------------------
-- HappyGardnerForm Functions
-----------------------------------------------------------------------------------------------
-- when the OK button is clicked
function HappyGardner:OnGenerateTooltip(wndControl, wndHandler, tType, item)

  if wndControl ~= wndHandler then return end
  wndControl:SetTooltipDoc(nil)
  if item ~= nil then
    local itemEquipped = item:GetEquippedItemForItemType()
    Tooltip.GetItemTooltipForm(self, wndControl, item, { bPrimary = true, bSelling = false, itemCompare = itemEquipped })
  end
end

function HappyGardner:TempClose(wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY, bDoubleClick, bStopPropagation)
    self.timerDisplaySeedBag:Stop()
    self:ToggleEventHandlers(false)
    self.nLastZoneId = 0
    self:CloseSeedBagWindow()
end

-----------------------------------------------------------------------------------------------
-- HappyGardner Instance
-----------------------------------------------------------------------------------------------
local HappyGardnerInst = HappyGardner:new()
HappyGardnerInst:Init()


function table.val_to_str(v)
  if "string" == type(v) then
    v = string.gsub(v, "\n", "\\n")
    if string.match(string.gsub(v, "[^'\"]", ""), '^"+$') then
      return "'" .. v .. "'"
    end
    return '"' .. string.gsub(v, '"', '\\"') .. '"'
  else
    return "table" == type(v) and table.tostring(v) or
        tostring(v)
  end
end

function table.key_to_str(k)
  if "string" == type(k) and string.match(k, "^[_%a][_%a%d]*$") then
    return k
  else
    return "[" .. table.val_to_str(k) .. "]"
  end
end

function table.tostring(tbl)
  if (not tbl) then return "nil" end

  local result, done = {}, {}
  for k, v in ipairs(tbl) do
    table.insert(result, table.val_to_str(v))
    done[k] = true
  end
  for k, v in pairs(tbl) do
    if not done[k] then
      table.insert(result,
        table.key_to_str(k) .. "=" .. table.val_to_str(v))
    end
  end
  return "{" .. table.concat(result, ",") .. "}"
end
