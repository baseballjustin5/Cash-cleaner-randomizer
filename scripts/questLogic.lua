local Utils = require "utils"

local hookQuestSubsystem = "/Game/Core/Quests/System/BP_QuestSubsystem.BP_QuestSubsystem_C"

local QuestLogic = {}

local MoneyPacksPercentUpgrades = {
    [0] = { Min = 0, Max = 0, GlobalProb = 0 },
    [1] = { Min = 10, Max = 50, GlobalProb = 30 },
    [2] = { Min = 50, Max = 90, GlobalProb = 70 },
}

local OuterFillPercentUpgrades = {
    [0] = { Min = 25, Max = 60},
    [1] = { Min = 50, Max = 80},
    [2] = { Min = 75, Max = 100},
}

local MarkedMoneyPercentUpgrades = {
    [0] = { Min = 75, Max = 100},
    [1] = { Min = 50, Max = 80},
    [2] = { Min = 25, Max = 60},
}

local RequiredMoneyFactorUpgrades = {
    [0] = { Min = 5, Max = 10}, 
    [1] = { Min = 2, Max = 5}, 
    [2] = { Min = 1, Max = 1}, 
    [3] = { Min = 0.5, Max = 0.75}, 
    [4] = { Min = 0.25, Max = 0.5}, 
}

local FillerPercentUpgrades = {
    [0] = { TrashMin = 75, TrashMax = 100, CoinMin = 0, CoinMax = 25},
    [1] = { TrashMin = 25, TrashMax = 75, CoinMin = 25, CoinMax = 75},
    [2] = { TrashMin = 0, TrashMax = 25, CoinMin = 75, CoinMax = 100},
}

local MixPercentUpgrades = {
    [0] = { Min = 0, Max = 10, Probability = 100 }, 
    [1] = { Min = 20, Max = 50, Probability = 50}, 
    [2] = { Min = 50, Max = 100, Probability = 20}, 
}

local AdditionalMoneyPercentUpgrades = {
    [0] = { Min = 5, Max = 10 }, 
    [1] = { Min = 20, Max = 50 }, 
    [2] = { Min = 50, Max = 100 }, 
}

local RareMoneyPercentUpgrades = {
    [0] = { Money = 5, Coin = 5 }, 
    [1] = { Money = 10, Coin = 10 },  
    [2] = { Money = 25, Coin = 25 }, 
}

-- total 18 upgrades
local CurrentUpgrades = {
    ["MoneyPacksPercentUpgrades"] = 0,
    ["OuterFillPercentUpgrades"] = 0,
    ["MarkedMoneyPercentUpgrades"] = 0,
    ["RequiredMoneyFactorUpgrades"] = 0,
    ["FillerPercentUpgrades"] = 0,
    ["MixPercentUpgrades"] = 0,
    ["AdditionalMoneyPercentUpgrades"] = 0,
    ["RareMoneyPercentUpgrades"] = 0,
}
QuestLogic.CurrentUpgrades = CurrentUpgrades

-- total 16 locations
local AvailableQuestBonuses = {
    ["BP_QuestBonus_ExactMoneyValue_C"] = { All = true },
    ["BP_QuestBonus_MoreMoneyValue_C"] =  { All = true }, 
    ["BP_QuestBonus_MuchMoreMoneyValue_C"] =  { All = true }, 
    ["BP_QuestBonus_OneShot_C"] =  { All = true }, 
    ["BP_QuestBonus_OnlyRequested_C"] =  { All = true },
    ["BP_QuestBonus_NoMarkedMoney_C"] =  { All = true, ["no-mark"] = true },
    ["BP_QuestBonus_NoFakeMoney_C"] = { All = true, ["no-fake"] = true },
    ["BP_QuestBonus_PerfectPacks_C"] = { All = true, ["packs"] = true },
    ["BP_QuestBonus_PerfectBlocks_C"] = { All = true, ["blocks"] = true },
    ["BP_QuestBonus_Stickers_C"] = { All = true },
    ["BP_QuestBonus_PerfectRolls_C"] = { All = true },
    ["BP_QuestBonus_PerfectRollBlocks_C"] = { All = true },
}
QuestLogic.AvailableQuestBonuses = AvailableQuestBonuses

-- 23 main quest location before pig available
-- 11 optional main location after pig
-- 16 main quest after pig
-- 2 high rep quest (16/24)
-- total 52 main quests

-- max 30 side locations 
QuestLogic.CompletedSideQuests = 0

QuestLogic.MaxCompletedSideQuests = 30

QuestLogic.CompletedSideQuestsIds = {}
QuestLogic.CompletedMainQuestsNames = {}

QuestLogic.ForceOpenPneumaticTube = false
QuestLogic.MaxDifficulty = -1

function QuestLogic:Init(ctx)
    self.Save = ctx.Save
    self.Reward = ctx.Reward
    self.MarketLogic = ctx.MarketLogic
end

local BaseMoneyRange = {
    [1] = { Min = 5000, Max = 25000},
    [2] = { Min = 30000, Max = 70000},
    [3] = { Min = 80000, Max = 145000},
    [4] = { Min = 180000, Max = 350000},
}

local BaseCoinRange = {
    [1] = { Min = 10, Max = 50},
    [2] = { Min = 50, Max = 180},
    [3] = { Min = 180, Max = 400},
    [4] = { Min = 400, Max = 1000},
}

function QuestLogic:AlterQuestGenerator()
    local questGenerator = FindFirstOf("BP_QuestGenerator_C")
    if questGenerator ~= nil and questGenerator:IsValid() then

        local moneyRangesArray = questGenerator.MoneyRangesPerVolume
        if moneyRangesArray ~= nil then
            for i = 1, # (moneyRangesArray), 1 do
                local moneyRange = moneyRangesArray[i]
                moneyRange.Min = math.ceil(BaseMoneyRange[i].Min * RequiredMoneyFactorUpgrades[self.CurrentUpgrades["RequiredMoneyFactorUpgrades"]].Min)
                moneyRange.Max = math.ceil(BaseMoneyRange[i].Max * RequiredMoneyFactorUpgrades[self.CurrentUpgrades["RequiredMoneyFactorUpgrades"]].Max)
            end
        end

        local coinsRangesArray = questGenerator.CoinsRangesPerVolume
        if coinsRangesArray ~= nil then
            for i = 1, # (moneyRangesArray), 1 do
                local coinsRange = coinsRangesArray[i] 
                coinsRange.Min = math.ceil(BaseCoinRange[i].Min * RequiredMoneyFactorUpgrades[self.CurrentUpgrades["RequiredMoneyFactorUpgrades"]].Min)
                coinsRange.Max = math.ceil(BaseCoinRange[i].Max * RequiredMoneyFactorUpgrades[self.CurrentUpgrades["RequiredMoneyFactorUpgrades"]].Max)
            end
        end

        questGenerator.MoneyPacksPercent.Min = MoneyPacksPercentUpgrades[self.CurrentUpgrades["MoneyPacksPercentUpgrades"]].Min
        questGenerator.MoneyPacksPercent.Max = MoneyPacksPercentUpgrades[self.CurrentUpgrades["MoneyPacksPercentUpgrades"]].Max
        questGenerator.CreatePacksProbPercent = MoneyPacksPercentUpgrades[self.CurrentUpgrades["MoneyPacksPercentUpgrades"]].GlobalProb

        questGenerator.OuterFillPercent.Min = OuterFillPercentUpgrades[self.CurrentUpgrades["OuterFillPercentUpgrades"]].Min
        questGenerator.OuterFillPercent.Max = OuterFillPercentUpgrades[self.CurrentUpgrades["OuterFillPercentUpgrades"]].Max

        questGenerator.MarkedMoneyPercent.Min = MarkedMoneyPercentUpgrades[self.CurrentUpgrades["OuterFillPercentUpgrades"]].Min
        questGenerator.MarkedMoneyPercent.Max = MarkedMoneyPercentUpgrades[self.CurrentUpgrades["OuterFillPercentUpgrades"]].Max

        questGenerator.TrashFillerRange.Min = FillerPercentUpgrades[self.CurrentUpgrades["FillerPercentUpgrades"]].TrashMin
        questGenerator.TrashFillerRange.Max = FillerPercentUpgrades[self.CurrentUpgrades["FillerPercentUpgrades"]].TrashMax

        questGenerator.CoinsFillerRange.Min = FillerPercentUpgrades[self.CurrentUpgrades["FillerPercentUpgrades"]].CoinMin
        questGenerator.CoinsFillerRange.Min = FillerPercentUpgrades[self.CurrentUpgrades["FillerPercentUpgrades"]].CoinMax

        questGenerator.CurrencyMixExtraMoneyPercent.Min = MixPercentUpgrades[self.CurrentUpgrades["MixPercentUpgrades"]].Min
        questGenerator.CurrencyMixExtraMoneyPercent.Max = MixPercentUpgrades[self.CurrentUpgrades["MixPercentUpgrades"]].Max
        questGenerator.CurrencyMixProbability = MixPercentUpgrades[self.CurrentUpgrades["MixPercentUpgrades"]].Probability
        questGenerator.CurrencyMixReputationLevelRequirement = 1

        questGenerator.UniqueObjectAddProbability = 0.05
        questGenerator.CoinsAddProbability = 0.1

        questGenerator.AdditionalMoneyValuePercent.Min = AdditionalMoneyPercentUpgrades[self.CurrentUpgrades["AdditionalMoneyPercentUpgrades"]].Min
        questGenerator.AdditionalMoneyValuePercent.Max = AdditionalMoneyPercentUpgrades[self.CurrentUpgrades["AdditionalMoneyPercentUpgrades"]].Max

        questGenerator.MarkedMoneyAmountRange.Min = 100
        questGenerator.MarkedMoneyAmountRange.Max = 100

        questGenerator.RareMoneyChance = RareMoneyPercentUpgrades[self.CurrentUpgrades["RareMoneyPercentUpgrades"]].Money
        questGenerator.RareCoinChance = RareMoneyPercentUpgrades[self.CurrentUpgrades["RareMoneyPercentUpgrades"]].Coin
    end
end

function QuestLogic:SetCompletedSideQuest(value)
    self.CompletedSideQuests = value
end

function QuestLogic:SetMaxCompletedSideQuests(value)
    self.MaxCompletedSideQuests = value
end

function QuestLogic:ReceiveUpgrade(target)
    self.CurrentUpgrades[target] = self.CurrentUpgrades[target] + 1
    self:AlterQuestGenerator()
end

function QuestLogic:SetUpgrades(Upgrades)
    self.CurrentUpgrades = Upgrades
    self:AlterQuestGenerator()
end

function QuestLogic:UpdateForceOpenTube(isOpen)
    if isOpen then
        self.ForceOpenPneumaticTube = true
        self:ForceOpenTube()
    end
end

function QuestLogic:LoadAvailableQuestBonuses(bonuses)
    self.AvailableQuestBonuses = bonuses
end

function QuestLogic:LoadCompletedQuests(MainQuestsNames, SideQuestsIds)
    self.CompletedSideQuestsIds = SideQuestsIds
    self.CompletedMainQuestsNames = MainQuestsNames
end

function QuestLogic:SetMaxDifficulty(Difficulty)
    self.MaxDifficulty = Difficulty
end

function QuestLogic:QuestHasTag(Quest, SearchedTag)
    local hasTag = false
    Utils.LoopGameplayTagContainer(Quest.Info.GameplayTags, function(tag, index)
        if tag.TagName:ToString() == SearchedTag then
            hasTag = true
        end
    end)
    return hasTag
end

function QuestLogic:GetMainQuestName(Quest)
    local name = ''
    Utils.LoopGameplayTagContainer(Quest.Info.GameplayTags, function(tag, index)
        if tag.TagName:ToString():match("^Quest.Specific.(.+)$") then
            name = tag.TagName:ToString():match("^Quest.Specific.(.+)$")
        end
    end)
    return name
end

function QuestLogic:LogQuestStarted()
    local pre,post = RegisterHook(hookQuestSubsystem .. ":OnQuestStarted", function(_self, questRef)
        local quest = questRef:get()
    end)
    Utils.OnQuit(function()
        local functionName = hookQuestSubsystem .. ":OnQuestStarted"
        UnregisterHook(functionName, pre, post)
    end)
end

QuestLogic.SAVE_PATH = "ue4ss/Mods/Randomizer/Saved/quests.lua"
function QuestLogic:LogQuestRegistered()
    local pre,post = RegisterHook("/Script/CashCleanerSim.Quest:OnRegistered", function(_self)
        local quest = _self:get()
        local staticTags = {}
        Utils.LoopGameplayTagContainer(quest.GameplayTags.StaticTags, function(tag, index)
            table.insert(staticTags, tag.TagName:ToString())
        end)

        local gameplayTags = {}
        Utils.LoopGameplayTagContainer(quest.GameplayTags.GameplayTags, function(tag, index)
             table.insert(gameplayTags, tag.TagName:ToString())
        end)

        local infoTags = {}
        Utils.LoopGameplayTagContainer(quest.Info.GameplayTags, function(tag, index)
             table.insert(infoTags, tag.TagName:ToString())
        end)
        
        local dMoney = {}
        pcall(function()
            for i = 1, #quest.Objectives do
                local objective = quest.Objectives[i]
                local amount = 0
                if objective.DesiredMoneyCurrency and objective.DesiredMoneyCurrency ~= nil then
                    if objective.DesiredMoneyValue and objective.DesiredMoneyValue ~= nil and objective.DesiredMoneyValue ~= 0 then
                        amount = objective.DesiredMoneyValue
                    end
                    if objective.DesiredMoneyValueV2 and objective.DesiredMoneyValueV2 ~= nil then
                        amount = objective.DesiredMoneyValueV2.Value
                    end
                    pcall(function() 
                        if objective.DesiredMoneyCurrency.TagName and objective.DesiredMoneyCurrency.TagName ~= nil then
                            dMoney[objective.DesiredMoneyCurrency.TagName:ToString()] = { Amount = amount, Rules = {} }
                            if objective.ValidationRules and objective.ValidationRules ~= nil and type(#objective.ValidationRules) == "number" then
                                for j = 1, #objective.ValidationRules do
                                    local rule = objective.ValidationRules[j]
                                    dMoney[objective.DesiredMoneyCurrency.TagName:ToString()].Rules[rule:ToString()] = true
                                    j = j + 1
                                end
                            end
                        end
                    end)
                end

                i = i + 1
            end
        end)
        local questInfo = {
            Name = quest.Info.Name:ToString(),
            Description = quest.Info.Description:ToString(),
            Difficulty = quest.Info.Difficulty,
            ReputationLevelRequirement = quest.Info.ReputationLevelRequirement,
            DesiredMoney = dMoney,
            StaticTags = staticTags,
            GameplayTags = gameplayTags,
            InfoTags = infoTags
        }
        local f, err = io.open(self.SAVE_PATH, "a")
        if not f then
            return false
        end

        f:write(Utils.Serialize(questInfo))
        f:close()

    end)
    Utils.OnQuit(function()
        local functionName = "/Script/CashCleanerSim.Quest:OnRegistered"
        UnregisterHook(functionName, pre, post)
    end)
end

function QuestLogic:AlterQuestValidationRule(Quest)
    for i = 1, #Quest.Objectives do
        local objective = Quest.Objectives[i]

        if objective.DesiredMoneyCurrency or objective.DesiredMoneyValueV2 ~= nil then
            for j = 1, #objective.ValidationRules do
                local rule = objective.ValidationRules[j]
                if rule:ToString() == "bills-usd" then
                    objective.ValidationRules[j] = FName("blocks-usd")
                end
                j = j + 1
            end
        end
        i = i + 1
    end
end

function QuestLogic:InitQuestLimitations()
    local pre, post = RegisterHook("/Script/CashCleanerSim.Quest:OnRegistered", function(_self)
        local quest = _self:get()
        
        if quest.Info.Rewards ~= nil then 
            if #quest.Info.Rewards > 0 then
                for i=1, #quest.Info.Rewards do
                    pcall(function()
                        local reward = quest.Info.Rewards[i]
                        if reward.Reputation ~= nil and type(reward.Reputation) == "number" then
                            reward.Reputation = 0
                        end

                        local readableQuestName = quest.Info.Name:ToString()
                        
                        if self:QuestHasTag(quest, "Quest.Specific.Main.TheLightTest") or
                           self:QuestHasTag(quest, "Quest.Specific.Side.HotDry") or
                           self:QuestHasTag(quest, "Quest.Specific.Side.CleanCut")  then
                            if reward.SpawnRequests ~= nil then
                                if #reward.SpawnRequests then
                                    local requests = reward.SpawnRequests
                                    for j = 1, #reward.SpawnRequests do
                                        
                                        local req = reward.SpawnRequests[j]
                                        local countRange = req.ObjectsCount
                                
                                        countRange.Min = 0
                                        countRange.Max = 0

                                        j = j + 1
                                    end
                                end
                            end
                        end
                    end)
                    i = i + 1
                end

                for i=1, #quest.Info.FailurePenalty do
                    pcall(function()
                        local penality = quest.Info.FailurePenalty[i]
                        if penality.Reputation ~= nil and type(penality.Reputation) == "number" then
                            penality.Reputation = 0
                        end
                    end)
                    i = i + 1
                end

                for i=1, #quest.Info.CancelFee do
                    pcall(function()
                        local fee = quest.Info.CancelFee[i]
                        if fee.Reputation ~= nil and type(fee.Reputation) == "number" then
                            fee.Reputation = 0
                        end
                    end)
                    i = i + 1
                end
            end
        end

        if self:QuestHasTag(quest, "Quest.Specific.Main.ShopTillItDrops") then
            local smartphoneSubSystem = FindFirstOf("BP_SmartphoneSubsystem_C")
            smartphoneSubSystem:MakeAllAppsAvailable()

            local questGenerator = FindFirstOf("BP_QuestGenerator_C")
            questGenerator:start()            
        end

    end)
    Utils.OnQuit(function()
        local functionName = "/Script/CashCleanerSim.Quest:OnRegistered"
        UnregisterHook(functionName, pre, post)
    end) 
end

function QuestLogic:SkipCurrentQuest()
    local subsystem = FindFirstOf("BP_QuestSubsystem_C")
    subsystem:CompleteTrackedQuest()
end

function QuestLogic:PunishQuestCancel(questInstance)
    for i = 1, #questInstance.Objectives do
        local objective = questInstance.Objectives[i]

        if objective.DesiredMoneyCurrency and objective.DesiredMoneyCurrency ~= nil then

            local dMoney = 0
            if objective.DesiredMoneyValue and objective.DesiredMoneyValue ~= nil and objective.DesiredMoneyValue ~= 0 then
                dMoney = objective.DesiredMoneyValue
            end
            if objective.DesiredMoneyValueV2 and objective.DesiredMoneyValueV2 ~= nil then
                dMoney = objective.DesiredMoneyValueV2.Value
            end

            if objective.DesiredMoneyCurrency.TagName:ToString() ~= "Object.Property.Denomination.USD" then
                dMoney = dMoney / (100 / MixPercentUpgrades[self.CurrentUpgrades["MixPercentUpgrades"]].Max )
            end
            if objective.DesiredMoneyCurrency.TagName:ToString() == "Object.Property.Denomination.JPY" then                           
                dMoney = dMoney / 100
            end
            dMoney = dMoney * (1.0 + AdditionalMoneyPercentUpgrades[self.CurrentUpgrades["AdditionalMoneyPercentUpgrades"]].Max / 100)
            local pig = FindFirstOf("BP_MoneyPig_C")
            if pig ~= nil then
                pig:SetNewGoal(pig.MoneyGoal + dMoney)
                self:ForceOpenTube()
            end
       
        end

        i = i + 1
    end
end

function QuestLogic:ForceOpenTube()
    if not self.ForceOpenPneumaticTube then
        local pre,post = RegisterHook("/Game/Core/Objects/BP_PneumaticMail.BP_PneumaticMail_C:OnLaunchEnded", function(_self)
            local PneumaticMail = _self:get()
            PneumaticMail:Open(true)
        end)
        Utils.OnQuit(function()
            local functionName = "/Game/Core/Objects/BP_PneumaticMail.BP_PneumaticMail_C:OnLaunchEnded"
            UnregisterHook(functionName, pre, post)
        end)
        self.ForceOpenPneumaticTube = true
    end
end

function QuestLogic:AwardBonus(Bonus, ValidationRules)
    if Bonus ~= nil and Bonus:IsValid() then
        local classText 
        local fullName = Bonus:GetClass():GetFullName()
        
        if fullName == "BlueprintGeneratedClass /Game/Core/Quests/Bonuses/BP_QuestBonus_ExactMoneyValue.BP_QuestBonus_ExactMoneyValue_C" then
            classText = "BP_QuestBonus_ExactMoneyValue_C"
        elseif fullName == "BlueprintGeneratedClass /Game/Core/Quests/Bonuses/BP_QuestBonus_MoreMoneyValue.BP_QuestBonus_MoreMoneyValue_C" then
            classText = "BP_QuestBonus_MoreMoneyValue_C"
        elseif fullName == "BlueprintGeneratedClass /Game/Core/Quests/Bonuses/BP_QuestBonus_MuchMoreMoneyValue.BP_QuestBonus_MuchMoreMoneyValue_C" then
            classText = "BP_QuestBonus_MuchMoreMoneyValue_C"
        elseif fullName == "BlueprintGeneratedClass /Game/Core/Quests/Bonuses/BP_QuestBonus_OneShot.BP_QuestBonus_OneShot_C" then
            classText = "BP_QuestBonus_OneShot_C"
        elseif fullName == "BlueprintGeneratedClass /Game/Core/Quests/Bonuses/BP_QuestBonus_OnlyRequested.BP_QuestBonus_OnlyRequested_C" then
            classText = "BP_QuestBonus_OnlyRequested_C"
        elseif fullName == "BlueprintGeneratedClass /Game/Core/Quests/Bonuses/BP_QuestBonus_NoMarkedMoney.BP_QuestBonus_NoMarkedMoney_C" then
            classText = "BP_QuestBonus_NoMarkedMoney_C"
        elseif fullName == "BlueprintGeneratedClass /Game/Core/Quests/Bonuses/BP_QuestBonus_NoFakeMoney.BP_QuestBonus_NoFakeMoney_C" then
            classText = "BP_QuestBonus_NoFakeMoney_C"
        elseif fullName == "BlueprintGeneratedClass /Game/Core/Quests/Bonuses/BP_QuestBonus_PerfectPacks.BP_QuestBonus_PerfectPacks_C" then
            classText = "BP_QuestBonus_PerfectPacks_C"
        elseif fullName == "BlueprintGeneratedClass /Game/Core/Quests/Bonuses/BP_QuestBonus_PerfectBlocks.BP_QuestBonus_PerfectBlocks_C" then
            classText = "BP_QuestBonus_PerfectBlocks_C"
        elseif fullName == "BlueprintGeneratedClass /Game/Core/Quests/Bonuses/BP_QuestBonus_Stickers.BP_QuestBonus_Stickers_C" then
            classText = "BP_QuestBonus_Stickers_C"
        elseif fullName == "BlueprintGeneratedClass /Game/Core/Quests/Bonuses/BP_QuestBonus_PerfectRolls.BP_QuestBonus_PerfectRolls_C" then
            classText = "BP_QuestBonus_PerfectRolls_C"
        elseif fullName == "BlueprintGeneratedClass /Game/Core/Quests/Bonuses/BP_QuestBonus_PerfectRollBlocks.BP_QuestBonus_PerfectRollBlocks_C" then
            classText = "BP_QuestBonus_PerfectRollBlocks_C"
        end

        if self.AvailableQuestBonuses[classText].All then
            self.AvailableQuestBonuses[classText].All = false
            self.Reward:Check("Quest_Bonus_" .. classText)
        end

        if classText == "BP_QuestBonus_NoMarkedMoney_C" and ValidationRules["no-mark"] and self.AvailableQuestBonuses[classText]["no-mark"] then
            self.AvailableQuestBonuses[classText]["no-mark"] = false
            self.Reward:Check("Quest_Bonus_" .. classText .. "_with_quest")

        end

        if classText == "BP_QuestBonus_NoFakeMoney_C" and ValidationRules["no-fake"] and self.AvailableQuestBonuses[classText]["no-fake"] then
            self.AvailableQuestBonuses[classText]["no-fake"] = false
            self.Reward:Check("Quest_Bonus_" .. classText .. "_with_quest")

        end

        if classText == "BP_QuestBonus_PerfectPacks_C" and ValidationRules["packs"] and self.AvailableQuestBonuses[classText]["packs"] then
            self.AvailableQuestBonuses[classText]["packs"] = false
            self.Reward:Check("Quest_Bonus_" .. classText .. "_with_quest")

        end

        if classText == "BP_QuestBonus_PerfectBlocks_C" and ValidationRules["blocks"] and self.AvailableQuestBonuses[classText]["blocks"] then
            self.AvailableQuestBonuses[classText]["blocks"] = false
            self.Reward:Check("Quest_Bonus_" .. classText .. "_with_quest")
        end
    end
    
end

function QuestLogic:OnQuestFinish()
    local pre, post = RegisterHook("/Script/CashCleanerSim.Quest:OnFinished", function(_self, Resolution)
        local questInstance = _self:get()

        local isSide = true
        Utils.LoopGameplayTagContainer(questInstance.Info.GameplayTags, function(tag, index)
            if  tag.TagName:ToString() == "Quest.Property.NonDiscardable" then
                isSide = false
            end
            
            if tag.TagName:ToString():find("^Quest.Specific.Tutorial") or
               tag.TagName:ToString():find("^Quest.Specific.Main") or
               tag.TagName:ToString():find("^Quest.Specific.Side") then
                isSide = false
            end 
        end)

        local canceled = false
        Utils.LoopGameplayTagContainer(Resolution:get(), function(tag, index)
            if tag.TagName:ToString() == "Quest.Resolution.Canceled" or tag.TagName:ToString() == "Quest.Resolution.Failed" then
                canceled = true
            end
        end)

        if canceled then
            self:PunishQuestCancel(questInstance)
        end
        
        if not canceled and not isSide then
            local mainQuestName = self:GetMainQuestName(questInstance)
            if not self.CompletedMainQuestsNames[mainQuestName] then
                self.CompletedMainQuestsNames[mainQuestName] = true
                self.Reward:Check("MainQuest_" .. mainQuestName)

                if mainQuestName == "Main.FinalAscent" or mainQuestName == "Main.PointOfNoReturn" then
                    self.Reward:Goal()
                end
            end
        end

        if not canceled and isSide then
            if not self.CompletedSideQuestsIds[Utils.GuidToString(questInstance.QuestId)] then
                self.CompletedSideQuestsIds[Utils.GuidToString(questInstance.QuestId)] = true
                if self.CompletedSideQuests < self.MaxCompletedSideQuests then
                    self.Reward:Check("SideQuest_" .. self.CompletedSideQuests)
                end
                self:SetCompletedSideQuest(self.CompletedSideQuests + 1)
            end
            
            local difficulty = questInstance.Info.Difficulty
            if difficulty > self.MaxDifficulty then
                while self.MaxDifficulty < difficulty do
                    self.MaxDifficulty = self.MaxDifficulty + 1
                    self.Reward:Check("Difficulty_" .. self.MaxDifficulty)
                end
            end

            local ValidationRules = {}
            for i = 1, #questInstance.Objectives do
                local objective = questInstance.Objectives[i]
                if objective.DesiredMoneyCurrency ~= nil or objective.DesiredMoneyValueV2 ~= nil then
                    if objective.ValidationRules ~= nil then
                        if #objective.ValidationRules > 0 then
                            for j = 1, #objective.ValidationRules do
                                local rule = objective.ValidationRules[j]
                                if rule:ToString() == "no-fake" then
                                    ValidationRules["no-fake"] = true
                                end
                                if rule:ToString() == "no-mark" then
                                    ValidationRules["no-mark"] = true
                                end
                                if rule:ToString():find("^blocks") then
                                    ValidationRules["blocks"] = true
                                end
                                if rule:ToString():find("^packs") then
                                    ValidationRules["packs"] = true
                                end
                                j = j + 1
                            end
                        end
                    end
                end
                i = i + 1
            end
            local Bonuses = questInstance.Bonuses
            for i = 1, #Bonuses do
                local bonus = Bonuses[i]
                if bonus:IsCompleted() then 
                    self:AwardBonus(bonus, ValidationRules)
                end
                i = i + 1
            end
        end
        
    end)
    Utils.OnQuit(function()
        local functionName = "/Script/CashCleanerSim.Quest:OnFinished"
        UnregisterHook(functionName, pre, post)
    end)
end

function QuestLogic:HandleReward(reward)
    local UpgradeKey = reward:match("^Quest_(.+)$")
    self:ReceiveUpgrade(UpgradeKey)
    self.Save:OnChange()
end

function QuestLogic:Start()
    self:InitQuestLimitations()
    self:OnQuestFinish()
end

return QuestLogic