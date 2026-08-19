-- ----------------------------------------
-- CheckBufferProfiles - 消耗品 Profile 配置
-- 面向 WoW 1.12，避免使用 Lua 5.1+ 语法
-- ----------------------------------------

if not CheckBufferCommon then
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[CheckBufferProfiles]|r 错误: CheckBufferCommon模块未加载!")
    return
end

local PrintMessage = CheckBufferCommon.PrintMessage

local function DeepCopy(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for k, v in pairs(value) do
        copy[DeepCopy(k)] = DeepCopy(v)
    end
    return copy
end

local function Trim(text)
    if not text then
        return ""
    end
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    return text
end

local DEFAULT_PROFILES = {
    ["坦克"] = {
        shortName = "t",
        aliases = {"tank"},
        bindings = {check = "CHECKBUFFER_CHECK_TANK", consume = "CHECKBUFFER_CONSUME_TANK"},
        items = {
            {name = "赞扎之魂", buffName = "赞扎之魂", type = "potion"},
            {name = "坚韧药剂", buffName = "生命 II", type = "potion"},
            {name = "翡翠猫鼬药剂", buffName = "翡翠猫鼬药剂", type = "potion", ruleGroup = "猫鼬路线"},
            {name = "敏捷药剂", buffName = "敏捷", type = "potion"},
            {name = "猫鼬药剂", buffName = "猫鼬药剂", type = "potion", ruleGroup = "猫鼬路线"},
            {name = "超强防御药剂", buffName = "强效护甲", type = "potion"},
            {name = "厚甲蝎药粉", buffName = "厚甲蝎之击", type = "potion"},
            {name = "魂能之力", buffName = "魂能之力", type = "potion"},
            {name = "黑根酒", buffName = "黑根酒", type = "potion", ruleGroup = "酒类路线"},
            {name = "冬泉火酒", buffName = "冬泉火酒", type = "potion", ruleGroup = "酒类路线"},
            {name = "阿尔萨斯的礼物", buffName = "阿尔萨斯的礼物", type = "potion"},
            {name = "麦迪文的葡萄酒", buffName = "麦迪文的葡萄酒", type = "potion"},
            {name = "保护卷轴 IV", buffName = "护甲", type = "food", effect = "护甲提高240点"},
            {name = "香脆的魔法蘑菇", buffName = "进食充分", type = "food", effect = "耐力提高25点", ruleGroup = "坦克食物路线"},
            {name = "巧克力鱼", buffName = "进食充分", type = "food", effect = "躲闪几率提高1%。防御值提高4点。", ruleGroup = "坦克食物路线"},
            {name = "神圣磨刀石", type = "enchant", slot = "main", effect = "+100 攻击强度vs亡灵", ruleGroup = "磨刀石路线"},
            {name = "元素磨刀石", type = "enchant", slot = "main", effect = "致命一击 +2%", ruleGroup = "磨刀石路线"}
        },
        rules = {
            ["猫鼬路线"] = {
                mode = "exclusive",
                candidates = {"翡翠猫鼬药剂", "猫鼬药剂"},
                requiresWhenPresent = {["翡翠猫鼬药剂"] = {"敏捷药剂"}}
            },
            ["酒类路线"] = {
                mode = "exclusive",
                candidates = {"黑根酒", "冬泉火酒"}
            },
            ["坦克食物路线"] = {
                mode = "exclusive",
                candidates = {"香脆的魔法蘑菇", "巧克力鱼"}
            },
            ["磨刀石路线"] = {
                mode = "exclusive",
                candidates = {"神圣磨刀石", "元素磨刀石"}
            }
        }
    },

    ["治疗"] = {
        shortName = "h",
        aliases = {"healer"},
        bindings = {check = "CHECKBUFFER_CHECK_HEALER", consume = "CHECKBUFFER_CONSUME_HEALER"},
        items = {
            {name = "赞扎之魂", buffName = "赞扎之魂", type = "potion"},
            {name = "坚韧药剂", buffName = "生命 II", type = "potion"},
            {name = "魔血药水", buffName = "法力回复", type = "potion"},
            {name = "梦境精华药剂", buffName = "梦境精华药剂", type = "potion"},
            {name = "麦迪文的蓝标葡萄酒", buffName = "麦迪文的蓝标葡萄酒", type = "potion"},
            {name = "脑皮层混合饮料", buffName = "坚定信念", type = "potion"},
            {name = "达农佐的泰拉比姆情调", buffName = "进食充分", type = "food", effect = "急速提高2%"},
            {name = "卓越法力之油", type = "enchant", slot = "main", effect = "卓越法力之油"}
        },
        rules = {}
    },

    ["物理DPS"] = {
        shortName = "p",
        aliases = {"pdps"},
        bindings = {check = "CHECKBUFFER_CHECK_PDPS", consume = "CHECKBUFFER_CONSUME_PDPS"},
        items = {
            {name = "赞扎之魂", buffName = "赞扎之魂", type = "potion"},
            {name = "翡翠猫鼬药剂", buffName = "翡翠猫鼬药剂", type = "potion", ruleGroup = "猫鼬路线"},
            {name = "敏捷药剂", buffName = "敏捷", type = "potion"},
            {name = "猫鼬药剂", buffName = "猫鼬药剂", type = "potion", ruleGroup = "猫鼬路线"},
            {name = "坚韧药剂", buffName = "生命 II", type = "potion"},
            {name = "厚甲蝎药粉", buffName = "厚甲蝎之击", type = "potion"},
            {name = "魂能之力", buffName = "魂能之力", type = "potion"},
            {name = "黑根酒", buffName = "黑根酒", type = "potion", ruleGroup = "酒类路线"},
            {name = "冬泉火酒", buffName = "冬泉火酒", type = "potion", ruleGroup = "酒类路线"},
            {name = "麦迪文的葡萄酒", buffName = "麦迪文的葡萄酒", type = "potion"},
            {name = "营养的魔法蘑菇", buffName = "进食充分", type = "food", effect = "力量提高20点"},
            {name = "神圣磨刀石", type = "enchant", slot = "main", effect = "+100 攻击强度vs亡灵", ruleGroup = "磨刀石路线"},
            {name = "元素磨刀石", type = "enchant", slot = "main", effect = "致命一击 +2%", ruleGroup = "磨刀石路线"}
        },
        rules = {
            ["猫鼬路线"] = {
                mode = "exclusive",
                candidates = {"翡翠猫鼬药剂", "猫鼬药剂"},
                requiresWhenPresent = {["翡翠猫鼬药剂"] = {"敏捷药剂"}}
            },
            ["酒类路线"] = {
                mode = "exclusive",
                candidates = {"黑根酒", "冬泉火酒"}
            },
            ["磨刀石路线"] = {
                mode = "exclusive",
                candidates = {"神圣磨刀石", "元素磨刀石"}
            }
        }
    },

    ["物理DPS（不差钱）"] = {
        shortName = "f",
        aliases = {"fdps"},
        bindings = {check = "CHECKBUFFER_CHECK_FDPS", consume = "CHECKBUFFER_CONSUME_FDPS"},
        items = {
            {name = "赞扎之魂", buffName = "赞扎之魂", type = "potion"},
            {name = "坚韧药剂", buffName = "生命 II", type = "potion"},
            {name = "猫鼬药剂", buffName = "猫鼬药剂", type = "potion"},
            {name = "龙息红椒", buffName = "龙息红椒", type = "potion"},
            {name = "厚甲蝎药粉", buffName = "厚甲蝎之击", type = "potion"},
            {name = "魂能之力", buffName = "魂能之力", type = "potion"},
            {name = "黑根酒", buffName = "黑根酒", type = "potion", ruleGroup = "酒类路线"},
            {name = "冬泉火酒", buffName = "冬泉火酒", type = "potion", ruleGroup = "酒类路线"},
            {name = "麦迪文的葡萄酒", buffName = "麦迪文的葡萄酒", type = "potion"},
            {name = "超级能量合剂", buffName = "至高能量", type = "flask", category = "flask"},
            {name = "梦境酊剂", buffName = "梦通", type = "potion"},
            {name = "梦境精华药剂", buffName = "梦境精华药剂", type = "potion"},
            {name = "强效奥法药剂", buffName = "强效奥法药剂", type = "potion"},
            {name = "强效火力药剂", buffName = "强效火力", type = "potion"},
            {name = "神圣磨刀石", type = "enchant", slot = "main", effect = "+100 攻击强度vs亡灵", ruleGroup = "磨刀石路线"},
            {name = "元素磨刀石", type = "enchant", slot = "main", effect = "致命一击 +2%", ruleGroup = "磨刀石路线"}
        },
        rules = {
            ["酒类路线"] = {
                mode = "exclusive",
                candidates = {"黑根酒", "冬泉火酒"}
            },
            ["磨刀石路线"] = {
                mode = "exclusive",
                candidates = {"神圣磨刀石", "元素磨刀石"}
            }
        }
    },

    ["法系DPS"] = {
        shortName = "m",
        aliases = {"mdps"},
        bindings = {check = "CHECKBUFFER_CHECK_MDPS", consume = "CHECKBUFFER_CONSUME_MDPS"},
        items = {
            {name = "赞扎之魂", buffName = "赞扎之魂", type = "potion"},
            {name = "坚韧药剂", buffName = "生命 II", type = "potion"},
            {name = "魔血药水", buffName = "法力回复", type = "potion"},
            {name = "超级能量合剂", buffName = "至高能量", type = "flask", category = "flask"},
            {name = "梦境酊剂", buffName = "梦通", type = "potion"},
            {name = "和谐灵药", buffName = "和谐灵药", type = "potion"},
            {name = "梦境精华药剂", buffName = "梦境精华药剂", type = "potion"},
            {name = "奥法巨人药剂", buffName = "奥法巨人药剂", type = "potion", ruleGroup = "奥法路线"},
            {name = "强效奥法药剂", buffName = "强效奥法药剂", type = "potion", ruleGroup = "奥法路线"},
            {name = "奥法药剂", buffName = "奥法药剂", type = "potion"},
            {name = "强效自然之力药水", buffName = "强效自然力量药剂", type = "potion"},
            {name = "强效奥术之力药剂", buffName = "强效奥术之力", type = "potion"},
            {name = "麦迪文的蓝标葡萄酒", buffName = "麦迪文的蓝标葡萄酒", type = "potion"},
            {name = "脑皮层混合饮料", buffName = "坚定信念", type = "potion"},
            {name = "达农佐的泰拉比姆趣味", buffName = "进食充分", type = "food", effect = "法术伤害提高22点"},
            {name = "卓越巫师之油", type = "enchant", slot = "main", effect = "卓越巫师之油"}
        },
        rules = {
            ["奥法路线"] = {
                mode = "exclusive",
                candidates = {"奥法巨人药剂", "强效奥法药剂"},
                requiresWhenPresent = {["奥法巨人药剂"] = {"奥法药剂"}}
            }
        }
    }
}

local DEFAULT_PROFILE_ORDER = {"坦克", "治疗", "物理DPS", "物理DPS（不差钱）", "法系DPS"}

local function GetCharacterKey()
    local realm = "UNKNOWN_REALM"
    local player = "UNKNOWN_PLAYER"
    if GetRealmName then
        realm = GetRealmName() or realm
    end
    if UnitName then
        player = UnitName("player") or player
    end
    return realm .. "-" .. player
end

local function EnsureDatabase()
    if not CheckBufferProfilesDB then
        CheckBufferProfilesDB = {}
    end

    local characterKey = GetCharacterKey()

    if not CheckBufferProfilesDB.characters then
        local oldProfiles = CheckBufferProfilesDB.profiles
        local oldProfileOrder = CheckBufferProfilesDB.profileOrder
        CheckBufferProfilesDB.characters = {}
        if oldProfiles then
            CheckBufferProfilesDB.characters[characterKey] = {
                profiles = oldProfiles,
                profileOrder = oldProfileOrder or DeepCopy(DEFAULT_PROFILE_ORDER)
            }
        end
        CheckBufferProfilesDB.profiles = nil
        CheckBufferProfilesDB.profileOrder = nil
    end

    if not CheckBufferProfilesDB.characters[characterKey] then
        CheckBufferProfilesDB.characters[characterKey] = {
            profiles = DeepCopy(DEFAULT_PROFILES),
            profileOrder = DeepCopy(DEFAULT_PROFILE_ORDER)
        }
    end

    if not CheckBufferProfilesDB.characters[characterKey].profiles then
        CheckBufferProfilesDB.characters[characterKey].profiles = DeepCopy(DEFAULT_PROFILES)
    end
    if not CheckBufferProfilesDB.characters[characterKey].profileOrder then
        CheckBufferProfilesDB.characters[characterKey].profileOrder = DeepCopy(DEFAULT_PROFILE_ORDER)
    end

    CheckBufferProfilesDB.currentCharacterKey = characterKey
    CheckBufferProfilesDB.profiles = CheckBufferProfilesDB.characters[characterKey].profiles
    CheckBufferProfilesDB.profileOrder = CheckBufferProfilesDB.characters[characterKey].profileOrder
end

local function ResolveProfile(profileKey)
    EnsureDatabase()

    local key = Trim(profileKey)
    if key == "" then
        return nil, nil
    end

    local profiles = CheckBufferProfilesDB.profiles
    if profiles[key] then
        return key, profiles[key]
    end

    local lowerKey = string.lower(key)
    local name, profile, i
    for name, profile in pairs(profiles) do
        if string.lower(name) == lowerKey then
            return name, profile
        end
        if profile.shortName and string.lower(profile.shortName) == lowerKey then
            return name, profile
        end
        if profile.aliases then
            for i = 1, table.getn(profile.aliases) do
                if string.lower(profile.aliases[i]) == lowerKey then
                    return name, profile
                end
            end
        end
    end

    return nil, nil
end

local function GetProfile(profileKey)
    local name, profile = ResolveProfile(profileKey)
    return profile, name
end

local function GetProfileItems(profileKey)
    local profile = GetProfile(profileKey)
    if profile then
        return profile.items or {}
    end
    return nil
end

local function GetProfileRules(profileKey)
    local profile = GetProfile(profileKey)
    if profile then
        return profile.rules or {}
    end
    return nil
end

local function ListProfiles()
    EnsureDatabase()
    local names = {}
    local used = {}
    local order = CheckBufferProfilesDB.profileOrder or {}
    local i, name

    for i = 1, table.getn(order) do
        name = order[i]
        if CheckBufferProfilesDB.profiles[name] then
            table.insert(names, name)
            used[name] = true
        end
    end

    for name in pairs(CheckBufferProfilesDB.profiles) do
        if not used[name] then
            table.insert(names, name)
        end
    end

    return names
end

local function GetProfileListText()
    local names = ListProfiles()
    local parts = {}
    local i, name, profile, text
    for i = 1, table.getn(names) do
        name = names[i]
        profile = CheckBufferProfilesDB.profiles[name]
        text = name
        if profile and profile.shortName then
            text = text .. "/" .. profile.shortName
        end
        table.insert(parts, text)
    end
    return table.concat(parts, ", ")
end

local function CanAutoUse(item)
    if not item then
        return false
    end
    if item.type == "enchant" then
        return false
    end
    if item.type == "flask" then
        return false
    end
    if item.category == "flask" then
        return false
    end
    if item.name and string.find(item.name, "合剂") then
        return false
    end
    return true
end

local function CreateProfile(profileName, shortName, templateName)
    EnsureDatabase()

    profileName = Trim(profileName)
    shortName = Trim(shortName)
    if profileName == "" or shortName == "" then
        return false, "Profile名和缩略名不能为空"
    end
    if CheckBufferProfilesDB.profiles[profileName] then
        return false, "Profile已存在: " .. profileName
    end
    if ResolveProfile(shortName) then
        return false, "缩略名已被占用: " .. shortName
    end

    local template = nil
    if templateName and templateName ~= "" then
        template = GetProfile(templateName)
    end

    local profile
    if template then
        profile = DeepCopy(template)
    else
        profile = {items = {}, rules = {}}
    end
    profile.shortName = shortName
    profile.aliases = {}
    profile.bindings = {
        check = "CHECKBUFFER_CHECK_CUSTOM_" .. string.upper(shortName),
        consume = "CHECKBUFFER_CONSUME_CUSTOM_" .. string.upper(shortName)
    }

    CheckBufferProfilesDB.profiles[profileName] = profile
    table.insert(CheckBufferProfilesDB.profileOrder, profileName)
    return true, profileName
end

local function DeleteProfile(profileKey)
    EnsureDatabase()
    local profileName = ResolveProfile(profileKey)
    local i
    if not profileName then
        return false, "Profile不存在"
    end
    CheckBufferProfilesDB.profiles[profileName] = nil
    if CheckBufferProfilesDB.profileOrder then
        for i = table.getn(CheckBufferProfilesDB.profileOrder), 1, -1 do
            if CheckBufferProfilesDB.profileOrder[i] == profileName then
                table.remove(CheckBufferProfilesDB.profileOrder, i)
            end
        end
    end
    return true, profileName
end

local function ResetDefaults()
    if not CheckBufferProfilesDB then
        CheckBufferProfilesDB = {}
    end
    if not CheckBufferProfilesDB.characters then
        CheckBufferProfilesDB.characters = {}
    end
    local characterKey = GetCharacterKey()
    CheckBufferProfilesDB.characters[characterKey] = {
        profiles = DeepCopy(DEFAULT_PROFILES),
        profileOrder = DeepCopy(DEFAULT_PROFILE_ORDER)
    }
    CheckBufferProfilesDB.currentCharacterKey = characterKey
    CheckBufferProfilesDB.profiles = CheckBufferProfilesDB.characters[characterKey].profiles
    CheckBufferProfilesDB.profileOrder = CheckBufferProfilesDB.characters[characterKey].profileOrder
    return true
end

local function GetBindingProfileName(names, index)
    if names[index] then
        return names[index]
    end
    return "未设置 Profile " .. index
end

local function UpdateBindingNames()
    local names = ListProfiles()
    BINDING_HEADER_CHECKBUFFER_HEADER = "CheckBuffer"
    BINDING_NAME_CHECKBUFFER_CHECK_TANK = "检查消耗品: " .. GetBindingProfileName(names, 1)
    BINDING_NAME_CHECKBUFFER_CONSUME_TANK = "自动吃药: " .. GetBindingProfileName(names, 1)
    BINDING_NAME_CHECKBUFFER_CHECK_HEALER = "检查消耗品: " .. GetBindingProfileName(names, 2)
    BINDING_NAME_CHECKBUFFER_CONSUME_HEALER = "自动吃药: " .. GetBindingProfileName(names, 2)
    BINDING_NAME_CHECKBUFFER_CHECK_PDPS = "检查消耗品: " .. GetBindingProfileName(names, 3)
    BINDING_NAME_CHECKBUFFER_CONSUME_PDPS = "自动吃药: " .. GetBindingProfileName(names, 3)
    BINDING_NAME_CHECKBUFFER_CHECK_FDPS = "检查消耗品: " .. GetBindingProfileName(names, 4)
    BINDING_NAME_CHECKBUFFER_CONSUME_FDPS = "自动吃药: " .. GetBindingProfileName(names, 4)
    BINDING_NAME_CHECKBUFFER_CHECK_MDPS = "检查消耗品: " .. GetBindingProfileName(names, 5)
    BINDING_NAME_CHECKBUFFER_CONSUME_MDPS = "自动吃药: " .. GetBindingProfileName(names, 5)
    BINDING_NAME_CHECKBUFFER_CHECK_CUSTOM_1 = "检查消耗品: " .. GetBindingProfileName(names, 6)
    BINDING_NAME_CHECKBUFFER_CONSUME_CUSTOM_1 = "自动吃药: " .. GetBindingProfileName(names, 6)
    BINDING_NAME_CHECKBUFFER_CHECK_CUSTOM_2 = "检查消耗品: " .. GetBindingProfileName(names, 7)
    BINDING_NAME_CHECKBUFFER_CONSUME_CUSTOM_2 = "自动吃药: " .. GetBindingProfileName(names, 7)
    BINDING_NAME_CHECKBUFFER_CHECK_CUSTOM_3 = "检查消耗品: " .. GetBindingProfileName(names, 8)
    BINDING_NAME_CHECKBUFFER_CONSUME_CUSTOM_3 = "自动吃药: " .. GetBindingProfileName(names, 8)
    BINDING_NAME_CHECKBUFFER_CHECK_CUSTOM_4 = "检查消耗品: " .. GetBindingProfileName(names, 9)
    BINDING_NAME_CHECKBUFFER_CONSUME_CUSTOM_4 = "自动吃药: " .. GetBindingProfileName(names, 9)
    BINDING_NAME_CHECKBUFFER_CHECK_CUSTOM_5 = "检查消耗品: " .. GetBindingProfileName(names, 10)
    BINDING_NAME_CHECKBUFFER_CONSUME_CUSTOM_5 = "自动吃药: " .. GetBindingProfileName(names, 10)
end

EnsureDatabase()

UpdateBindingNames()

CheckBufferProfilesAPI = {
    defaultProfiles = DEFAULT_PROFILES,
    ResolveProfile = ResolveProfile,
    GetProfile = GetProfile,
    GetProfileItems = GetProfileItems,
    GetProfileRules = GetProfileRules,
    ListProfiles = ListProfiles,
    GetProfileListText = GetProfileListText,
    CanAutoUse = CanAutoUse,
    CreateProfile = CreateProfile,
    DeleteProfile = DeleteProfile,
    ResetDefaults = ResetDefaults,
    UpdateBindingNames = UpdateBindingNames,
    DeepCopy = DeepCopy
}

PrintMessage("消耗品Profile配置已加载", true)
