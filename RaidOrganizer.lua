-- ============================================================
-- HAUPTFENSTER SETUP
-- ============================================================
local RO_Frame = CreateFrame("Frame", "RaidOrganizerMain", UIParent, "BackdropTemplate")
RO_Frame:SetSize(280, 320)
RO_Frame:SetPoint("CENTER")
RO_Frame:SetFrameStrata("HIGH")

RO_Frame:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 }
})
RO_Frame:SetBackdropColor(0, 0, 0, 0.7)
RO_Frame:SetFrameLevel(1) -- Hauptfenster auf Basis-Level

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
-- HELPER FUNKTIONEN (UI)
-- ============================================================

-- Erstellt Eingabefelder für Rollen
local function CreateRoleInput(label, y)
    -- 1. Label erstellen
    local txt = RO_Frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    -- Wir setzen den Punkt auf die Y-Achse, aber zentrieren ihn vertikal zur Box
    txt:SetPoint("LEFT", RO_Frame, "TOPLEFT", 35, y)
    txt:SetText(label)

    -- 2. EditBox erstellen (ohne Template, um volle Kontrolle zu haben)
    local eb = CreateFrame("EditBox", nil, RO_Frame)
    eb:SetSize(45, 20) -- Jetzt genau so klein, wie du es wolltest
    eb:SetPoint("RIGHT", RO_Frame, "TOPRIGHT", -35, y)
    
    -- Design: Hintergrund und Rahmen
    eb:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground", -- Schlichter Hintergrund
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",    -- Dünner Rahmen
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    eb:SetBackdropColor(0, 0, 0, 0.8) -- Schwarz mit 80% Deckkraft
    eb:SetBackdropBorderColor(0.5, 0.5, 0.5, 1) -- Grauer Rahmen

    -- Text-Einstellungen innerhalb der Box
    eb:SetFontObject("ChatFontNormal") -- Standardfont nutzen
    eb:SetJustifyH("CENTER")          -- Zahl mittig anzeigen
    eb:SetTextInsets(0, 0, 0, 0)      -- Kein Versatz nötig bei Zentrierung
    
    -- Verhalten
    eb:SetAutoFocus(false)
    eb:SetNumeric(true)
    eb:SetMaxLetters(2)

    -- Hilfreiche Scripts für die Bedienung
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    eb:SetScript("OnEditFocusGained", function(self) self:SetBackdropBorderColor(1, 0.8, 0, 1) end) -- Goldener Rand bei Fokus
    eb:SetScript("OnEditFocusLost", function(self) self:SetBackdropBorderColor(0.5, 0.5, 0.5, 1) end)

    return eb
end

local tankInput = CreateRoleInput("Tanks needed:", -60)
local healInput = CreateRoleInput("Heals needed:", -90)
local dpsInput  = CreateRoleInput("DPS needed:", -120)

-- ============================================================
-- OPTIMIERTE RADIO-BUTTON FUNKTION
-- ============================================================

-- Kleine Trennlinie für die Optik
local function CreateSeparator(y)
    local line = RO_Frame:CreateTexture(nil, "ARTWORK")
    line:SetSize(220, 1)
    line:SetPoint("TOP", 0, y)
    line:SetColorTexture(1, 1, 1, 0.15) -- Dezentes Weiß
end

local function CreateRadio(label, x, y, group, onClick)
    local name = "RO_Radio_" .. label:gsub("%W", "")
    local cb = CreateFrame("CheckButton", name, RO_Frame, "ChatConfigCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", x, y)
    cb:SetSize(22, 22) -- Etwas kompakter
    
    -- Text-Positionierung korrigieren
    local text = _G[name .. "Text"]
    text:SetText(label)
    text:SetFontObject("GameFontHighlightSmall")
    text:ClearAllPoints()
    text:SetPoint("LEFT", cb, "RIGHT", 4, 1) -- Text direkt neben die Box setzen
    
    -- Klickbereich auf den Text erweitern (wichtig für UX)
    cb:SetHitRectInsets(0, -50, 0, 0) 
    
    cb:SetScript("OnClick", function(self)
        for _, btn in ipairs(group) do
            btn:SetChecked(false)
        end
        self:SetChecked(true)
        onClick()
    end)
    
    table.insert(group, cb)
    return cb
end

-- ============================================================
-- POSITIONIERUNG DER GRUPPEN
-- ============================================================

-- 1. Gruppe: Raid Size (3 Spalten)
CreateSeparator(-155)
local groupRadios = {}
local r5 = CreateRadio("5-man", 30, -170, groupRadios, function()
    maxPlayers = 5
    tankInput:SetText("1"); healInput:SetText("1"); dpsInput:SetText("3")
end)
r5:SetChecked(true)

CreateRadio("10-man", 105, -170, groupRadios, function()
    maxPlayers = 10
    tankInput:SetText("2"); healInput:SetText("2"); dpsInput:SetText("6")
end)

CreateRadio("15-man", 185, -170, groupRadios, function()
    maxPlayers = 15
    tankInput:SetText("2"); healInput:SetText("3"); dpsInput:SetText("10")
end)

-- 2. Gruppe: Activity Type (2 Spalten)
CreateSeparator(-205)
local textRadios = {}
local rLev = CreateRadio("Leveling", 30, -220, textRadios, function()
    adType = "LFM MS Leveling"
end)
rLev:SetChecked(true)

CreateRadio("Gold Farm", 140, -220, textRadios, function()
    adType = "LFM MS Gold"
end)

-- ============================================================
-- KERN-LOGIK: POSTING & TIMER
-- ============================================================

local btn = CreateFrame("Button", "RO_MainBtn", RO_Frame, "GameMenuButtonTemplate")
btn:SetPoint("BOTTOM", 0, 25)
btn:SetSize(140, 35)
btn:SetText("Start Search")

local function PostLFM()
    -- 1. Check ob Gruppe voll
    if GetNumGroupMembers() >= maxPlayers then
        isRunning = false
        btn:SetText("Start Search")
        print("|cffff0000RaidOrganizer: Group is full! Stopping search.|r")
        return
    end

    -- 2. Werte auslesen
    local tNeed = tonumber(tankInput:GetText()) or 0
    local hNeed = tonumber(healInput:GetText()) or 0
    local dNeed = tonumber(dpsInput:GetText()) or 0

    -- 3. Nachricht zusammenbauen
    if tNeed > 0 or hNeed > 0 or dNeed > 0 then
        local msg = adType .. ": "
        if tNeed > 0 then msg = msg .. tNeed .. "x Tank " end
        if hNeed > 0 then msg = msg .. hNeed .. "x Heal " end
        if dNeed > 0 then msg = msg .. dNeed .. "x DPS " end
        msg = msg .. "- Whisper 'inv T/H/D' for auto-invite! Examples 'inv T' for Tank, 'inv H' for Healer and 'inv D' for Damage."

        -- 4. In Channels senden
        for i = 1, 20 do
            local id, name = GetChannelName(i)
            if name then
                local lowName = name:lower()
                if lowName:find("newcomers") or lowName:find("looking") or lowName:find("suche") or lowName:find("general") then
                    SendChatMessage(msg, "CHANNEL", nil, id)
                end
            end
        end
    else
        -- Falls alles auf 0 ist
        isRunning = false
        btn:SetText("Start Search")
        print("|cff00ff00RaidOrganizer: All slots filled.|r")
    end
end

btn:SetScript("OnClick", function(self)
    isRunning = not isRunning
    if isRunning then
        self:SetText("Stop Search")
        print("|cff00ff00RaidOrganizer: Searching...|r")
        timer = 58 -- Erster Post nach 2 Sek.
        recentWhispers = {}
    else
        self:SetText("Start Search")
        print("|cffff0000RaidOrganizer: Paused.|r")
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

-- ============================================================
-- AUTO-INVITE LOGIK
-- ============================================================

local inviteFrame = CreateFrame("Frame")
inviteFrame:RegisterEvent("CHAT_MSG_WHISPER")
inviteFrame:SetScript("OnEvent", function(self, event, text, sender)
    if not isRunning then return end
    
    -- Ignorieren, wenn bereits in Gruppe
    if UnitInParty(sender) or UnitInRaid(sender) then return end

    local msg = text:lower()
    local invSuccess = false
    local roleFound = false

    -- Rollen-Check
    if msg:find("inv t") or msg:find("tank") then
        roleFound = true
        local current = tonumber(tankInput:GetText()) or 0
        if current > 0 then 
            tankInput:SetText(current - 1)
            invSuccess = true
        end
    elseif msg:find("inv h") or msg:find("heal") then
        roleFound = true
        local current = tonumber(healInput:GetText()) or 0
        if current > 0 then 
            healInput:SetText(current - 1)
            invSuccess = true
        end
    elseif msg:find("inv d") or msg:find("dps") or msg:find("dd") then
        roleFound = true
        local current = tonumber(dpsInput:GetText()) or 0
        if current > 0 then 
            dpsInput:SetText(current - 1)
            invSuccess = true
        end
    end

    -- Ergebnis verarbeiten
    if invSuccess then
        InviteUnit(sender)
        recentWhispers[sender] = nil
    elseif not roleFound then
        if not recentWhispers[sender] then
            SendChatMessage("RO: Please whisper 'inv T', 'inv H' or 'inv D' for auto-invite!", "WHISPER", nil, sender)
            recentWhispers[sender] = true
        end
    end
end)

-- ============================================================
-- SLASH COMMAND
-- ============================================================
SLASH_RAIDORGANIZER1 = "/ro"
SlashCmdList["RAIDORGANIZER"] = function()
    if RO_Frame:IsShown() then RO_Frame:Hide() else RO_Frame:Show() end
end

-- Startwerte setzen (Initialisierung)
tankInput:SetText("1")
healInput:SetText("1")
dpsInput:SetText("3")

print("|cff69ccf0RaidOrganizer v1.7 loaded. Use /ro to toggle.|r")
