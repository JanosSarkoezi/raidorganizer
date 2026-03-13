-- HAUPTFENSTER ERSTELLEN
local RO_Frame = CreateFrame("Frame", "RaidOrganizerMain", UIParent, "BackdropTemplate")
RO_Frame:SetSize(220, 240)
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
title:SetText("Raid Organizer v1.4")

-- STATUS-VARIABLEN
local isRunning = false
local timer = 55 
local recentWhispers = {} -- Spam-Schutz für Hilfe-Nachrichten

-- INPUT FELDER FUNKTION
local function CreateRoleInput(label, yOffset, defaultValue)
    local text = RO_Frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("TOPLEFT", 25, yOffset)
    text:SetText(label)

    local eb = CreateFrame("EditBox", nil, RO_Frame, "InputBoxTemplate")
    eb:SetPoint("TOPRIGHT", -25, yOffset + 5)
    eb:SetSize(45, 20)
    eb:SetAutoFocus(false)
    eb:SetNumeric(true)
    eb:SetText(tostring(defaultValue or 0)) 
    return eb
end

local tankInput = CreateRoleInput("Tanks needed:", -45, 2)
local healInput = CreateRoleInput("Heals needed:", -70, 3)
local dpsInput  = CreateRoleInput("DPS needed:", -95, 9)

-- START/STOP BUTTON
local btn = CreateFrame("Button", nil, RO_Frame, "GameMenuButtonTemplate")
btn:SetPoint("BOTTOM", 0, 20)
btn:SetSize(140, 30)
btn:SetText("Start Search")

-- POSTING-FUNKTION
local function PostLFM()
    if GetNumGroupMembers() >= 5 then
        print("|cffff0000RaidOrganizer: Group is full! Stopped.|r")
        isRunning = false
        btn:SetText("Start Search")
        return
    end

    local tNeed = tonumber(tankInput:GetText()) or 0
    local hNeed = tonumber(healInput:GetText()) or 0
    local dNeed = tonumber(dpsInput:GetText()) or 0

    if tNeed > 0 or hNeed > 0 or dNeed > 0 then
        local msg = "LFM MS Leveling: "
        if tNeed > 0 then msg = msg .. tNeed .. "x Tank " end
        if hNeed > 0 then msg = msg .. hNeed .. "x Heal " end
        if dNeed > 0 then msg = msg .. dNeed .. "x DPS " end
        msg = msg .. "- Whisper 'inv T/H/D' for auto-invite!. Examples 'inv T' for Tank, 'inv H' for Helaer or 'inv D' for Damage."

        for i = 1, 20 do
            local id, name = GetChannelName(i)
            if name then
                local lowName = name:lower()
                if lowName:find("german") or lowName:find("newcomers") or lowName:find("looking") or lowName:find("general") or lowName:find("world") then
                    SendChatMessage(msg, "CHANNEL", nil, id)
                end
            end
        end
    else
        isRunning = false
        btn:SetText("Start Search")
        print("|cff00ff00RaidOrganizer: All slots filled.|r")
    end
end

-- BUTTON LOGIK
btn:SetScript("OnClick", function(self)
    isRunning = not isRunning
    if isRunning then
        self:SetText("Stop Search")
        print("|cff00ff00RaidOrganizer: Active! (Post every 60s)|r")
        timer = 58 
        recentWhispers = {} -- Reset Spam-Schutz bei Neustart
    else
        self:SetText("Start Search")
        print("|cffff0000RaidOrganizer: Paused.|r")
    end
end)

-- TIMER
RO_Frame:SetScript("OnUpdate", function(self, elapsed)
    if not isRunning then return end 
    timer = timer + elapsed
    if timer >= 60 then 
        PostLFM()
        timer = 0
    end
end)

-- AUTO-INVITE & ERROR-HANDLING
local inviteFrame = CreateFrame("Frame")
inviteFrame:RegisterEvent("CHAT_MSG_WHISPER")
inviteFrame:SetScript("OnEvent", function(self, event, text, sender)
    if not isRunning then return end

    -- NEU: Wenn der Spieler bereits in der Gruppe/Raid ist, brich hier ab.
    if UnitInParty(sender) or UnitInRaid(sender) then return end

    local msg = text:lower()
    local invSuccess = false
    local roleFound = false

    -- Prüfung auf Rollen
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

    -- Reaktion
    if invSuccess then
        InviteUnit(sender)
        recentWhispers[sender] = nil
    elseif not roleFound then
        -- Nur antworten, wenn noch kein Whisper in dieser Session geschickt wurde
        if not recentWhispers[sender] then
            SendChatMessage("Please whisper 'inv T', 'inv H' or 'inv D' so I can assign your role automatically!", "WHISPER", nil, sender)
            recentWhispers[sender] = true
        end
    end
end)

-- SLASH-BEFEHL
SLASH_RAIDORGANIZER1 = "/ro"
SlashCmdList["RAIDORGANIZER"] = function()
    if RO_Frame:IsShown() then RO_Frame:Hide() else RO_Frame:Show() end
end

print("|cff69ccf0RaidOrganizer loaded. Type /ro to open.|r")
