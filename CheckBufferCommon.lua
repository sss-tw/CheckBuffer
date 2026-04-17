-- ----------------------------------------
-- CheckBufferCommon - WoW乌龟服团队Buff检查插件通用函数
-- 作者：旧德
-- 版本：1.0.1
-- ----------------------------------------

-- 初始化变量
local addonName = "CheckBuffer"
local addonVersion = "1.0.1"
-- 日志输出控制变量，设置为false表示不输出调试日志
local logEnabled = false
-- 默认通信频道，默认为团队频道
local chatChannel = "RAID"

-- 可用的频道列表
local availableChannels = {
    ["RAID"] = "团队",
    ["PARTY"] = "小队",
    ["SAY"] = "说话",
    ["YELL"] = "大喊",
    ["GUILD"] = "公会",
    ["OFFICER"] = "官员"
}

-- 职业名称映射（游戏内英文职业名与中文名的对应）
local classNameMap = {
    ["WARRIOR"] = "战士",
    ["PALADIN"] = "圣骑士",
    ["HUNTER"] = "猎人",
    ["ROGUE"] = "盗贼",
    ["PRIEST"] = "牧师",
    ["SHAMAN"] = "萨满祭司",
    ["MAGE"] = "法师",
    ["WARLOCK"] = "术士",
    ["DRUID"] = "德鲁伊"
}

-- 反向映射（中文名到英文名）
local reverseClassNameMap = {}
for engName, locName in pairs(classNameMap) do
    reverseClassNameMap[locName] = engName
end

-- 打印插件消息
-- isResult 参数：true表示这是结果消息，始终输出；false或nil表示这是调试消息，根据logEnabled控制是否输出
local function PrintMessage(message, isResult)
    if isResult or logEnabled then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF33AAFF[CheckBuffer]|r " .. message)
    end
end

-- 启用或禁用日志输出
local function SetLogEnabled(enabled)
    logEnabled = enabled
    PrintMessage("日志输出已" .. (enabled and "启用" or "禁用"), true)
end

-- 获取当前日志状态
local function GetLogEnabled()
    return logEnabled
end

-- 设置通信频道
local function SetChatChannel(channel)
    -- 检查是否是有效的频道
    if availableChannels[channel] then
        chatChannel = channel
        PrintMessage("通信频道已设置为: " .. availableChannels[channel] .. " (" .. channel .. ")", false)
        return true
    else
        PrintMessage("无效的频道: " .. channel, false)
        PrintMessage("可用频道: RAID(团队), PARTY(小队), SAY(说话), YELL(大喊), GUILD(公会), OFFICER(官员)", false)
        return false
    end
end

-- 获取当前通信频道
local function GetChatChannel()
    return chatChannel
end

-- 获取当前通信频道的中文描述
local function GetChatChannelName()
    return availableChannels[chatChannel] or "未知"
end

-- 列出所有可用频道
local function ListAvailableChannels()
    PrintMessage("可用的通信频道:", false)
    for code, name in pairs(availableChannels) do
        local current = ""
        if code == chatChannel then
            current = " (当前)"
        end
        PrintMessage("- " .. code .. " - " .. name .. current, false)
    end
end

-- 为buff检查创建Tooltip框架
local BuffCheckTooltip = _G["CheckBufferTooltip"] or CreateFrame("GameTooltip", "CheckBufferTooltip", UIParent, "GameTooltipTemplate")

-- 检查玩家是否有指定buff，并返回剩余时间和buff描述
local function HasBuff(buffName, checkEffect)
    -- 使用GetPlayerAuraIndex获取buff索引
    local buffIndex = GetPlayerAuraIndex(buffName)
    
    -- 如果找到了buff
    if buffIndex and buffIndex >= 0 then
        -- 使用GetPlayerBuffTimeLeft获取剩余时间（秒）
        local timeLeft = GetPlayerBuffTimeLeft(buffIndex)
        -- 获取buff的详细描述（用于食物等需要检查效果的情况）
        local buffDesc = ""
        
        if checkEffect then
            -- 使用tooltip来获取buff的完整描述
            BuffCheckTooltip:SetOwner(UIParent, "ANCHOR_NONE")
            BuffCheckTooltip:ClearLines()
            BuffCheckTooltip:SetPlayerBuff(buffIndex)
            
            -- 获取第一行（buff名称）
            local line1 = CheckBufferTooltipTextLeft1:GetText() or ""
            -- 获取第二行（buff效果）
            local line2 = CheckBufferTooltipTextLeft2:GetText() or ""
            
            buffDesc = line1 .. "|" .. line2
        end
        
        -- 输出buff名称和剩余秒数用于调试
        PrintMessage("检测到buff: " .. buffName .. " - 剩余时间: " .. math.floor(timeLeft) .. "秒", false)
        return true, timeLeft, buffDesc
    end
    
    -- 检查debuff（某些负面效果也可能需要检查）
    BuffCheckTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    local i = 1
    while UnitDebuff("player", i) do
        BuffCheckTooltip:ClearLines()
        BuffCheckTooltip:SetUnitDebuff("player", i)
        local tooltipText = CheckBufferTooltipTextLeft1:GetText()
        
        if tooltipText == buffName then
            PrintMessage("检测到debuff: " .. buffName .. " - 无法获取剩余时间", false)
            return true, nil, tooltipText  -- debuff通常不需要检查剩余时间
        end
        i = i + 1
    end
    
    return false, nil, ""
end

-- 获取团队中指定职业的玩家名单
local function GetRaidMembersByClass(className)
    local members = {}
    
    -- 如果传入的是中文职业名，转换为英文
    local englishClassName = reverseClassNameMap[className] or className
    
    -- 遍历团队成员
    for i = 1, 40 do
        local name, _, _, _, _, class = GetRaidRosterInfo(i)
        if name and class == englishClassName then
            table.insert(members, name)
        end
    end
    
    return members
end

-- 使用物品
local function UseItem(itemName)
    -- 查找背包中的物品
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local link = GetContainerItemLink(bag, slot)
            if link and string.find(link, itemName) then
                -- 找到物品，使用它
                PrintMessage("使用物品: " .. itemName, false)
                UseContainerItem(bag, slot)
                return true
            end
        end
    end
    
    PrintMessage("未找到物品: " .. itemName, false)
    return false
end

-- 检查食物buff，通过检查buff效果来匹配
local function HasFoodBuff(foodEffectDesc)
    PrintMessage("[DEBUG] HasFoodBuff: 开始检查食物效果: " .. (foodEffectDesc or "nil"), false)
    
    -- 安全检查
    if not foodEffectDesc or foodEffectDesc == "" then
        PrintMessage("[DEBUG] HasFoodBuff: 食物效果描述为空，返回false", false)
        return false, nil, ""
    end
    
    -- 初始化
    local i = 0
    local maxBuffs = 32  -- 设置一个合理的上限，防止无限循环
    PrintMessage("[DEBUG] HasFoodBuff: 开始遍历玩家身上的buff", false)
    
    -- 遍历所有buff，使用安全计数器防止无限循环
    while i < maxBuffs do
        local buffIndex = GetPlayerBuff(i)
        PrintMessage("[DEBUG] HasFoodBuff: 检查buff索引 " .. i .. ": " .. (buffIndex or "nil"), false)
        
        if buffIndex < 0 then
            PrintMessage("[DEBUG] HasFoodBuff: 到达buff列表末尾", false)
            break  -- 已经检查完所有buff
        end
        
        -- 使用tooltip获取详细信息
        PrintMessage("[DEBUG] HasFoodBuff: 设置tooltip", false)
        BuffCheckTooltip:SetOwner(UIParent, "ANCHOR_NONE")
        BuffCheckTooltip:ClearLines()
        
        -- 这里可能会出错，添加保护
        local tooltipSuccess = pcall(function()
            BuffCheckTooltip:SetPlayerBuff(buffIndex)
        end)
        
        if not tooltipSuccess then
            PrintMessage("[DEBUG] HasFoodBuff: 设置buff tooltip失败，继续检查下一个", false)
            i = i + 1
            -- 使用标准循环结构代替goto
        else
        
        -- 安全获取文本
        local buffName = ""
        local effect = ""
        
        if CheckBufferTooltipTextLeft1 and CheckBufferTooltipTextLeft1:GetText() then
            buffName = CheckBufferTooltipTextLeft1:GetText()
            PrintMessage("[DEBUG] HasFoodBuff: buff名称: " .. buffName, false)
        else
            PrintMessage("[DEBUG] HasFoodBuff: 无法获取buff名称", false)
        end
        
        if CheckBufferTooltipTextLeft2 and CheckBufferTooltipTextLeft2:GetText() then
            effect = CheckBufferTooltipTextLeft2:GetText()
            PrintMessage("[DEBUG] HasFoodBuff: buff效果: " .. effect, false)
        else
            PrintMessage("[DEBUG] HasFoodBuff: 无法获取buff效果", false)
        end
        
        -- 直接检查效果是否匹配（按照开头匹配），不限定buff类型
        local matchesEffect = false
        if effect and effect ~= "" and foodEffectDesc and foodEffectDesc ~= "" then
            -- 检查effect是否以foodEffectDesc开头
            matchesEffect = string.sub(effect, 1, string.len(foodEffectDesc)) == foodEffectDesc
        end
        
        PrintMessage("[DEBUG] HasFoodBuff: 效果匹配？" .. tostring(matchesEffect), false)
        
        if matchesEffect then
            local timeLeft = 0
            local timeSuccess, timeError = pcall(function()
                timeLeft = GetPlayerBuffTimeLeft(buffIndex)
            end)
            
            if not timeSuccess then
                PrintMessage("[DEBUG] HasFoodBuff: 获取buff剩余时间失败: " .. (timeError or "未知错误"), false)
                timeLeft = 0
            end
            
            PrintMessage("[DEBUG] HasFoodBuff: 找到匹配食物buff: " .. buffName .. " - 效果: " .. effect .. " - 剩余时间: " .. math.floor(timeLeft) .. "秒", false)
            return true, timeLeft, buffName .. "|" .. effect
        end
        
        end
        i = i + 1  -- 移动到下一个buff
    end
    
    PrintMessage("[DEBUG] HasFoodBuff: 未找到匹配食物效果，返回false", false)
    return false, nil, ""
end

-- 检查武器临时附魔
local function HasWeaponEnchant(slot, enchantName)
    -- 安全检查参数
    if not enchantName then
        return false, 0
    end
    
    -- 设置默认值
    local slotName = ""
    local weaponText = ""
    
    -- 根据参数确定槽位名称
    if string.lower(slot) == "main" or string.lower(slot) == "mainhand" or string.lower(slot) == "mainhandslot" then
        slotName = "MainHandSlot"
        weaponText = "主手"
    elseif string.lower(slot) == "off" or string.lower(slot) == "offhand" or string.lower(slot) == "secondaryhandslot" then
        slotName = "SecondaryHandSlot"
        weaponText = "副手"
    else
        return false, 0
    end
    
    -- 转义特殊字符，处理效果名称中可能包含的Lua模式匹配特殊字符
    local escapedName = enchantName
    local needsEscape = false
    
    -- 检查是否包含需要转义的特殊字符
    if string.find(enchantName, "[%%%+%-%*%?%.%[%]%(%)]") then
        needsEscape = true
        -- 转义所有特殊字符
        escapedName = string.gsub(enchantName, "%%", "%%%%") -- %
        escapedName = string.gsub(escapedName, "%+", "%%+") -- +
        escapedName = string.gsub(escapedName, "%-", "%%-") -- -
        escapedName = string.gsub(escapedName, "%*", "%%*") -- *
        escapedName = string.gsub(escapedName, "%?", "%%?") -- ?
        escapedName = string.gsub(escapedName, "%.", "%%.") -- .
        escapedName = string.gsub(escapedName, "%[", "%%[") -- [
        escapedName = string.gsub(escapedName, "%]", "%%]") -- ]
        escapedName = string.gsub(escapedName, "%(", "%%(") -- (
        escapedName = string.gsub(escapedName, "%)", "%%)") -- )
        
        PrintMessage("[DEBUG] 效果名称包含特殊字符，转义后: " .. escapedName, false)
    end
    
    -- 使用Tooltip检查武器附魔
    BuffCheckTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    BuffCheckTooltip:ClearLines()
    BuffCheckTooltip:SetInventoryItem("player", GetInventorySlotInfo(slotName))
    
    -- 遍历tooltip的所有行，查找匹配的附魔
    for i = 1, BuffCheckTooltip:NumLines() do
        local line = _G["CheckBufferTooltipTextLeft"..i]
        if line and line:GetText() then
            local text = line:GetText()
            PrintMessage("[DEBUG] 武器Tooltip行" .. i .. ": " .. text, false)
            
            -- 检查文本是否包含指定的附魔效果名称（使用转义后的名称）
            if string.find(text, escapedName) then
                local timeLeft = 600 -- 默认10分钟
                
                -- 尝试从文本中提取括号内的时间信息，支持全角和半角括号
                -- 格式可能是 "效果名称 (XX分钟)" 或 "效果名称 （XX分钟）"
                -- 或 "效果名称 (XX秒)" 或 "效果名称 （XX秒）"
                local timeText = string.match(text, "%((.-)%)") or string.match(text, "（(.-)）")
                if timeText then
                    PrintMessage("[DEBUG] 发现时间信息: " .. timeText, false)
                    
                    timeLeft = 0
                    
                    -- 尝试解析"分钟"
                    local minutes = string.match(timeText, "(%d+)分钟")
                    if not minutes then
                        -- 尝试其他可能的格式
                        minutes = string.match(timeText, "(%d+)分")
                    end
                    minutes = minutes and tonumber(minutes) or 0
                    
                    -- 尝试解析"秒"
                    local seconds = string.match(timeText, "(%d+)秒")
                    seconds = seconds and tonumber(seconds) or 0
                    
                    -- 计算总秒数
                    timeLeft = (minutes * 60) + seconds
                    
                    -- 如果未找到有效时间，使用默认值
                    if timeLeft <= 0 then
                        timeLeft = 600  -- 默认10分钟
                    end
                end
                
                PrintMessage("[DEBUG] 检测到" .. weaponText .. "武器附魔: " .. enchantName .. " - 文本: " .. text, false)
                if timeLeft > 0 then
                    PrintMessage("[DEBUG] 附魔剩余时间: " .. math.floor(timeLeft / 60) .. "分" .. math.floor(math.mod(timeLeft, 60)) .. "秒", false)
                end
                
                return true, timeLeft
            end
        end
    end
    
    return false, 0
end

-- 导出通用API
CheckBufferCommon = {}
CheckBufferCommon.addonName = addonName
CheckBufferCommon.addonVersion = addonVersion
CheckBufferCommon.classNameMap = classNameMap
CheckBufferCommon.reverseClassNameMap = reverseClassNameMap
CheckBufferCommon.PrintMessage = PrintMessage
CheckBufferCommon.HasBuff = HasBuff
CheckBufferCommon.GetRaidMembersByClass = GetRaidMembersByClass
CheckBufferCommon.UseItem = UseItem
CheckBufferCommon.HasFoodBuff = HasFoodBuff
CheckBufferCommon.HasWeaponEnchant = HasWeaponEnchant
CheckBufferCommon.SetLogEnabled = SetLogEnabled
CheckBufferCommon.GetLogEnabled = GetLogEnabled
CheckBufferCommon.SetChatChannel = SetChatChannel
CheckBufferCommon.GetChatChannel = GetChatChannel
CheckBufferCommon.GetChatChannelName = GetChatChannelName
CheckBufferCommon.ListAvailableChannels = ListAvailableChannels
CheckBufferCommon.BuffCheckTooltip = BuffCheckTooltip
CheckBufferCommon.logEnabled = logEnabled
CheckBufferCommon.chatChannel = chatChannel

-- 打印加载消息
PrintMessage("通用函数库已加载", true)