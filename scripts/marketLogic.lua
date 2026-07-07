local Utils = require "utils"
local MarketDB = require "marketDB"

local MarketLogic = {}

local Upgrades = {
    ["BP_MoneyGun_C"] = 0,
    ["BP_Washer_C"] = 0,
    ["BP_UVLamp_C"] = 0,
    ["BP_Dryer_C"] = 0,
    ["BP_MoneyCounter_C"] = 0,
    ["BP_MoneyCounterTier2_C"] = 0,
    ["BP_MoneyCounterTier2_Euro_C"] = 0,
    ["BP_MoneyCounterTier2_Yen_C"] = 0,
    ["BP_MoneyCounterTier3_C"] = 0,
    ["BP_Ladder_C"] = 0,
    ["BP_WorkbenchTool_Sponge_C"] = 0,
    ["BP_MarkedCounter_C"] = 0,
    ["BP_WorkbenchTool_FoamA_C"] = 0,
    ["BP_WorkbenchTool_FoamB_C"] = 0,
    ["BP_WorkbenchTool_FoamC_C"] = 0,
    ["BP_DetergentSourceComponent_C"] = 0,
    ["BP_DetergentSourceComponent_C2"] = 0,
    ["BP_DetergentSourceComponent_C3"] = 0,
    ["BP_BigWasher_C"] = 0,
    ["BP_StickerGun_C"] = 0,
    ["BP_PickupSensor_CoinCounter_C"] = 0   
}
MarketLogic.Upgrades = Upgrades

local UpgradeTargets = {
    ["BP_MoneyGun_C"] = { ["BP_MoneyGun_C"] = true},
    ["BP_Washer_C"] = { ["BP_Washer_C"] = true, ["BP_Washer_C_DLC_1"] = true, ["BP_Washer_C_DLC_2"] = true},
    ["BP_UVLamp_C"] = { ["BP_UVLamp_C"] = true, ["BP_UVLamp_Big_C"] = true },
    ["BP_Dryer_C"] = { ["BP_Dryer_C"] = true},
    ["BP_MoneyCounter_C"] = { ["BP_MoneyCounter_C"] = true},
    ["BP_MoneyCounterTier2_C"] = { ["BP_MoneyCounterTier2_C"] = true},
    ["BP_MoneyCounterTier2_Euro_C"] = { ["BP_MoneyCounterTier2_Euro_C"] = true},
    ["BP_MoneyCounterTier2_Yen_C"] = { ["BP_MoneyCounterTier2_Yen_C"] = true},
    ["BP_MoneyCounterTier3_C"] = { ["BP_MoneyCounterTier3_C"] = true},
    ["BP_Ladder_C"] = { ["BP_Ladder_C"] = true},
    ["BP_WorkbenchTool_Sponge_C"] = { ["BP_WorkbenchTool_Sponge_C"] = true},
    ["BP_MarkedCounter_C"] = { ["BP_MarkedCounter_C"] = true},
    ["BP_WorkbenchTool_FoamA_C"] = { ["BP_WorkbenchTool_FoamA_C"] = true},
    ["BP_WorkbenchTool_FoamB_C"] = { ["BP_WorkbenchTool_FoamB_C"] = true},
    ["BP_WorkbenchTool_FoamC_C"] = { ["BP_WorkbenchTool_FoamC_C"] = true},
    ["BP_DetergentSourceComponent_C"] = { ["BP_DetergentSourceComponent_C"] = true},
    ["BP_DetergentSourceComponent_C2"] = { ["BP_DetergentSourceComponent_C2"] = true},
    ["BP_DetergentSourceComponent_C3"] = {  ["BP_DetergentSourceComponent_C3"] = true},
    ["BP_BigWasher_C"] = { ["BP_BigWasher_C"] = true},
    ["BP_StickerGun_C"] = { ["BP_StickerGun_C"] = true},
    ["BP_PickupSensor_CoinCounter_C"] = { ["BP_PickupSensor_CoinCounter_C"] = true},
}

local BaseUpgradeLevels = {
    [0] = 32,
    [1] = 24,
    [2] = 16,
    [3] = 8
}

local HighUpgradeLevels = {
    [0] = 40,
    [1] = 32,
    [2] = 24,
    [3] = 16
}

local LowUpgradeLevels = {
    [0] = 24,
    [1] = 16,
    [2] = 8,
    [3] = 1
}

local UpgradesValues = {
    ["BP_MoneyGun_C"] = BaseUpgradeLevels,
    ["BP_Washer_C"] = BaseUpgradeLevels,
    ["BP_UVLamp_C"] = BaseUpgradeLevels,
    ["BP_Dryer_C"] = BaseUpgradeLevels,
    ["BP_MoneyCounter_C"] = LowUpgradeLevels,
    ["BP_MoneyCounterTier2_C"] = BaseUpgradeLevels,
    ["BP_MoneyCounterTier2_Euro_C"] = BaseUpgradeLevels,
    ["BP_MoneyCounterTier2_Yen_C"] = BaseUpgradeLevels,
    ["BP_MoneyCounterTier3_C"] = HighUpgradeLevels,
    ["BP_Ladder_C"] = LowUpgradeLevels,
    ["BP_WorkbenchTool_Sponge_C"] = BaseUpgradeLevels,
    ["BP_MarkedCounter_C"] = BaseUpgradeLevels,
    ["BP_WorkbenchTool_FoamA_C"] = LowUpgradeLevels,
    ["BP_WorkbenchTool_FoamB_C"] = BaseUpgradeLevels,
    ["BP_WorkbenchTool_FoamC_C"] = HighUpgradeLevels,
    ["BP_DetergentSourceComponent_C"] = LowUpgradeLevels,
    ["BP_DetergentSourceComponent_C2"] = BaseUpgradeLevels,
    ["BP_DetergentSourceComponent_C3"] = HighUpgradeLevels,
    ["BP_BigWasher_C"] = HighUpgradeLevels,
    ["BP_StickerGun_C"] = BaseUpgradeLevels,
    ["BP_PickupSensor_CoinCounter_C"] = LowUpgradeLevels   
}

MarketLogic.PriceSeed = os.time()

function MarketLogic:Init(ctx)
    self.Save = ctx.Save
    self.Reward = ctx.Reward
    self:SpyMarketOrder()
end

function MarketLogic:SetItemReputationReq(Product, ItemKey)
    for k, _v in pairs(UpgradeTargets[ItemKey]) do
        if Utils.compareGuids(MarketDB[k].Guid, Product.ProductId) then
            Product.ReputationRequirement = UpgradesValues[ItemKey][self.Upgrades[ItemKey]]
        end
    end
end

function MarketLogic:LoadUpgrades(Upgrades)
    self.Upgrades = Upgrades
    self:InitLimitation()
end

function MarketLogic:SetMarketSeed(seed)
    self.PriceSeed = seed
end

function MarketLogic:LoopProducts(Callback)
    local firstMarketSubsytem = FindFirstOf("BP_MarketSubsystem_C")
    if firstMarketSubsytem ~= nil and firstMarketSubsytem:IsValid() then
        local products = firstMarketSubsytem.MarketData.Products
        
        for i=1, #products do
            local product = products[i]
            if product == nil then
                break
            end
            Callback(product)
            i = i + 1
        end
    end
end
function MarketLogic:Upgrade(Target)
    self.Upgrades[Target] = self.Upgrades[Target] + 1
    self:LoopProducts(function(product)
        self:SetItemReputationReq(product, Target)
    end)
   
end

function MarketLogic:InitLimitation()
    math.randomseed(self.PriceSeed)
    self:LoopProducts(function(product)
        product.Price = math.ceil(product.Price * math.random(4, 25) / 10)
        for k, v in pairs(self.Upgrades) do
            self:SetItemReputationReq(product, k)
        end
    end)
end

function MarketLogic:SpyMarketOrder()
    local pre, post = RegisterHook("/Game/Core/Market/FL_Market.FL_Market_C:SpawnMarketOrder", function(_self, _order, _spawner, __WorldContext)
        local order = _order:get() 
        for i=1, #order.Products do
            local product = order.Products[i]
            if product == nil then
                break
            end
            -- Do Stuff
            i = i + 1
        end 

    end, true)
    Utils.OnQuit(function()
        local functionName = "/Game/Core/Market/FL_Market.FL_Market_C:SpawnMarketOrder"
        UnregisterHook(functionName, pre, post)
    end) 
end

function MarketLogic:SetMarketPriceFree()
    self:LoopProducts(function(product) 
        product.Price = 0  
    end)
end

function MarketLogic:HandleReward(reward)
    local UpgradeKey = reward:match("^Market_(.+)$")
    self:Upgrade(UpgradeKey)
    self.Save:OnChange()
end

return MarketLogic