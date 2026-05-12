-- ----------------------------------------
-- CheckBufferConsumable - WoW乌龟服团队药剂食物检查插件
-- 作者：旧德
-- 版本：1.0.0
-- 功能：检查角色身上的药剂和食物buff，并提醒缺失的消耗品
-- 使用方法：
-- 1. 输入 /cbc tank 或 /checkbc tank - 检查坦克药剂食物
-- 2. 输入 /cbc healer 或 /checkbc healer - 检查治疗药剂食物
-- 3. 输入 /cbc pdps 或 /checkbc pdps - 检查物理DPS药剂食物
-- 4. 输入 /cbc mdps 或 /checkbc mdps - 检查法系DPS药剂食物
-- 5. 输入 /cbc food - 只检查食物buff
-- 6. 输入 /cbc potion - 只检查药剂buff
-- 7. 输入 /cbc help 或 /checkbc help - 显示帮助信息
-- ----------------------------------------

-- 检查依赖模块是否加载
if not CheckBufferCommon then
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[CheckBufferConsumable]|r 错误: CheckBufferCommon模块未加载!")
    return
end

-- 加载通用函数
local PrintMessage = CheckBufferCommon.PrintMessage
local HasBuff = CheckBufferCommon.HasBuff
local HasFoodBuff = CheckBufferCommon.HasFoodBuff
local UseItem = CheckBufferCommon.UseItem
local HasWeaponEnchant = CheckBufferCommon.HasWeaponEnchant

-- 互斥且有优先级的食物效果
local CRISPY_MAGIC_MUSHROOM_EFFECT = "耐力提高25点"
local CHOCOLATE_FISH_EFFECT = "躲闪几率提高1%。防御值提高4点。"
local HOLY_SHARPENING_STONE_EFFECT = "+100 攻击强度vs亡灵"
local ELEMENTAL_SHARPENING_STONE_EFFECT = "致命一击 +2%"

-- 定义不同角色类型所需的药剂和食物
local consumablesList = {
    tank = {  -- 坦克药剂和食物
        {name = "赞扎之魂", buffName = "赞扎之魂", type = "potion"},
        {name = "坚韧药剂", buffName = "生命 II", type = "potion"},
        {name = "猫鼬药剂", buffName = "猫鼬药剂", type = "potion"},
        {name = "超强防御药剂", buffName = "强效护甲", type = "potion"},
        {name = "厚甲蝎药粉", buffName = "厚甲蝎之击", type = "potion"},
        {name = "魂能之力", buffName = "魂能之力", type = "potion"},
        {name = "黑根酒", buffName = "黑根酒", type = "potion"},
        {name = "冬泉火酒", buffName = "冬泉火酒", type = "potion"},
        {name = "阿尔萨斯的礼物", buffName = "阿尔萨斯的礼物", type = "potion"},
        {name = "麦迪文的葡萄酒", buffName = "麦迪文的葡萄酒", type = "potion"},
        {name = "保护卷轴 IV", buffName = "护甲", type = "food", effect = "护甲提高240点"},
        {name = "香脆的魔法蘑菇", buffName = "进食充分", type = "food", effect = CRISPY_MAGIC_MUSHROOM_EFFECT},
        {name = "巧克力鱼", buffName = "进食充分", type = "food", effect = CHOCOLATE_FISH_EFFECT},
        {name = "神圣磨刀石", slot = "main", type = "enchant", effect = "+100 攻击强度vs亡灵"},
        {name = "元素磨刀石", slot = "main", type = "enchant", effect = "致命一击 +2%"}
    },
    healer = {  -- 治疗药剂和食物
        {name = "赞扎之魂", buffName = "赞扎之魂", type = "potion"},
        {name = "坚韧药剂", buffName = "生命 II", type = "potion"},
        {name = "魔血药水", buffName = "法力回复", type = "potion"},
        {name = "梦境精华药剂", buffName = "梦境精华药剂", type = "potion"},
        {name = "麦迪文的蓝标葡萄酒", buffName = "麦迪文的蓝标葡萄酒", type = "potion"},
        {name = "脑皮层混合饮料", buffName = "坚定信念", type = "potion"},
        {name = "达农佐的泰拉比姆情调", buffName = "进食充分", type = "food", effect = "急速提高2%"},
        {name = "卓越法力之油", slot = "main", type = "enchant", effect = "卓越法力之油"}
    },
    pdps = {  -- 物理DPS药剂和食物
        {name = "赞扎之魂", buffName = "赞扎之魂", type = "potion"},
        {name = "猫鼬药剂", buffName = "猫鼬药剂", type = "potion"},
        {name = "坚韧药剂", buffName = "生命 II", type = "potion"},
        {name = "厚甲蝎药粉", buffName = "厚甲蝎之击", type = "potion"},
        {name = "魂能之力", buffName = "魂能之力", type = "potion"},
        {name = "黑根酒", buffName = "黑根酒", type = "potion"},
        {name = "冬泉火酒", buffName = "冬泉火酒", type = "potion"},
        {name = "麦迪文的葡萄酒", buffName = "麦迪文的葡萄酒", type = "potion"},
        {name = "营养的魔法蘑菇", buffName = "进食充分", type = "food", effect = "力量提高20点"},
        {name = "神圣磨刀石", slot = "main", type = "enchant", effect = "+100 攻击强度vs亡灵"},
        {name = "元素磨刀石", slot = "main", type = "enchant", effect = "致命一击 +2%"}
    },
    fdps = {  -- 物理DPS药剂和食物
        {name = "赞扎之魂", buffName = "赞扎之魂", type = "potion"},
        {name = "坚韧药剂", buffName = "生命 II", type = "potion"},
        {name = "猫鼬药剂", buffName = "猫鼬药剂", type = "potion"},
        {name = "龙息红椒", buffName = "龙息红椒", type = "potion"},
        {name = "厚甲蝎药粉", buffName = "厚甲蝎之击", type = "potion"},
        {name = "魂能之力", buffName = "魂能之力", type = "potion"},
        {name = "黑根酒", buffName = "黑根酒", type = "potion"},
        {name = "冬泉火酒", buffName = "冬泉火酒", type = "potion"},
        {name = "麦迪文的葡萄酒", buffName = "麦迪文的葡萄酒", type = "potion"},
        {name = "超级能量合剂", buffName = "至高能量", type = "potion"},
        {name = "梦境酊剂", buffName = "梦通", type = "potion"},
        {name = "梦境精华药剂", buffName = "梦境精华药剂", type = "potion"},
        {name = "强效奥法药剂", buffName = "强效奥法药剂", type = "potion"},
        {name = "强效火力药剂", buffName = "强效火力", type = "potion"},
        {name = "神圣磨刀石", slot = "main", type = "enchant", effect = "+100 攻击强度vs亡灵"},
        {name = "元素磨刀石", slot = "main", type = "enchant", effect = "致命一击 +2%"}
    },
    mdps = {  -- 法系DPS药剂和食物
        {name = "赞扎之魂", buffName = "赞扎之魂", type = "potion"},
        {name = "坚韧药剂", buffName = "生命 II", type = "potion"},
        {name = "魔血药水", buffName = "法力回复", type = "potion"},
        {name = "超级能量合剂", buffName = "至高能量", type = "potion"},
        {name = "梦境酊剂", buffName = "梦通", type = "potion"},
        {name = "和谐灵药", buffName = "和谐灵药", type = "potion"},
        {name = "梦境精华药剂", buffName = "梦境精华药剂", type = "potion"},
        {name = "强效奥法药剂", buffName = "强效奥法药剂", type = "potion"},
        {name = "强效自然之力药水", buffName = "强效自然力量药剂", type = "potion"},
        {name = "强效奥术之力药剂", buffName = "强效奥术之力", type = "potion"},
        {name = "麦迪文的蓝标葡萄酒", buffName = "麦迪文的蓝标葡萄酒", type = "potion"},
        {name = "脑皮层混合饮料", buffName = "坚定信念", type = "potion"},
        {name = "达农佐的泰拉比姆趣味", buffName = "进食充分", type = "food", effect = "法术伤害提高22点"},
        {name = "卓越巫师之油", slot = "main", type = "enchant", effect = "卓越巫师之油"}
    }
}

-- 检查角色对应的药剂和食物
local function CheckRoleConsumables(roleType)
    PrintMessage("[DEBUG] 开始检查 " .. roleType .. " 消耗品", false)
    
    -- 获取角色类型对应的消耗品列表
    local roleConsumables = consumablesList[roleType]
    if not roleConsumables then
        PrintMessage("[DEBUG] 没有找到 " .. roleType .. " 的消耗品定义", false)
        return true, {} -- 没有定义的消耗品，认为是完整的
    end
    
    PrintMessage("[DEBUG] 找到 " .. table.getn(roleConsumables) .. " 个 " .. roleType .. " 消耗品定义", false)
    local missingConsumables = {}
    
    -- 用于记录已检测到的消耗品
    local detectedConsumables = {}
    
    -- 检查每个消耗品
    for i, consumable in ipairs(roleConsumables) do
        PrintMessage("[DEBUG] 检查第 " .. i .. " 个消耗品: " .. consumable.name, false)
        local hasBuff = false
        local timeLeft = 0
        
        if consumable.type == "food" and consumable.effect then
            -- 对于食物，检查效果而不仅仅是buff名称（香脆蘑菇优先于巧克力鱼）
            if consumable.name == "香脆的魔法蘑菇" then
                PrintMessage("[DEBUG] 即将检查食物效果: 香脆的魔法蘑菇（优先）", false)
                hasBuff, timeLeft = HasFoodBuff(CRISPY_MAGIC_MUSHROOM_EFFECT)
                if not hasBuff then
                    hasBuff, timeLeft = HasFoodBuff(CHOCOLATE_FISH_EFFECT)
                end
            elseif consumable.name == "巧克力鱼" then
                PrintMessage("[DEBUG] 即将检查食物效果: 巧克力鱼（香脆的魔法蘑菇优先）", false)
                hasBuff, timeLeft = HasFoodBuff(CRISPY_MAGIC_MUSHROOM_EFFECT)
                if not hasBuff then
                    hasBuff, timeLeft = HasFoodBuff(CHOCOLATE_FISH_EFFECT)
                end
            else
                PrintMessage("[DEBUG] 即将检查食物效果: " .. consumable.effect, false)
                hasBuff, timeLeft = HasFoodBuff(consumable.effect)
            end
            PrintMessage("[DEBUG] 食物 " .. consumable.name .. " 检查结果: " .. tostring(hasBuff), false)
        elseif consumable.type == "enchant" and consumable.slot then
            -- 对于武器临时附魔，使用特殊函数检查
            local slotText = consumable.slot == "main" and "主手" or "副手"
            local effectName = consumable.effect or consumable.name
            if consumable.name == "神圣磨刀石" or consumable.name == "元素磨刀石" then
                PrintMessage("[DEBUG] 即将检查" .. slotText .. "武器附魔: 神圣/元素磨刀石（任意一种即可）", false)
                hasBuff, timeLeft = HasWeaponEnchant(consumable.slot, HOLY_SHARPENING_STONE_EFFECT)
                if not hasBuff then
                    hasBuff, timeLeft = HasWeaponEnchant(consumable.slot, ELEMENTAL_SHARPENING_STONE_EFFECT)
                end
            else
                PrintMessage("[DEBUG] 即将检查" .. slotText .. "武器附魔: " .. consumable.name .. " (效果: " .. effectName .. ")", false)
                hasBuff, timeLeft = HasWeaponEnchant(consumable.slot, effectName)
            end
            PrintMessage("[DEBUG] " .. slotText .. "武器附魔 " .. consumable.name .. " 检查结果: " .. tostring(hasBuff), false)
        else
            -- 对于药剂，正常检查buff名称（黑根酒/冬泉火酒做优先级兼容）
            if consumable.name == "黑根酒" then
                PrintMessage("[DEBUG] 即将检查药剂buff: 黑根酒（优先）", false)
                hasBuff, timeLeft = HasBuff("黑根酒")
                if not hasBuff then
                    -- 黑根酒缺失时允许冬泉火酒作为替代，避免重复提示
                    hasBuff, timeLeft = HasBuff("冬泉火酒")
                end
            elseif consumable.name == "冬泉火酒" then
                PrintMessage("[DEBUG] 即将检查药剂buff: 冬泉火酒（黑根酒优先）", false)
                -- 如果已存在黑根酒buff，则不再要求冬泉火酒
                hasBuff, timeLeft = HasBuff("黑根酒")
                if not hasBuff then
                    hasBuff, timeLeft = HasBuff("冬泉火酒")
                end
            else
                PrintMessage("[DEBUG] 即将检查药剂buff: " .. consumable.buffName, false)
                hasBuff, timeLeft = HasBuff(consumable.buffName)
            end
            PrintMessage("[DEBUG] 药剂 " .. consumable.name .. " 检查结果: " .. tostring(hasBuff), false)
        end
        
        if hasBuff then
            -- 记录检测到的消耗品
            table.insert(detectedConsumables, {
                name = consumable.name,
                type = consumable.type,
                timeLeft = timeLeft or 0,
            })
        else
            table.insert(missingConsumables, consumable)
        end
    end
    
    PrintMessage("[DEBUG] 检查完成，缺少 " .. table.getn(missingConsumables) .. " 个消耗品", false)
    
    -- 输出缺失的消耗品（已存在的buff不再显示，只显示缺失的）
    if table.getn(missingConsumables) > 0 then
        PrintMessage("|cFFFFFF00缺少以下" .. roleType .. "消耗品:|r", true)
        for _, consumable in ipairs(missingConsumables) do
            PrintMessage("- " .. consumable.name, true)
        end
        return false, missingConsumables
    else
        PrintMessage("所有" .. roleType .. "需要的消耗品都已使用！", true)
        return true, {}
    end
end


-- 检查指定角色类型的药剂和食物
local function CheckConsumablesByRole(role)
    PrintMessage("[DEBUG] 开始处理命令: " .. (role or "无命令"), false)
    
    -- 安全检查
    if not role or role == "" then
        PrintMessage("未提供角色类型。可用参数: tank/t, healer/h, pdps/p, mdps/m, food, potion", true)
        return false
    end
    
    role = string.lower(role)  -- 确保小写
    PrintMessage("[DEBUG] 处理命令参数: " .. role, false)

    local result = false
    if role == "tank" or role == "t" then
        PrintMessage("[DEBUG] 调用坦克消耗品检查", false)
        result = CheckRoleConsumables("tank")
    elseif role == "healer" or role == "h" then
        PrintMessage("[DEBUG] 调用治疗消耗品检查", false)
        result = CheckRoleConsumables("healer")
    elseif role == "pdps" or role == "p" then
        PrintMessage("[DEBUG] 调用物理DPS消耗品检查", false)
        result = CheckRoleConsumables("pdps")
    elseif role == "fdps" or role == "f" then
        PrintMessage("[DEBUG] 调用物理DPS和法系DPS消耗品检查", false)
        result = CheckRoleConsumables("fdps")
    elseif role == "mdps" or role == "m" then
        PrintMessage("[DEBUG] 调用法系DPS消耗品检查", false)
        result = CheckRoleConsumables("mdps")
    else
        PrintMessage("未知角色类型: " .. role, true)
        PrintMessage("可用参数: tank/t, healer/h, pdps/p, mdps/m, food, potion", true)
        result = false
    end
    
    PrintMessage("[DEBUG] 命令处理完成: " .. role .. ", 结果: " .. tostring(result), false)
    return result
end

-- 显示帮助信息
local function ShowConsumableHelp()
    PrintMessage("消耗品检查模块", true)
    PrintMessage("请使用 /cb help 查看完整帮助信息", true)
end

-- 创建命令
SLASH_CHECKBUFFCONSUMABLE1 = "/checkbc"
SLASH_CHECKBUFFCONSUMABLE2 = "/cbc"
SlashCmdList["CHECKBUFFCONSUMABLE"] = function(msg)
    PrintMessage("[DEBUG] 收到命令: /cbc " .. (msg or ""), false)
    
    -- 安全错误处理
    local status, result = pcall(function()
        local command = string.lower(msg or "")
        PrintMessage("[DEBUG] 处理命令: " .. command, false)
        
        if command == "" or command == "help" or command == "?" then
            PrintMessage("[DEBUG] 显示帮助信息", false)
            ShowConsumableHelp()
        else
            PrintMessage("[DEBUG] 执行角色消耗品检查: " .. command, false)
            CheckConsumablesByRole(command)
        end
        
        PrintMessage("[DEBUG] 命令执行完成: " .. command, false)
    end)
    
    -- 如果执行出错，显示错误信息并提供帮助
    if not status then
        PrintMessage("[ERROR] 执行命令时出错: " .. (result or "未知错误"), true)
        PrintMessage("使用 /cb help 查看完整帮助", true)
    end
    
    PrintMessage("[DEBUG] 命令处理结束", false)
end

-- 导出消耗品API
CheckBufferConsumableAPI = {
    CheckRoleConsumables = CheckRoleConsumables,
    CheckConsumablesByRole = CheckConsumablesByRole,
    UseConsumable = UseItem, -- 为未来的自动吃药功能预留
    consumablesList = consumablesList -- 暴露消耗品列表，用于自动吃药功能
}

-- 打印一些信息表明插件已加载
PrintMessage("药剂食物检查模块已加载，使用 /cb help 查看完整帮助", true)