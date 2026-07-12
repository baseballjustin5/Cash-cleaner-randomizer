for _, bp in pairs(counterBlueprints) do

    local moneyCounterBP = bp.path
    local bpConfig = config[bp.key]
    local allCounter = FindAllOf(bp.key .. "_C")

    if not allCounter or #allCounter == 0 then
        continue
    end
    for _, counter in ipairs(allCounter) do
        if not counter then
            continue
        end

        if counter.MaxIncomingBillsCount then
            counter.MaxIncomingBillsCount = bpConfig.MaxIncomingBillsCount
        end

        if counter.MaxOutgoingBillsCount then
            counter.MaxOutgoingBillsCount = bpConfig.MaxOutgoingBillsCount
        end
    end

    LoadAsset(moneyCounterBP)
    local mainPre, mainPost = RegisterHook(moneyCounterBP .. ":Initialize", function(_self)
        local counter = _self:get()

        if not counter or not counter:IsValid() then
            return
        end

        if counter.MaxIncomingBillsCount then
            counter.MaxIncomingBillsCount = bpConfig.MaxIncomingBillsCount
        end

        if counter.MaxOutgoingBillsCount then
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