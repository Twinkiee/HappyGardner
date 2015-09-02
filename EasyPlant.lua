-----------------------------------------------------------------------------------------------
-- Client Lua Script for EasyPlant
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"

-----------------------------------------------------------------------------------------------
-- EasyPlant Module Definition
-----------------------------------------------------------------------------------------------
local EasyPlant = {}
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

function EasyPlant:CloseSeedBagWindow()
  self.wndMain:Close()
  self.nToPlantFertileGroundId = 0
end

function EasyPlant:ToggleEvents(activate)
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

function EasyPlant:OnLoad()

  self.tExistingFertileGrounds = {}
  self.arPreloadUnits = {}

  Apollo.RegisterEventHandler("SubZoneChanged", "OnSubZoneChanged", self)
  Apollo.RegisterEventHandler("ChangeWorld", "OnChangeWorld", self)
  self:ToggleEvents(true)

  self.xmlDoc = XmlDoc.CreateFromFile("EasyPlant.xml")
  self.xmlDoc:RegisterCallback("OnDocLoaded", self)
end

-----------------------------------------------------------------------------------------------
-- EasyPlant OnDocLoaded
-----------------------------------------------------------------------------------------------
function EasyPlant:OnDocLoaded()

  if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
    self.wndMain = Apollo.LoadForm(self.xmlDoc, "EasyPlantForm", nil, self)
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

    Apollo.RegisterSlashCommand("hg", "OnShowHappyGardener", self)
    Apollo.RegisterSlashCommand("ep2", "OnEp2", self)

    self.wndSeedBag:SetSort(true)
    self.wndSeedBag:SetItemSortComparer(fnSortSeedsFirst)
    self.wndSeedBag:SetNewItemOverlaySprite("")

    self.timerDisplaySeedBag = ApolloTimer.Create(1, true, "OnDisplaySeedBagTimer", self)
    self.timerEnableSeedBag1 = ApolloTimer.Create(0.2, false, "OnEnableSeedBagTimer", self)
    self.timerEnableSeedBag2 = ApolloTimer.Create(0.5, false, "OnEnableSeedBagTimer", self)
  end
end

function EasyPlant:OnEnableSeedBagTimer()
  self.wndSeedBag:Enable(not self.wndSeedBag:IsEnabled())
  -- self.wndSeedBag:SetStyle("IgnoreMouse", false)
end

function EasyPlant:OnWindowManagementReady()
  Event_FireGenericEvent("WindowManagementAdd", { wnd = self.wndMain, strName = "EasyPlant" })
  if (self.nLastZoneId == 0) then
    self:OnSubZoneChanged(GameLib.GetCurrentZoneId())
  end
end

function EasyPlant:OnEp2()
  --Print(tostring(self.eventsActive))
  Print(self.nLastZoneId)
  Print(tostring(self.eventsActive))
  Print(tostring(self.nToPlantFertileGroundId))
end

-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
-- e.g. local kiExampleVariableMax = 999

-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function EasyPlant:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self

  -- initialize variables here

  return o
end

function EasyPlant:Init()
  local bHasConfigureFunction = false
  local strConfigureButtonText = ""
  local tDependencies = {-- "UnitOrPackageName",
  }

  Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end

-----------------------------------------------------------------------------------------------
-- EasyPlant OnLoad
-----------------------------------------------------------------------------------------------
function EasyPlant:OnShowHappyGardener(override)

  -- Print("OnShowHappyGardener")
  if (self.wndMain:IsVisible() and override == false) then
    return
  end

  local nSeedCount = 0
  local tInventoryItems = GameLib.GetPlayerUnit():GetInventoryItems()
  for i, itemInventory in ipairs(tInventoryItems) do
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

  local nLeft, nTop, nRight, nBottom = self.wndMain:GetAnchorOffsets()
  self.wndMain:SetAnchorOffsets(nLeft, nTop, (nLeft) + (nSeedCount * N_BAG_WINDOWS_SQUARE_SIZE + N_BAG_WINDOWS_SQUARE_SIZE), nBottom)

  self.wndSeedBag:SetBoxesPerRow(nSeedCount)
end

function EasyPlant:OnMouseButtonDown()

  if (not self.wndSeedBag:IsEnabled()) then
    return
  end

  local unitTarget = GameLib.GetTargetUnit()
  if unitTarget and self:IsFertileGround(unitTarget:GetName()) then
    self.nToPlantFertileGroundId = unitTarget:GetId()
  end

  if (self.nToPlantFertileGroundId == 0) then

    local nFertileGroundId = self:GetToPlantUnitId()
    if (nFertileGroundId > 0) then
      self.nToPlantFertileGroundId = nFertileGroundId
    else
      return
    end
  end

  self.tExistingFertileGrounds[self.nToPlantFertileGroundId][STR_FERTILE_GROUND_TABLE_TIME] = GameLib.GetGameTime()
  GameLib.SetTargetUnit(self.tExistingFertileGrounds[self.nToPlantFertileGroundId][STR_FERTILE_GROUND_TABLE_UNIT])
  self.nToPlantFertileGroundId = 0
  self.timerEnableSeedBag1:Start()
  self.timerEnableSeedBag2:Start()
end

function EasyPlant:OnChangeWorld()
  if (self.eventsActive == false) then
    self:ToggleEvents(true)
  end
end

function EasyPlant:OnSubZoneChanged(nZoneId, pszZoneName)

  -- Print("nZoneId: " .. tostring(nZoneId) .. "; self.nLastZoneId: " .. self.nLastZoneId)

  if (nZoneId == 0) then
    return
  end

  if (nZoneId == N_HOUSE_PLOT_ID and self.nLastZoneId ~= N_HOUSE_PLOT_ID) then
    if (not self.eventsActive) then
      self:ToggleEvents(true)
    end
    self.timerDisplaySeedBag:Start()

  elseif (nZoneId ~= N_HOUSE_PLOT_ID) then

    self.tExistingFertileGrounds = {}
    self:ToggleEvents(false)
    self.timerDisplaySeedBag:Stop()
  end
  self.nLastZoneId = nZoneId
end

function EasyPlant:OnUpdateInventory()
  --Print("updateinv")
  if (self.nToPlantFertileGroundId == 0) then
    local nToPlantFertileGroundId = self:GetToPlantUnitId()
    if (nToPlantFertileGroundId > 0) then
      self.nToPlantFertileGroundId = nToPlantFertileGroundId
    end
  end

  if (self.nToPlantFertileGroundId and self.nToPlantFertileGroundId > 0) then
    self:OnShowHappyGardener(true)
  end
end

function EasyPlant:IsFertileGround(strName)

  return strName == Apollo.GetString(N_FERTILE_GROUND_STRING_ID) -- or strName == Apollo.GetString(N_FERTILE_GROUND_UNKNOWN_STRING_ID)
end


function EasyPlant:OnUnitCreated(unit)

  if ((unit) and (self:IsFertileGround(unit:GetName())) and (unit:GetType() == STR_FERTILE_GROUND_TYPE) and (self.tExistingFertileGrounds[unit:GetId()] == nil)) then
    --Print("watching")
    self.tExistingFertileGrounds[unit:GetId()] = {}
    self.tExistingFertileGrounds[unit:GetId()][STR_FERTILE_GROUND_TABLE_UNIT] = unit
  end
end

function EasyPlant:DistanceToUnit(unit)

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

function EasyPlant:GetToPlantUnitId()
  local nDistanceToFertileGround, nCurtime

  -- Print("tExistingFertileGrounds: " .. table.tostring(self.tExistingFertileGrounds))

  for i, tCurrentUnitInfo in pairs(self.tExistingFertileGrounds) do
    nDistanceToFertileGround = self:DistanceToUnit(tCurrentUnitInfo[STR_FERTILE_GROUND_TABLE_UNIT])
    nCurtime = GameLib.GetGameTime()

    -- Print ("distance: " .. distance .. "; curunit[STR_FERTILE_GROUND_TABLE_TIME]: " .. tostring(curunit[STR_FERTILE_GROUND_TABLE_TIME]) .. "; " .. tostring(self:IsFertileGround(curunit[STR_FERTILE_GROUND_TABLE_UNIT]:GetName())))
    if (nDistanceToFertileGround < N_FERTILE_GROUND_MAX_DISTANCE and (tCurrentUnitInfo[STR_FERTILE_GROUND_TABLE_TIME] == nil or nCurtime - tCurrentUnitInfo[STR_FERTILE_GROUND_TABLE_TIME] > 1) and self:IsFertileGround(tCurrentUnitInfo[STR_FERTILE_GROUND_TABLE_UNIT]:GetName())) then
      return i
    end
  end
  return 0
end

function EasyPlant:OnDisplaySeedBagTimer()

  if (not GameLib.GetPlayerUnit()) then return end

  local nToPlantUnitId = self:GetToPlantUnitId()

  if (nToPlantUnitId > 0) then
    self.nToPlantFertileGroundId = nToPlantUnitId
    self:OnShowHappyGardener(false)
  else
    self:CloseSeedBagWindow()
  end
end


-----------------------------------------------------------------------------------------------
-- EasyPlant Functions
-----------------------------------------------------------------------------------------------
-- Define general functions here


-----------------------------------------------------------------------------------------------
-- EasyPlantForm Functions
-----------------------------------------------------------------------------------------------
-- when the OK button is clicked
function EasyPlant:OnGenerateTooltip(wndControl, wndHandler, tType, item)

  if wndControl ~= wndHandler then return end
  wndControl:SetTooltipDoc(nil)
  if item ~= nil then
    local itemEquipped = item:GetEquippedItemForItemType()
    Tooltip.GetItemTooltipForm(self, wndControl, item, { bPrimary = true, bSelling = false, itemCompare = itemEquipped })
  end
end

function EasyPlant:TempClose(wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY, bDoubleClick, bStopPropagation)
  self.timerDisplaySeedBag:Stop()
  self:ToggleEvents(false)
  self.nLastZoneId = 0
  self:CloseSeedBagWindow()
end

-----------------------------------------------------------------------------------------------
-- EasyPlant Instance
-----------------------------------------------------------------------------------------------
local EasyPlantInst = EasyPlant:new()
EasyPlantInst:Init()


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