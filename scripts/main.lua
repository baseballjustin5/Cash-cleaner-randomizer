local Utils = require "utils"
local StackSize = require "stackSize"
local QuestLogic = require "questLogic"
local MarketLogic = require "marketLogic"
local WorldInteraction = require "worldInteraction"
local Reward = require "reward"
local Archipelago = require "archipelago"
local Save = require "save"
local AP = require "lua-apclientpp"

local mainGameMode = "/Game/Core/Rules/BP_TheMainGameMode.BP_TheMainGameMode_C"

ExecuteInGameThread(function()

    LoadAsset(mainGameMode)
    RegisterHook(mainGameMode .. ":ReceiveBeginPlay", function(_self)
        local mainGameModeInstance = _self:get()

        if mainGameModeInstance == nil or not mainGameModeInstance:IsValid() then
            return
        end

        print("[Randomizer] World State Loaded! Initializing modules...\n")

        local ctx = {
            Save = Save,
            StackSize = StackSize,
            QuestLogic = QuestLogic,
            MarketLogic = MarketLogic,
            WorldInteraction = WorldInteraction,
            Reward = Reward,
            Archipelago = Archipelago,
        }

        Save:Init(ctx)
        Reward:Init(ctx)
        QuestLogic:Init(ctx)
        WorldInteraction:Init(ctx)
        MarketLogic:Init(ctx)
        StackSize:Init(ctx)
        Archipelago:Init(ctx)

        Utils.InitTickCallback()

        local success, err = pcall(
            function()
                Save:LoadSave()
                WorldInteraction:AlterInitConsumables()

                if QuestLogic.Start then
                    QuestLogic:Start()
                else
                    print("QuestLogic:Start() missing")
                end
                if WorldInteraction.ListenAllEvents then
                    WorldInteraction:ListenAllEvents()
                else
                    print("WorldInteraction:ListenAllEvents() missing")
                end
                
                print("Registering Hook for returning to main lobby")
                RegisterHook("/Game/Core/Rules/BP_TheMainGameMode.BP_TheMainGameMode_C:ReceiveEndPlay", function(Context, EndPlayReason)
                    print("[Archipelago] Main game mode ended. Returning to main menu or shutting down...")
                    if Archipelago and type(Archipelago.Disconnect) == "function" then
                        Archipelago:Disconnect()
                    end
                end)
                Archipelago:ConnectToAp()
        end)

        if not success then

            print(
                "[Randomizer] Failed to Initialize with error: " ..
                tostring(err) .. "\n"
            )
        end
    end)
end)