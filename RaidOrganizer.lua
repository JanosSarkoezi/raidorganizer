-- HAUPTFENSTER ERSTELLEN (Kompatibel mit Retail & Private Servers wie Ascension)
local RO_Frame = CreateFrame("Frame", "RaidOrganizerMain", UIParent, "BackdropTemplate")
RO_Frame:SetSize(220, 220)
RO_Frame:SetPoint("CENTER")
RO_Frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 }
})

-- FENSTER BEWEGLICH MACHEN
RO_Frame:SetMovable(true)
RO_Frame:EnableMouse(true)
RO_Frame:RegisterForDrag("LeftButton")
RO_Frame:SetScript("OnDragStart", RO_Frame.StartMoving)
RO_Frame:SetScript("OnDragStop", RO_Frame.StopMovingOrSizing)

-- TITEL
local title = RO_Frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOP", 0, -15)
title:SetText("Raid Organizer v1.2")

-- STATUS-VARIABLEN
local isRunning = false
local lastPost = 115 -- Startet fast sofort nach dem ersten Klick

-- INPUT FELDER FUNKTION (Jetzt mit Initialwert)
local function CreateRoleInput(label, yOffset, defaultValue)
    local text = RO_Frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("TOPLEFT", 25, yOffset)
    text:SetText(label)

    local eb = CreateFrame("EditBox", nil, RO_Frame, "InputBoxTemplate")
    eb:SetPoint("TOPRIGHT", -25, yOffset + 5)
    eb:SetSize(45, 20)
    eb:SetAutoFocus(false)
    eb:SetNumeric(true)
    -- Hier setzen wir den Initialwert (oder "0", falls keiner angegeben wurde)
    eb:SetText(tostring(defaultValue or 0)) 
    return eb
end

-- Hier definierst du jetzt deine Standard-Werte beim Erstellen:
local tankInput = CreateRoleInput("Tanks gesucht:", -45, 2)
local healInput = CreateRoleInput("Heals gesucht:", -70, 3)
local dpsInput  = CreateRoleInput("DPS gesucht:", -95, 8)

-- START/STOP BUTTON
local btn = CreateFrame("Button", nil, RO_Frame, "GameMenuButtonTemplate")
btn:SetPoint("BOTTOM", 0, 20)
btn:SetSize(120, 30)
btn:SetText("Start Suche")

btn:SetScript("OnClick", function(self)
    isRunning = not isRunning
    if isRunning then
        self:SetText("Stop Suche")
        print("|cff00ff00RaidOrganizer: Suche aktiv!|r")
        lastPost = 115 -- Erster Post nach 5 Sekunden
    else
        self:SetText("Start Suche")
        print("|cffff0000RaidOrganizer: Suche pausiert.|r")
    end
end)

-- TIMER & CHAT-LOGIK
RO_Frame:SetScript("OnUpdate", function(self, elapsed)
    if not isRunning then return end 

    lastPost = lastPost + elapsed
    
    if lastPost >= 60 then -- Alle 120 Sekunden (2 Min)
        local tNeed = tonumber(tankInput:GetText()) or 0
        local hNeed = tonumber(healInput:GetText()) or 0
        local dNeed = tonumber(dpsInput:GetText()) or 0

        if tNeed > 0 or hNeed > 0 or dNeed > 0 then
            local msg = "LFM MS Leveling: "
            if tNeed > 0 then msg = msg .. tNeed .. "x Tank " end
            if hNeed > 0 then msg = msg .. hNeed .. "x Heal " end
            if dNeed > 0 then msg = msg .. dNeed .. "x DPS " end
            msg = msg .. "- Whisper 'inv T/H/D'! Example: 'inv T' for invite as Tank."

            -- Sende in relevante Channels
            for i = 1, 20 do
                local id, name = GetChannelName(i)
                if name then
                    local lowName = name:lower()
                    if lowName:find("newcomers") or lowName:find("suche") or lowName:find("looking") or lowName:find("general") then
                        SendChatMessage(msg, "CHANNEL", nil, id)
                    end
                end
            end
        else
            -- Automatisch stoppen, wenn alle Felder auf 0 sind
            isRunning = false
            btn:SetText("Start Suche")
            print("|cff00ff00RaidOrganizer: Gruppe ist voll!|r")
        end
        lastPost = 0
    end
end)

-- AUTO-INVITE & AUTOMATISCHES RUNTERZÄHLEN
local inviteFrame = CreateFrame("Frame")
inviteFrame:RegisterEvent("CHAT_MSG_WHISPER")
inviteFrame:SetScript("OnEvent", function(self, event, text, sender)
    if not isRunning then return end

    local msg = text:lower()
    local invSuccess = false

    -- Prüfung auf Rollen-Kürzel
    if msg:find("inv t") or msg:find("tank") then
        local current = tonumber(tankInput:GetText()) or 0
        if current > 0 then 
            tankInput:SetText(current - 1)
            invSuccess = true
        end
    elseif msg:find("inv h") or msg:find("heal") then
        local current = tonumber(healInput:GetText()) or 0
        if current > 0 then 
            healInput:SetText(current - 1)
            invSuccess = true
        end
    elseif msg:find("inv d") or msg:find("dps") or msg:find("dd") then
        local current = tonumber(dpsInput:GetText()) or 0
        if current > 0 then 
            dpsInput:SetText(current - 1)
            invSuccess = true
        end
    elseif msg == "inv" or msg == "+" then
        -- Falls jemand nur "inv" schreibt, laden wir ihn trotzdem ein,
        -- verringern aber keine Zähler, da wir die Rolle nicht wissen.
        invSuccess = true
    end

    if invSuccess then
        InviteUnit(sender)
    end
end)

-- SLASH-BEFEHL
SLASH_RAIDORGANIZER1 = "/ro"
SlashCmdList["RAIDORGANIZER"] = function()
    if RO_Frame:IsShown() then RO_Frame:Hide() else RO_Frame:Show() end
end

print("|cff69ccf0RaidOrganizer geladen. Nutze /ro zum Öffnen.|r")
