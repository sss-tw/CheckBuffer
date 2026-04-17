-- ----------------------------------------
-- CheckBufferAutoDispel - WoW乌龟服团队自动取消buff插件
-- 作者：旧德
-- 版本：1.0.0
-- 功能：自动检测并取消不需要的buff
-- 使用方式: /cbad <角色类型> 或 /cbautodispel <角色类型>; 调试控制使用 /cb log on/off
-- ----------------------------------------

-- 检查依赖模块是否加载
if not CheckBufferCommon then
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[CheckBufferAutoDispel]|r 错误: CheckBufferCommon模块未加载!")
    return
end

-- 加载通用函数
local PrintMessage = CheckBufferCommon.PrintMessage
local HasBuff = CheckBufferCommon.HasBuff

-- 为buff检查获取BuffCheckTooltip引用
local CheckBufferAutoDispelTooltip = CheckBufferCommon.BuffCheckTooltip



-- 定义不同角色类型需要取消的buff列表
local unwantedBuffsList = {
    tank = {  -- 坦克需要取消的buff
        {name = "拯救祝福", alternativeBuffs = {"强效拯救祝福"}},
        {name = "智慧祝福", alternativeBuffs = {"强效智慧祝福"}},
        {name = "精神祷言", alternativeBuffs = {"神圣之灵"}},
        {name = "奥术智慧", alternativeBuffs = {"奥术光辉"}},
    },
    healer = {  -- 治疗需要取消的buff
        {name = "力量祝福", alternativeBuffs = {"强效力量祝福"}},
    },
    pdps = {  -- 物理DPS需要取消的buff
        {name = "智慧祝福", alternativeBuffs = {"强效智慧祝福"}},
        {name = "精神祷言", alternativeBuffs = {"神圣之灵"}},
    },
    mdps = {  -- 法系DPS需要取消的buff
        {name = "力量祝福", alternativeBuffs = {"强效力量祝福"}},
    }
}

-- 检查一个buff及其替代buff是否存在，返回实际找到的buff名称
local function CheckUnwantedBuffAndAlternatives(buff)
    -- 先检查主buff
    local hasBuff = HasBuff(buff.name)
    if hasBuff then
        return true, buff.name
    end
    
    -- 如果没有主buff，检查替代buff
    if buff.alternativeBuffs then
        for _, altBuff in ipairs(buff.alternativeBuffs) do
            local hasAltBuff = HasBuff(altBuff)
            if hasAltBuff then
                return true, altBuff
            end
        end
    end
    
    return false, nil
end

-- 取消指定的buff
local function CancelBuff(buffName)
    PrintMessage("[DEBUG_AUTODISPEL] 尝试取消buff: " .. tostring(buffName), false)
    
    -- 使用现有的GetPlayerAuraIndex函数，和HasBuff保持一致
    local buffIndex = GetPlayerAuraIndex(buffName)
    
    if buffIndex and buffIndex >= 0 then
        PrintMessage("[DEBUG_AUTODISPEL] 找到要取消的buff: " .. buffName .. " (索引: " .. buffIndex .. ")", false)
        
        -- 取消buff (使用buff索引)
        CancelPlayerBuff(buffIndex)
        PrintMessage("已取消buff: " .. buffName, true)
        return true
    else
        PrintMessage("[DEBUG_AUTODISPEL] 未找到buff: " .. buffName, false)
        return false
    end
end

-- 检查并自动取消指定角色类型的不需要buff
local function AutoDispelRole(roleType)
    PrintMessage("[DEBUG_AUTODISPEL] 开始自动取消buff: " .. tostring(roleType), false)

    local unwantedBuffs = unwantedBuffsList[roleType]
    if not unwantedBuffs then
        PrintMessage("未找到角色类型: " .. tostring(roleType) .. " 的unwanted buff列表", true)
        return
    end

    PrintMessage("[DEBUG_AUTODISPEL] 找到 " .. table.getn(unwantedBuffs) .. " 个需要检查的unwanted buff", false)
    
    local canceledBuffs = {}
    local notFoundBuffs = {}
    
    -- 检查每个不想要的buff
    for i, buff in ipairs(unwantedBuffs) do
        PrintMessage("[DEBUG_AUTODISPEL] 检查第 " .. i .. " 个unwanted buff: " .. buff.name, false)
        
        -- 检查是否存在这个buff或其替代buff
        local hasBuff, actualBuffName = CheckUnwantedBuffAndAlternatives(buff)
        if hasBuff then
            PrintMessage("发现不需要的buff: " .. actualBuffName .. "，尝试取消", true)
            
            -- 尝试取消实际找到的buff
            local success = CancelBuff(actualBuffName)
            if success then
                table.insert(canceledBuffs, actualBuffName)
            else
                PrintMessage("取消buff失败: " .. actualBuffName, true)
            end
        else
            PrintMessage("[DEBUG_AUTODISPEL] 未发现unwanted buff: " .. buff.name .. " 及其替代版本", false)
            table.insert(notFoundBuffs, buff.name)
        end
    end
    
    -- 输出结果
    if table.getn(canceledBuffs) > 0 then
        local canceledText = table.concat(canceledBuffs, ", ")
        PrintMessage("成功取消了以下buff: " .. canceledText, true)
    else
        PrintMessage("没有发现需要取消的buff", true)
    end
    
    PrintMessage("[DEBUG_AUTODISPEL] 自动取消buff完成，取消了 " .. table.getn(canceledBuffs) .. " 个buff", false)
end

-- Slash命令注册
SLASH_CHECKBUFFER_AUTODISPEL1 = "/cbad"
SLASH_CHECKBUFFER_AUTODISPEL2 = "/cbautodispel"
SlashCmdList["CHECKBUFFER_AUTODISPEL"] = function(msg)
    -- 安全处理输入参数
    if not msg then
        msg = ""
    end
    
    -- 使用string.match而不是冒号语法
    local cmd, arg = string.match(msg, "(%S+)%s*(%S*)")
    cmd = string.lower(cmd or "")
    arg = string.lower(arg or "")

    if cmd == "" or cmd == "help" then
        PrintMessage("自动取消buff模块", true)
        PrintMessage("请使用 /cb help 查看完整帮助信息", true)
    elseif cmd == "list" then
        -- 显示指定角色类型的unwanted buff列表
        if arg == "" then
            PrintMessage("用法: /cbad list <角色类型>", true)
            PrintMessage("可用角色类型: tank, healer, pdps, mdps", true)
            return
        end
        
        -- 转换简写角色类型到全名
        local roleType = arg
        if arg == "t" then
            roleType = "tank"
        elseif arg == "h" then
            roleType = "healer"
        elseif arg == "p" then
            roleType = "pdps"
        elseif arg == "m" then
            roleType = "mdps"
        end
        
        local unwantedBuffs = unwantedBuffsList[roleType]
        if unwantedBuffs then
            PrintMessage(roleType .. "角色需要取消的buff列表:", true)
            for i, buff in ipairs(unwantedBuffs) do
                local buffText = "- " .. buff.name
                if buff.alternativeBuffs and table.getn(buff.alternativeBuffs) > 0 then
                    buffText = buffText .. " (包括: " .. table.concat(buff.alternativeBuffs, ", ") .. ")"
                end
                PrintMessage(buffText, true)
            end
        else
            PrintMessage("未找到角色类型: " .. roleType, true)
        end
    else
        -- 转换简写角色类型到全名
        local roleType = cmd
        if cmd == "t" then
            roleType = "tank"
        elseif cmd == "h" then
            roleType = "healer"
        elseif cmd == "p" then
            roleType = "pdps"
        elseif cmd == "m" then
            roleType = "mdps"
        end
        
        AutoDispelRole(roleType)
    end
end

-- 导出API供其他模块使用
CheckBufferAutoDispelAPI = {
    AutoDispelRole = AutoDispelRole,
    CancelBuff = CancelBuff,
    unwantedBuffsList = unwantedBuffsList
}

-- 初始化加载信息
PrintMessage("自动取消buff模块已加载，使用 /cb help 查看完整帮助", true) 