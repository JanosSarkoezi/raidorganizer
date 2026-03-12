-- HAUPTFENSTER ERSTELLE
local RO_Frame = CreateFrame("Frame", "RaidOrganizerMain", UIParent)
RO_Frame:SetSize(220, 180)
RO_Frame:SetPoint("CENTER")
RO_Frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 }
})
--
-- FENSTER BEWEGLICH MACHEN (Korrektur)
RO_Frame:SetMovable(true)
RO_Frame:EnableMouse(true)
RO_Frame:RegisterForDrag("LeftButton")
RO_Frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
RO_Frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

-- TITEL
local title = RO_Frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOP", 0, -15)
title:SetText("Raid Organizer v1.0")

-- STATUS-VARIABLE
local isRunning = false

-- START/STOP BUTTON
local btn = CreateFrame("Button", nil, RO_Frame, "GameMenuButtonTemplate")
btn:SetPoint("BOTTOM", 0, 20)
btn:SetSize(120, 30)
btn:SetText("Start Suche")

-- LOGIK FÜR DEN BUTTON
btn:SetScript("OnClick", function(self)
    isRunning = not isRunning
    if isRunning then
        self:SetText("Stop Suche")
        print("|cff00ff00RaidOrganizer: Suche gestartet!|r")
        
        -- TRICK: Den Timer auf 120 setzen, damit er beim nächsten 
        -- Frame-Update sofort merkt: "Oh, 120s sind um!"
        lastPost = 120 
    else
        self:SetText("Start Suche")
        print("|cffff0000RaidOrganizer: Suche gestoppt.|r")
        lastPost = 0
    end
end)

-- INPUT FELDER (Beispiel für Tanks)
local function CreateRoleInput(label, yOffset)
    local text = RO_Frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("TOPLEFT", 25, yOffset)
    text:SetText(label)

    local eb = CreateFrame("EditBox", nil, RO_Frame, "InputBoxTemplate")
    eb:SetPoint("TOPRIGHT", -25, yOffset + 5)
    eb:SetSize(40, 20)
    eb:SetAutoFocus(false)
    eb:SetNumeric(true)
    eb:SetText("0")
    return eb
end

local tankInput = CreateRoleInput("Tanks gesamt:", -45)
local healInput = CreateRoleInput("Heals gesamt:", -70)
local dpsInput  = CreateRoleInput("DPS gesamt:", -95)

-- TIMER & SENDE-LOGIK
RO_Frame:SetScript("OnUpdate", function(self, elapsed)
    if not isRunning then return end 

    lastPost = (lastPost or 0) + elapsed
    
    if lastPost >= 120 then -- Alle 2 Minuten
        -- 1. Freie Plätze berechnen
        -- Wir zählen, wie viele Leute aktuell im Raid sind
        local currentTanks, currentHeals, currentDPS = 0, 0, 0
        for i = 1, GetNumGroupMembers() do
            local role = UnitGroupRolesAssigned(IsInRaid() and "raid"..i or "party"..i)
            if role == "TANK" then currentTanks = currentTanks + 1
            elseif role == "HEALER" then currentHeals = currentHeals + 1
            elseif role == "DAMAGER" then currentDPS = currentDPS + 1 end
        end

        -- 2. Bedarf ermitteln (Input-Feld MINUS aktuelle Leute)
        local tNeed = (tonumber(tankInput:GetText()) or 0) - currentTanks
        local hNeed = (tonumber(healInput:GetText()) or 0) - currentHeals
        local dNeed = (tonumber(dpsInput:GetText()) or 0) - currentDPS

        -- 3. Nachricht zusammenbauen
        if tNeed > 0 or hNeed > 0 or dNeed > 0 then
            local msg = "LFM MS Leveling: "
            if tNeed > 0 then msg = msg .. tNeed .. "x Tank " end
            if hNeed > 0 then msg = msg .. hNeed .. "x Heal " end
            if dNeed > 0 then msg = msg .. dNeed .. "x DPS " end
            msg = msg .. "- Whisper 'inv' for invite!"

            -- 4. Nachricht in die Channels senden
            -- Wir suchen nach den Kanälen "World" und "LookingForGroup"
            for i = 1, 10 do
                local id, name = GetChannelName(i)
                if name and (name:find("german") or name:find("Newcomers")) then
                    SendChatMessage(msg, "CHANNEL", nil, id)
                end
            end
        end

        lastPost = 0
    end
end)

-- AUTO-INVITE (Muss auch in die Datei, falls noch nicht geschehen)
local inviteFrame = CreateFrame("Frame")
inviteFrame:RegisterEvent("CHAT_MSG_WHISPER")
inviteFrame:SetScript("OnEvent", function(self, event, text, sender)
    if isRunning and (text:lower():find("inv") or text:find("+")) then
        InviteUnit(sender)
    end
end)

-- SLASH-BEFEHL REGISTRIEREN
SLASH_RAIDORGANIZER1 = "/ro"
SlashCmdList["RAIDORGANIZER"] = function(msg)
    if RO_Frame:IsShown() then
        RO_Frame:Hide()
        print("|cff69ccf0RaidOrganizer ausgeblendet. Nutze /ro zum Zeigen.|r")
    else
        RO_Frame:Show()
        print("|cff69ccf0RaidOrganizer eingeblendet.|r")
    end
end
