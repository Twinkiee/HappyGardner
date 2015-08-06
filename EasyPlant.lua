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


function EasyPlant:Events(activate)
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

  self.watching = {}
  self.arPreloadUnits = {}


  Apollo.RegisterEventHandler("SubZoneChanged", "OnSubZoneChanged", self)
  Apollo.RegisterEventHandler("ChangeWorld", "OnChangeWorld", self)
  self:Events(true)

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

    -- local x, y = Apollo.GetScreenSize()
    -- self.wndMain:SetAnchorOffsets((x / 2), (y / 2) - 45, (x / 2), (y / 2))
    -- if the xmlDoc is no longer needed, you should set it to nil
    -- self.xmlDoc = nil
    self.nLastZoneId = 0
    self.unit = 0
    self.toplant = 0
    self.wndSeedBag = self.wndMain:FindChild("MainBagWindow")

    Apollo.RegisterSlashCommand("ep", "OnEp", self)
    Apollo.RegisterSlashCommand("ep2", "OnEp2", self)

    self.wndSeedBag:SetSort(true)
    self.wndSeedBag:SetItemSortComparer(fnSortSeedsFirst)
    self.wndSeedBag:SetNewItemOverlaySprite("")

    self.wndSeedBag:SetStyle("IgnoreMouse", false)
    self.timerDisplaySeedBag = ApolloTimer.Create(1.000, true, "OnDisplaySeedBagTimer", self)
    self.timerEnableSeedBag = ApolloTimer.Create(0.4, false, "OnEnableSeedBagTimer", self)
    -- self.BlockTimerStart = ApolloTimer.Create(0.1, false, "OnBlockTimer", self)
  end
end

function EasyPlant:OnEnableSeedBagTimer()
  -- self.wndSeedBag:Enable(not self.wndSeedBag:IsEnabled())
  self.wndSeedBag:SetStyle("IgnoreMouse", false)
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
function EasyPlant:OnEp(override)

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
  if (nSeedCount < 1) then
    self.wndMain:Close()
    return
  end

  if (not self.wndMain:IsVisible()) then

    self.wndMain:Show(true, true)
  end

  local bagwindow = self.wndMain:FindChild("MainBagWindow")
  --Print("repainting")
  local multi = 47

  local nLeft, nTop, nRight, nBottom = self.wndMain:GetAnchorOffsets()
  self.wndMain:SetAnchorOffsets(nLeft, nTop, (nLeft) + (nSeedCount * N_BAG_WINDOWS_SQUARE_SIZE + N_BAG_WINDOWS_SQUARE_SIZE), nBottom)

  bagwindow:SetSquareSize(N_BAG_SQUARE_SIZE, N_BAG_SQUARE_SIZE)
  bagwindow:SetBoxesPerRow(nSeedCount)
end

function EasyPlant:OnMouseButtonDown()

  --[[
  if (not self.wndSeedBag:IsEnabled()) then
    return
  end
  ]]

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
  --Print(self.nToPlantFertileGroundId)
  self.watching[self.nToPlantFertileGroundId][STR_FERTILE_GROUND_TABLE_TIME] = GameLib.GetGameTime()
  GameLib.SetTargetUnit(self.watching[self.nToPlantFertileGroundId][STR_FERTILE_GROUND_TABLE_UNIT])
  self.nToPlantFertileGroundId = 0

  self.wndSeedBag:SetStyle("IgnoreMouse", true)
  self.timerEnableSeedBag:Start()
end

function EasyPlant:OnChangeWorld()
  if (self.eventsActive == false) then
    self:Events(true)
  end
end

function EasyPlant:OnSubZoneChanged(nZoneId, pszZoneName)

  Print("nZoneId: " .. tostring(nZoneId) .. "; self.nLastZoneId: " .. self.nLastZoneId)

  if (nZoneId == 0) then
    return
  end

  if (nZoneId == N_HOUSE_PLOT_ID and self.nLastZoneId ~= N_HOUSE_PLOT_ID) then
    if (not self.eventsActive) then
      self:Events(true)
    end
    self.timerDisplaySeedBag:Start()

  elseif (nZoneId ~= N_HOUSE_PLOT_ID) then

    self.watching = {}
    self:Events(false)
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
    --Print("execute")
    self:OnEp(true)
  end
end

function EasyPlant:IsFertileGround(strName)

  return strName == Apollo.GetString(N_FERTILE_GROUND_STRING_ID) or strName == Apollo.GetString(N_FERTILE_GROUND_UNKNOWN_STRING_ID)
end


function EasyPlant:OnUnitCreated(unit)

  if ((unit) and (self:IsFertileGround(unit:GetName())) and (unit:GetType() == STR_FERTILE_GROUND_TYPE) and (self.watching[unit:GetId()] == nil)) then
    --Print("watching")
    self.watching[unit:GetId()] = {}
    self.watching[unit:GetId()][STR_FERTILE_GROUND_TABLE_UNIT] = unit
  end
end


--[[
function EasyPlant:OnUnitDestroyed(unit)
  if ((unit) and (self.watching[unit:GetId()])) then
    self.watching[unit:GetId()] = nil
  end
end
]]


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
  local distance, curtime

  for i, curunit in pairs(self.watching) do
    distance = self:DistanceToUnit(curunit[STR_FERTILE_GROUND_TABLE_UNIT])
    curtime = GameLib.GetGameTime()

    -- Print ("distance: " .. distance .. "; curunit[STR_FERTILE_GROUND_TABLE_TIME]: " .. tostring(curunit[STR_FERTILE_GROUND_TABLE_TIME]) .. "; " .. tostring(self:IsFertileGround(curunit[STR_FERTILE_GROUND_TABLE_UNIT]:GetName())))
    if (distance < N_FERTILE_GROUND_MAX_DISTANCE and (curunit[STR_FERTILE_GROUND_TABLE_TIME] == nil or curtime - curunit[STR_FERTILE_GROUND_TABLE_TIME] > 1) and self:IsFertileGround(curunit[STR_FERTILE_GROUND_TABLE_UNIT]:GetName())) then
      return i
    end
  end
  return 0
end

function EasyPlant:OnDisplaySeedBagTimer()

  if (not GameLib.GetPlayerUnit()) then return end

  local toplant = self:GetToPlantUnitId()

  -- Print("OnDisplaySeedBagTimer: " .. toplant)

  if (toplant > 0) then
    self.nToPlantFertileGroundId = toplant
    self:OnEp(false)
  else
    self.wndMain:Close()
  end

  --Print("timer")
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
        -- Tooltip.GetItemTooltipForm(self, wndControl, itemEquipped, {bPrimary = false, bSelling = false, itemCompare = item})
    end
end

function EasyPlant:TempClose(wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY, bDoubleClick, bStopPropagation)
    self.timerDisplaySeedBag:Stop()
    self:Events(false)
    self.nLastZoneId = 0
    self.wndMain:Close()
end

-----------------------------------------------------------------------------------------------
-- EasyPlant Instance
-----------------------------------------------------------------------------------------------
local EasyPlantInst = EasyPlant:new()
EasyPlantInst:Init()
