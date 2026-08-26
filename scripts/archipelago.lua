local Archipelago = {}
Archipelago.PendingChecks = {}
Archipelago.sendingChecks = {}

local ArchipelagoLists = require "ArchipelagoLists"
local AP = require "lua-apclientpp"
local Utils = require "utils"

-- global to this mod
local game_name = "Cash Cleaner Simulator"
local items_handling = 7  -- full remote
local client_version = {0, 6, 4}  -- optional, defaults to lib version
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
        if not data.host or data.host == "" then
            self.host = "localhost:38281"
        else
            self.host = data.host
        end

        self.slot = data.player
        self.password = data.password
        self.seed = data.seed
        self.MarketLogic:SetMarketSeed(
            math.tointeger(
                math.fmod(
                    self.seed, math.maxinteger
                )
            )
        )
    end
end

function Archipelago:Connect(server, slot, password)
    local on_socket_connected = function()
        print("[Archipelago] Socket connected\n" )
        Utils.Notify("[Archipelago] Connection Established")
    end

    local on_socket_error = function(msg)
       print("[Archipelago] Socket error: " .. msg .. "\n")
       Utils.Notify("[Archipelago] Connection Failed: " .. tostring(msg).."\n")
    end

    local on_socket_disconnected = function()
        print("[Archipelago] Socket disconnected\n")
        Utils.Notify("[Archipelago] Disconnected from server\n")
    end

    local on_room_info = function()
        print("[Archipelago] Room info\n")
        if ap then
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
        print("[Archipelago] Slot connected\n")
        if ap then
            playerID = ap:get_player_number()
            ap:ConnectUpdate(nil, {"Lua-APClientPP"})
        end
        Utils.Notify("[Archipelago] Connected to server\n")

        if not self.PendingChecks or type(self.PendingChecks) ~= "table" or #self.PendingChecks == 0 then
            print("[Archipelago] No pending checks to flush\n")
            return
        else
            print("[Archipelago] Pushing " .. #self.PendingChecks .. " checks to server\n")
        end

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
        print("[Archipelago] Slot refused: " .. table.concat(reasons, ", ") .. "\n")
        Utils.Notify("[Archipelago] Slot refused: " .. table.concat(reasons, ", ") .. "\n")
    end 

    local on_items_received = function(items)
        local success, err = pcall(function()
            for _, item in ipairs(items) do
                local location
                local player = nil
            
                if item.player == playerID then
                    location = ArchipelagoLists.APLocationIdToName[item.location]
                    if location == nil then
                        print("[Archipelago] WARNING: Missing location mapping for ID: " .. tostring(item.location) .. "\n")
                    end
                    player = self.slot
                else
                    location = item.player .. "-" .. item.location
                    if ap then
                        player = ap:get_player_alias(item.player)
                    end
                end
                if location and not self.CheckedLocation[location] then
                        local reward = ArchipelagoLists.APItemIdToName[item.item]
                        if reward == nil then
                            print("[Archipelago] WARNING: Missing item mapping for ID: " .. tostring(item.item) .. "\n")
                        end

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
        end)
        if not success then
            Utils.WriteCrashLog(err)
            print("[Archipelago] Error processing received items: " .. tostring(err) .. "\n")
        end
    end

    local on_location_info = function(items)
        print("[Archipelago] Locations scouted\n")
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

    local seedStr = string.format("%.0f", tonumber(self.seed) or 0)
    local uuid = tostring(slot) .. "_" .. seedStr

    print("UUID: " .. uuid .. " Game Name: " .. game_name .. " Server: " .. server .. "\n")
    local success, err = pcall(
        function()
            ap = AP(uuid, game_name, server);
    end)

    print("apcalled")
    if not success or ap == nil then
        print("[Archipelago] Failed to initialize AP client: " .. tostring(err) .. "\n")
        Utils.Notify("[Randomizer] Connection failed. Check your server address\n")
        return
    end
    print("[Archipelago] Connecting to " .. server .. " ...")
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
    -- Guard against double initialization calls during boot
    if ap ~= nil then
        print("[Archipelago] Connection already active or initialized, skipping duplicate call.")
        return
    end

    print("[Archipelago] Starting Background Connection to server")
    
    -- Initialize connection in a background thread
    ExecuteAsync(function()
		print("Self.host: '" .. self.host .. "'\n")
		print("Self.slot: '" .. self.slot .. "'\n")
		print("Self.password: '" .. self.password .. "'\n")
        self:Connect(self.host, self.slot, self.password)
    end)
    
    -- Primary polling loop (runs every 250ms)
    LoopAsync(250, function()
        if ap ~= nil then
            local ok, err = pcall(function()
                ap:poll()
            end)
            if not ok then
                print("[Archipelago] Error during poll: " .. tostring(err) .. "\n")
                Utils.WriteCrashLog(err)
            end
        end
        return true
    end)

    -- Auto-retry to reconnect (runs every 30 seconds)
    LoopAsync(30000, function()
        if ap == nil then
            print("[Archipelago] Connection dropped. Attempting to reconnect...")
            Utils.Notify("[Archipelago] Reconnecting...")
            self:Disconnect()
            ExecuteAsync(function()
                self:Connect(self.host, self.slot, self.password)
            end)
        end
        return true
    end)
end

function Archipelago:Disconnect()
    if ap ~= nil then
        pcall(function ()
            ap:reset()         
        end)
    end
    ap = nil
    collectgarbage("collect")
end

function Archipelago:SendLocationFromName(locationName)
    local locationID = self:GetAPLocationIDfromName(locationName)
    if ap == nil then
        print("AP client not connected, cannot send location")
        return
    end
     
    if locationID == nil then
        print("Location name:"..locationName.."Is not valid.")
        return
    end
    ap:LocationChecks({tonumber(locationID)})
end

function Archipelago:Goal()
    if ap == nil then
        print("AP client not connected, cannot send goal")
        return
    end
    ap:StatusUpdate(AP.ClientStatus.GOAL)
end

---@param locationName string
---@return integer?
function Archipelago:GetAPLocationIDfromName(locationName)
    return ArchipelagoLists.LocationNameToAPId[locationName]
end

return Archipelago