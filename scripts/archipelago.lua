local Archipelago = {}
Archipelago.pendingChecks = {}

local ArchipelagoLists = require "ArchipelagoLists"
local AP = require "lua-apclientpp"
local Utils = require "utils"

-- global to this mod
local game_name = "Cash cleaner simulator"
local items_handling = 7  -- full remote
local client_version = {0, 5, 1}  -- optional, defaults to lib version
local message_format = AP.RenderFormat.TEXT
---@type APClient
local ap = nil


-- TODO: user input
Archipelago.host = ""
Archipelago.slot = ""
Archipelago.password = ""
local playerId = 0

function Archipelago:Init(ctx)
    self.Reward = ctx.Reward
    self.Save = ctx.Save
    self.MarketLogic = ctx.MarketLogic
    self:ReadConfig()
end

Archipelago.CheckedLocation = {}
function Archipelago:SetCheckedLocation(locations)
    self.CheckedLocation = locations
end

Archipelago.CONFIG_PATH = "ue4ss/Mods/Randomizer/Saved/ap_config.lua"
function Archipelago:ReadConfig()
    local ok, data = pcall(dofile, self.CONFIG_PATH)
    if ok and type(data) == "table" then
        self.host = data.host
        self.slot = data.player
        self.password = data.password
        if data.seed then
            self.MarketLogic:SetMarketSeed(math.tointeger(math.fmod(data.seed, math.maxinteger)))
        end
    end
end

function Archipelago:Connect(server, slot, password)
    local on_socket_connected = function()
        print("[Archipelago] Socket connected" .. "\n")
    end

    local on_socket_error = function(msg)
       print("[Archipelago] Socket error: " .. msg .. "\n")
    end

    local on_socket_disconnected = function()
        print("[Archipelago] Socket disconnected" .. "\n")
        Utils.Notify("[Archipelago] Disconnected from server" .. "\n")
    end

    local on_room_info = function()
        print("[Archipelago] Room info" .. "\n")
        ap:ConnectSlot(slot, password, items_handling, {"Lua-APClientPP"}, client_version)
    end

    local on_slot_connected = function(slot_data)
        print("[Archipelago] Slot connected" .. "\n")
        playerId = ap:get_player_number()
        ap:ConnectUpdate(nil, {"Lua-APClientPP"})
        Utils.Notify("[Archipelago] Connected to server")

        if Archipelago.pendingChecks and #Archipelago.pendingChecks > 0 then
            print("[Archipelago] Flushing pending location checks" .. "\n")
            for _, locationName in ipairs(Archipelago.pendingChecks) do
                local locationID = self:GetAPLocationIDfromName(locationName)
                if locationID then
                    print("[Archipelago] Sending pending location check for: " .. tostring(locationName) .. "\n")
                    ap:LocationChecks({tonumber(locationID)})
                end
            end
            Archipelago.pendingChecks = {}
        end
    end

    local on_slot_refused = function(reasons)
        print("[Archipelago] Slot refused: " .. table.concat(reasons, ", ") .. "\n")
        Utils.Notify("[Archipelago] Slot refused: " .. table.concat(reasons, ", "))
    end

    local on_items_received = function(items)
        for _, item in ipairs(items) do
            local location
            local player = nil

            if item.player == playerId then
                location = ArchipelagoLists.APLocationIdToName[item.location]
            else
                location = item.player .. "-" .. item.location
                player = ap:get_player_alias(item.player)
            end
            if not self.CheckedLocation[location] then
                local reward = ArchipelagoLists.APItemIdToName[item.item]
                self.Reward:Award(reward, location, player)
                self.CheckedLocation[location] = true
            end
        end
    end

    local on_location_info = function(items)
        print("[Archipelago] Locations scouted" .. "\n")
    end

    local on_location_checked = function(locations)
        print("[Archipelago] Calling location checked" .. "\n")
    end

    local on_data_package_changed = function(data_package)
        print("[Archipelago] Data package changed" .. "\n")
    end

    local on_print = function(msg)
        print("[Archipelago]" .. tostring(msg) .. "\n")
    end

    local on_print_json = function(msg, extra)
        print("[Archipelago] JSON Message:" .. "\n")
        print(ap:render_json(msg, message_format) .. "\n")
    end

    local on_bounced = function(bounce)
        print("[Archipelago] Bounced" .. "\n")
    end

    local on_retrieved = function(map, keys, extra)
        print("[Archipelago] Retrieved" .. "\n")
    end

    local on_set_reply = function(message)
        print("[Archipelago] Set Reply" .. "\n")
    end

    local uuid = ""
    ap = AP(uuid, game_name, server);
    print("[Archipelago] Connecting to " .. server .. " ..." .. "\n")
    ap:set_socket_connected_handler(on_socket_connected)
    ap:set_socket_error_handler(on_socket_error)
    ap:set_socket_disconnected_handler(on_socket_disconnected)
    ap:set_room_info_handler(on_room_info)
    ap:set_slot_connected_handler(on_slot_connected)
    ap:set_slot_refused_handler(on_slot_refused)
    ap:set_items_received_handler(on_items_received)
    ap:set_location_info_handler(on_location_info)
    ap:set_location_checked_handler(on_location_checked)
    ap:set_data_package_changed_handler(on_data_package_changed)
    ap:set_print_handler(on_print)
    ap:set_print_json_handler(on_print_json)
    ap:set_bounced_handler(on_bounced)
    ap:set_retrieved_handler(on_retrieved)
    ap:set_set_reply_handler(on_set_reply)
end

function Archipelago:ConnectToAp()
    ExecuteAsync(function ()
        self:Connect(self.host, self.slot, self.password)
        LoopAsync(500, function()
            while ap do
                ap:poll()
            end
        end)
    end)
end

function Archipelago:Disconnect()
    ap = nil
    collectgarbage("collect")
end

function Archipelago:SendLocationFromName(locationName)
    if type(self.pendingChecks) ~= "table" then
        self.pendingChecks = {}
    end

    if not isConnected or ap == nil then
        print("AP client not connected, queueing location: " .. tostring(locationName) .. "\n")
        print("[Archipelago] Will try again when connected." .. "\n")
        table.insert(self.pendingChecks, locationName)
        return
    end

    local locationID = self:GetAPLocationIDfromName(locationName)
    if locationID == nil then
        print("Location name: " .. locationName .. " is not valid." .. "\n")
        return
    end

    local success, err = pcall(function()
        ap:LocationChecks({tonumber(locationID)})
    end)
    if not success then
        print("Error sending location with error: " .. tostring(err) .. "\n")
        table.insert(self.pendingChecks, locationName)
        for index, location in ipairs(self.pendingChecks) do
            print(string.index .. ": " .. tostring(location))
        end
    end
end

function Archipelago:Goal()
    if ap == nil then
        print("AP client not connected, cannot send goal" .. "\n")
        table.insert(self.pendingGoal, true)
        return
    end
    ap:StatusUpdate(AP.ClientStatus.GOAL)
end

function Archipelago:GetAPLocationIDfromName(locationName)
    return ArchipelagoLists.LocationNameToAPId[locationName]
end

return Archipelago