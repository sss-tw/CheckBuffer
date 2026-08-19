-- ----------------------------------------
-- CheckBufferConsumable - 药剂食物检查
-- 面向 WoW 1.12，避免使用 Lua 5.1+ 语法
-- ----------------------------------------

if not CheckBufferCommon then
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[CheckBufferConsumable]|r 错误: CheckBufferCommon模块未加载!")
    return
end

if not CheckBufferProfilesAPI then
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[CheckBufferConsumable]|r 错误: CheckBufferProfiles模块未加载!")
    return
end

local PrintMessage = CheckBufferCommon.PrintMessage
local HasBuff = CheckBufferCommon.HasBuff
local HasFoodBuff = CheckBufferCommon.HasFoodBuff
local UseItem = CheckBufferCommon.UseItem
local HasWeaponEnchant = CheckBufferCommon.HasWeaponEnchant
local ProfilesAPI = CheckBufferProfilesAPI

local function Trim(text)
    if not text then
        return ""
    end
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    return text
end

local function FindItemByName(items, itemName)
    local i
    for i = 1, table.getn(items) do
        if items[i].name == itemName then
            return items[i]
        end
    end
    return nil
end

local function ItemIsRuleCandidate(rule, itemName)
    local i
    if not rule or not rule.candidates then
        return false
    end
    for i = 1, table.getn(rule.candidates) do
        if rule.candidates[i] == itemName then
            return true
        end
    end
    return false
end

local function CheckSingleConsumable(consumable)
    local hasBuff = false
    local timeLeft = 0

    if not consumable then
        return false, 0
    end

    if consumable.type == "food" and consumable.effect then
        PrintMessage("[DEBUG] 即将检查食物效果: " .. consumable.effect, false)
        hasBuff, timeLeft = HasFoodBuff(consumable.effect)
    elseif consumable.type == "enchant" then
        local effectName = consumable.effect or consumable.name
        PrintMessage("[DEBUG] 即将检查武器附魔: " .. effectName .. "（" .. (consumable.slot or "any") .. "）", false)
        hasBuff, timeLeft = HasWeaponEnchant(consumable.slot or "any", effectName)
    else
        local buffName = consumable.buffName or consumable.name
        PrintMessage("[DEBUG] 即将检查药剂buff: " .. buffName, false)
        hasBuff, timeLeft = HasBuff(buffName)
    end

    PrintMessage("[DEBUG] 消耗品 " .. (consumable.name or "未知") .. " 检查结果: " .. tostring(hasBuff), false)
    return hasBuff, timeLeft
end

local function BuildRuleStates(items, rules)
    local states = {}
    local requiredByItem = {}
    local ruleName, rule, state, i, candidateName, candidateItem, hasBuff, timeLeft, requires, requiredName

    if not rules then
        return states, requiredByItem
    end

    for ruleName, rule in pairs(rules) do
        state = {
            rule = rule,
            activeCandidate = nil,
            activeTimeLeft = 0,
            hasActive = false
        }

        if rule.candidates then
            for i = 1, table.getn(rule.candidates) do
                candidateName = rule.candidates[i]
                candidateItem = FindItemByName(items, candidateName)
                if candidateItem then
                    hasBuff, timeLeft = CheckSingleConsumable(candidateItem)
                    if hasBuff then
                        state.activeCandidate = candidateName
                        state.activeTimeLeft = timeLeft or 0
                        state.hasActive = true
                        break
                    end
                end
            end
        end

        if rule.requiresWhenPresent then
            for candidateName, requires in pairs(rule.requiresWhenPresent) do
                if requires then
                    for i = 1, table.getn(requires) do
                        requiredName = requires[i]
                        if not requiredByItem[requiredName] then
                            requiredByItem[requiredName] = {}
                        end
                        table.insert(requiredByItem[requiredName], ruleName)
                    end
                end
            end
        end

        states[ruleName] = state
    end

    return states, requiredByItem
end

local function RuleRequiresItem(state, itemName)
    local requires, i
    if not state or not state.hasActive or not state.rule or not state.rule.requiresWhenPresent then
        return false
    end
    requires = state.rule.requiresWhenPresent[state.activeCandidate]
    if not requires then
        return false
    end
    for i = 1, table.getn(requires) do
        if requires[i] == itemName then
            return true
        end
    end
    return false
end

local function ShouldSkipRequiredItem(itemName, states, requiredByItem)
    local ruleNames = requiredByItem[itemName]
    local i, ruleName

    if not ruleNames then
        return false
    end

    for i = 1, table.getn(ruleNames) do
        ruleName = ruleNames[i]
        if RuleRequiresItem(states[ruleName], itemName) then
            return false
        end
    end

    return true
end

local function ResolveProfile(profileKey)
    local profile, profileName = ProfilesAPI.GetProfile(profileKey)
    return profileName, profile
end

-- 检查指定 profile 的消耗品
local function CheckRoleConsumables(profileKey)
    profileKey = Trim(profileKey)
    PrintMessage("[DEBUG] 开始检查Profile: " .. (profileKey or "nil"), false)

    local profileName, profile = ResolveProfile(profileKey)
    if not profile then
        PrintMessage("未知Profile: " .. (profileKey or ""), true)
        PrintMessage("可用Profile: " .. ProfilesAPI.GetProfileListText(), true)
        return false, {}
    end

    local items = profile.items or {}
    local rules = profile.rules or {}
    local ruleStates, requiredByItem = BuildRuleStates(items, rules)
    local missingConsumables = {}
    local detectedConsumables = {}
    local i, consumable, hasBuff, timeLeft, state

    PrintMessage("[DEBUG] 找到 " .. table.getn(items) .. " 个 " .. profileName .. " 消耗品定义", false)

    for i = 1, table.getn(items) do
        consumable = items[i]
        hasBuff = false
        timeLeft = 0

        PrintMessage("[DEBUG] 检查第 " .. i .. " 个消耗品: " .. consumable.name, false)

        if consumable.ruleGroup and ruleStates[consumable.ruleGroup] and ItemIsRuleCandidate(ruleStates[consumable.ruleGroup].rule, consumable.name) then
            state = ruleStates[consumable.ruleGroup]
            if state.hasActive then
                hasBuff = true
                timeLeft = state.activeTimeLeft
                PrintMessage("[DEBUG] 规则组 " .. consumable.ruleGroup .. " 已由 " .. state.activeCandidate .. " 满足，跳过候选 " .. consumable.name, false)
            else
                hasBuff, timeLeft = CheckSingleConsumable(consumable)
            end
        elseif ShouldSkipRequiredItem(consumable.name, ruleStates, requiredByItem) then
            hasBuff = true
            timeLeft = 0
            PrintMessage("[DEBUG] " .. consumable.name .. " 不是当前互斥路线的额外要求，跳过检查", false)
        else
            hasBuff, timeLeft = CheckSingleConsumable(consumable)
        end

        if hasBuff then
            table.insert(detectedConsumables, {
                name = consumable.name,
                type = consumable.type,
                timeLeft = timeLeft or 0
            })
        else
            table.insert(missingConsumables, consumable)
        end
    end

    PrintMessage("[DEBUG] 检查完成，缺少 " .. table.getn(missingConsumables) .. " 个消耗品", false)

    if table.getn(missingConsumables) > 0 then
        PrintMessage("|cFFFFFF00缺少以下" .. profileName .. "消耗品:|r", true)
        for i = 1, table.getn(missingConsumables) do
            PrintMessage("- " .. missingConsumables[i].name, true)
        end
        return false, missingConsumables
    end

    PrintMessage("所有" .. profileName .. "需要的消耗品都已使用！", true)
    return true, {}
end

local function CheckConsumablesByRole(profileKey)
    if not profileKey or Trim(profileKey) == "" then
        PrintMessage("未提供Profile。可用Profile: " .. ProfilesAPI.GetProfileListText(), true)
        return false
    end
    return CheckRoleConsumables(profileKey)
end

local function ShowConsumableHelp()
    PrintMessage("消耗品检查模块", true)
    PrintMessage("/cbc <Profile名|缩略名|旧参数> - 检查指定Profile消耗品", true)
    PrintMessage("示例: /cbc 法系DPS, /cbc m, /cbc mdps", true)
    PrintMessage("可用Profile: " .. ProfilesAPI.GetProfileListText(), true)
end

function CheckBuffer_CheckConsumableProfile(profileKey)
    return CheckConsumablesByRole(profileKey)
end

function CheckBuffer_CheckConsumableProfileByIndex(profileIndex)
    local names = ProfilesAPI.ListProfiles()
    local profileName = names[profileIndex]
    if profileName then
        return CheckConsumablesByRole(profileName)
    end
    PrintMessage("没有找到第 " .. tostring(profileIndex) .. " 个Profile", true)
    return false
end

SLASH_CHECKBUFFCONSUMABLE1 = "/checkbc"
SLASH_CHECKBUFFCONSUMABLE2 = "/cbc"
SlashCmdList["CHECKBUFFCONSUMABLE"] = function(msg)
    local command = Trim(msg or "")
    local lowerCommand = string.lower(command)

    PrintMessage("[DEBUG] 收到命令: /cbc " .. command, false)

    local status, result = pcall(function()
        if command == "" or lowerCommand == "help" or command == "?" then
            ShowConsumableHelp()
        else
            CheckConsumablesByRole(command)
        end
    end)

    if not status then
        PrintMessage("[ERROR] 执行命令时出错: " .. (result or "未知错误"), true)
        PrintMessage("使用 /cbc help 查看帮助", true)
    end
end

CheckBufferConsumableAPI = {
    CheckRoleConsumables = CheckRoleConsumables,
    CheckConsumablesByRole = CheckConsumablesByRole,
    ResolveProfile = ResolveProfile,
    CheckSingleConsumable = CheckSingleConsumable,
    CanAutoUse = ProfilesAPI.CanAutoUse,
    UseConsumable = UseItem
}

PrintMessage("药剂食物检查模块已加载，使用 /cbc help 查看帮助", true)
