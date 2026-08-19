-- ----------------------------------------
-- CheckBufferAutoConsume - 自动使用缺失消耗品
-- 面向 WoW 1.12，避免使用 Lua 5.1+ 语法
-- ----------------------------------------

if not CheckBufferCommon then
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[CheckBufferAutoConsume]|r 错误: CheckBufferCommon模块未加载!")
    return
end

if not CheckBufferConsumableAPI then
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[CheckBufferAutoConsume]|r 错误: CheckBufferConsumableAPI模块未加载!")
    return
end

if not CheckBufferProfilesAPI then
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[CheckBufferAutoConsume]|r 错误: CheckBufferProfiles模块未加载!")
    return
end

local PrintMessage = CheckBufferCommon.PrintMessage
local UseItem = CheckBufferCommon.UseItem
local ConsumableAPI = CheckBufferConsumableAPI
local ProfilesAPI = CheckBufferProfilesAPI

local function Trim(text)
    if not text then
        return ""
    end
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    return text
end

local function IsEatingOrDrinking()
    if CheckBufferCommon.HasBuff("进食") and not CheckBufferCommon.HasBuff("进食充分") then
        PrintMessage("[DEBUG_AUTOCONSUME] 检测到吃喝buff: 进食", false)
        return true
    end

    if CheckBufferCommon.HasBuff("食物") then
        PrintMessage("[DEBUG_AUTOCONSUME] 检测到吃喝buff: 食物", false)
        return true
    end

    return false
end

local function AutoConsumeProfile(profileKey)
    profileKey = Trim(profileKey)
    PrintMessage("[DEBUG_AUTOCONSUME] 开始自动吃药: " .. tostring(profileKey), false)

    local profile, profileName = ProfilesAPI.GetProfile(profileKey)
    if not profile then
        PrintMessage("未找到Profile: " .. tostring(profileKey), true)
        PrintMessage("可用Profile: " .. ProfilesAPI.GetProfileListText(), true)
        return false
    end

    if IsEatingOrDrinking() then
        PrintMessage("正在吃喝中，跳过自动吃药", true)
        return false
    end

    local ok, missing = ConsumableAPI.CheckRoleConsumables(profileName)
    PrintMessage("[DEBUG_AUTOCONSUME] CheckRoleConsumables 返回 ok=" .. tostring(ok) .. " missingCount=" .. (missing and table.getn(missing) or 0), false)

    if not ok and missing and table.getn(missing) > 0 then
        local itemUsed = false
        local skippedItems = {}
        local i, item, currentTargetName, success

        for i = 1, table.getn(missing) do
            item = missing[i]
            if not ProfilesAPI.CanAutoUse(item) then
                table.insert(skippedItems, item.name .. "(只检查)")
            else
                PrintMessage("缺少 " .. item.name .. "，尝试使用", true)
                currentTargetName = UnitName("target")
                ClearTarget()
                success = UseItem(item.name)
                if currentTargetName then
                    TargetByName(currentTargetName)
                end

                if success then
                    itemUsed = true
                    PrintMessage("成功使用了 " .. item.name .. "，由于药水冷却时间，停止使用其他药物", true)
                    break
                else
                    PrintMessage("没有找到" .. item.name .. "，跳过使用", true)
                end
            end
        end

        if table.getn(skippedItems) > 0 then
            PrintMessage("跳过的物品: " .. table.concat(skippedItems, ", "), true)
        end

        if not itemUsed then
            PrintMessage("没有找到可以自动使用的消耗品", true)
        end

        return itemUsed
    end

    PrintMessage("所有消耗品buff均已存在", true)
    return true
end

function CheckBuffer_AutoConsumeProfile(profileKey)
    return AutoConsumeProfile(profileKey)
end

function CheckBuffer_AutoConsumeProfileByIndex(profileIndex)
    local names = ProfilesAPI.ListProfiles()
    local profileName = names[profileIndex]
    if profileName then
        return AutoConsumeProfile(profileName)
    end
    PrintMessage("没有找到第 " .. tostring(profileIndex) .. " 个Profile", true)
    return false
end

SLASH_CHECKBUFFER_AUTOCONSUME1 = "/cbca"
SLASH_CHECKBUFFER_AUTOCONSUME2 = "/cbcauto"
SlashCmdList["CHECKBUFFER_AUTOCONSUME"] = function(msg)
    local command = Trim(msg or "")
    local lowerCommand = string.lower(command)

    if command == "" or lowerCommand == "help" or command == "?" then
        PrintMessage("自动吃药模块", true)
        PrintMessage("/cbca <Profile名|缩略名|旧参数> - 自动使用指定Profile缺失消耗品", true)
        PrintMessage("示例: /cbca 法系DPS, /cbca m, /cbca mdps", true)
        PrintMessage("可用Profile: " .. ProfilesAPI.GetProfileListText(), true)
    else
        AutoConsumeProfile(command)
    end
end

PrintMessage("自动吃药模块已加载，使用 /cbca help 查看帮助", true)
