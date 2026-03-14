-- ============================================================
-- HAUPTFENSTER SETUP
-- ============================================================
local RO_Frame = CreateFrame("Frame", "RaidOrganizerMain", UIParent, "BackdropTemplate")
RO_Frame:SetSize(280, 300) -- Kompakt auf 300px gekürzt
RO_Frame:SetPoint("CENTER")
RO_Frame:SetFrameStrata("HIGH")

RO_Frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 16, insets = {left=5, right=5, top=5, bottom=5}
})
-- RO_Frame:SetBackdropColor(0, 0, 0, 0.5)
RO_Frame:SetFrameLevel(1)

-- FENSTER BEWEGLICH MACHEN
RO_Frame:SetMovable(true)
RO_Frame:EnableMouse(true)
RO_Frame:RegisterForDrag("LeftButton")
RO_Frame:SetScript("OnDragStart", RO_Frame.StartMoving)
RO_Frame:SetScript("OnDragStop", RO_Frame.StopMovingOrSizing)

local title = RO_Frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", 0, -18)
title:SetText("Raid Organizer v1.7")

-- ============================================================
-- STATUS VARIABLEN
-- ============================================================
local isRunning = false
local timer = 55
local maxPlayers = 5
local adType = "LFM MS Leveling"
local recentWhispers = {}

-- ============================================================
-- UI HELPER FUNKTIONEN
-- ============================================================

-- Kleine Trennlinie für visuelle Struktur
local function CreateSeparator(y)
    local line = RO_Frame:CreateTexture(nil, "ARTWORK")
    line:SetSize(220, 1)
    line:SetPoint("TOP", 0, y)
    line:SetColorTexture(1, 1, 1, 0.15)
end

-- Erstellt saubere Eingabefelder
local function CreateRoleInput(label, y)
    local txt = RO_Frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    txt:SetPoint("LEFT", RO_Frame, "TOPLEFT", 35, y)
    txt:SetText(label)

    local eb = CreateFrame("EditBox", nil, RO_Frame, "BackdropTemplate")
    eb:SetSize(35, 20) -- Etwas schmaler für bessere Optik
    -- POSITION: 165px von links rückt das Ganze schön in die Mitte
    eb:SetPoint("LEFT", RO_Frame, "TOPLEFT", 165, y) 
    
    eb:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    eb:SetBackdropColor(0, 0, 0, 0.8)
    eb:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    eb:SetFontObject("ChatFontNormal")
    eb:SetJustifyH("CENTER")
    eb:SetAutoFocus(false)
    eb:SetNumeric(true)

    -- Minus Button links neben die EditBox
    local btnMinus = CreateFrame("Button", nil, RO_Frame, "UIPanelButtonTemplate")
    btnMinus:SetSize(22, 22) -- Etwas größer für bessere Klickbarkeit
    btnMinus:SetPoint("RIGHT", eb, "LEFT", -5, 0)
    btnMinus:SetText("-")
    btnMinus:SetScript("OnClick", function()
        local val = tonumber(eb:GetText()) or 0
        if val > 0 then eb:SetText(val - 1) end
    end)

    -- Plus Button rechts neben die EditBox
    local btnPlus = CreateFrame("Button", nil, RO_Frame, "UIPanelButtonTemplate")
    btnPlus:SetSize(22, 22)
    btnPlus:SetPoint("LEFT", eb, "RIGHT", 5, 0)
    btnPlus:SetText("+")
    btnPlus:SetScript("OnClick", function()
        local val = tonumber(eb:GetText()) or 0
        eb:SetText(val + 1)
    end)

    return eb
end

-- Erstellt Radio-Buttons
local function CreateRadio(label, x, y, group, onClick)
    local name = "RO_Radio_" .. label:gsub("%W", "")
    local cb = CreateFrame("CheckButton", name, RO_Frame, "ChatConfigCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", x, y)
    cb:SetSize(22, 22)
    
    local text = _G[name .. "Text"]
    text:SetText(label)
    text:SetFontObject("GameFontHighlightSmall")
    text:ClearAllPoints()
    text:SetPoint("LEFT", cb, "RIGHT", 4, 1)
    
    cb:SetHitRectInsets(0, -50, 0, 0) 
    cb:SetScript("OnClick", function(self)
        for _, btn in ipairs(group) do btn:SetChecked(false) end
        self:SetChecked(true)
        onClick()
    end)
    table.insert(group, cb)
    return cb
end

-- ============================================================
-- UI ELEMENTE ERSTELLEN
-- ============================================================

local tankInput = CreateRoleInput("Tanks needed:", -60)
local healInput = CreateRoleInput("Heals needed:", -90)
local dpsInput  = CreateRoleInput("DPS needed:", -120)

-- Gruppe: Raid Size
CreateSeparator(-145)
local groupRadios = {}
local r5 = CreateRadio("5-man", 30, -155, groupRadios, function()
    maxPlayers = 5; tankInput:SetText("1"); healInput:SetText("1"); dpsInput:SetText("3")
end)
r5:SetChecked(true)
CreateRadio("10-man", 105, -155, groupRadios, function()
    maxPlayers = 10; tankInput:SetText("2"); healInput:SetText("2"); dpsInput:SetText("6")
end)
CreateRadio("15-man", 185, -155, groupRadios, function()
    maxPlayers = 15; tankInput:SetText("2"); healInput:SetText("3"); dpsInput:SetText("10")
end)

-- Gruppe: Activity
CreateSeparator(-185)
local textRadios = {}
local rLev = CreateRadio("Leveling", 30, -195, textRadios, function() adType = "LFM MS Leveling" end)
rLev:SetChecked(true)
CreateRadio("Gold Farm", 140, -195, textRadios, function() adType = "LFM MS Gold" end)

-- Start Button
local btn = CreateFrame("Button", "RO_MainBtn", RO_Frame, "GameMenuButtonTemplate")
btn:SetPoint("TOP", RO_Frame, "TOP", 0, -240) 
btn:SetSize(140, 30)
btn:SetText("Start Search")

-- ============================================================
-- LOGIK FUNKTIONEN
-- ============================================================

local function RO_HandleWhisper(text, sender)
    if not isRunning then return end
    if UnitInParty(sender) or UnitInRaid(sender) or sender == UnitName("player") then return end

    local msg = text:lower()
    local roleFound = nil
    local inputField = nil

    -- Rollen-Erkennung
    if msg:find("inv t") or msg:find("tank") then
        roleFound = "Tank"
        inputField = tankInput
    elseif msg:find("inv h") or msg:find("heal") then
        roleFound = "Healer"
        inputField = healInput
    elseif msg:find("inv d") or msg:find("dps") or msg:find("dd") then
        roleFound = "DPS"
        inputField = dpsInput
    end

    if roleFound then
        local current = tonumber(inputField:GetText()) or 0
        if current > 0 then 
            inputField:SetText(current - 1)
            InviteUnit(sender)
            recentWhispers[sender] = nil 
            print("|cff00ff00RO: Invited " .. sender .. " (" .. roleFound .. ")|r")
        else
            if not recentWhispers[sender] then
                SendChatMessage("RO: Sorry, we are already full on " .. roleFound .. "s! Good luck with your search.", "WHISPER", nil, sender)
                recentWhispers[sender] = true 
                print("|cffff0000RO: Rejected " .. sender .. " (Full on " .. roleFound .. ")|r")
            end
        end
    elseif (msg:find("inv") or msg:find("invite")) and not recentWhispers[sender] then
        SendChatMessage("RO: Please whisper 'inv T', 'inv H' or 'inv D' for auto-invite!", "WHISPER", nil, sender)
        recentWhispers[sender] = true
    end
end

local function PostLFM()
    if GetNumGroupMembers() >= maxPlayers then
        isRunning = false
        btn:SetText("Start Search")
        print("|cffff0000RO: Group full! Search stopped.|r")
        return
    end

    local tanksNeeded = tonumber(tankInput:GetText()) or 0
    local healsNeeded = tonumber(healInput:GetText()) or 0
    local dpsNeeded = tonumber(dpsInput:GetText()) or 0

    if tanksNeeded > 0 or healsNeeded > 0 or dpsNeeded > 0 then
        local msg = adType .. ": "
        if tanksNeeded > 0 then msg = msg .. tanksNeeded .. "x Tank " end
        if healsNeeded > 0 then msg = msg .. healsNeeded .. "x Heal " end
        if dpsNeeded > 0 then msg = msg .. dpsNeeded .. "x DPS " end
        msg = msg .. "- Whisper 'inv T' for Tank, 'inv H' for Heal and 'inv D' for Damage."

        for i = 1, 20 do
            local id, name = GetChannelName(i)
            if name then
                local lowName = name:lower()
                if lowName:find("newcomers") or lowName:find("ascension") or lowName:find("suche") or lowName:find("general") then
                    SendChatMessage(msg, "CHANNEL", nil, id)
                end
            end
        end
    else
        isRunning = false
        btn:SetText("Start Search")
        print("|cff00ff00RO: All slots filled.|r")
    end
end

-- ============================================================
-- SCRIPTS & EVENTS
-- ============================================================

btn:SetScript("OnClick", function(self)
    isRunning = not isRunning
    if isRunning then
        self:SetText("Stop Search")
        print("|cff00ff00RO: Searching...|r")
        timer = 58 
        recentWhispers = {}
    else
        self:SetText("Start Search")
        print("|cffff0000RO: Paused.|r")
    end
end)

RO_Frame:SetScript("OnUpdate", function(self, elapsed)
    if not isRunning then return end
    timer = timer + elapsed
    if timer >= 60 then
        PostLFM()
        timer = 0
    end
end)

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("CHAT_MSG_WHISPER")
eventFrame:SetScript("OnEvent", function(self, event, text, sender)
    RO_HandleWhisper(text, sender)
end)

-- SLASH COMMAND
SLASH_RAIDORGANIZER1 = "/ro"
SlashCmdList["RAIDORGANIZER"] = function()
    if RO_Frame:IsShown() then RO_Frame:Hide() else RO_Frame:Show() end
end

-- Init Standardwerte
tankInput:SetText("1")
healInput:SetText("1")
dpsInput:SetText("3")
print("|cff69ccf0RaidOrganizer v1.7 loaded. Use /ro to toggle.|r")
