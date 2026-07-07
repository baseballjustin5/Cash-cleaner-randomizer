local Utils = {}
local UEHelpers = require("UEHelpers")

function Utils.GuidToString(guid)
    if guid == nil then
        return "nil"
    end
    return string.format("%i_%i_%i_%i", guid.A, guid.B, guid.C, guid.D)
end

function Utils.compareGuids(guid1, guid2)
    if guid1 == nil or guid2 == nil then
        return false
    end
    return guid1.A == guid2.A and guid1.B == guid2.B and guid1.C == guid2.C and guid1.D == guid2.D
end

function Utils.LoopGameplayTagContainer(Container, Callback)
    for i = 1, #Container.GameplayTags do
        local tag = Container.GameplayTags[i]
        Callback(tag, i)
        i = i + 1
    end
end


function Utils.Serialize(value, indent)
    indent = indent or 0
    local spacing = string.rep("  ", indent)

    if type(value) == "table" then
        local result = "{\n"
        for k, v in pairs(value) do
            local key
            if type(k) == "string" then
                key = string.format("[%q]", k)
            else
                key = string.format("[%d]", k)
            end
            result = result .. spacing .. "  " .. key .. " = " ..
                Utils.Serialize(v, indent + 1) .. ",\n"
        end
        return result .. spacing .. "}"
    elseif type(value) == "string" then
        return string.format("%q", value)
    else
        return tostring(value)
    end
end

function Utils.Notify(RichText)
    ExecuteInGameThread(function()
        local smartPhone = FindFirstOf("BP_SmartphoneSubsystem_C")
        pcall(function()
            return smartPhone:PushNotification(FText(RichText), nil, nil, true)
        end)
    end)
end

function Utils.OnQuit(Callback)
    local mainGameMode = "/Game/Core/Rules/BP_TheMainGameMode.BP_TheMainGameMode_C"
    RegisterHook(mainGameMode .. ":ReceiveEndPlay", function(_self)
        Callback()
    end)
end

function Utils.OnWakeUp(Callback)
    local mainGameMode = "/Game/Core/Rules/BP_TheMainGameMode.BP_TheMainGameMode_C"
    RegisterHook(mainGameMode .. ":OnWakeUpFinished", function(_self)
        local mainGameModeInstance = _self:get()
        if mainGameModeInstance == nil or not mainGameModeInstance:IsValid() then
            return
        end
        Callback()
    end)
end

local world
local gameplayStatics
local function IsGamePaused()
    if (world == nil or not world:IsValid()) then
        world = UEHelpers.GetWorldContextObject()
        if (world == nil or not world:IsValid()) then
            return true
        end
    end

    if (gameplayStatics == nil or not gameplayStatics:IsValid()) then
        gameplayStatics = UEHelpers.GetGameplayStatics(false)
        if (gameplayStatics == nil or not gameplayStatics:IsValid()) then
            return true
        end
    end

    local isPaused = gameplayStatics:IsGamePaused(world)
    return isPaused
end

local PendingCallbacks = {}
local MIN_DELAY = 500
local lastCall = 0

function Utils.InitTickCallback()
    RegisterHook("/Game/Core/UI/VirtualCursor/W_VirtualCursor.W_VirtualCursor_C:Tick", function(_, deltaSeconds)
        if not IsGamePaused() then
            local now = os.clock() * 1000
            for i = #PendingCallbacks, 1, -1 do
                local entry = PendingCallbacks[i]
                if now >= entry.executeAt then 
                    entry.callback()
                    table.remove(PendingCallbacks, i)
                end
            end
        end
    end)
end

function Utils.ThrottledCall(callback)
    Utils.DelayedCall(callback, 0)
end

function Utils.DelayedCall(callback, delay)
    local now = os.clock() * 1000
    local wait = math.max(delay, MIN_DELAY - (now - lastCall))
    lastCall = now + wait

    table.insert(PendingCallbacks, {
        executeAt = now + wait,
        callback = callback
    })   
end
return Utils