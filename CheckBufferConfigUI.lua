-- ----------------------------------------
-- CheckBufferConfigUI - Profile 配置界面
-- 面向 WoW 1.12，使用基础 Frame API
-- ----------------------------------------

if not CheckBufferCommon or not CheckBufferProfilesAPI then
    return
end

local PrintMessage = CheckBufferCommon.PrintMessage
local ProfilesAPI = CheckBufferProfilesAPI
local MINIMAP_ICON = "Interface\\Icons\\INV_Potion_62"

local UI = {
    frame = nil,
    minimapButton = nil,
    currentProfile = "法系DPS",
    currentTab = "items",
    selectedItemIndex = 1,
    selectedItemType = "potion",
    selectedRuleName = nil,
    profileButtons = {},
    itemButtons = {},
    ruleButtons = {},
    typeOptions = {},
    ruleCandidateNames = {},
    ruleRequireItemNames = {},
    ruleRequireCandidate = "",
    sections = {}
}

local ITEM_TYPE_OPTIONS = {
    {value = "potion", label = "药剂"},
    {value = "flask", label = "合剂"},
    {value = "food", label = "食物"},
    {value = "enchant-main", label = "武器附魔(主手)"},
    {value = "enchant-off", label = "武器附魔(副手)"}
}

local function Trim(text)
    if not text then
        return ""
    end
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    return text
end

local function SplitList(text)
    local result = {}
    local pos = 1
    local startPos, endPos, part
    text = text or ""
    while true do
        startPos, endPos, part = string.find(text, "([^,，]+)", pos)
        if not startPos then
            break
        end
        part = Trim(part)
        if part ~= "" then
            table.insert(result, part)
        end
        pos = endPos + 1
    end
    return result
end

local function JoinList(list)
    if not list then
        return ""
    end
    return table.concat(list, ", ")
end

local function NormalizeItemType(item)
    if item and (item.category == "flask" or item.type == "flask") then
        return "flask"
    end
    if item and item.type == "enchant" then
        if item.slot == "off" then
            return "enchant-off"
        end
        return "enchant-main"
    end
    if item and item.type and item.type ~= "" then
        return item.type
    end
    return "potion"
end

local function GetTypeLabel(item)
    local itemType = NormalizeItemType(item)
    local i, option
    for i = 1, table.getn(ITEM_TYPE_OPTIONS) do
        option = ITEM_TYPE_OPTIONS[i]
        if option.value == itemType then
            return option.label
        end
    end
    return itemType
end

local function GetTypeLabelByValue(value)
    local i, option
    for i = 1, table.getn(ITEM_TYPE_OPTIONS) do
        option = ITEM_TYPE_OPTIONS[i]
        if option.value == value then
            return option.label
        end
    end
    return value or "药剂"
end

local function GetTypeValueByLabel(label)
    local i, option
    for i = 1, table.getn(ITEM_TYPE_OPTIONS) do
        option = ITEM_TYPE_OPTIONS[i]
        if option.label == label then
            return option.value
        end
    end
    return "potion"
end

local function GetTypeLabelOptions()
    local labels = {}
    local i
    for i = 1, table.getn(ITEM_TYPE_OPTIONS) do
        table.insert(labels, ITEM_TYPE_OPTIONS[i].label)
    end
    return labels
end

local function CreatePanel(parent, x, y, width, height)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    panel:SetWidth(width)
    panel:SetHeight(height)
    panel:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4}
    })
    panel:SetBackdropColor(0, 0, 0, 0.85)
    return panel
end

local function CreateLabel(parent, text, x, y, width)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetWidth(width or 120)
    label:SetJustifyH("LEFT")
    label:SetText(text or "")
    return label
end

local function CreateSmallText(parent, text, x, y, width)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetWidth(width or 120)
    label:SetJustifyH("LEFT")
    label:SetText(text or "")
    return label
end

local function CreateEditBox(parent, x, y, width)
    local box = CreateFrame("EditBox", nil, parent)
    box:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    box:SetWidth(width or 160)
    box:SetHeight(22)
    box:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 8,
        edgeSize = 10,
        insets = {left = 2, right = 2, top = 2, bottom = 2}
    })
    box:SetBackdropColor(0, 0, 0, 0.9)
    box:SetTextColor(1, 0.82, 0)
    box:SetFontObject("GameFontHighlightSmall")
    box:SetTextInsets(6, 6, 0, 0)
    box:SetAutoFocus(false)
    return box
end

local function CreateButton(parent, text, x, y, width, height, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    button:SetWidth(width or 80)
    button:SetHeight(height or 22)
    button:SetText(text or "")
    if onClick then
        button:SetScript("OnClick", onClick)
    end
    return button
end

local function CreateCheckBox(parent, text, x, y, onClick)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    check:SetWidth(24)
    check:SetHeight(24)
    check.label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    check.label:SetPoint("LEFT", check, "RIGHT", 2, 0)
    check.label:SetText(text or "")
    if onClick then
        check:SetScript("OnClick", onClick)
    end
    return check
end

local function CreateListRow(parent, x, y, width, height, onClick)
    local row = CreateFrame("Button", nil, parent)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    row:SetWidth(width)
    row:SetHeight(height)
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints(row)
    row.bg:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    row.bg:SetVertexColor(0, 0, 0, 0)
    row.hover = false
    row.selected = false
    if onClick then
        row:SetScript("OnClick", onClick)
    end
    row:SetScript("OnEnter", function()
        if this then
            this.hover = true
            if this.bg then
                this.bg:SetVertexColor(0.25, 0.18, 0.05, 0.45)
            end
        end
    end)
    row:SetScript("OnLeave", function()
        if this then
            this.hover = false
            if this.bg then
                if this.selected then
                    this.bg:SetVertexColor(0.85, 0.28, 0.03, 0.85)
                else
                    this.bg:SetVertexColor(0, 0, 0, 0)
                end
            end
        end
    end)
    return row
end

local function SetListRowSelected(row, selected)
    if not row then
        return
    end
    row.selected = selected
    if row.bg then
        if selected then
            row.bg:SetVertexColor(0.85, 0.28, 0.03, 0.85)
        else
            row.bg:SetVertexColor(0, 0, 0, 0)
        end
    end
end

local function CreateOptionBox(parent, x, y, width, height, onClick)
    local box = CreateFrame("Button", nil, parent)
    box:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    box:SetWidth(width)
    box:SetHeight(height)
    box:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 8,
        edgeSize = 8,
        insets = {left = 2, right = 2, top = 2, bottom = 2}
    })
    box:SetBackdropColor(0, 0, 0, 0.75)
    if onClick then
        box:SetScript("OnClick", onClick)
    end
    return box
end

local AddRowText

local function CreateDropdown(parent, x, y, width, optionsProvider, onSelect)
    local drop = {}
    local button = CreateOptionBox(parent, x, y, width, 22, function()
        if drop.menu:IsVisible() then
            drop.menu:Hide()
        else
            drop.offset = 0
            drop:Refresh()
            drop.menu:Show()
        end
    end)
    drop.button = button
    drop.value = ""
    button:SetBackdropColor(0.04, 0.01, 0, 0.95)
    button.text = AddRowText(button, 8, width - 18, "LEFT")
    button.text:SetText("")
    button.arrowBg = button:CreateTexture(nil, "BACKGROUND")
    button.arrowBg:SetPoint("TOPRIGHT", button, "TOPRIGHT", -3, -3)
    button.arrowBg:SetWidth(18)
    button.arrowBg:SetHeight(16)
    button.arrowBg:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    button.arrowBg:SetVertexColor(0.35, 0.08, 0.02, 0.9)
    button.arrow = AddRowText(button, width - 18, 16, "CENTER")
    button.arrow:SetText("▼")

    drop.menu = CreatePanel(parent, x, y - 24, width, 196)
    drop.menu:SetFrameStrata("DIALOG")
    drop.menu:Hide()
    drop.rows = {}
    drop.optionsProvider = optionsProvider
    drop.onSelect = onSelect
    drop.offset = 0
    drop.menu:EnableMouseWheel(true)
    drop.menu:SetScript("OnMouseWheel", function()
        local options = {}
        local maxOffset = 0
        if drop.optionsProvider then
            options = drop.optionsProvider() or {}
        end
        maxOffset = table.getn(options) - table.getn(drop.rows)
        if maxOffset < 0 then
            maxOffset = 0
        end
        if arg1 and arg1 < 0 then
            drop.offset = drop.offset + 1
        else
            drop.offset = drop.offset - 1
        end
        if drop.offset < 0 then
            drop.offset = 0
        end
        if drop.offset > maxOffset then
            drop.offset = maxOffset
        end
        drop:Refresh()
    end)

    local i, row
    for i = 1, 8 do
        row = CreateListRow(drop.menu, 4, -4 - (i - 1) * 23, width - 8, 23, function()
            if this and this.value then
                drop:SetValue(this.value)
                drop.menu:Hide()
                if drop.onSelect then
                    drop.onSelect(this.value)
                end
            end
        end)
        row.text = AddRowText(row, 6, width - 20, "LEFT")
        drop.rows[i] = row
    end

    function drop:SetValue(value)
        self.value = value or ""
        self.button.text:SetText(self.value)
    end

    function drop:GetValue()
        return self.value or ""
    end

    function drop:Refresh()
        local options = {}
        local i, row, value
        if self.optionsProvider then
            options = self.optionsProvider() or {}
        end
        for i = 1, table.getn(self.rows) do
            row = self.rows[i]
            value = options[i + self.offset]
            if value then
                row.value = value
                row.text:SetText(value)
                row:Show()
            else
                row.value = nil
                row:Hide()
            end
        end
    end

    return drop
end

AddRowText = function(row, x, width, justify)
    local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("LEFT", row, "LEFT", x, 0)
    text:SetWidth(width)
    text:SetJustifyH(justify or "LEFT")
    text:SetText("")
    return text
end

local function CreateProfileRow(parent, x, y, width, height, onClick)
    local row = CreateListRow(parent, x, y, width, height, onClick)
    row.text = AddRowText(row, 8, width - 16, "LEFT")
    return row
end

local function CreateItemRow(parent, x, y, width, height, onClick)
    local row = CreateListRow(parent, x, y, width, height, onClick)
    row.typeText = AddRowText(row, 8, 90, "LEFT")
    row.nameText = AddRowText(row, 103, 95, "LEFT")
    row.buffText = AddRowText(row, 203, 95, "LEFT")
    row.groupText = AddRowText(row, 303, 60, "LEFT")
    return row
end

local function CreateRuleRow(parent, x, y, width, height, onClick)
    local row = CreateListRow(parent, x, y, width, height, onClick)
    row.nameText = AddRowText(row, 8, 105, "LEFT")
    row.candidatesText = AddRowText(row, 118, 155, "LEFT")
    row.requiresText = AddRowText(row, 278, 110, "LEFT")
    return row
end

local SaveSelectedItem

local function RefreshTypeOptions()
    local i, button
    for i = 1, table.getn(UI.typeOptions) do
        button = UI.typeOptions[i]
        if button.typeValue == UI.selectedItemType then
            button:SetBackdropColor(0.35, 0.12, 0.02, 0.95)
        else
            button:SetBackdropColor(0, 0, 0, 0.75)
        end
    end
end

local function RefreshBuffBoxState()
    if not UI.buffSameCheck or not UI.buffBox then
        return
    end
    if UI.buffSameCheck:GetChecked() then
        UI.buffBox:SetText(UI.nameBox:GetText())
        UI.buffBox:ClearFocus()
        UI.buffBox:EnableMouse(false)
        UI.buffBox:SetTextColor(0.55, 0.55, 0.55)
    else
        UI.buffBox:EnableMouse(true)
        UI.buffBox:SetTextColor(1, 0.82, 0)
    end
end

local function RefreshEffectBoxState()
    if not UI.effectBox then
        return
    end
    if UI.selectedItemType == "potion" or UI.selectedItemType == "flask" then
        UI.effectBox:SetText("")
        UI.effectBox:ClearFocus()
        UI.effectBox:EnableMouse(false)
        UI.effectBox:SetTextColor(0.55, 0.55, 0.55)
    else
        UI.effectBox:EnableMouse(true)
        UI.effectBox:SetTextColor(1, 0.82, 0)
    end
end

local function SelectItemType(itemType)
    UI.selectedItemType = itemType or "potion"
    if UI.typeDropdown then
        UI.typeDropdown:SetValue(GetTypeLabelByValue(UI.selectedItemType))
    end
    RefreshTypeOptions()
    RefreshEffectBoxState()
    if UI.nameBox then
        SaveSelectedItem()
    end
end

local function CreateTypeOption(parent, label, value, x, y, width, height)
    local row = CreateOptionBox(parent, x, y, width, height, function()
        SelectItemType(this.typeValue)
    end)
    row.typeValue = value
    row.text = AddRowText(row, 8, width - 16, "CENTER")
    row.text:SetText(label)
    row:SetScript("OnLeave", function()
        RefreshTypeOptions()
    end)
    table.insert(UI.typeOptions, row)
    return row
end

local function GetCurrentProfile()
    local profile = ProfilesAPI.GetProfile(UI.currentProfile)
    return profile
end

local function SetSectionVisible(name, visible)
    if UI.sections[name] then
        if visible then
            UI.sections[name]:Show()
        else
            UI.sections[name]:Hide()
        end
    end
end

local function GetScrollOffset(scrollFrame)
    if scrollFrame and FauxScrollFrame_GetOffset then
        return FauxScrollFrame_GetOffset(scrollFrame)
    end
    return 0
end

local function UpdateScroll(scrollFrame, totalRows, visibleRows, rowHeight)
    if scrollFrame and FauxScrollFrame_Update then
        FauxScrollFrame_Update(scrollFrame, totalRows, visibleRows, rowHeight)
    end
end

local function RefreshProfileButtons()
    local names = ProfilesAPI.ListProfiles()
    local offset = GetScrollOffset(UI.profileScroll)
    local i, button, name, profile
    UpdateScroll(UI.profileScroll, table.getn(names), table.getn(UI.profileButtons), 24)
    for i = 1, table.getn(UI.profileButtons) do
        button = UI.profileButtons[i]
        name = names[i + offset]
        if name then
            profile = CheckBufferProfilesDB.profiles[name]
            button.text:SetText(name)
            button.profileName = name
            SetListRowSelected(button, name == UI.currentProfile)
            button:Show()
        else
            SetListRowSelected(button, false)
            button:Hide()
        end
    end
end

local function LoadSelectedItem()
    local profile = GetCurrentProfile()
    local item
    if profile and profile.items then
        item = profile.items[UI.selectedItemIndex]
    end
    if not item then
        item = {name = "", buffName = "", type = "potion", effect = "", ruleGroup = ""}
    end
    UI.selectedItemType = NormalizeItemType(item)
    if UI.typeDropdown then
        UI.typeDropdown:SetValue(GetTypeLabelByValue(UI.selectedItemType))
    end
    RefreshTypeOptions()
    UI.nameBox:SetText(item.name or "")
    UI.buffBox:SetText(item.buffName or "")
    if UI.buffSameCheck then
        UI.buffSameCheck:SetChecked((item.buffName or item.name or "") == (item.name or ""))
    end
    UI.effectBox:SetText(item.effect or "")
    UI.ruleBox:SetText(item.ruleGroup or "")
    RefreshBuffBoxState()
    RefreshEffectBoxState()
end

local function RefreshItemRows()
    local profile = GetCurrentProfile()
    local items = profile and profile.items or {}
    local offset = GetScrollOffset(UI.itemScroll)
    local i, button, item
    UpdateScroll(UI.itemScroll, table.getn(items), table.getn(UI.itemButtons), 24)
    for i = 1, table.getn(UI.itemButtons) do
        button = UI.itemButtons[i]
        item = items[i + offset]
        if item then
            button.typeText:SetText(GetTypeLabel(item))
            button.nameText:SetText(item.name or "")
            button.buffText:SetText(item.buffName or item.name or "")
            button.groupText:SetText(item.ruleGroup or "")
            button.itemIndex = i + offset
            SetListRowSelected(button, button.itemIndex == UI.selectedItemIndex)
            button:Show()
        else
            SetListRowSelected(button, false)
            button:Hide()
        end
    end
    if UI.selectedItemIndex > table.getn(items) then
        UI.selectedItemIndex = table.getn(items)
    end
    if UI.selectedItemIndex < 1 then
        UI.selectedItemIndex = 1
    end
    LoadSelectedItem()
end

SaveSelectedItem = function()
    local profile = GetCurrentProfile()
    local item
    if not profile then
        return
    end
    if not profile.items then
        profile.items = {}
    end
    if not profile.items[UI.selectedItemIndex] then
        profile.items[UI.selectedItemIndex] = {}
    end
    item = profile.items[UI.selectedItemIndex]
    item.type = UI.selectedItemType or "potion"
    item.slot = nil
    item.category = nil
    if item.type == "flask" then
        item.category = "flask"
    elseif item.type == "enchant-main" then
        item.type = "enchant"
        item.slot = "main"
    elseif item.type == "enchant-off" then
        item.type = "enchant"
        item.slot = "off"
    end
    item.name = Trim(UI.nameBox:GetText())
    if UI.buffSameCheck and UI.buffSameCheck:GetChecked() then
        item.buffName = item.name
    else
        item.buffName = Trim(UI.buffBox:GetText())
    end
    item.effect = Trim(UI.effectBox:GetText())

    if item.buffName == "" then
        item.buffName = item.name
    end
    if item.effect == "" then
        item.effect = nil
    end
    if item.type == "potion" or item.type == "flask" then
        item.effect = nil
    end
    RefreshItemRows()
end

local function AddItem()
    local profile = GetCurrentProfile()
    if not profile then
        return
    end
    if not profile.items then
        profile.items = {}
    end
    table.insert(profile.items, {type = "potion", name = "新消耗品", buffName = "新消耗品"})
    UI.selectedItemIndex = table.getn(profile.items)
    RefreshItemRows()
end

local function DeleteItem()
    local profile = GetCurrentProfile()
    if profile and profile.items and profile.items[UI.selectedItemIndex] then
        table.remove(profile.items, UI.selectedItemIndex)
        RefreshItemRows()
    end
end

local function MoveItem(delta)
    local profile = GetCurrentProfile()
    local items = profile and profile.items
    local target, temp
    if not items then
        return
    end
    target = UI.selectedItemIndex + delta
    if target < 1 or target > table.getn(items) then
        return
    end
    temp = items[UI.selectedItemIndex]
    items[UI.selectedItemIndex] = items[target]
    items[target] = temp
    UI.selectedItemIndex = target
    RefreshItemRows()
end

local function GetCurrentItemNameOptions()
    local profile = GetCurrentProfile()
    local items = profile and profile.items or {}
    local names = {}
    local i, item
    for i = 1, table.getn(items) do
        item = items[i]
        if item and item.name and item.name ~= "" then
            table.insert(names, item.name)
        end
    end
    return names
end

local function GetProfileNameOptions()
    return ProfilesAPI.ListProfiles()
end

local function ContainsText(list, text)
    local i
    if not list or not text or text == "" then
        return false
    end
    for i = 1, table.getn(list) do
        if list[i] == text then
            return true
        end
    end
    return false
end

local function RefreshRuleEditLists()
    UI.ruleCandidatesText:SetText(JoinList(UI.ruleCandidateNames))
    UI.ruleRequireItemsText:SetText(JoinList(UI.ruleRequireItemNames))
    if UI.ruleCandidateDropdown then
        UI.ruleCandidateDropdown:SetValue("")
    end
    if UI.ruleRequireCandidateDropdown then
        UI.ruleRequireCandidateDropdown:SetValue(UI.ruleRequireCandidate or "")
    end
    if UI.ruleRequireItemDropdown then
        UI.ruleRequireItemDropdown:SetValue("")
    end
end

local SaveRule

local function AddRuleCandidate()
    local value = UI.ruleCandidateDropdown and UI.ruleCandidateDropdown:GetValue() or ""
    if value ~= "" and not ContainsText(UI.ruleCandidateNames, value) then
        table.insert(UI.ruleCandidateNames, value)
    end
    RefreshRuleEditLists()
    if SaveRule and UI.ruleNameBox and Trim(UI.ruleNameBox:GetText()) ~= "" then
        SaveRule()
    end
end

local function ClearRuleCandidates()
    UI.ruleCandidateNames = {}
    UI.ruleRequireCandidate = ""
    RefreshRuleEditLists()
    if SaveRule and UI.ruleNameBox and Trim(UI.ruleNameBox:GetText()) ~= "" then
        SaveRule()
    end
end

local function AddRuleRequireItem()
    local value = UI.ruleRequireItemDropdown and UI.ruleRequireItemDropdown:GetValue() or ""
    if value ~= "" and not ContainsText(UI.ruleRequireItemNames, value) then
        table.insert(UI.ruleRequireItemNames, value)
    end
    RefreshRuleEditLists()
    if SaveRule and UI.ruleNameBox and Trim(UI.ruleNameBox:GetText()) ~= "" then
        SaveRule()
    end
end

local function ClearRuleRequireItems()
    UI.ruleRequireItemNames = {}
    RefreshRuleEditLists()
    if SaveRule and UI.ruleNameBox and Trim(UI.ruleNameBox:GetText()) ~= "" then
        SaveRule()
    end
end

local function ApplyRuleGroupToCandidates(profile, oldRuleName, newRuleName, candidates)
    local items = profile and profile.items or {}
    local i, item, candidateName
    for i = 1, table.getn(items) do
        item = items[i]
        if item and (item.ruleGroup == oldRuleName or item.ruleGroup == newRuleName) then
            item.ruleGroup = nil
        end
    end
    for i = 1, table.getn(candidates) do
        candidateName = candidates[i]
        local j
        for j = 1, table.getn(items) do
            item = items[j]
            if item and item.name == candidateName then
                item.ruleGroup = newRuleName
            end
        end
    end
end

SaveRule = function()
    local profile = GetCurrentProfile()
    local ruleName = Trim(UI.ruleNameBox:GetText())
    local candidates = UI.ruleCandidateNames or {}
    local requireCandidate = UI.ruleRequireCandidate or ""
    local requireItems = UI.ruleRequireItemNames or {}
    if not profile or ruleName == "" then
        PrintMessage("组名不能为空", true)
        return
    end
    if not profile.rules then
        profile.rules = {}
    end
    if UI.selectedRuleName and UI.selectedRuleName ~= ruleName then
        profile.rules[UI.selectedRuleName] = nil
    end
    ApplyRuleGroupToCandidates(profile, UI.selectedRuleName, ruleName, candidates)
    profile.rules[ruleName] = {mode = "exclusive", candidates = candidates}
    if requireCandidate ~= "" and table.getn(requireItems) > 0 then
        profile.rules[ruleName].requiresWhenPresent = {}
        profile.rules[ruleName].requiresWhenPresent[requireCandidate] = requireItems
    end
    UI.selectedRuleName = ruleName
    RefreshRuleRows()
    RefreshItemRows()
end

local function GetRuleNames()
    local profile = GetCurrentProfile()
    local rules = profile and profile.rules or {}
    local names = {}
    local ruleName
    for ruleName in pairs(rules) do
        table.insert(names, ruleName)
    end
    table.sort(names)
    return names
end

local function GetRuleRequireText(rule)
    local candidate, items
    if rule and rule.requiresWhenPresent then
        candidate, items = next(rule.requiresWhenPresent)
        if candidate and items then
            return candidate .. " -> " .. JoinList(items)
        end
    end
    return ""
end

local function LoadSelectedRule()
    local profile = GetCurrentProfile()
    local rules = profile and profile.rules or {}
    local names = GetRuleNames()
    local ruleName = UI.selectedRuleName
    local rule, candidate, items
    if (not ruleName or not rules[ruleName]) and table.getn(names) > 0 then
        ruleName = names[1]
        UI.selectedRuleName = ruleName
    end
    rule = ruleName and rules[ruleName] or nil
    if ruleName and rule then
        UI.ruleNameBox:SetText(ruleName)
        UI.ruleCandidateNames = {}
        UI.ruleRequireCandidate = ""
        UI.ruleRequireItemNames = {}
        if rule.candidates then
            local i
            for i = 1, table.getn(rule.candidates) do
                table.insert(UI.ruleCandidateNames, rule.candidates[i])
            end
        end
        if rule.requiresWhenPresent then
            candidate, items = next(rule.requiresWhenPresent)
            if candidate and items then
                UI.ruleRequireCandidate = candidate
                local i
                for i = 1, table.getn(items) do
                    table.insert(UI.ruleRequireItemNames, items[i])
                end
            end
        end
        RefreshRuleEditLists()
    else
        UI.ruleNameBox:SetText("")
        UI.ruleCandidateNames = {}
        UI.ruleRequireCandidate = ""
        UI.ruleRequireItemNames = {}
        RefreshRuleEditLists()
    end
end

function RefreshRuleRows()
    local profile = GetCurrentProfile()
    local rules = profile and profile.rules or {}
    local names = GetRuleNames()
    local offset = GetScrollOffset(UI.ruleScroll)
    local i, button, ruleName, rule
    UpdateScroll(UI.ruleScroll, table.getn(names), table.getn(UI.ruleButtons), 24)
    for i = 1, table.getn(UI.ruleButtons) do
        button = UI.ruleButtons[i]
        ruleName = names[i + offset]
        if ruleName then
            rule = rules[ruleName]
            button.nameText:SetText(ruleName)
            button.candidatesText:SetText(JoinList(rule.candidates))
            button.requiresText:SetText(GetRuleRequireText(rule))
            button.ruleName = ruleName
            SetListRowSelected(button, ruleName == UI.selectedRuleName)
            button:Show()
        else
            SetListRowSelected(button, false)
            button:Hide()
        end
    end
    LoadSelectedRule()
end

local function AddRule()
    local profile = GetCurrentProfile()
    local baseName = "新组"
    local name = baseName
    local index = 1
    if not profile then
        return
    end
    if not profile.rules then
        profile.rules = {}
    end
    while profile.rules[name] do
        index = index + 1
        name = baseName .. index
    end
    profile.rules[name] = {mode = "exclusive", candidates = {}}
    UI.selectedRuleName = name
    RefreshRuleRows()
end

local function DeleteRule()
    local profile = GetCurrentProfile()
    local items = profile and profile.items or {}
    local i, item
    if profile and profile.rules and UI.selectedRuleName then
        profile.rules[UI.selectedRuleName] = nil
        for i = 1, table.getn(items) do
            item = items[i]
            if item and item.ruleGroup == UI.selectedRuleName then
                item.ruleGroup = nil
            end
        end
        UI.selectedRuleName = nil
        RefreshRuleRows()
        RefreshItemRows()
    end
end

local function JsonQuote(text)
    text = text or ""
    text = string.gsub(text, "\\", "\\\\")
    text = string.gsub(text, "\"", "\\\"")
    text = string.gsub(text, "\n", "\\n")
    return "\"" .. text .. "\""
end

local function JsonStringArray(list)
    local text = "["
    local i
    if list then
        for i = 1, table.getn(list) do
            if i > 1 then
                text = text .. ", "
            end
            text = text .. JsonQuote(list[i])
        end
    end
    return text .. "]"
end

local function RefreshPreview()
    local profile = GetCurrentProfile()
    local text = ""
    local i, item, ruleName, rule, firstRule, candidateName, requires, characterKey
    if not profile then
        UI.previewText:SetText("")
        return
    end

    characterKey = CheckBufferProfilesDB.currentCharacterKey or ""
    text = text .. "{\n"
    text = text .. "  \"currentCharacterKey\": " .. JsonQuote(characterKey) .. ",\n"
    text = text .. "  \"characters\": {\n"
    text = text .. "    " .. JsonQuote(characterKey) .. ": {\n"
    text = text .. "      \"profiles\": {\n"
    text = text .. "        " .. JsonQuote(UI.currentProfile) .. ": {\n"
    text = text .. "          \"shortName\": " .. JsonQuote(profile.shortName) .. ",\n"
    text = text .. "          \"aliases\": " .. JsonStringArray(profile.aliases) .. ",\n"
    text = text .. "          \"items\": [\n"
    if profile.items then
        for i = 1, table.getn(profile.items) do
            item = profile.items[i]
            text = text .. "            {\"name\": " .. JsonQuote(item.name)
            if item.buffName then
                text = text .. ", \"buffName\": " .. JsonQuote(item.buffName)
            end
            text = text .. ", \"type\": " .. JsonQuote(item.type or "potion")
            if item.category then
                text = text .. ", \"category\": " .. JsonQuote(item.category)
            end
            if item.slot then
                text = text .. ", \"slot\": " .. JsonQuote(item.slot)
            end
            if item.effect then
                text = text .. ", \"effect\": " .. JsonQuote(item.effect)
            end
            if item.ruleGroup then
                text = text .. ", \"ruleGroup\": " .. JsonQuote(item.ruleGroup)
            end
            text = text .. "}"
            if i < table.getn(profile.items) then
                text = text .. ","
            end
            text = text .. "\n"
        end
    end
    text = text .. "          ],\n"
    text = text .. "          \"rules\": {\n"
    firstRule = true
    if profile.rules then
        for ruleName, rule in pairs(profile.rules) do
            if not firstRule then
                text = text .. ",\n"
            end
            firstRule = false
            text = text .. "            " .. JsonQuote(ruleName) .. ": {\"mode\": " .. JsonQuote(rule.mode or "exclusive")
            text = text .. ", \"candidates\": " .. JsonStringArray(rule.candidates)
            if rule.requiresWhenPresent then
                text = text .. ", \"requiresWhenPresent\": {"
                local firstRequire = true
                for candidateName, requires in pairs(rule.requiresWhenPresent) do
                    if not firstRequire then
                        text = text .. ", "
                    end
                    firstRequire = false
                    text = text .. JsonQuote(candidateName) .. ": " .. JsonStringArray(requires)
                end
                text = text .. "}"
            end
            text = text .. "}"
        end
    end
    text = text .. "\n          }\n"
    text = text .. "        }\n"
    text = text .. "      },\n"
    text = text .. "      \"profileOrder\": " .. JsonStringArray(CheckBufferProfilesDB.profileOrder) .. "\n"
    text = text .. "    }\n"
    text = text .. "  }\n"
    text = text .. "}"
    UI.previewText:SetText(text)
end

local ShowTab

local function CreateProfileFromUI()
    local templateName = ""
    if UI.newTemplateDropdown then
        templateName = UI.newTemplateDropdown:GetValue()
    end
    local ok, message = ProfilesAPI.CreateProfile(UI.newNameBox:GetText(), UI.newShortBox:GetText(), templateName)
    if ok then
        UI.currentProfile = message
        UI.selectedItemIndex = 1
        UI.selectedRuleName = nil
        if ProfilesAPI.UpdateBindingNames then
            ProfilesAPI.UpdateBindingNames()
        end
        RefreshProfileButtons()
        RefreshItemRows()
        ShowTab("items")
        PrintMessage("已创建Profile: " .. message, true)
    else
        PrintMessage(message or "创建Profile失败", true)
    end
end

local function RefreshProfileInfo()
    local profile = GetCurrentProfile()
    local itemCount = 0
    local ruleCount = 0
    local ruleName, aliasText, commands, keys, i
    if not profile then
        return
    end
    if profile.items then
        itemCount = table.getn(profile.items)
    end
    if profile.rules then
        for ruleName in pairs(profile.rules) do
            ruleCount = ruleCount + 1
        end
    end
    UI.profileInfoNameBox:SetText(UI.currentProfile or "")
    UI.profileInfoShortBox:SetText(profile.shortName or "")
    UI.profileInfoAliasesBox:SetText(JoinList(profile.aliases))
    UI.profileInfoCountText:SetText("消耗品 " .. itemCount .. " 项，效果覆盖 " .. ruleCount .. " 条")
    keys = {}
    table.insert(keys, UI.currentProfile or "")
    if profile.shortName and profile.shortName ~= "" then
        table.insert(keys, profile.shortName)
    end
    if profile.aliases then
        for i = 1, table.getn(profile.aliases) do
            aliasText = profile.aliases[i]
            if aliasText and aliasText ~= "" then
                table.insert(keys, aliasText)
            end
        end
    end
    commands = "检查命令:\n"
    for i = 1, table.getn(keys) do
        commands = commands .. "/cbc " .. keys[i] .. "\n"
    end
    commands = commands .. "吃药命令:\n"
    for i = 1, table.getn(keys) do
        commands = commands .. "/cbca " .. keys[i] .. "\n"
    end
    UI.profileInfoCommandText:SetText(commands)
end

local function SaveProfileInfo()
    local profile = GetCurrentProfile()
    local oldName = UI.currentProfile
    local newName = Trim(UI.profileInfoNameBox:GetText())
    local order = CheckBufferProfilesDB and CheckBufferProfilesDB.profileOrder or {}
    local i
    if not profile then
        return
    end
    if newName == "" then
        UI.profileInfoNameBox:SetText(oldName or "")
        PrintMessage("Profile名不能为空", true)
        return
    end
    if newName ~= oldName then
        if CheckBufferProfilesDB.profiles[newName] then
            UI.profileInfoNameBox:SetText(oldName or "")
            PrintMessage("Profile名已存在: " .. newName, true)
            return
        end
        CheckBufferProfilesDB.profiles[newName] = profile
        CheckBufferProfilesDB.profiles[oldName] = nil
        for i = 1, table.getn(order) do
            if order[i] == oldName then
                order[i] = newName
            end
        end
        UI.currentProfile = newName
    end
    profile.shortName = Trim(UI.profileInfoShortBox:GetText())
    profile.aliases = SplitList(UI.profileInfoAliasesBox:GetText())
    if ProfilesAPI.UpdateBindingNames then
        ProfilesAPI.UpdateBindingNames()
    end
    RefreshProfileButtons()
    RefreshProfileInfo()
end

function CheckBufferConfig_ShowItems()
    ShowTab("items")
end

function CheckBufferConfig_ShowRules()
    ShowTab("rules")
end

function CheckBufferConfig_ShowPreview()
    ShowTab("preview")
end

function CheckBufferConfig_ShowProfileInfo()
    ShowTab("profileinfo")
end

function CheckBufferConfig_ShowNewProfile()
    if UI.newNameBox then
        UI.newNameBox:SetText("")
    end
    if UI.newShortBox then
        UI.newShortBox:SetText("")
    end
    if UI.newTemplateDropdown then
        UI.newTemplateDropdown:SetValue("")
    end
    ShowTab("newprofile")
end

function CheckBufferConfig_ShowCopyProfile()
    if UI.newNameBox then
        UI.newNameBox:SetText("")
    end
    if UI.newShortBox then
        UI.newShortBox:SetText("")
    end
    if UI.newTemplateDropdown then
        UI.newTemplateDropdown:SetValue(UI.currentProfile or "")
    end
    ShowTab("newprofile")
end

function CheckBufferConfig_SelectProfileRow()
    if this and this.profileName then
        UI.currentProfile = this.profileName
        UI.selectedItemIndex = 1
        UI.selectedRuleName = nil
        RefreshProfileButtons()
        RefreshItemRows()
        ShowTab(UI.currentTab)
    end
end

function CheckBufferConfig_SelectItemRow()
    if this and this.itemIndex then
        UI.selectedItemIndex = this.itemIndex
        RefreshItemRows()
    end
end

function CheckBufferConfig_SelectRuleRow()
    if this and this.ruleName then
        UI.selectedRuleName = this.ruleName
        RefreshRuleRows()
    end
end

function CheckBufferConfig_ProfileScroll()
    if FauxScrollFrame_OnVerticalScroll then
        FauxScrollFrame_OnVerticalScroll(24, RefreshProfileButtons)
    end
end

function CheckBufferConfig_ItemScroll()
    if FauxScrollFrame_OnVerticalScroll then
        FauxScrollFrame_OnVerticalScroll(24, RefreshItemRows)
    end
end

function CheckBufferConfig_RuleScroll()
    if FauxScrollFrame_OnVerticalScroll then
        FauxScrollFrame_OnVerticalScroll(24, RefreshRuleRows)
    end
end

function CheckBufferConfig_SelectType(label)
    SelectItemType(GetTypeValueByLabel(label))
end

function CheckBufferConfig_BuffSameClick()
    if this and this:GetChecked() and UI.nameBox and UI.buffBox then
        UI.buffBox:SetText(UI.nameBox:GetText())
    end
    RefreshBuffBoxState()
    SaveSelectedItem()
end

function CheckBufferConfig_MoveItemUp()
    MoveItem(-1)
end

function CheckBufferConfig_MoveItemDown()
    MoveItem(1)
end

function CheckBufferConfig_SaveItem()
    SaveSelectedItem()
end

function CheckBufferConfig_AddItem()
    AddItem()
end

function CheckBufferConfig_DeleteItem()
    DeleteItem()
end

function CheckBufferConfig_SaveRule()
    SaveRule()
end

function CheckBufferConfig_AddRule()
    AddRule()
end

function CheckBufferConfig_DeleteRule()
    DeleteRule()
end

function CheckBufferConfig_AddRuleCandidate()
    AddRuleCandidate()
end

function CheckBufferConfig_ClearRuleCandidates()
    ClearRuleCandidates()
end

function CheckBufferConfig_AddRuleRequireItem()
    AddRuleRequireItem()
end

function CheckBufferConfig_ClearRuleRequireItems()
    ClearRuleRequireItems()
end

function CheckBufferConfig_CreateProfile()
    CreateProfileFromUI()
end

function CheckBufferConfig_SaveProfileInfo()
    SaveProfileInfo()
end

function CheckBufferConfig_CloseFrame()
    if UI.frame then
        UI.frame:Hide()
    end
end

function CheckBufferConfig_StartMoving()
    if this then
        this:StartMoving()
    end
end

function CheckBufferConfig_StopMoving()
    if this then
        this:StopMovingOrSizing()
    end
end

function CheckBufferConfig_DeleteProfile()
    local ok, message
    if not UI.currentProfile then
        return
    end
    ok, message = ProfilesAPI.DeleteProfile(UI.currentProfile)
    if ok then
        local names = ProfilesAPI.ListProfiles()
        UI.currentProfile = names[1]
        UI.selectedItemIndex = 1
        UI.selectedRuleName = nil
        if ProfilesAPI.UpdateBindingNames then
            ProfilesAPI.UpdateBindingNames()
        end
        RefreshProfileButtons()
        RefreshItemRows()
        ShowTab(UI.currentTab)
        PrintMessage("已删除Profile: " .. (message or ""), true)
    else
        PrintMessage(message or "删除Profile失败", true)
    end
end

function CheckBufferConfig_ResetDefaults()
    ProfilesAPI.ResetDefaults()
    UI.currentProfile = "法系DPS"
    UI.selectedItemIndex = 1
    UI.selectedRuleName = nil
    if ProfilesAPI.UpdateBindingNames then
        ProfilesAPI.UpdateBindingNames()
    end
    RefreshProfileButtons()
    RefreshItemRows()
    ShowTab("items")
    PrintMessage("已恢复默认Profile", true)
end

StaticPopupDialogs["CHECKBUFFER_RESET_DEFAULTS"] = {
    text = "恢复默认会删除所有自定义Profile，并还原为初始5个预设Profile。确定继续？",
    button1 = OKAY,
    button2 = CANCEL,
    OnAccept = function()
        CheckBufferConfig_ResetDefaults()
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1
}

function CheckBufferConfig_ShowResetDefaultsConfirm()
    StaticPopup_Show("CHECKBUFFER_RESET_DEFAULTS")
end

function CheckBufferConfig_GetRuleCandidates()
    if UI.ruleCandidateNames and table.getn(UI.ruleCandidateNames) > 0 then
        return UI.ruleCandidateNames
    end
    return GetCurrentItemNameOptions()
end

function CheckBufferConfig_SelectRequireCandidate(value)
    UI.ruleRequireCandidate = value
    if value and value ~= "" and not ContainsText(UI.ruleCandidateNames, value) then
        table.insert(UI.ruleCandidateNames, value)
    end
    RefreshRuleEditLists()
end

ShowTab = function(tabName)
    UI.currentTab = tabName
    SetSectionVisible("items", tabName == "items")
    SetSectionVisible("rules", tabName == "rules")
    SetSectionVisible("preview", tabName == "preview")
    SetSectionVisible("newprofile", tabName == "newprofile")
    SetSectionVisible("profileinfo", tabName == "profileinfo")
    if tabName == "rules" then
        RefreshRuleRows()
    elseif tabName == "preview" then
        RefreshPreview()
    elseif tabName == "profileinfo" then
        RefreshProfileInfo()
    end
end

local function CreateMinimapButton()
    if UI.minimapButton or not Minimap then
        return
    end
    local button = CreateFrame("Button", "CheckBufferMinimapButton", Minimap)
    UI.minimapButton = button
    button:SetWidth(31)
    button:SetHeight(31)
    button:SetFrameStrata("MEDIUM")
    button:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 52, -52)
    button:EnableMouse(true)
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetWidth(20)
    icon:SetHeight(20)
    icon:SetPoint("TOPLEFT", button, "TOPLEFT", 7, -6)
    icon:SetTexture(MINIMAP_ICON)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetWidth(53)
    border:SetHeight(53)
    border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    button:SetScript("OnClick", function()
        CheckBuffer_OpenConfigUI()
    end)
    button:SetScript("OnEnter", function()
        GameTooltip:SetOwner(button, "ANCHOR_LEFT")
        GameTooltip:AddLine("CheckBuffer")
        GameTooltip:AddLine("点击打开Profile配置", 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

local function CreateUI()
    if UI.frame then
        return
    end

    local frame = CreateFrame("Frame", "CheckBufferConfigFrame", UIParent)
    UI.frame = frame
    frame:SetWidth(980)
    frame:SetHeight(660)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = {left = 11, right = 12, top = 12, bottom = 11}
    })
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", CheckBufferConfig_StartMoving)
    frame:SetScript("OnDragStop", CheckBufferConfig_StopMoving)
    frame:Hide()

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -18)
    title:SetText("CheckBuffer Profile 配置")
    CreateButton(frame, "X", 930, -18, 28, 24, CheckBufferConfig_CloseFrame)

    local profilePanel = CreatePanel(frame, 22, -55, 190, 565)
    CreateLabel(profilePanel, "Profile列表", 20, -18, 140)
    UI.profileScroll = CreateFrame("ScrollFrame", "CheckBufferProfileScrollFrame", profilePanel, "FauxScrollFrameTemplate")
    UI.profileScroll:SetPoint("TOPLEFT", profilePanel, "TOPLEFT", 12, -50)
    UI.profileScroll:SetWidth(160)
    UI.profileScroll:SetHeight(380)
    UI.profileScroll:SetScript("OnVerticalScroll", CheckBufferConfig_ProfileScroll)
    local i, button
    for i = 1, 10 do
        button = CreateProfileRow(profilePanel, 16, -50 - (i - 1) * 24, 145, 24, CheckBufferConfig_SelectProfileRow)
        UI.profileButtons[i] = button
    end
    CreateButton(profilePanel, "新建", 16, -510, 48, 22, CheckBufferConfig_ShowNewProfile)
    CreateButton(profilePanel, "复制", 70, -510, 48, 22, CheckBufferConfig_ShowCopyProfile)
    CreateButton(profilePanel, "删除", 124, -510, 48, 22, CheckBufferConfig_DeleteProfile)
    CreateButton(profilePanel, "恢复默认", 16, -538, 80, 22, CheckBufferConfig_ShowResetDefaultsConfirm)

    CreateButton(frame, "消耗品列表", 230, -55, 110, 26, CheckBufferConfig_ShowItems)
    CreateButton(frame, "效果覆盖", 345, -55, 110, 26, CheckBufferConfig_ShowRules)
    CreateButton(frame, "生成预览", 460, -55, 110, 26, CheckBufferConfig_ShowPreview)
    CreateButton(frame, "Profile情报", 575, -55, 110, 26, CheckBufferConfig_ShowProfileInfo)

    local items = CreateFrame("Frame", nil, frame)
    items:SetPoint("TOPLEFT", frame, "TOPLEFT", 230, -90)
    items:SetWidth(720)
    items:SetHeight(540)
    UI.sections.items = items
    local listPanel = CreatePanel(items, 0, 0, 445, 530)
    local editPanel = CreatePanel(items, 455, 0, 265, 530)
    CreateLabel(listPanel, "消耗品列表（上移下移排序）", 14, -18, 300)
    CreateSmallText(listPanel, "类型", 23, -48, 90)
    CreateSmallText(listPanel, "物品名", 118, -48, 90)
    CreateSmallText(listPanel, "Buff名", 218, -48, 90)
    CreateSmallText(listPanel, "组", 303, -48, 80)
    UI.itemScroll = CreateFrame("ScrollFrame", "CheckBufferItemScrollFrame", listPanel, "FauxScrollFrameTemplate")
    UI.itemScroll:SetPoint("TOPLEFT", listPanel, "TOPLEFT", 12, -75)
    UI.itemScroll:SetWidth(395)
    UI.itemScroll:SetHeight(380)
    UI.itemScroll:SetScript("OnVerticalScroll", CheckBufferConfig_ItemScroll)
    for i = 1, 14 do
        button = CreateItemRow(listPanel, 15, -75 - (i - 1) * 24, 365, 24, CheckBufferConfig_SelectItemRow)
        UI.itemButtons[i] = button
    end
    CreateButton(listPanel, "新增行", 15, -485, 70, 22, CheckBufferConfig_AddItem)
    CreateButton(listPanel, "删除行", 90, -485, 70, 22, CheckBufferConfig_DeleteItem)
    CreateButton(listPanel, "上移", 165, -485, 60, 22, CheckBufferConfig_MoveItemUp)
    CreateButton(listPanel, "下移", 230, -485, 60, 22, CheckBufferConfig_MoveItemDown)

    CreateLabel(editPanel, "类型", 20, -38, 80)
    UI.typeDropdown = CreateDropdown(editPanel, 95, -34, 145, GetTypeLabelOptions, CheckBufferConfig_SelectType)
    CreateLabel(editPanel, "物品名", 20, -83, 80)
    UI.nameBox = CreateEditBox(editPanel, 95, -79, 145)
    CreateLabel(editPanel, "Buff名", 20, -128, 80)
    UI.buffBox = CreateEditBox(editPanel, 95, -124, 145)
    UI.buffSameCheck = CreateCheckBox(editPanel, "同物品名", 95, -148, CheckBufferConfig_BuffSameClick)
    CreateLabel(editPanel, "描述", 20, -185, 80)
    UI.effectBox = CreateEditBox(editPanel, 95, -181, 145)
    CreateLabel(editPanel, "组", 20, -230, 80)
    UI.ruleBox = CreateSmallText(editPanel, "", 95, -226, 145)
    UI.nameBox:SetScript("OnEditFocusLost", CheckBufferConfig_SaveItem)
    UI.buffBox:SetScript("OnEditFocusLost", CheckBufferConfig_SaveItem)
    UI.effectBox:SetScript("OnEditFocusLost", CheckBufferConfig_SaveItem)

    local rules = CreateFrame("Frame", nil, frame)
    rules:SetPoint("TOPLEFT", frame, "TOPLEFT", 230, -90)
    rules:SetWidth(720)
    rules:SetHeight(540)
    UI.sections.rules = rules
    local ruleListPanel = CreatePanel(rules, 0, 0, 445, 530)
    local ruleEditPanel = CreatePanel(rules, 455, 0, 265, 530)
    CreateLabel(ruleListPanel, "效果覆盖列表", 14, -18, 180)
    CreateSmallText(ruleListPanel, "组", 23, -48, 100)
    CreateSmallText(ruleListPanel, "会顶掉的效果", 135, -48, 140)
    CreateSmallText(ruleListPanel, "追加检查", 295, -48, 100)
    UI.ruleScroll = CreateFrame("ScrollFrame", "CheckBufferRuleScrollFrame", ruleListPanel, "FauxScrollFrameTemplate")
    UI.ruleScroll:SetPoint("TOPLEFT", ruleListPanel, "TOPLEFT", 12, -75)
    UI.ruleScroll:SetWidth(395)
    UI.ruleScroll:SetHeight(380)
    UI.ruleScroll:SetScript("OnVerticalScroll", CheckBufferConfig_RuleScroll)
    for i = 1, 14 do
        button = CreateRuleRow(ruleListPanel, 15, -75 - (i - 1) * 24, 365, 24, CheckBufferConfig_SelectRuleRow)
        UI.ruleButtons[i] = button
    end
    CreateButton(ruleListPanel, "新增组", 15, -485, 80, 22, CheckBufferConfig_AddRule)
    CreateButton(ruleListPanel, "删除组", 100, -485, 80, 22, CheckBufferConfig_DeleteRule)

    CreateLabel(ruleEditPanel, "组设置", 20, -38, 120)
    CreateLabel(ruleEditPanel, "组", 20, -83, 80)
    UI.ruleNameBox = CreateEditBox(ruleEditPanel, 95, -79, 145)
    CreateLabel(ruleEditPanel, "会顶掉的效果", 20, -128, 90)
    UI.ruleCandidateDropdown = CreateDropdown(ruleEditPanel, 95, -124, 145, GetCurrentItemNameOptions, nil)
    CreateButton(ruleEditPanel, "添加", 95, -151, 50, 22, CheckBufferConfig_AddRuleCandidate)
    CreateButton(ruleEditPanel, "清空", 150, -151, 50, 22, CheckBufferConfig_ClearRuleCandidates)
    UI.ruleCandidatesText = CreateSmallText(ruleEditPanel, "", 20, -180, 220)
    CreateLabel(ruleEditPanel, "吃到此效果", 20, -218, 80)
    UI.ruleRequireCandidateDropdown = CreateDropdown(ruleEditPanel, 95, -214, 145, CheckBufferConfig_GetRuleCandidates, CheckBufferConfig_SelectRequireCandidate)
    CreateLabel(ruleEditPanel, "追加检查", 20, -263, 80)
    UI.ruleRequireItemDropdown = CreateDropdown(ruleEditPanel, 95, -259, 145, GetCurrentItemNameOptions, nil)
    CreateButton(ruleEditPanel, "添加", 95, -286, 50, 22, CheckBufferConfig_AddRuleRequireItem)
    CreateButton(ruleEditPanel, "清空", 150, -286, 50, 22, CheckBufferConfig_ClearRuleRequireItems)
    UI.ruleRequireItemsText = CreateSmallText(ruleEditPanel, "", 20, -315, 220)
    UI.ruleNameBox:SetScript("OnEditFocusLost", CheckBufferConfig_SaveRule)
    CreateSmallText(ruleEditPanel, "只填会顶掉的效果，就是单纯覆盖关系。", 22, -395, 220)
    CreateSmallText(ruleEditPanel, "吃到此效果 + 追加检查，用于吃A后还要检查B。", 22, -420, 220)

    local preview = CreatePanel(frame, 230, -90, 720, 540)
    UI.sections.preview = preview
    CreateLabel(preview, "生成预览", 18, -18, 160)
    UI.previewText = preview:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    UI.previewText:SetPoint("TOPLEFT", preview, "TOPLEFT", 24, -55)
    UI.previewText:SetWidth(660)
    UI.previewText:SetJustifyH("LEFT")
    UI.previewText:SetJustifyV("TOP")

    local newprofile = CreatePanel(frame, 230, -90, 720, 540)
    UI.sections.newprofile = newprofile
    CreateLabel(newprofile, "新建Profile", 18, -18, 160)
    CreateLabel(newprofile, "Profile名", 24, -70, 100)
    UI.newNameBox = CreateEditBox(newprofile, 140, -66, 220)
    CreateLabel(newprofile, "缩略名", 24, -115, 100)
    UI.newShortBox = CreateEditBox(newprofile, 140, -111, 220)
    CreateLabel(newprofile, "基于模板", 24, -160, 100)
    UI.newTemplateDropdown = CreateDropdown(newprofile, 140, -156, 220, GetProfileNameOptions, nil)
    UI.newTemplateDropdown:SetValue("")
    CreateButton(newprofile, "创建Profile", 140, -205, 110, 24, CheckBufferConfig_CreateProfile)
    CreateSmallText(newprofile, "创建后复制模板的消耗品和效果覆盖；缩略名必须唯一。", 24, -260, 520)

    local profileinfo = CreatePanel(frame, 230, -90, 720, 540)
    UI.sections.profileinfo = profileinfo
    CreateLabel(profileinfo, "当前Profile情报", 18, -18, 180)
    CreateLabel(profileinfo, "Profile名", 24, -70, 100)
    UI.profileInfoNameBox = CreateEditBox(profileinfo, 140, -66, 220)
    CreateLabel(profileinfo, "缩略名", 24, -115, 100)
    UI.profileInfoShortBox = CreateEditBox(profileinfo, 140, -111, 220)
    CreateLabel(profileinfo, "命令别名", 24, -160, 100)
    UI.profileInfoAliasesBox = CreateEditBox(profileinfo, 140, -156, 360)
    CreateLabel(profileinfo, "调用命令", 24, -205, 100)
    UI.profileInfoCommandText = profileinfo:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    UI.profileInfoCommandText:SetPoint("TOPLEFT", profileinfo, "TOPLEFT", 140, -205)
    UI.profileInfoCommandText:SetWidth(500)
    UI.profileInfoCommandText:SetJustifyH("LEFT")
    UI.profileInfoCountText = profileinfo:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    UI.profileInfoCountText:SetPoint("TOPLEFT", profileinfo, "TOPLEFT", 140, -345)
    UI.profileInfoCountText:SetWidth(360)
    UI.profileInfoCountText:SetJustifyH("LEFT")
    UI.profileInfoNameBox:SetScript("OnEditFocusLost", CheckBufferConfig_SaveProfileInfo)
    UI.profileInfoShortBox:SetScript("OnEditFocusLost", CheckBufferConfig_SaveProfileInfo)
    UI.profileInfoAliasesBox:SetScript("OnEditFocusLost", CheckBufferConfig_SaveProfileInfo)
    CreateSmallText(profileinfo, "缩略名只保留一个，例如 t、h、p、f、m；aliases 保存在 profile.aliases，可填多个，用逗号分隔。", 24, -390, 620)

    RefreshProfileButtons()
    RefreshItemRows()
    ShowTab("items")
end

function CheckBuffer_OpenConfigUI()
    CreateMinimapButton()
    CreateUI()
    RefreshProfileButtons()
    RefreshItemRows()
    ShowTab(UI.currentTab)
    UI.frame:Show()
end

SLASH_CHECKBUFFER_CONFIG1 = "/cbconfig"
SlashCmdList["CHECKBUFFER_CONFIG"] = function(msg)
    CheckBuffer_OpenConfigUI()
end

CreateMinimapButton()
PrintMessage("Profile配置界面已加载，使用 /cbconfig 打开", true)
