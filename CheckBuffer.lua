-- ----------------------------------------
-- CheckBuffer - WoW乌龟服团队Buff检查插件
-- 作者：旧德
-- 版本：1.0.1
-- 功能：检查角色身上的团队buff，并提醒缺失的buff
-- 使用方法：
-- 1. 输入 /cb tank 或 /checkbuff tank - 检查坦克buff
-- 2. 输入 /cb healer 或 /checkbuff healer - 检查治疗buff
-- 3. 输入 /cb pdps 或 /checkbuff pdps - 检查物理DPS buff
-- 4. 输入 /cb mdps 或 /checkbuff mdps - 检查法系DPS buff
-- 5. 输入 /cb help 或 /checkbuff help - 显示帮助信息
-- ----------------------------------------

-- 加载通用函数
local addonName = CheckBufferCommon.addonName
local addonVersion = CheckBufferCommon.addonVersion
local classNameMap = CheckBufferCommon.classNameMap
local reverseClassNameMap = CheckBufferCommon.reverseClassNameMap
local PrintMessage = CheckBufferCommon.PrintMessage
local HasBuff = CheckBufferCommon.HasBuff
local GetRaidMembersByClass = CheckBufferCommon.GetRaidMembersByClass

-- 定义不同角色类型所需的buff
local buffLists = {
    tank = {  -- 坦克
        {name = "王者祝福", provider = "圣骑士", alternativeBuffs = {"强效王者祝福"}},
        {name = "力量祝福", provider = "圣骑士", alternativeBuffs = {"强效力量祝福"}},
        {name = "真言术：韧", provider = "牧师", alternativeBuffs = {"坚韧祷言"}},
        {name = "野性印记", provider = "德鲁伊", alternativeBuffs = {"野性赐福"}}
    },
    healer = {  -- 治疗
        {name = "王者祝福", provider = "圣骑士", alternativeBuffs = {"强效王者祝福"}},
        {name = "智慧祝福", provider = "圣骑士", alternativeBuffs = {"强效智慧祝福"}}, -- 回蓝buff
        {name = "拯救祝福", provider = "圣骑士", alternativeBuffs = {"强效拯救祝福"}},
        {name = "野性印记", provider = "德鲁伊", alternativeBuffs = {"野性赐福"}},
        {name = "真言术：韧", provider = "牧师", alternativeBuffs = {"坚韧祷言"}},
        {name = "精神祷言", provider = "牧师", alternativeBuffs = {"神圣之灵"}},
        {name = "奥术智慧", provider = "法师", alternativeBuffs = {"奥术光辉"}} -- 智慧buff
    },
    pdps = {  -- 物理DPS
        {name = "拯救祝福", provider = "圣骑士", alternativeBuffs = {"强效拯救祝福"}},
        {name = "王者祝福", provider = "圣骑士", alternativeBuffs = {"强效王者祝福"}},
        {name = "力量祝福", provider = "圣骑士", alternativeBuffs = {"强效力量祝福"}},
        {name = "野性印记", provider = "德鲁伊", alternativeBuffs = {"野性赐福"}},
        {name = "真言术：韧", provider = "牧师", alternativeBuffs = {"坚韧祷言"}}
    },
    mdps = {  -- 法系DPS
        {name = "拯救祝福", provider = "圣骑士", alternativeBuffs = {"强效拯救祝福"}},
        {name = "王者祝福", provider = "圣骑士", alternativeBuffs = {"强效王者祝福"}},
        {name = "智慧祝福", provider = "圣骑士", alternativeBuffs = {"强效智慧祝福"}}, -- 回蓝buff
        {name = "野性印记", provider = "德鲁伊", alternativeBuffs = {"野性赐福"}},
        {name = "真言术：韧", provider = "牧师", alternativeBuffs = {"坚韧祷言"}},
        {name = "精神祷言", provider = "牧师", alternativeBuffs = {"神圣之灵"}},
        {name = "奥术智慧", provider = "法师", alternativeBuffs = {"奥术光辉"}} -- 智慧buff
    }
}



-- 根据buffLists顺序处理圣骑士buff的优先级
local function GetOriginalBuffIndex(buff, roleType)
    -- 查找buff在原始buffLists中的索引
    local roleBuffs = buffLists[string.lower(roleType)]
    if not roleBuffs then
        return 999 -- 未知位置，赋予低优先级
    end
    
    for i, originalBuff in ipairs(roleBuffs) do
        if originalBuff.name == buff.name then
            return i -- 返回在buffLists中的索引位置
        end
    end
    
    return 999 -- 未找到，赋予低优先级
end

-- 发送喊话消息
local function SendBuffRequest(missingBuffs, expiringBuffs, goodBuffs, roleType)
    -- 如果没有缺失的buff也没有即将过期的buff，直接返回，不发送喊话
    if table.getn(missingBuffs) == 0 and table.getn(expiringBuffs) == 0 then
        PrintMessage("所有" .. roleType .. "buff齐全且时间充足，无需喊话。", true)
        return
    end
    
    -- 获取玩家信息
    local playerName = UnitName("player")
    local _, playerClass = UnitClass("player")
    local raidID = "未知"
    
    -- 尝试获取玩家所在团队的编号
    if UnitInRaid("player") then
        for i = 1, 40 do
            local name, _, subgroup = GetRaidRosterInfo(i)
            if name == playerName then
                raidID = tostring(subgroup)
                break
            end
        end
    end
    
    -- 构建缺失buff列表
    local missingBuffText = ""
    for i, buff in ipairs(missingBuffs) do
        if i == 1 then
            missingBuffText = buff.name
        elseif i == table.getn(missingBuffs) then
            missingBuffText = missingBuffText .. "和" .. buff.name
        else
            missingBuffText = missingBuffText .. "，" .. buff.name
        end
    end
    
    -- 构建即将到期buff列表
    local expiringBuffText = ""
    if table.getn(expiringBuffs) > 0 then
        expiringBuffText = "另外，"
        for i, buff in ipairs(expiringBuffs) do
            if i == 1 then
                expiringBuffText = expiringBuffText .. buff.name
            elseif i == table.getn(expiringBuffs) then
                expiringBuffText = expiringBuffText .. "和" .. buff.name
            else
                expiringBuffText = expiringBuffText .. "，" .. buff.name
            end
        end
        expiringBuffText = expiringBuffText .. "已经不足5分钟。"
    end
    
    -- 构建请求部分
    local requestText = ""
    
    -- 合并所有需要请求的buff
    local allRequestedBuffs = {}
    for _, buff in ipairs(missingBuffs) do
        if not allRequestedBuffs[buff.provider] then
            allRequestedBuffs[buff.provider] = {}
        end
        table.insert(allRequestedBuffs[buff.provider], buff)
    end
    
    for _, buff in ipairs(expiringBuffs) do
        if not allRequestedBuffs[buff.provider] then
            allRequestedBuffs[buff.provider] = {}
        end
        
        -- 检查是否已经在请求列表中
        local found = false
        for _, existingBuff in ipairs(allRequestedBuffs[buff.provider]) do
            if existingBuff.name == buff.name then
                found = true
                break
            end
        end
        
        if not found then
            table.insert(allRequestedBuffs[buff.provider], buff)
        end
    end
    
    -- 获取玩家自己的职业名称
    local _, playerClass = UnitClass("player")
    
    -- 将玩家职业转为中文（如果是英文）或保留（如果已经是中文）
    local myClassChinese = classNameMap[playerClass] or playerClass
    
    -- 每个职业的请求存储在单独的表中
    local requestsByClass = {}
    
    -- 处理圣骑士buff的优先级
    if allRequestedBuffs["圣骑士"] then
        -- 获取团队中圣骑士的数量
        local paladins = GetRaidMembersByClass("圣骑士")
        local paladinCount = table.getn(paladins)
        
        if paladinCount > 0 then
            -- 统计已经存在且状态良好的圣骑士buff
            local existingPaladinBuffCount = 0
            for _, buff in ipairs(goodBuffs) do
                if buff.provider == "圣骑士" then
                    existingPaladinBuffCount = existingPaladinBuffCount + 1
                end
            end
            
            -- 计算需要的总buff数量
            local totalNeededPaladinBuffs = existingPaladinBuffCount + table.getn(allRequestedBuffs["圣骑士"])
            
            -- 计算可用的圣骑士数量（总数减去已分配的）
            local availablePaladins = paladinCount - existingPaladinBuffCount
            
            -- 如果没有可用的圣骑士，移除圣骑士的buff请求
            if availablePaladins <= 0 then
                PrintMessage("团队中有" .. paladinCount .. "个圣骑士，但都已分配给其他buff，无可用圣骑士，不请求圣骑士buff。", true)
                allRequestedBuffs["圣骑士"] = nil
            else
                -- 对圣骑士buff按照原始buffLists中的顺序排序
                table.sort(allRequestedBuffs["圣骑士"], function(a, b)
                    return GetOriginalBuffIndex(a, roleType) < GetOriginalBuffIndex(b, roleType)
                end)
                
                -- 只保留不超过可用圣骑士数量的buff
                if table.getn(allRequestedBuffs["圣骑士"]) > availablePaladins then
                    -- 创建一个新表存储优先级高的buff
                    local priorityBuffs = {}
                    for i = 1, availablePaladins do
                        table.insert(priorityBuffs, allRequestedBuffs["圣骑士"][i])
                    end
                    
                    -- 记录被丢弃的buff
                    local discardedBuffs = {}
                    for i = availablePaladins + 1, table.getn(allRequestedBuffs["圣骑士"]) do
                        table.insert(discardedBuffs, allRequestedBuffs["圣骑士"][i].name)
                    end
                    
                    -- 输出信息
                    local discardedText = ""
                    for i, buffName in ipairs(discardedBuffs) do
                        if i == 1 then
                            discardedText = buffName
                        elseif i == table.getn(discardedBuffs) then
                            discardedText = discardedText .. "和" .. buffName
                        else
                            discardedText = discardedText .. "，" .. buffName
                        end
                    end
                    
                    if paladinCount < totalNeededPaladinBuffs then
                        PrintMessage("团队中只有" .. paladinCount .. "个圣骑士，需要提供" .. totalNeededPaladinBuffs ..
                                   "个buff，其中" .. existingPaladinBuffCount .. "个已分配，剩余" .. availablePaladins ..
                                   "个可用，按照优先级请求前" .. availablePaladins .. "个buff，忽略" .. discardedText, false)
                    else
                        PrintMessage("团队中有" .. paladinCount .. "个圣骑士，其中" .. existingPaladinBuffCount ..
                                   "个已分配，剩余" .. availablePaladins .. "个可用，按照优先级请求前" ..
                                   availablePaladins .. "个buff，忽略" .. discardedText, false)
                    end
                    
                    -- 替换为优先级高的buff
                    allRequestedBuffs["圣骑士"] = priorityBuffs
                end
            end
        else
            -- 如果团队中没有圣骑士，移除圣骑士的buff请求
            allRequestedBuffs["圣骑士"] = nil
        end
    end
    
    -- 处理每种职业的请求
    for provider, buffs in pairs(allRequestedBuffs) do
        -- 忽略玩家自己的职业（无论是中文还是英文名称）
        if provider ~= playerClass and provider ~= myClassChinese then
            -- 获取该职业在团队中的成员
            local classMembers = GetRaidMembersByClass(provider)
            
            -- 只有当团队中有这个职业的成员时，才发送请求
            if table.getn(classMembers) > 0 then
                local memberText = ""
                
                -- 构建成员名字列表
                for i, member in ipairs(classMembers) do
                    if i == 1 then
                        memberText = " " .. member .. " "
                    elseif i == table.getn(classMembers) then
                        memberText = memberText .. "和 " .. member .. " "
                    else
                        memberText = memberText .. "， " .. member .. " "
                    end
                end
                
                -- 构建buff列表
                local buffText = ""
                for i, buff in ipairs(buffs) do
                    if i == 1 then
                        buffText = buff.name
                    elseif i == table.getn(buffs) then
                        buffText = buffText .. "和" .. buff.name
                    else
                        buffText = buffText .. "，" .. buff.name
                    end
                end
                
                -- 为每个职业创建一个单独的请求文本
                requestsByClass[provider] = "请队伍中的" .. provider .. memberText .. "加一下" .. buffText
            end
        end
        -- 如果是玩家自己的职业或团队中没有这个职业，则不发送请求
    end
    
    -- 如果没有任何可发送的请求，提示玩家
    if not next(requestsByClass) then
        PrintMessage("团队中没有可以提供所需buff的玩家，不发送喊话。", true)
        return
    end
    
    -- 获取玩家职业的中文名称用于显示
    local playerClassDisplay = classNameMap[playerClass] or playerClass
    
    -- 构建基础消息
    local baseMessage = "检查" .. roleType .. " BUFF，"
    if missingBuffText ~= "" then
        baseMessage = baseMessage .. "我缺失" .. missingBuffText .. "。"
    end
    baseMessage = baseMessage .. expiringBuffText
    
    -- 获取当前通信频道
    local currentChannel = CheckBufferCommon.GetChatChannel()
    local channelName = CheckBufferCommon.GetChatChannelName()
    
    PrintMessage("通过" .. channelName .. "频道发送消息", false)
    
    -- 发送基础消息
    SendChatMessage(baseMessage, currentChannel)
    
    -- 为每个职业发送单独的请求
    for _, requestMsg in pairs(requestsByClass) do
        -- 添加签名
        local fullRequest = requestMsg .. "，谢谢，我是" .. raidID .. "队的" .. playerClassDisplay
        -- 发送请求消息
        SendChatMessage(fullRequest, currentChannel)
    end
end

-- 检查一个buff及其替代buff
local function CheckBuffAndAlternatives(buff)
    -- 先检查主buff
    local hasBuff, timeLeft = HasBuff(buff.name)
    
    -- 如果没有主buff，检查替代buff
    if not hasBuff and buff.alternativeBuffs then
        for _, altBuff in ipairs(buff.alternativeBuffs) do
            local hasAltBuff, altTimeLeft = HasBuff(altBuff)
            if hasAltBuff then
                hasBuff = true
                timeLeft = altTimeLeft
                break
            end
        end
    end
    
    return hasBuff, timeLeft
end


-- 检查坦克buff
function CheckTankBuffs()
    PrintMessage("正在检查坦克buff...", false)
    local missingBuffs = {}
    local expiringBuffs = {}  -- 剩余时间不足5分钟的buff
    local goodBuffs = {}      -- 状态良好的buff
    
    for _, buff in ipairs(buffLists.tank) do
        local hasBuff, timeLeft = CheckBuffAndAlternatives(buff)
        
        if hasBuff then
            -- 检查是否即将到期（小于5分钟）
            if timeLeft and timeLeft < 300 then
                table.insert(expiringBuffs, buff)
            else
                -- 状态良好的buff
                table.insert(goodBuffs, buff)
            end
        else
            -- 完全没有buff
            table.insert(missingBuffs, buff)
        end
    end
    
    if table.getn(missingBuffs) == 0 and table.getn(expiringBuffs) == 0 then
        PrintMessage("所有坦克buff齐全且时间充足！", true)
    else
        if table.getn(missingBuffs) > 0 then
            PrintMessage("缺少以下坦克buff:", true)
            for _, buff in ipairs(missingBuffs) do
                PrintMessage("- " .. buff.name .. " (" .. buff.provider .. ")", true)
            end
        end
        
        if table.getn(expiringBuffs) > 0 then
            PrintMessage("以下坦克buff即将到期:", true)
            for _, buff in ipairs(expiringBuffs) do
                PrintMessage("- " .. buff.name .. " (" .. buff.provider .. ")", true)
            end
        end
        
        -- 发送喊话
        SendBuffRequest(missingBuffs, expiringBuffs, goodBuffs, "坦克")
    end
    
    
    return table.getn(missingBuffs) == 0
end

-- 检查治疗buff
function CheckHealerBuffs()
    PrintMessage("正在检查治疗buff...", false)
    local missingBuffs = {}
    local expiringBuffs = {}  -- 剩余时间不足5分钟的buff
    local goodBuffs = {}      -- 状态良好的buff
    
    for _, buff in ipairs(buffLists.healer) do
        local hasBuff, timeLeft = CheckBuffAndAlternatives(buff)
        
        if hasBuff then
            -- 检查是否即将到期（小于5分钟）
            if timeLeft and timeLeft < 300 then
                table.insert(expiringBuffs, buff)
            else
                -- 状态良好的buff
                table.insert(goodBuffs, buff)
            end
        else
            -- 完全没有buff
            table.insert(missingBuffs, buff)
        end
    end
    
    if table.getn(missingBuffs) == 0 and table.getn(expiringBuffs) == 0 then
        PrintMessage("所有治疗buff齐全且时间充足！", true)
    else
        if table.getn(missingBuffs) > 0 then
            PrintMessage("缺少以下治疗buff:", true)
            for _, buff in ipairs(missingBuffs) do
                PrintMessage("- " .. buff.name .. " (" .. buff.provider .. ")", true)
            end
        end
        
        if table.getn(expiringBuffs) > 0 then
            PrintMessage("以下治疗buff即将到期:", true)
            for _, buff in ipairs(expiringBuffs) do
                PrintMessage("- " .. buff.name .. " (" .. buff.provider .. ")", true)
            end
        end
        
        -- 发送喊话
        SendBuffRequest(missingBuffs, expiringBuffs, goodBuffs, "治疗")
    end
    
    
    return table.getn(missingBuffs) == 0
end

-- 检查物理DPS buff
function CheckPhysicalDPSBuffs()
    PrintMessage("正在检查物理DPS buff...", false)
    local missingBuffs = {}
    local expiringBuffs = {}  -- 剩余时间不足5分钟的buff
    local goodBuffs = {}      -- 状态良好的buff
    
    for _, buff in ipairs(buffLists.pdps) do
        local hasBuff, timeLeft = CheckBuffAndAlternatives(buff)
        
        if hasBuff then
            -- 检查是否即将到期（小于5分钟）
            if timeLeft and timeLeft < 300 then
                table.insert(expiringBuffs, buff)
            else
                -- 状态良好的buff
                table.insert(goodBuffs, buff)
            end
        else
            -- 完全没有buff
            table.insert(missingBuffs, buff)
        end
    end
    
    if table.getn(missingBuffs) == 0 and table.getn(expiringBuffs) == 0 then
        PrintMessage("所有物理DPS buff齐全且时间充足！", true)
    else
        if table.getn(missingBuffs) > 0 then
            PrintMessage("缺少以下物理DPS buff:", true)
            for _, buff in ipairs(missingBuffs) do
                PrintMessage("- " .. buff.name .. " (" .. buff.provider .. ")", true)
            end
        end
        
        if table.getn(expiringBuffs) > 0 then
            PrintMessage("以下物理DPS buff即将到期:", true)
            for _, buff in ipairs(expiringBuffs) do
                PrintMessage("- " .. buff.name .. " (" .. buff.provider .. ")", true)
            end
        end
        
        -- 发送喊话
        SendBuffRequest(missingBuffs, expiringBuffs, goodBuffs, "物理DPS")
    end
    
    
    return table.getn(missingBuffs) == 0
end

-- 检查法系DPS buff
function CheckMagicDPSBuffs()
    PrintMessage("正在检查法系DPS buff...", false)
    local missingBuffs = {}
    local expiringBuffs = {}  -- 剩余时间不足5分钟的buff
    local goodBuffs = {}      -- 状态良好的buff
    
    for _, buff in ipairs(buffLists.mdps) do
        local hasBuff, timeLeft = CheckBuffAndAlternatives(buff)
        
        if hasBuff then
            -- 检查是否即将到期（小于5分钟）
            if timeLeft and timeLeft < 300 then
                table.insert(expiringBuffs, buff)
            else
                -- 状态良好的buff
                table.insert(goodBuffs, buff)
            end
        else
            -- 完全没有buff
            table.insert(missingBuffs, buff)
        end
    end
    
    if table.getn(missingBuffs) == 0 and table.getn(expiringBuffs) == 0 then
        PrintMessage("所有法系DPS buff齐全且时间充足！", true)
    else
        if table.getn(missingBuffs) > 0 then
            PrintMessage("缺少以下法系DPS buff:", true)
            for _, buff in ipairs(missingBuffs) do
                PrintMessage("- " .. buff.name .. " (" .. buff.provider .. ")", true)
            end
        end
        
        if table.getn(expiringBuffs) > 0 then
            PrintMessage("以下法系DPS buff即将到期:", true)
            for _, buff in ipairs(expiringBuffs) do
                PrintMessage("- " .. buff.name .. " (" .. buff.provider .. ")", true)
            end
        end
        
        -- 发送喊话
        SendBuffRequest(missingBuffs, expiringBuffs, goodBuffs, "法系DPS")
    end
    
    -- 检查法系DPS的药剂和食物
    if CheckBufferConsumableAPI and CheckBufferConsumableAPI.CheckRoleConsumables then
        PrintMessage("正在检查法系DPS消耗品...", false)
        CheckBufferConsumableAPI.CheckRoleConsumables("法系DPS")
    end
    
    return table.getn(missingBuffs) == 0
end

-- 检查任意角色类型的buff
local function CheckBuffsByRole(role)
    -- 检查玩家是否在团队中，香草版本团队buff检查只在团队中有意义
    if not UnitInRaid("player") then
        PrintMessage("你不在团队中，无法检查团队buff。", true)
        return false
    end
    
    local result = false
    
    if role == "tank" or role == "t" then
        result = CheckTankBuffs()
    elseif role == "healer" or role == "h" then
        result = CheckHealerBuffs()
    elseif role == "pdps" or role == "p" then
        result = CheckPhysicalDPSBuffs()
    elseif role == "mdps" or role == "m" then
        result = CheckMagicDPSBuffs()
    else
        PrintMessage("未知角色类型: " .. role, true)
        PrintMessage("可用角色类型: tank/t, healer/h, pdps/p, mdps/m", true)
        return false
    end
    
    return result
end

-- 显示帮助信息
local function ShowHelp()
    PrintMessage(addonName .. " v" .. addonVersion .. " 完整使用帮助:", true)
    PrintMessage("", true)
    PrintMessage("=== BUFF检查功能 ===", true)
    PrintMessage("/cb tank 或 /cb t - 检查坦克buff", true)
    PrintMessage("/cb healer 或 /cb h - 检查治疗buff", true)
    PrintMessage("/cb pdps 或 /cb p - 检查物理DPS buff", true)
    PrintMessage("/cb mdps 或 /cb m - 检查法系DPS buff", true)
    PrintMessage("", true)
    PrintMessage("=== 消耗品检查功能 ===", true)
    PrintMessage("/cbc tank 或 /cbc t - 检查坦克药剂和食物", true)
    PrintMessage("/cbc healer 或 /cbc h - 检查治疗药剂和食物", true)
    PrintMessage("/cbc pdps 或 /cbc p - 检查物理DPS药剂和食物", true)
    PrintMessage("/cbc fdps 或 /cbc f - 检查物理DPS药剂,法系DPS药剂和食物", true)
    PrintMessage("/cbc mdps 或 /cbc m - 检查法系DPS药剂和食物", true)
    PrintMessage("", true)
    PrintMessage("=== 自动吃药功能 ===", true)
    PrintMessage("/cbca tank 或 /cbca t - 自动使用坦克消耗品", true)
    PrintMessage("/cbca healer 或 /cbca h - 自动使用治疗消耗品", true)
    PrintMessage("/cbca pdps 或 /cbca p - 自动使用物理DPS消耗品", true)
    PrintMessage("/cbca fdps 或 /cbca f - 自动使用物理DPS+法系DPS消耗品", true)
    PrintMessage("/cbca mdps 或 /cbca m - 自动使用法系DPS消耗品", true)
    PrintMessage("", true)
    PrintMessage("=== 自动取消buff功能 ===", true)
    PrintMessage("/cbad tank 或 /cbad t - 自动取消坦克不需要的buff", true)
    PrintMessage("/cbad healer 或 /cbad h - 自动取消治疗不需要的buff", true)
    PrintMessage("/cbad pdps 或 /cbad p - 自动取消物理DPS不需要的buff", true)
    PrintMessage("/cbad mdps 或 /cbad m - 自动取消法系DPS不需要的buff", true)
    PrintMessage("/cbad list <角色类型> - 显示指定角色类型的unwanted buff列表", true)
    PrintMessage("", true)
    PrintMessage("=== 系统设置 ===", true)
    PrintMessage("/cb config - 打开消耗品Profile配置界面", true)
    PrintMessage("/cb log on/off - 启用/禁用调试日志", true)
    PrintMessage("/cb channel [频道] - 设置通信频道", true)
    PrintMessage("/cb channels - 列出所有可用频道", true)
    PrintMessage("/cb buffs - 显示所有buff的图标信息", true)
    PrintMessage("/cb icon <buff名称> - 显示指定buff的图标路径", true)
    PrintMessage("/cb help - 显示此帮助信息", true)
end

-- 创建命令
SLASH_CHECKBUFFER1 = "/checkbuff"
SLASH_CHECKBUFFER2 = "/cb"
SlashCmdList["CHECKBUFFER"] = function(msg)
    local command = string.lower(msg)
    
    if command == "" or command == "help" or command == "?" then
        ShowHelp()
    elseif command == "tank" or command == "t" then
        CheckBuffsByRole("tank")
    elseif command == "healer" or command == "h" then
        CheckBuffsByRole("healer")
    elseif command == "pdps" or command == "p" then
        CheckBuffsByRole("pdps")
    elseif command == "mdps" or command == "m" then
        CheckBuffsByRole("mdps")
    elseif command == "buffs" then
        -- 显示所有buff的图标信息
        CheckBufferCommon.ShowAllBuffIcons()
    elseif command == "config" then
        if CheckBuffer_OpenConfigUI then
            CheckBuffer_OpenConfigUI()
        else
            PrintMessage("配置界面尚未加载", true)
        end
    else
        -- 检查是否是日志控制命令
        if string.sub(command, 1, 4) == "log " then
            local logCmd = string.sub(command, 5)
            logCmd = string.gsub(logCmd, "^%s+", "") -- 移除开头的空格
            if logCmd == "on" then
                CheckBufferCommon.SetLogEnabled(true)
            elseif logCmd == "off" then
                CheckBufferCommon.SetLogEnabled(false)
            else
                PrintMessage("用法: /cb log on/off", true)
            end
        -- 检查是否是频道设置命令
        elseif string.sub(command, 1, 8) == "channel " then
            local channelCode = string.sub(command, 9)
            channelCode = string.gsub(channelCode, "^%s+", "") -- 移除开头的空格
            if channelCode and channelCode ~= "" then
                CheckBufferCommon.SetChatChannel(string.upper(channelCode))
            else
                PrintMessage("当前通信频道: " .. CheckBufferCommon.GetChatChannelName() .. " (" .. CheckBufferCommon.GetChatChannel() .. ")", true)
                PrintMessage("用法: /cb channel [频道代码]", true)
                CheckBufferCommon.ListAvailableChannels()
            end
        elseif command == "channels" then
            PrintMessage("当前通信频道: " .. CheckBufferCommon.GetChatChannelName() .. " (" .. CheckBufferCommon.GetChatChannel() .. ")", true)
            CheckBufferCommon.ListAvailableChannels()
        -- 检查是否是图标查询命令
        elseif string.sub(command, 1, 5) == "icon " then
            local buffName = string.sub(msg, 6) -- 使用原始msg保持大小写
            buffName = string.gsub(buffName, "^%s+", "") -- 移除开头的空格
            CheckBufferCommon.ShowBuffIcon(buffName)
        else
            PrintMessage("未知命令: " .. command, true)
            ShowHelp()
        end
    end
end

-- 导出公共API，以便其他插件或宏使用
CheckBufferAPI = {
    CheckTankBuffs = CheckTankBuffs,
    CheckHealerBuffs = CheckHealerBuffs,
    CheckPhysicalDPSBuffs = CheckPhysicalDPSBuffs,
    CheckMagicDPSBuffs = CheckMagicDPSBuffs
}