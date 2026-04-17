-- ----------------------------------------
-- CheckBufferAutoConsume - WoW乌龟服团队自动吃药插件
-- 作者：旧德
-- 版本：1.0.0
-- 功能：自动检测并使用缺失的药剂和食物buff
-- 使用方式: /cbca <角色类型> 或 /cbcauto <角色类型>; 调试控制使用 /cb log on/off
-- ----------------------------------------

-- 检查依赖模块是否加载
if not CheckBufferCommon then
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[CheckBufferAutoConsume]|r 错误: CheckBufferCommon模块未加载!")
    return
end

if not CheckBufferConsumableAPI then
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[CheckBufferAutoConsume]|r 错误: CheckBufferConsumableAPI模块未加载!")
    return
end

-- 加载通用函数和消耗品API
local PrintMessage = CheckBufferCommon.PrintMessage
local HasBuff = CheckBufferCommon.HasBuff
local HasFoodBuff = CheckBufferCommon.HasFoodBuff
local UseItem = CheckBufferCommon.UseItem
local UnitChannelInfo = UnitChannelInfo
local ConsumableAPI = CheckBufferConsumableAPI

-- 为buff检查获取BuffCheckTooltip引用
local CheckBufferAutoConsumeTooltip = CheckBufferCommon.BuffCheckTooltip



local function IsEatingOrDrinking()
    -- 在经典版中，使用检查buff的方式判断是否在吃喝
    -- 检查吃喝动作buff，排除"进食充分"等效果buff
    
    -- 检查真正的吃喝动作buff（排除效果buff）
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

local function AutoConsumeRole(roleType)
    PrintMessage("[DEBUG_AUTOCONSUME] 开始自动吃药: " .. tostring(roleType), false)

    local consumablesList = CheckBufferConsumableAPI.consumablesList
    local roleList = consumablesList[roleType]
    if not roleList then
        PrintMessage("未找到角色类型: " .. tostring(roleType) .. " 的消耗品列表", true)
        return
    end

    if IsEatingOrDrinking() then
        PrintMessage("正在吃喝中，跳过自动吃药", true)
        return
    end

    -- 使用 CheckBufferConsumable.lua 中的函数检查缺失消耗品
    local ok, missing = ConsumableAPI.CheckRoleConsumables(roleType)
    PrintMessage("[DEBUG_AUTOCONSUME] CheckRoleConsumables 返回 ok=" .. tostring(ok) .. " missingCount=" .. (missing and table.getn(missing) or 0), false)
    if not ok and missing and table.getn(missing) > 0 then
        -- 查找第一个可以使用的药物（考虑药水CD，一次只使用一个）
        local itemUsed = false
        local skippedItems = {}
        
        for i, item in ipairs(missing) do
            -- 跳过武器附魔（type == "enchant"）
            if item.type == "enchant" then
                table.insert(skippedItems, item.name .. "(武器附魔)")
            -- 跳过合剂（名称中包含"合剂"）
            elseif string.find(item.name, "合剂") then
                table.insert(skippedItems, item.name .. "(合剂)")
            else
                PrintMessage("缺少 " .. item.name .. "，尝试使用", true)
                
                -- 保存当前目标名称
                local currentTargetName = UnitName("target")
                -- 清除目标（某些物品需要无目标状态才能使用）
                ClearTarget()
                -- 使用物品（UseItem会自动检查物品是否存在）
                local success = UseItem(item.name)
                -- 如果之前有目标，恢复目标
                if currentTargetName then
                    TargetByName(currentTargetName)
                end
                
                if success then
                    itemUsed = true
                    PrintMessage("成功使用了 " .. item.name .. "，由于药水冷却时间，停止使用其他药物", true)
                    break -- 成功使用一个药物后立即停止
                else
                    PrintMessage("没有找到" .. item.name .. "，跳过使用", true)
                end
                -- 如果UseItem返回false，说明没有物品或使用失败，继续尝试下一个
            end
        end
        
        -- 如果有跳过的物品，显示提示
        if table.getn(skippedItems) > 0 then
            local skippedText = table.concat(skippedItems, ", ")
            PrintMessage("跳过的物品: " .. skippedText, true)
        end
        
        if not itemUsed then
            PrintMessage("没有找到可以自动使用的消耗品", true)
        end
    else
        PrintMessage("所有消耗品buff均已存在", true)
    end
end

-- Slash命令注册
SLASH_CHECKBUFFER_AUTOCONSUME1 = "/cbca"
SLASH_CHECKBUFFER_AUTOCONSUME2 = "/cbcauto"
SlashCmdList["CHECKBUFFER_AUTOCONSUME"] = function(msg)
    -- 安全处理输入参数
    if not msg then
        msg = ""
    end
    
    -- 使用string.match而不是冒号语法
    local cmd, arg = string.match(msg, "(%S+)%s*(%S*)")
    cmd = string.lower(cmd or "")
    arg = string.lower(arg or "")

    if cmd == "" or cmd == "help" then
        PrintMessage("自动吃药模块", true)
        PrintMessage("请使用 /cb help 查看完整帮助信息", true)
    else
        -- 转换简写角色类型到全名
        local roleType = cmd
        if cmd == "t" then
            roleType = "tank"
        elseif cmd == "h" then
            roleType = "healer"
        elseif cmd == "p" then
            roleType = "pdps"
        elseif cmd == "f" then
            roleType = "fdps"
        elseif cmd == "m" then
            roleType = "mdps"
        end
        
        AutoConsumeRole(roleType)
    end
end

-- 初始化加载信息
PrintMessage("自动吃药模块已加载，使用 /cb help 查看完整帮助", true)