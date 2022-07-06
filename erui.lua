local _G = _G

local me = UnitName('player')
local _, myClass = UnitClass('player')

myClass = string.lower(myClass)

local ctrltime = 0
local alttime = 0
local ctrlalttime = 0
local tradedelay = 0
local tradestatus = false
local delayaction = 0

local CLASS_COLORS = {
    ["warrior"] = { r = 0.78, g = 0.61, b = 0.43, colorStr = "ffc79c6e" },
    ["mage"] = { r = 0.41, g = 0.8, b = 0.94, colorStr = "ff69ccf0" },
    ["rogue"] = { r = 1, g = 0.96, b = 0.41, colorStr = "fffff569" },
    ["druid"] = { r = 1, g = 0.49, b = 0.04, colorStr = "ffff7d0a" },
    ["hunter"] = { r = 0.67, g = 0.83, b = 0.45, colorStr = "ffabd473" },
    ["shaman"] = { r = 0.14, g = 0.35, b = 1.0, colorStr = "ff0070de" },
    ["priest"] = { r = 1, g = 1, b = 1, colorStr = "ffffffff" },
    ["warlock"] = { r = 0.58, g = 0.51, b = 0.79, colorStr = "ff9482c9" },
    ["paladin"] = { r = 0.96, g = 0.55, b = 0.73, colorStr = "fff58cba" },
    ["deathknight"] = { r = 0.77, g = 0.12, b = 0.23, colorStr = "ffC41F3B" }
}

ERui = CreateFrame("Frame")
ERui:Hide()
ERui:RegisterEvent("ADDON_LOADED")
ERui:RegisterEvent("LOOT_OPENED")
ERui:RegisterEvent("LOOT_CLOSED")
ERui:RegisterEvent("LOOT_SLOT_CLEARED")
ERui:RegisterEvent("CHAT_MSG_SYSTEM")
ERui:RegisterEvent("UPDATE_MASTER_LOOT_LIST")
ERui:RegisterEvent("TRADE_SHOW")
ERui:RegisterEvent("TRADE_CLOSED")

ERui.MSRollText = '|c' .. CLASS_COLORS['shaman'].colorStr .. 'MS Roll'
ERui.OSRollText = '|c' .. CLASS_COLORS['rogue'].colorStr .. 'OS Roll'
ERui.RandomText = '|c' .. CLASS_COLORS['druid'].colorStr .. 'Random'
ERui.index_to_name = {}
ERui.name_to_index = {}
ERui.classes_in_raid = {} -- [global class]=localized class for display
ERui.players_in_class = {}
ERui.myIndex = 0
ERui.lootFrames = {}

ERui:SetScript("OnEvent", function()
    if event then
        if event == "ADDON_LOADED" and arg1 == 'erui' then
            ERui:Show()
            ERui:Init()
            return
        end
        if event == "TRADE_SHOW" then
            tradestatus = true
            return
        end
        if event == "TRADE_CLOSED" then
            tradedelay = GetTime() + 1
            tradestatus = false
        end
        if event == 'CHAT_MSG_SYSTEM' and ERui.RollTimer.rollsOpen then
            ERui.RollTimer:CheckRolls(arg1)
            return
        end
        if event == "LOOT_OPENED" and GetNumRaidMembers() > 0 then
            ERui.LootOpenDelay:Show()
            return
        end
        if event == "LOOT_SLOT_CLEARED" and GetNumRaidMembers() > 0 then
            if not TalcVoteFrame:IsVisible() then
                ERui.LootOpenDelay:Show()
            end
            return
        end
        if event == "LOOT_CLOSED" and GetNumRaidMembers() > 0 then
            ErUILootFrame:Hide()
            return
        end
    end
end)
ERui:SetScript('OnShow', function()
    this.startTime = GetTime()
end)
ERui:SetScript('OnUpdate', function()
    local gt = GetTime() * 1000
    local st = (this.startTime + 10) * 1000
    if gt >= st then
        this.startTime = GetTime()
        ERui:Init()
    end
end)

function ERui.ucFirst(str)
    return string.upper(string.sub(str, 1, 1)) .. string.sub(str, 2, string.len(str))
end

function ERui:ColorName(name)

    for i = 0, 40 do
        if GetRaidRosterInfo(i) then
            local n = GetRaidRosterInfo(i)
            if name == n then
                local _, unitClass = UnitClass('raid' .. i) --standard
                return '|c' .. CLASS_COLORS[string.lower(unitClass)].colorStr .. n
            end

        end
    end

end

function ERui:RaidMenu(id)
    ERui.RollTimer.slot = id
    ToggleDropDownMenu(1, nil, ERLootDropdown, "cursor", 2, 3)
end

function ERui:LootOpened()

    if GetLootMethod() ~= 'master' or GetNumLootItems() == 0 then
        ErUILootFrame:Hide()
        return false
    end

    self.index_to_name = {}
    self.name_to_index = {}
    self.classes_in_raid = {} -- [global class]=localized class for display
    self.players_in_class = {}
    self.myIndex = 0

    for i = 1, 40 do
        local candidate = GetMasterLootCandidate(i)
        if candidate then
            self.index_to_name[i] = candidate
            self.name_to_index[candidate] = i
            if candidate == me then
                self.myIndex = i
            end

            local class = 'priest'
            for j = 1, 40 do
                if UnitName('raid' .. j) then
                    if UnitName('raid' .. j) == candidate then
                        local _, c = UnitClass('raid' .. j)
                        class = string.lower(c)
                    end
                end
            end
            self.classes_in_raid[class] = class
            if not self.players_in_class[class] then
                self.players_in_class[class] = {}
            end
            table.insert(self.players_in_class[class], candidate)
        end
    end

    for i = 0, 15 do
        if _G["ERuiLootFrame_" .. i] then
            _G["ERuiLootFrame_" .. i]:Hide()
        end
    end

    for id = 0, GetNumLootItems() do
        if GetLootSlotInfo(id) and GetLootSlotLink(id) then
            local _, _, itemLink = string.find(GetLootSlotLink(id), "(item:%d+:%d+:%d+:%d+)");
            local name, link, _, _, _, _, _, _, _, tex = GetItemInfo(itemLink)

            if not self.lootFrames[id] then
                self.lootFrames[id] = CreateFrame("Frame", "ERuiLootFrame_" .. id, ErUILootFrame, "ERuiItemTemplate")
            end

            local frame = "ERuiLootFrame_" .. id

            self:addButtonOnEnterTooltip(_G[frame .. 'ItemIcon'], GetLootSlotLink(id))

            _G[frame]:SetPoint("LEFT", ErUILootFrame, "TOPLEFT", 2, -10 - 33 * id)

            _G[frame .. 'ItemName']:SetText(GetLootSlotLink(id))
            _G[frame .. 'ItemIcon']:SetNormalTexture(tex)

            _G[frame .. 'MSRoll']:SetID(id)
            _G[frame .. 'MSRoll']:SetText(self.MSRollText)
            _G[frame .. 'MSRoll']:SetNormalTexture(0, 1, 0, 1)
            _G[frame .. 'OSRoll']:SetID(id)
            _G[frame .. 'OSRoll']:SetText(self.OSRollText)
            _G[frame .. 'Random']:SetID(id)
            _G[frame .. 'Random']:SetText(self.RandomText)
            _G[frame .. 'GiveTo']:SetID(id)

            _G[frame .. 'ER']:SetText('|c' .. CLASS_COLORS[myClass].colorStr .. "ME")
            _G[frame .. 'ER']:SetID(id)

            _G[frame]:Show()

            ErUILootFrame:SetHeight(33 * id + 12 + 17)

        end
    end

    ErUILootFrame:Show()

    UIDropDownMenu_Initialize(ERLootDropdown, RaidMenu_Initialize, "MENU");
end

function ERui:Init()
    FramerateLabel:SetPoint("BOTTOM", WorldFrame, "BOTTOM", 0, 120)
    ErUIBGBG:SetTexture('')
    ErUIBGBG:SetTexture('Interface\\addons\\erui\\images\\bg')
    ErUIBGBG:SetAlpha(0.4)
end

function ERui:RandomItem(slot)

    if not slot then
        return
    end

    local _, _, itemLink = string.find(GetLootSlotLink(slot), "(item:%d+:%d+:%d+:%d+)");
    local _, _, q = GetItemInfo(itemLink)

    if q >= 3 then
        SendChatMessage('Random rolling ' .. GetLootSlotLink(slot), "RAID_WARNING")
    end

    local candidates = {}
    for i = 0, 40 do
        local candidate = GetMasterLootCandidate(i)
        if candidate then
            candidates[table.getn(candidates) + 1] = {
                name = candidate,
                index = i
            }
        end
    end

    local randomWinner = math.random(1, table.getn(candidates))

    if candidates[randomWinner] then
        GiveMasterLoot(slot, candidates[randomWinner].index)
        _G['ERuiLootFrame_' .. slot .. 'Random']:SetText(candidates[randomWinner].name)
    else
        print("random winner index error")
    end

end

function ERui:RaidRoll(id, spec)

    self.RollTimer.slot = id

    if spec == 'ms' then
        if _G['ERuiLootFrame_' .. self.RollTimer.slot .. 'MSRoll']:GetText() == 'TIE'
                or _G['ERuiLootFrame_' .. self.RollTimer.slot .. 'OSRoll']:GetText() == 'TIE' then
            return
        end
        if _G['ERuiLootFrame_' .. self.RollTimer.slot .. 'MSRoll']:GetText() ~= self.MSRollText then
            ER_GiveTo(nil, self.RollTimer.slot, _G['ERuiLootFrame_' .. self.RollTimer.slot .. 'MSRoll']:GetText())
            return
        end

    end
    if spec == 'os' then
        if _G['ERuiLootFrame_' .. self.RollTimer.slot .. 'MSRoll']:GetText() == 'TIE'
                or _G['ERuiLootFrame_' .. self.RollTimer.slot .. 'OSRoll']:GetText() == 'TIE' then
            return
        end

        if _G['ERuiLootFrame_' .. self.RollTimer.slot .. 'OSRoll']:GetText() ~= self.OSRollText then
            ER_GiveTo(nil, self.RollTimer.slot, _G['ERuiLootFrame_' .. self.RollTimer.slot .. 'OSRoll']:GetText())
            return
        end
    end

    if self.RollTimer.rollsOpen then
        SendChatMessage("ROLLS Canceled ! Restarting.", self.RollTimer.timerChannel);
    end

    self.RollTimer:Hide()

    self.RollTimer.T = 1 --start
    self.RollTimer.C = self.RollTimer.secondsToRoll --count to

    self.RollTimer.rollers = {}
    self.RollTimer.maxRoll = 0

    self.RollTimer.offspecRoll = spec == 'os'

    if ERui.RollTimer.offspecRoll then
        SendChatMessage("OFFSPEC ROLL " .. GetLootSlotLink(id) .. " " .. self.RollTimer.secondsToRoll .. " Seconds", self.RollTimer.timerChannel);
    else
        SendChatMessage("ROLL " .. GetLootSlotLink(id) .. " " .. self.RollTimer.secondsToRoll .. " Seconds", self.RollTimer.timerChannel);
    end

    self.RollTimer:Show()
    self.RollTimer.rollsOpen = true

end

function ERui:addButtonOnEnterTooltip(frame, itemLink)

    if string.find(itemLink, "|", 1, true) then
        local ex = self.split("|", itemLink)

        if not ex[3] then
            return
        end

        frame:SetScript("OnEnter", function(self)
            ERTooltip:SetOwner(this, "ANCHOR_RIGHT", -(this:GetWidth() / 4), -(this:GetHeight() / 4));
            ERTooltip:SetHyperlink(string.sub(ex[3], 2, string.len(ex[3])));
            ERTooltip:Show();
        end)
    else
        frame:SetScript("OnEnter", function(self)
            ERTooltip:SetOwner(this, "ANCHOR_RIGHT", -(this:GetWidth() / 4), -(this:GetHeight() / 4));
            ERTooltip:SetHyperlink(itemLink);
            ERTooltip:Show();
        end)
    end
    frame:SetScript("OnLeave", function(self)
        ERTooltip:Hide();
    end)
end

function ERui:SendToTalc()
    ErUILootFrame:Hide()
    TalcVoteFrame:Show()
end

ERui.LootOpenDelay = CreateFrame("Frame")
ERui.LootOpenDelay:Hide()
ERui.LootOpenDelay:SetScript('OnShow', function()
    this.startTime = GetTime()
end)
ERui.LootOpenDelay:SetScript('OnUpdate', function()
    local plus = 0.6
    local gt = GetTime() * 1000
    local st = (this.startTime + plus) * 1000
    if gt >= st then
        ERui:LootOpened()
        this:Hide()
    end
end)

ERui.split = function(delimiter, str)
    local result = {}
    local from = 1
    local delim_from, delim_to = string.find(str, delimiter, from)
    while delim_from do
        table.insert(result, string.sub(str, from, delim_from - 1))
        from = delim_to + 1
        delim_from, delim_to = string.find(str, delimiter, from)
    end
    table.insert(result, string.sub(str, from))
    return result
end

ERui.RollTimer = CreateFrame("Frame")
ERui.RollTimer:Hide()
ERui.RollTimer.rollsOpen = false
ERui.RollTimer.secondsToRoll = 10
ERui.RollTimer.timerChannel = "RAID_WARNING"
ERui.RollTimer.rollers = {} --list of people who rolled
ERui.RollTimer.maxRoll = 0 --max recorded roll
ERui.RollTimer.slot = -1 --max recorded roll
ERui.RollTimer.T = 1
ERui.RollTimer.C = ERui.RollTimer.secondsToRoll
ERui.RollTimer:SetScript("OnShow", function()
    this.startTime = math.floor(GetTime())
end)
ERui.RollTimer:SetScript("OnUpdate", function()
    if math.floor(GetTime()) == math.floor(this.startTime) + 1 then
        if this.T ~= this.secondsToRoll + 1 then
            SendChatMessage(" - " .. (this.C - this.T + 1) .. " -", "RAID")
            if this.offspecRoll then
                _G['ERuiLootFrame_' .. this.slot .. 'OSRoll']:SetText(this.C - this.T + 1)
            else
                _G['ERuiLootFrame_' .. this.slot .. 'MSRoll']:SetText(this.C - this.T + 1)
            end
        end
        this:Hide()
        if this.T < this.C + 1 then
            this.T = this.T + 1
            this:Show()
        elseif this.T == this.secondsToRoll + 1 then
            SendChatMessage(" - Closed -", this.timerChannel)
            this:Hide()
            this.T = 1
            this.rollsOpen = false

            if this.maxRoll ~= 0 then
                local winners = {}
                local winnersNo = 0;

                for index, pr in next, this.rollers do
                    if tonumber(pr) == tonumber(this.maxRoll) then
                        winners[index] = pr
                        winnersNo = winnersNo + 1
                    end
                end
                if winnersNo == 1 then
                    for index, pr in next, winners do
                        local nice = ""
                        if (pr == 69) then
                            nice = "(nice)"
                        end
                        if (pr == 1) then
                            nice = "(oof)"
                        end
                        if (pr == 100) then
                            nice = "(yeet)"
                        end
                        SendChatMessage("Highest roll by " .. index .. " with " .. pr .. nice, this.timerChannel)

                        if this.offspecRoll then
                            _G['ERuiLootFrame_' .. this.slot .. 'OSRoll']:SetText(ERui:ColorName(index))
                        else
                            _G['ERuiLootFrame_' .. this.slot .. 'MSRoll']:SetText(ERui:ColorName(index))
                        end
                    end
                else
                    --tie
                    local tieRollers = ""
                    local tieRoll = 0
                    for index, pr in next, winners do
                        tieRollers = tieRollers .. " " .. index
                        tieRoll = pr
                    end
                    local nice = ""
                    if (tieRoll == 69) then
                        nice = "(nice)"
                    end
                    if (tieRoll == 1) then
                        nice = "(oof)"
                    end
                    if (tieRoll == 100) then
                        nice = "(yeet)"
                    end
                    SendChatMessage("LootRes: Highest roll by " .. tieRollers .. " with " .. tieRoll .. nice .. " TIE", this.timerChannel)
                    if this.offspecRoll then
                        _G['ERuiLootFrame_' .. this.slot .. 'OSRoll']:SetText('TIE')
                    else
                        _G['ERuiLootFrame_' .. this.slot .. 'MSRoll']:SetText('TIE')
                    end
                end
            else
                SendChatMessage("No rolls recorded.", this.timerChannel)
            end

            this.maxRoll = 0
            this.rollers = {}

        end
    end
end)
function ERui.RollTimer:CheckRolls(arg)
    if string.find(arg, "rolls", 1) and string.find(arg, "(1-100)") then
        local r = ERui.split(" ", arg)

        if not self.rollers[r[1]] then
            self.rollers[r[1]] = tonumber(r[3])
            if tonumber(r[3]) > tonumber(self.maxRoll) then
                self.maxRoll = tonumber(r[3])
            end
        end
    end
end

SLASH_ERUI1 = "/erui"
SlashCmdList["ERUI"] = function(cmd)
    if cmd then
        ERui:Init()
    end
end

function ER_GiveTo(_, lootId, toNameOrIndex)

    if toNameOrIndex == 'me' then
        toNameOrIndex = ERui.myIndex
    end

    if tonumber(toNameOrIndex) then
        GiveMasterLoot(lootId, toNameOrIndex)
        return
    end
    for i = 1, 40 do
        local candidate = GetMasterLootCandidate(i)
        if candidate then
            if string.find(toNameOrIndex, '|c', 1, true) then
                toNameOrIndex = string.sub(toNameOrIndex, 11, string.len(toNameOrIndex)) --remove color
            end
            if candidate == toNameOrIndex then
                GiveMasterLoot(lootId, i)
                return
            end
        end
    end
end

function ER_BuildRaidMenu(level)

    if level == 1 then

        for class, data in next, CLASS_COLORS do
            if ERui.classes_in_raid[class] then
                local info = {}
                info.text = "|c" .. data.colorStr .. ERui.ucFirst(class)
                info.textR, info.textG, info.textB = .7, .7, .7
                --if class and CLASS_COLORS[class] then
                --    print(CLASS_COLORS[class].r)
                --    info.textR = CLASS_COLORS[class].r
                --    info.textG = CLASS_COLORS[class].g
                --    info.textB = CLASS_COLORS[class].b
                --end
                info.textHeight = 12
                info.hasArrow = 1
                info.notCheckable = 1
                info.value = class
                info.func = nil
                UIDropDownMenu_AddButton(info)
            end
        end

    elseif level == 2 then
        -- players
        local players = ERui.players_in_class[UIDROPDOWNMENU_MENU_VALUE]
        if players and next(players) then
            table.sort(players)
            for _, candidate in ipairs(players) do
                local info = {}
                info.text = "|c" .. CLASS_COLORS[UIDROPDOWNMENU_MENU_VALUE].colorStr .. candidate
                info.textR, info.textG, info.textB = .7, .7, .7
                if UIDROPDOWNMENU_MENU_VALUE and CLASS_COLORS[UIDROPDOWNMENU_MENU_VALUE] then
                    info.textR = CLASS_COLORS[UIDROPDOWNMENU_MENU_VALUE].r
                    info.textG = CLASS_COLORS[UIDROPDOWNMENU_MENU_VALUE].g
                    info.textB = CLASS_COLORS[UIDROPDOWNMENU_MENU_VALUE].b
                end
                info.textHeight = 12
                info.arg1 = ERui.RollTimer.slot
                info.arg2 = ERui.name_to_index[candidate]
                info.func = ER_GiveTo
                UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL)
            end
        end
    end
end

function RaidMenu_Initialize(level)
    ER_BuildRaidMenu(UIDROPDOWNMENU_MENU_LEVEL)
end

function ERui_OnUpdate()

    local current_time = GetTime();
    local ctrlstatus = IsControlKeyDown();
    local altstatus = IsAltKeyDown();

    if altstatus and not ctrlstatus and current_time > alttime then
        alttime = current_time + 0.75
    elseif not altstatus and ctrlstatus and current_time > ctrltime then
        ctrltime = current_time + 0.75
    elseif not altstatus and not ctrlstatus or altstatus and ctrlstatus then
        ctrltime = 0
        alttime = 0
    end
    if ctrlstatus and altstatus and current_time > ctrlalttime then
        ctrlalttime = current_time + 0.75
    end

    if ctrlstatus and altstatus and current_time > delayaction then
        if tradestatus then
            AcceptTrade();
        end
    end

    if ctrlstatus and altstatus then
        for i = 1, STATICPOPUP_NUMDIALOGS do
            local frame = getglobal("StaticPopup" .. i)
            if frame:IsShown() then
                --DEFAULT_CHAT_FRAME:AddMessage(frame.which)
                if frame.which ~= "CONFIRM_SUMMON" and frame.which ~= "CONFIRM_BATTLEFIELD_ENTRY" and frame.which ~= "CAMP" and frame.which ~= "AREA_SPIRIT_HEAL" then
                    --and release and
                    getglobal("StaticPopup" .. i .. "Button1"):Click();
                end
            end
        end
    end

end