local Utils = require "utils"
local MarketDB = require "marketDB"
local WorldInteraction = {}

Collectibles = {
    ["Marked"] = {
        ["Object.Property.Mark.FBI"] = true,
        ["Object.Property.Mark.Police"] = true,
        ["Object.Property.Mark.Bandits"] = true,
        ["Object.Property.Mark.BanditCorpA"] = true,
        ["Object.Property.Mark.BanditCorpB"] = true,
        ["Object.Property.Mark.Custom"] = true,
    },
    ["Coin"] = {
        ["Object.Property.Denomination.Misc.Pitcoin"] = true,
        ["Object.Property.Denomination.Misc.Legionnare"] = true,
        ["Object.Property.Denomination.Misc.Liberty"] = true,
        ["Object.Property.Denomination.Misc.Pirate"] = true,
        ["Object.Property.Denomination.Misc.AshokaLion"] = true,
        ["Object.Property.Denomination.Misc.Fugio"] = true,
        ["Object.Property.Denomination.Misc.Edokoban"] = true,
        ["Object.Property.Denomination.Misc.RetroPixel"] = true,
    },
    ["Bill"] = {
        ["Object.Property.Denomination.EUR.100"] = true,
        ["Object.Property.Denomination.EUR.50"] = true,
        ["Object.Property.Denomination.EUR.20"] = true,
        ["Object.Property.Denomination.JPY.10000"] = true,
        ["Object.Property.Denomination.JPY.5000"] = true,
        ["Object.Property.Denomination.JPY.1000"] = true,
        ["Object.Property.Denomination.USD.100"] = true,
        ["Object.Property.Denomination.USD.50"] = true,
        ["Object.Property.Denomination.USD.20"] = true,
        ["Object.Property.Denomination.USD.10"] = true,
    }
}
WorldInteraction.Collectibles = Collectibles

-- 24 location
function WorldInteraction:OnCollectible()
    ExecuteInGameThread(function()
        local pre, post = RegisterHook("/Game/Core/Collectibles/BP_CollectibleSubsystem.BP_CollectibleSubsystem_C:RegisterMarkCollectibles", function(_self, Container)
            Utils.LoopGameplayTagContainer(Collectibles:get(), function(tag, index)
                if self.Collectibles["Marked"][tag.TagName:ToString()] then
                    self.Collectibles["Marked"][tag.TagName:ToString()] = false
                    local endOfTag = tag.TagName:ToString():match("^Object.Property.Mark.(.+)$")
                    self.Reward:Check("WorldCollectiblesMarked" .. endOfTag)
                end
            end)
        end)
        Utils.OnQuit(function()
            local functionName = "/Game/Core/Collectibles/BP_CollectibleSubsystem.BP_CollectibleSubsystem_C:RegisterMarkCollectibles"
            UnregisterHook(functionName, pre, post)
        end)
        local pre2, post2 = RegisterHook("/Game/Core/Collectibles/BP_CollectibleSubsystem.BP_CollectibleSubsystem_C:RegisterCollectibles", function(_self, Container)
            Utils.LoopGameplayTagContainer(Collectibles:get(), function(tag, index)
                if self.Collectibles["Bill"][tag.TagName:ToString()] then
                    self.Collectibles["Bill"][tag.TagName:ToString()] = false
                    local endOfTag = tag.TagName:ToString():match("^Object.Property.Denomination.(.+)$")
                    self.Reward:Check("WorldCollectiblesBill" .. endOfTag)
                end

                if self.Collectibles["Coin"][tag.TagName:ToString()] then
                    self.Collectibles["Coin"][tag.TagName:ToString()] = false
                    local endOfTag = tag.TagName:ToString():match("^Object.Property.Denomination.Misc.(.+)$")
                    self.Reward:Check("WorldCollectiblesCoin" .. endOfTag)
                end
            end)
        end)
        Utils.OnQuit(function()
            local functionName = "/Game/Core/Collectibles/BP_CollectibleSubsystem.BP_CollectibleSubsystem_C:RegisterCollectibles"
            UnregisterHook(functionName, pre2, post2)
        end)
    end)
end

-- 5 Locations
local Interactions = {
    ["RelaxArea"] = true,
    ["UpperArea"] = true,
    ["Dunked"] = true,
    ["OutOfBound"] = true,
    ["MoneyGun"] = true,
}
WorldInteraction.Interactions = Interactions

function WorldInteraction:OnUnlockWAll()
    ExecuteInGameThread(function()
        local pre, post = RegisterHook("/Game/Core/Rules/BP_TheMainGameMode.BP_TheMainGameMode_C:OnWorldEventRegistered", function(_self, Tag)

            if Tag:get().TagName:ToString() == "World.Area.Relax" and self.Interactions["RelaxArea"] then
                    self.Interactions["RelaxArea"] = false
                    self.Reward:Check("WorldInteractionsRelaxArea")
            end

            if Tag:get().TagName:ToString() == "World.Area.Upper" and self.Interactions["UpperArea"] then
                    self.Interactions["UpperArea"] = false
                    self.Reward:Check("WorldInteractionsUpperArea")
            end
        end)
        Utils.OnQuit(function()
            local functionName = "/Game/Core/Rules/BP_TheMainGameMode.BP_TheMainGameMode_C:OnWorldEventRegistered"
            UnregisterHook(functionName, pre, post)
        end)
    end)

end

function WorldInteraction:OnDunk()
    ExecuteInGameThread(function()
        local pre, post = RegisterHook("/Game/Core/System/Achievements/BP_AchievementHandler_SlamDunkKingpin.BP_AchievementHandler_SlamDunkKingpin_C:OnScored", function(_self, score)
            if score:get() == 200 and self.Interactions["Dunked"] then
                self.Interactions["Dunked"] = false
                self.Reward:Check("WorldInteractionsDunked")
            end
        end)
        Utils.OnQuit(function()
            local functionName = "/Game/Core/System/Achievements/BP_AchievementHandler_SlamDunkKingpin.BP_AchievementHandler_SlamDunkKingpin_C:OnScored"
            UnregisterHook(functionName, pre, post)
        end)
    end)

end

function WorldInteraction:OnOutOfBound()
    ExecuteInGameThread(function()
        local pre, post = RegisterHook("/Game/Core/System/Achievements/BP_AchievementHandler_OutOfBounds.BP_AchievementHandler_OutOfBounds_C:OnWorldEventRegistered", function(_self, tag)
            if tag:get().TagName:ToString() == "World.Event.Ending.GotOut" and self.Interactions["OutOfBound"] then
                self.Interactions["OutOfBound"] = false
                self.Reward:Check("WorldInteractionsOutOfBound")
            end
        end)

        Utils.OnQuit(function()
            local functionName = "/Game/Core/System/Achievements/BP_AchievementHandler_OutOfBounds.BP_AchievementHandler_OutOfBounds_C:OnWorldEventRegistered"
            UnregisterHook(functionName, pre, post)
        end)
    end)
end

function WorldInteraction:OnMakeItRain()
    ExecuteInGameThread(function()
        local pre, post = RegisterHook("/Game/Core/System/Achievements/BP_AchievementHandler_Rainmaker.BP_AchievementHandler_Rainmaker_C:OnOrderDeliveryReady", function(_self, order)

            local orderI = order:get()

            if not orderI or not orderI.Products then
                return
            end

            for i = 1, #orderI.Products do
                local product = orderI.Products[i]
                if product == nil then
                    break
                end

                local moneyGunData = MarketDB["BP_MoneyGun_C"]
                if moneyGunData and Utils.compareGuids(MarketDB["BP_MoneyGun_C"].Guid, product.ProductId) and self.Interactions["MoneyGun"] then
                        self.Interactions["MoneyGun"] = false
                        self.Reward:Check("WorldInteractionsMoneyGun")
                end
            end
        end)
        Utils.OnQuit(function()
            local functionName = "/Game/Core/System/Achievements/BP_AchievementHandler_Rainmaker.BP_AchievementHandler_Rainmaker_C:OnOrderDeliveryReady"
            UnregisterHook(functionName, pre, post)
        end)
    end)
end

function WorldInteraction:AlterInitConsumables()
    local tapes = FindAllOf("BP_MoneyTape_C")
    if tapes ~= nil and #tapes > 0 then
        for i = 1, #tapes do
            local tape = tapes[i]
            tape.ConsumableObject.MaxUses = 250
            tape.ConsumableObject.StartingUses = 250
            tape.ConsumableObject:SetUsesLeft(250, true)
        end
    end

    local wraps = FindAllOf("BP_ClingWrap_C")
    if wraps ~= nil and #wraps > 0 then
        for i = 1, #wraps do
            local wrap = wraps[i]
            wrap.ConsumableObject.MaxUses = 250
            wrap.ConsumableObject.StartingUses = 250
            wrap.ConsumableObject:SetUsesLeft(250, true)
        end
    end
end
function WorldInteraction:LoadCollectibles(_Collectibles)
    self.Collectibles = _Collectibles
end

function WorldInteraction:LoadInteractions(_Interactions)
    self.Interactions = _Interactions
end

function WorldInteraction:Init(ctx)
    self.Save = ctx.Save
    self.Reward = ctx.Reward
end

function WorldInteraction:ListenAllEvents()
    self:OnCollectible()
    self:OnUnlockWAll()
    self:OnDunk()
    self:OnOutOfBound()
    self:OnMakeItRain()
end

return WorldInteraction
