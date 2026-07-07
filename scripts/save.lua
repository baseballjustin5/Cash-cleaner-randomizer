local Utils = require "utils"

local Save = {}

Save.SAVE_PATH = "ue4ss/Mods/Randomizer/Saved/state.lua"

function Save:Init(ctx)
    self.QuestLogic = ctx.QuestLogic
    self.StackSize = ctx.StackSize
    self.MarketLogic = ctx.MarketLogic
    self.WorldInteraction = ctx.WorldInteraction
    self.Reward = ctx.Reward
    self.Archipelago = ctx.Archipelago
    
    Utils.OnQuit(function()
        self:OnChange()
    end)
end

function Save:WriteSave(data)
    local f, err = io.open(self.SAVE_PATH, "w")
    if not f then
        return false
    end

    f:write("return ")
    f:write(Utils.Serialize(data))
    f:close()

    return true
end

function Save:Default()
    return {
        WorldInteraction = {
            Collectibles = self.WorldInteraction.Collectibles,
            Interactions = self.WorldInteraction.Interactions,
        },
        StackSize = {
            CurrentUpgradeLevel = self.StackSize.CurrentUpgradeLevel
        },
        QuestLogic = {
            CurrentUpgrades = self.QuestLogic.CurrentUpgrades,
            AvailableQuestBonuses = self.QuestLogic.AvailableQuestBonuses,
            CompletedSideQuests = self.QuestLogic.CompletedSideQuests,

            MaxCompletedSideQuests = self.QuestLogic.MaxCompletedSideQuests,
            CompletedSideQuestsIds = self.QuestLogic.CompletedSideQuestsIds,
            CompletedMainQuestsNames = self.QuestLogic.CompletedMainQuestsNames,
            ForceOpenPneumaticTube = self.QuestLogic.ForceOpenPneumaticTube,
            MaxDifficulty = self.QuestLogic.MaxDifficulty
        },
        MarketLogic = {
            Upgrades = self.MarketLogic.Upgrades,
            PriceSeed = self.MarketLogic.PriceSeed
        },
        Reward = {
            ExpectedReputation = self.Reward.ExpectedReputation
        },
        Archipelago = {
            CheckedLocation = self.Archipelago.CheckedLocation
        }
    }
end

function Save:ReadSave()
    local ok, data = pcall(dofile, self.SAVE_PATH)
    if ok and type(data) == "table" then
        print("[Randomizer] Save data loaded")
        return data
    end

    print("[Randomizer] Creating new save data")
    return self:Default()
end

function Save:LoadSave()
    local LoadedData = self:ReadSave()
    if LoadedData.WorldInteraction then
        self.WorldInteraction:LoadCollectibles(LoadedData.WorldInteraction.Collectibles)
        self.WorldInteraction:LoadInteractions(LoadedData.WorldInteraction.Interactions)
    end

    if LoadedData.StackSize then
        self.StackSize:LoadLevelUpStatus(LoadedData.StackSize.CurrentUpgradeLevel)
    end

    if LoadedData.QuestLogic then
        self.QuestLogic:SetCompletedSideQuest(LoadedData.QuestLogic.CompletedSideQuests)
        self.QuestLogic:SetMaxCompletedSideQuests(LoadedData.QuestLogic.MaxCompletedSideQuests)
        self.QuestLogic:LoadCompletedQuests(LoadedData.QuestLogic.CompletedMainQuestsNames, LoadedData.QuestLogic.CompletedSideQuestsIds)
        self.QuestLogic:LoadAvailableQuestBonuses(LoadedData.QuestLogic.AvailableQuestBonuses)
        self.QuestLogic:SetUpgrades(LoadedData.QuestLogic.CurrentUpgrades)
        self.QuestLogic:UpdateForceOpenTube(LoadedData.QuestLogic.ForceOpenPneumaticTube)
        self.QuestLogic:SetMaxDifficulty(LoadedData.QuestLogic.MaxDifficulty)
    end

    if LoadedData.MarketLogic then
        self.MarketLogic:SetMarketSeed(LoadedData.MarketLogic.PriceSeed)
        self.MarketLogic:LoadUpgrades(LoadedData.MarketLogic.Upgrades)
    end

    if LoadedData.Reward then
        self.Reward:SetExpectedReputation(LoadedData.Reward.ExpectedReputation)
    end

    if LoadedData.Archipelago then
        self.Archipelago:SetCheckedLocation(LoadedData.Archipelago.CheckedLocation)
    end
end


function Save:OnChange()
    local SaveData = {
        WorldInteraction = {
            Collectibles = self.WorldInteraction.Collectibles,
            Interactions = self.WorldInteraction.Interactions,
        },
        StackSize = {
            CurrentUpgradeLevel = self.StackSize.CurrentUpgradeLevel
        },
        QuestLogic = {
            CurrentUpgrades = self.QuestLogic.CurrentUpgrades,
            AvailableQuestBonuses = self.QuestLogic.AvailableQuestBonuses,
            CompletedSideQuests = self.QuestLogic.CompletedSideQuests,
            MaxCompletedSideQuests = self.QuestLogic.MaxCompletedSideQuests,
            CompletedSideQuestsIds = self.QuestLogic.CompletedSideQuestsIds,
            CompletedMainQuestsNames = self.QuestLogic.CompletedMainQuestsNames,
            ForceOpenPneumaticTube = self.QuestLogic.ForceOpenPneumaticTube,
            MaxDifficulty = self.QuestLogic.MaxDifficulty
        },
        MarketLogic = {
            Upgrades = self.MarketLogic.Upgrades,
            PriceSeed = self.MarketLogic.PriceSeed
        },
        Reward = {
            ExpectedReputation = self.Reward.ExpectedReputation
        },
        Archipelago = {
            CheckedLocation = self.Archipelago.CheckedLocation
        }
    }

    self:WriteSave(SaveData)
end
return Save