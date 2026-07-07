local Utils = require "utils"

local StackSize = {}
local marketSubsystem = "/Game/Core/Market/BP_MarketSubsystem.BP_MarketSubsystem_C"

local function generateBundle(MaxStackSize)
    return {
        stackSize = MaxStackSize,
        BundleReplacements = {
            [100] = MaxStackSize,
            [50]  = MaxStackSize / 2,
            [20]  = MaxStackSize / 5,
            [10]  = MaxStackSize / 10,
        }
    }
end

local sizeUpgrade = {
    [0] = generateBundle(20),
    [1] = generateBundle(50),
    [2] = generateBundle(100),
    [3] = generateBundle(200),
    [4] = generateBundle(500),
}

local counterBlueprints = {
    ["BP_MoneyCounterTier3"] = { path = "/Game/Core/Objects/BP_MoneyCounterTier3.BP_MoneyCounterTier3_C", key = "BP_MoneyCounterTier3", hooks = { main = nil, pre = nil, post = nil} },
    ["BP_MoneyCounter"] = { path = "/Game/Core/Objects/BP_MoneyCounter.BP_MoneyCounter_C", key = "BP_MoneyCounter", hooks = { main = nil, post = nil} },
    ["BP_MarkedCounter"] = { path = "/Game/Core/Objects/BP_MarkedCounter.BP_MarkedCounter_C", key = "BP_MarkedCounter", hooks = { main = nil, post = nil} }, 
    ["BP_MoneyCounterTier2_Euro"] = { path = "/Game/Core/Objects/BP_MoneyCounterTier2_Euro.BP_MoneyCounterTier2_Euro_C", key = "BP_MoneyCounterTier2_Euro", hooks =  { main = nil, post = nil} }, 
    ["BP_MoneyCounterTier2_Yen"] = { path = "/Game/Core/Objects/BP_MoneyCounterTier2_Yen.BP_MoneyCounterTier2_Yen_C", key = "BP_MoneyCounterTier2_Yen", hooks =  { main = nil, post = nil} }, 
    ["BP_MoneyCounterTier2"] = { path = "/Game/Core/Objects/BP_MoneyCounterTier2.BP_MoneyCounterTier2_C", key = "BP_MoneyCounterTier2", hooks = { main = nil, post = nil} },
}

local CurrentUpgradeLevel = 0
StackSize.CurrentUpgradeLevel = CurrentUpgradeLevel

function StackSize:Init(ctx)
    self.Save = ctx.Save
    self.MarketLogic = ctx.MarketLogic
end

local function counterConfig(incomingFactor, upgradeLevel)
    local currentConfig = sizeUpgrade[upgradeLevel]
    return {
        MaxIncomingBillsCount = currentConfig.stackSize * incomingFactor,
        MaxOutgoingBillsCount = currentConfig.stackSize,
        BundleReplacements = currentConfig.BundleReplacements
    }
end
local function generateTier3Config(upgradeLevel) return counterConfig(10, upgradeLevel) end
local function generateTier2Config(upgradeLevel) return counterConfig(7.5, upgradeLevel) end
local function generateTier1Config(upgradeLevel) return counterConfig(5, upgradeLevel) end

function StackSize:changeInOutSettings(upgradeLevel)
    ExecuteInGameThread(function()
        -- Loop to force load everything
        self.MarketLogic:LoopProducts(function(product)
            print('[Randomizer] Loading all market product', product)
        end)
        Utils.DelayedCall(function()
            ExecuteInGameThread(function()

                local config =  {
                    BP_MoneyCounter = generateTier1Config(upgradeLevel),
                    BP_MarkedCounter = generateTier1Config(upgradeLevel),
                    BP_MoneyCounterTier2_Euro = generateTier2Config(upgradeLevel),
                    BP_MoneyCounterTier2_Yen = generateTier2Config(upgradeLevel),
                    BP_MoneyCounterTier2 = generateTier2Config(upgradeLevel),
                    BP_MoneyCounterTier3 = generateTier3Config(upgradeLevel),
                }
                for _, bp in pairs(counterBlueprints) do

                    local moneyCounterBP = bp.path
                    local bpConfig = config[bp.key]

                    local allCounter = FindAllOf(bp.key .. '_C')
                    if allCounter ~= nil and #allCounter > 0 then
                        for i=1, #allCounter do
                            local counter = allCounter[i]
                            if counter == nil then
                                break
                            end

                            if counter.MaxIncomingBillsCount ~= nil then
                                counter.MaxIncomingBillsCount = bpConfig.MaxIncomingBillsCount
                            end
                            
                            if counter.MaxOutgoingBillsCount ~= nil then
                                counter.MaxOutgoingBillsCount = bpConfig.MaxOutgoingBillsCount
                            end

                            i = i + 1
                        end
                    end

                    LoadAsset(moneyCounterBP)
                    local mainPre, mainPost = RegisterHook(moneyCounterBP .. ":Initialize", function(_self)
                        local counter = _self:get()

                        if not counter or not counter:IsValid() then
                            return
                        end
                                        
                        if counter.MaxIncomingBillsCount ~= nil then
                            counter.MaxIncomingBillsCount = bpConfig.MaxIncomingBillsCount
                        end
                        
                        if counter.MaxOutgoingBillsCount ~= nil then
                            counter.MaxOutgoingBillsCount = bpConfig.MaxOutgoingBillsCount
                        end
                    end)
                    if counterBlueprints[bp.key].hooks.main ~= nil then
                        local functionName = moneyCounterBP .. ":Initialize"
                        pcall(function() 
                            UnregisterHook(functionName, counterBlueprints[bp.key].hooks.main.pre, counterBlueprints[bp.key].hooks.main.post)
                        end)
                    end
                    counterBlueprints[bp.key].hooks.main = { pre = mainPre, post = mainPost }

                    if bp.key == "BP_MoneyCounterTier3" then

                        local lastSlotIndex = nil
                        local lastCountSetting = nil
                        
                        local prePre, prePost = RegisterHook(moneyCounterBP .. ":GetCountSetting", function(_self, slotIndex, CountSetting)
                            if slotIndex then
                                local currentSlotIndex = slotIndex:get()
                                if currentSlotIndex ~= lastSlotIndex then
                                    lastSlotIndex = currentSlotIndex
                                end
                            end
                        end, true)
                        if counterBlueprints[bp.key].hooks.pre ~= nil then
                            local functionName = moneyCounterBP .. ":GetCountSetting"
                            pcall(function() 
                                UnregisterHook(functionName, counterBlueprints[bp.key].hooks.pre.pre, counterBlueprints[bp.key].hooks.pre.post)
                            end)
                        end
                        counterBlueprints[bp.key].hooks.pre = { pre = prePre, post = prePost }

                        local postPre, postPost = RegisterHook(moneyCounterBP .. ":GetCountSetting", function(_self, slotIndex, CountSetting)
                            if CountSetting then
                                local currentCountSetting = CountSetting:get()
                                if bpConfig.BundleReplacements and bpConfig.BundleReplacements[currentCountSetting] then
                                    local newVal = bpConfig.BundleReplacements[currentCountSetting]
                                    CountSetting:set(newVal)
                                elseif currentCountSetting ~= lastCountSetting then
                                    lastCountSetting = currentCountSetting
                                end
                            end
                        end)
                        if counterBlueprints[bp.key].hooks.post ~= nil then
                            local functionName = moneyCounterBP .. ":GetCountSetting"
                            pcall(function() 
                                UnregisterHook(functionName, counterBlueprints[bp.key].hooks.post.pre, counterBlueprints[bp.key].hooks.post.post)
                            end)
                        end
                        counterBlueprints[bp.key].hooks.post = { pre = postPre, post = postPost }
                    else
                        
                        local lastCountSetting = nil
                        
                        local postPre, postPost = RegisterHook(moneyCounterBP .. ":GetCountSetting", function(_self, CountSetting)
                            if CountSetting then
                                local currentCountSetting = CountSetting:get()
                                if bpConfig.BundleReplacements and bpConfig.BundleReplacements[currentCountSetting] then
                                    local newVal = bpConfig.BundleReplacements[currentCountSetting]
                                    CountSetting:set(newVal)
                                elseif currentCountSetting ~= lastCountSetting then
                                    lastCountSetting = currentCountSetting
                                end
                            end
                        end)
                        if counterBlueprints[bp.key].hooks.post ~= nil then
                            local functionName = moneyCounterBP .. ":GetCountSetting"
                            pcall(function() 
                                UnregisterHook(functionName, counterBlueprints[bp.key].hooks.post.pre, counterBlueprints[bp.key].hooks.post.post)
                            end)
                        end

                        counterBlueprints[bp.key].hooks.post = { pre = postPre, post = postPost }
                    end
                end
            end)
        end, 250)
    end)
    Utils.OnQuit(function()
        for _, bp in pairs(counterBlueprints) do
            local moneyCounterBP = bp.path

            if counterBlueprints[bp.key].hooks.main ~= nil then
                local functionName = moneyCounterBP .. ":Initialize"
                pcall(function() 
                    UnregisterHook(functionName, counterBlueprints[bp.key].hooks.main.pre, counterBlueprints[bp.key].hooks.main.post)
                end)
            end

            if bp.key == "BP_MoneyCounterTier3" then
                if counterBlueprints[bp.key].hooks.pre ~= nil then
                    local functionName = moneyCounterBP .. ":GetCountSetting"
                    pcall(function() 
                        UnregisterHook(functionName, counterBlueprints[bp.key].hooks.pre.pre, counterBlueprints[bp.key].hooks.pre.post)
                    end)
                end
                if counterBlueprints[bp.key].hooks.post ~= nil then
                    local functionName = moneyCounterBP .. ":GetCountSetting"
                    pcall(function() 
                        UnregisterHook(functionName, counterBlueprints[bp.key].hooks.post.pre, counterBlueprints[bp.key].hooks.post.post)
                    end)
                end
            else
                if counterBlueprints[bp.key].hooks.post ~= nil then
                    local functionName = moneyCounterBP .. ":GetCountSetting"
                    pcall(function() 
                        UnregisterHook(functionName, counterBlueprints[bp.key].hooks.post.pre, counterBlueprints[bp.key].hooks.post.post)
                    end)
                end
            end
        end
    end)
end

local stackBlueprints = {
    ["BP_MoneyPack_C"] = { path = "/Game/Core/Objects/BP_MoneyPack.BP_MoneyPack_C", key = "BP_MoneyPack_C", hooks = nil },
    ["BP_MoneyStack_C"] = { path = "/Game/Core/Objects/BP_MoneyStack.BP_MoneyStack_C", key = "BP_MoneyStack_C", hooks = nil },
}

local function changeStackSize(upgradeLevel)
    ExecuteInGameThread(function()
        for _, bp in pairs(stackBlueprints) do
            local moneyStackBP = bp.path
            LoadAsset(moneyStackBP)

            if stackBlueprints[bp.key].hooks ~= nil then
                local functionName = moneyStackBP .. ":Initialize"
                pcall(function() 
                    UnregisterHook(functionName, stackBlueprints[bp.key].hooks.pre, stackBlueprints[bp.key].hooks.post)
                end)
            end

            local pre, post = RegisterHook(moneyStackBP .. ":Initialize", function(_self)
                local pack = _self:get()
                if pack then
                    local comp = pack.CompositionObject
                    if comp then
                        comp.MaxInnerStatesCount = sizeUpgrade[upgradeLevel].stackSize
                    end
                end
            end)
            stackBlueprints[bp.key].hooks = { pre = pre, post = post }
        end
    end)
    Utils.OnQuit(function()
         for _, bp in pairs(stackBlueprints) do
            local moneyStackBP = bp.path
            if stackBlueprints[bp.key].hooks ~= nil then
                local functionName = moneyStackBP .. ":Initialize"
                pcall(function() 
                    UnregisterHook(functionName, stackBlueprints[bp.key].hooks.pre, stackBlueprints[bp.key].hooks.post)
                end)
            end
        end
    end)
end

function StackSize:OnStart()
    self.CurrentUpgradeLevel = 0
    changeStackSize(self.CurrentUpgradeLevel)
    self:changeInOutSettings(self.CurrentUpgradeLevel)
end

function StackSize:LevelUpStacks()
    self.CurrentUpgradeLevel = self.CurrentUpgradeLevel + 1
    changeStackSize(self.CurrentUpgradeLevel)
    self:changeInOutSettings(self.CurrentUpgradeLevel)
end

function StackSize:LoadLevelUpStatus(upgradeLevel)
    self.CurrentUpgradeLevel = upgradeLevel
    changeStackSize(self.CurrentUpgradeLevel)
    self:changeInOutSettings(self.CurrentUpgradeLevel)
end

function StackSize:HandleReward()
    self:LevelUpStacks()
    self.Save:OnChange()
end

return StackSize