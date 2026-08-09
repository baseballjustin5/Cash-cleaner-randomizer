local Archipelago = {}
Archipelago.pendingChecks = {}

local ArchipelagoLists = require "ArchipelagoLists"
local AP = require "lua-apclientpp"
local Utils = require "utils"

-- global to this mod
local game_name = "Cash Cleaner Simulator"
local items_handling = 7  -- full remote
local client_version = {0, 5, 1}  -- optional, defaults to lib version
local message_format = AP.RenderFormat.TEXT

---@type APClient?
local ap = nil

-- TODO: user input
Archipelago.host = ""
Archipelago.slot = ""
Archipelago.password = ""
local playerID = 0

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

function Archipelago:SetPendingChecks(pendingChecks)
    self.PendingChecks = pendingChecks
end

Archipelago.CONFIG_PATH = "ue4ss/Mods/Randomizer/Saved/ap_config.lua"
function Archipelago:ReadConfig()
    local ok, data = pcall(dofile, self.CONFIG_PATH)
    if ok and type(data) == "table" then
        local rawHost = data.host
        if not rawHost or rawHost == "" then
            self.host = "ws://localhost:38281"
        elseif string.match(rawHost, "^%a+://") then
            -- If you explicitly wrote ws:// or wss:// in the config, use it directly!
            self.host = rawHost
        else
            -- If you just provided an IP or domain without a prefix, default to plain ws://
            -- (essential for home-hosted servers that don't use SSL/WSS certificates)
            self.host = "ws://" .. rawHost
            print(self.host)
        end

        self.slot = data.player
        self.password = data.password
        if data.seed then
            self.MarketLogic:SetMarketSeed(
                math.tointeger(
                    math.fmod(
                        data.seed, math.maxinteger
                    )
                )
            )
        end
    end
end

function Archipelago:Connect(server, slot, password)
    local on_socket_connected = function()
        print("[Archipelago] Socket connected\n")
    end

    local on_socket_error = function(msg)
        print("[Archipelago CRITICAL] Socket error encountered: " .. tostring(msg) .. "\n")
        Utils.Notify("[Archipelago] Connection Failed: " .. tostring(msg))
    end

    local on_socket_disconnected = function()
        print("[Archipelago] Socket disconnected\n")
        Utils.Notify("[Archipelago] Disconnected from server\n")
    end

    local on_room_info = function()
        print("[Archipelago] Room info\n")
        if ap ~= nil then
            print(ap:ConnectSlot(
                slot,
                password,
                items_handling,
                {"Lua-APClientPP"},
                client_version
            ))
        end
    end

    local on_slot_connected = function(slot_data)
        print("[Archipelago] Slot connected")
        if ap ~= nil then
            playerID = ap:get_player_number()
            ap:ConnectUpdate(nil, {"Lua-APClientPP"})
        end
        Utils.Notify("[Archipelago] Connected to server")

        if not self.PendingChecks or type(self.PendingChecks) ~= "table" or #self.PendingChecks == 0 then
            print("[Archipelago] No pending checks to flush\n")
            return
        end

        print("[Archipelago] Pushing " .. #self.PendingChecks .. " checks to server\n")

        local success, err = pcall(function()
            local sendingChecks = {}
            for _, locName in ipairs(self.PendingChecks) do
                if locName and not self.CheckedLocation[locName] then
                    local locId = self:GetAPLocationIDfromName(locName)
                    if locId == nil then
                        print("[Archipelago] WARNING: Could not resolve ID for queued location: " .. tostring(locName) .. "\n")
                    else
                        table.insert(sendingChecks, tonumber(locId))
                    end
                end
            end

            if #sendingChecks > 0 and ap ~= nil then
                ap:LocationChecks(sendingChecks)
            end
            self.PendingChecks = {}
        end)

        if not success then
            Utils.WriteCrashLog(err)
            print("[Archipelago] Error syncing checks with server: " .. tostring(err) .. "\n")
        end
    end

    local on_slot_refused = function(reasons)
        print(
            "[Archipelago] Slot refused: " ..
            table.concat(reasons, ", ") .. "\n"
        )
        Utils.Notify(
            "[Archipelago] Slot refused: " ..
            table.concat(reasons, ", ") .. "\n"
        )
    end

    local on_items_received = function(items)
        local success, err = pcall(function()
            for _, item in ipairs(items) do
                if item and item.item and item.location then
                    local location = nil
                    local player = nil

                    if item.player == playerID then
                        location = ArchipelagoLists.APLocationIdToName[item.location]
                    else
                        location = tostring(item.player) .. "-" .. tostring(item.location)
                        if ap ~= nil then
                            player = ap:get_player_alias(item.player)
                        end
                    end

                    if location and not self.CheckedLocation[location] then
                        local reward = ArchipelagoLists.APItemIdToName[item.item]

                        ExecuteInGameThread(function()
                            self.Reward:Award(reward, location, player)
                        end)

                        self.CheckedLocation[location] = true
                        print(
                            "[Archipelago] Received item: " ..
                            " from location: " .. tostring(location) ..
                            " for player: " .. tostring(player) ..
                            " with reward: " .. tostring(reward) .. "\n"
                        )
                    end
                end
            end
        end)

        if not success then
            Utils.WriteCrashLog(err)
            print(
                "[Archipelago] Error handling received items with error: " ..
                tostring(err) .. "\n"
            )
        end
    end

    local on_location_info = function(items)
        print("[Archipelago] Locations scouted" .. "\n")
    end

    local on_location_checked = function(locations)
        -- 'locations' passed from APClient contains an array of numeric IDs already checked on server
        local success, err = pcall(function()
            if locations and type(locations) == "table" then
                for _, locId in ipairs(locations) do
                    local locName = ArchipelagoLists.APLocationIdToName[locId]
                    if locName then
                        self.CheckedLocation[locName] = true
                    end
                end
            end
            print("[Archipelago] Location checked packet processed successfully\n")
        end)

        if not success then
            print("[Archipelago] Error in on_location_checked: " .. tostring(err) .. "\n")
            Utils.WriteCrashLog(err)
        end
    end

    local on_data_package_changed = function(data_package)
        print("[Archipelago] Data package changed\n")
    end

    local on_print = function(msg)
        print("[Archipelago]" .. msg .. "\n")
    end

    local on_print_json = function(msg, extra)
        print("[Archipelago] JSON Message:")
        if ap ~= nil then
            print(ap:render_json(msg, message_format) .. "\n")
        end
    end

    local on_bounced = function(bounce)
        print("[Archipelago] Bounced" .. "\n")
    end

    local on_retrieved = function(map, keys, extra)
        print("[Archipelago] Retrieved" .. "\n")
    end

    local on_set_reply = function(message)
        print("[Archipelago] Set Reply\n")
    end

    local uuid = ""
    print("[Archipelago] Connecting to server ...")
    print("UUID: " .. uuid .. " Game Name: " .. game_name .. " Server: " .. server)
    ap = AP(uuid, game_name, server);
    print("[Archipelago] AP client created, setting up handlers ...")
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
            local success, err = pcall(function()
                    if ap ~= nil then
                        print("connecting")
                        local poll_success, poll_err = pcall(
                            function()
                                ap:poll()
                            end)
                        if not poll_success then
                            print(
                                "[Archipelago] Error polling AP client with error: " ..
                                tostring(poll_err) .. "\n"
                            )
                            return false
                        end
                    else
                        print("[Archipelago] AP client reference is nil, cannot poll.\n")
                        return false
                    end
            end)
            if not success then
                print(
                    "[Archipelago] Error polling AP client with error: " ..
                    tostring(err) .. "\n"
                )
                if err and not string.match(tostring(err), "not connected") then
                    Utils.WriteCrashLog(err)
                end
            end
            return true
        end)
    end)
end


--
--         if not success then
--             print("[Archipelago] Socket failed with error: " .. tostring(err))
--             return false
--         end
--     else
--         print("[Archipelago] Socket failed: AP client reference is nil.")
--         return false
--     end
--     return true
-- end)
function Archipelago:Disconnect()
    ap = nil
    collectgarbage("collect")
end

function Archipelago:SendLocationFromName(locationName)
    if type(self.PendingChecks) ~= "table" then
        self.PendingChecks = {}
    end

    print("[Archipelago] SendLocationFromName triggered for: " .. tostring(locationName) .. "\n")

    if locationName == nil or type(locationName) ~= "string" then
        print("[Archipelago] ERROR: Location name is nil or not a string.\n")
        return
    end

    if playerID == 0 or ap == nil or type(ap) ~= "userdata" then
        print("[Archipelago] AP client not connected. Queueing location: " .. tostring(locationName) .. "\n")
        table.insert(self.PendingChecks, locationName)
        return
    end

    local locationID = self:GetAPLocationIDfromName(locationName)
    if locationID == nil then
        print("[Archipelago] ERROR: Could not find AP Location ID for name: " .. tostring(locationName) .. "\n")
        return
    end

    print("[Archipelago] Resolved location ID: " .. tostring(locationID) .. " -> Converting to number...\n")
    local numericID = tonumber(locationID)
    if numericID == nil then
        print("[Archipelago] ERROR: Failed to convert location ID to a number.\n")
        return
    end

    print("[Archipelago] Attempting to call ap:LocationChecks with ID: " .. tostring(numericID) .. "\n")

    local success, err = pcall(function()
        local queued = ap:LocationChecks({numericID})
        return queued
    end)

    if not success then
        print("[Archipelago] CRITICAL: ap:LocationChecks threw an error: " .. tostring(err) .. "\n")
        Utils.WriteCrashLog(err)
        table.insert(self.PendingChecks, locationName)
    else
        print("[Archipelago] SUCCESS: Location check successfully transmitted to server!\n")
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
    local id = ArchipelagoLists.LocationNameToAPId[locationName]
    if id ~= nil then
        return id
    else
        return nil
    end
end

return Archipelago