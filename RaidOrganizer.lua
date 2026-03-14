-- ============================================================
-- RAID ORGANIZER CLASS DEFINITION (v1.8)
-- ============================================================
RaidOrganizer = {}
RaidOrganizer.__index = RaidOrganizer

-- "Constructor" - Erstellt eine neue Addon-Instanz
function RaidOrganizer:New()
    local obj = setmetatable({}, RaidOrganizer)
    
    -- Interne Status-Variablen
    obj.isRunning = false
    obj.timer = 55 -- Startet kurz vor dem ersten Post
    obj.maxPlayers = 5
    obj.adType = "LFM MS Leveling"
    obj.recentWhispers = {}
    obj.groupRadios = {}
    obj.activityRadios = {}
    
    -- Initialisierung
    obj:CreateMainFrame()
    obj:BuildUI()
    obj:SetupEvents()

    -- Konfiguration: Hier kannst du Kanäle einfach hinzufügen/löschen
    obj.targetChannels = {
	"rotest", 
	-- "german", 
        -- "newcomers",
        -- "ascension",
    }
    
    print("|cff69ccf0RaidOrganizer v1.8 (Class-based) geladen. Nutze /ro zum Anzeigen.|r")
    return obj
end

-- ============================================================
-- UI METHODEN
-- ============================================================

function RaidOrganizer:CreateMainFrame()
    local f = CreateFrame("Frame", "RaidOrganizerMain", UIParent, "BackdropTemplate")
    f:SetSize(280, 300)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 16, insets = {left=5, right=5, top=5, bottom=5}
    })
    
    -- Beweglich machen
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -18)
    title:SetText("Raid Organizer v1.8")
    
    self.frame = f
end

function RaidOrganizer:CreateRoleInput(label, y)
    -- Label
    local txt = self.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    txt:SetPoint("LEFT", self.frame, "TOPLEFT", 35, y)
    txt:SetText(label)

    -- EditBox (Zentriert im Fenster)
    local eb = CreateFrame("EditBox", nil, self.frame, "BackdropTemplate")
    eb:SetSize(35, 20)
    eb:SetPoint("LEFT", self.frame, "TOPLEFT", 165, y) 
    eb:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    eb:SetBackdropColor(0, 0, 0, 0.8)
    eb:SetFontObject("ChatFontNormal")
    eb:SetJustifyH("CENTER")
    eb:SetAutoFocus(false)
    eb:SetNumeric(true)
    eb:SetMaxLetters(2)

    -- Scripting für Fokus-Farben
    eb:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
    eb:SetScript("OnEditFocusGained", function(s) s:SetBackdropBorderColor(1, 0.8, 0, 1) end)
    eb:SetScript("OnEditFocusLost", function(s) s:SetBackdropBorderColor(0.5, 0.5, 0.5, 1) end)

    -- Minus Button
    local btnMinus = CreateFrame("Button", nil, self.frame, "UIPanelButtonTemplate")
    btnMinus:SetSize(22, 22)
    btnMinus:SetPoint("RIGHT", eb, "LEFT", -5, 0)
    btnMinus:SetText("-")
    btnMinus:SetScript("OnClick", function()
        local val = tonumber(eb:GetText()) or 0
        if val > 0 then eb:SetText(val - 1) end
    end)

    -- Plus Button
    local btnPlus = CreateFrame("Button", nil, self.frame, "UIPanelButtonTemplate")
    btnPlus:SetSize(22, 22)
    btnPlus:SetPoint("LEFT", eb, "RIGHT", 5, 0)
    btnPlus:SetText("+")
    btnPlus:SetScript("OnClick", function()
        local val = tonumber(eb:GetText()) or 0
        eb:SetText(val + 1)
    end)

    return eb
end

function RaidOrganizer:CreateRadio(label, x, y, group, onClick)
    local name = "RO_Radio_" .. label:gsub("%W", "")
    local cb = CreateFrame("CheckButton", name, self.frame, "ChatConfigCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", x, y)
    cb:SetSize(22, 22)
    
    local text = _G[name .. "Text"]
    text:SetText(label)
    text:SetFontObject("GameFontHighlightSmall")
    text:ClearAllPoints()
    text:SetPoint("LEFT", cb, "RIGHT", 4, 1)
    
    cb:SetHitRectInsets(0, -50, 0, 0) 
    cb:SetScript("OnClick", function(button)
        for _, btn in ipairs(group) do btn:SetChecked(false) end
        button:SetChecked(true)
        onClick()
    end)
    table.insert(group, cb)
    return cb
end

function RaidOrganizer:BuildUI()
    local function CreateSeparator(y)
        local line = self.frame:CreateTexture(nil, "ARTWORK")
        line:SetSize(220, 1)
        line:SetPoint("TOP", 0, y)
        line:SetColorTexture(1, 1, 1, 0.15)
    end

    -- 1. Rollen Eingabe
    self.tankInput = self:CreateRoleInput("Tanks needed:", -60)
    self.healInput = self:CreateRoleInput("Heals needed:", -90)
    self.dpsInput  = self:CreateRoleInput("DPS needed:", -120)
    
    self.tankInput:SetText("1")
    self.healInput:SetText("1")
    self.dpsInput:SetText("3")

    -- 2. Raid Größe (Radio Buttons)
    CreateSeparator(-145)
    local r5 = self:CreateRadio("5-man", 30, -155, self.groupRadios, function()
        self.maxPlayers = 5; self.tankInput:SetText("1"); self.healInput:SetText("1"); self.dpsInput:SetText("3")
    end)
    r5:SetChecked(true)
    
    self:CreateRadio("10-man", 105, -155, self.groupRadios, function()
        self.maxPlayers = 10; self.tankInput:SetText("1"); self.healInput:SetText("2"); self.dpsInput:SetText("7")
    end)
    
    self:CreateRadio("15-man", 185, -155, self.groupRadios, function()
        self.maxPlayers = 15; self.tankInput:SetText("2"); self.healInput:SetText("3"); self.dpsInput:SetText("10")
    end)

    -- 3. Aktivität
    CreateSeparator(-185)
    local rLev = self:CreateRadio("Leveling", 30, -195, self.activityRadios, function() self.adType = "LFM MS Leveling" end)
    rLev:SetChecked(true)
    
    self:CreateRadio("Gold Farm", 140, -195, self.activityRadios, function() self.adType = "LFM MS Gold" end)

    -- 4. Start Button
    self.btn = CreateFrame("Button", "RO_MainBtn", self.frame, "GameMenuButtonTemplate")
    self.btn:SetPoint("TOP", self.frame, "TOP", 0, -240) 
    self.btn:SetSize(140, 30)
    self.btn:SetText("Start Search")
    self.btn:SetScript("OnClick", function() self:ToggleSearch() end)

    -- 5. Update Loop
    self.frame:SetScript("OnUpdate", function(_, elapsed) self:OnUpdate(elapsed) end)
end

-- ============================================================
-- LOGIK METHODEN (Das "Gehirn" des Addons)
-- ============================================================

function RaidOrganizer:OnUpdate(elapsed)
    if not self.isRunning then return end
    self.timer = self.timer + elapsed
    if self.timer >= 60 then
        self:PostLFM()
        self.timer = 0
    end
end

function RaidOrganizer:RefreshChannels()
    self.activeChannels = {}
    local foundAny = false

    -- Wir scannen alle 10 Standard-Slots
    for i = 1, 10 do
        local id, name = GetChannelName(i)
        if name then
            local lowName = name:lower()
            
            for _, pattern in ipairs(self.targetChannels) do
                if lowName:find(pattern:lower()) then
                    table.insert(self.activeChannels, id)
                    foundAny = true
                    print("|cff69ccf0RO: Channel gefunden:|r [" .. id .. "] " .. name)
                    break 
                end
            end
        end
    end

    if not foundAny then
        print("|cffff0000RO Warnung: Kein Ziel-Channel gefunden! (Prüfe /join " .. (self.targetChannels[1] or "") .. ")|r")
    end
end

function RaidOrganizer:PostLFM()
    -- Gruppe voll Check
    if GetNumGroupMembers() >= self.maxPlayers then
        self:ToggleSearch()
        print("|cffff0000RO: Raid full!|r")
        return
    end

    local t = tonumber(self.tankInput:GetText()) or 0
    local h = tonumber(self.healInput:GetText()) or 0
    local d = tonumber(self.dpsInput:GetText()) or 0

    if t > 0 or h > 0 or d > 0 then
        -- Einfachere Nachricht ohne zu viele Farbcodes (verhindert Spam-Block)
        local msg = self.adType .. " needs: "

        if t > 0 then msg = msg .. t .. " Tank " end
        if h > 0 then msg = msg .. h .. " Heal " end
        if d > 0 then msg = msg .. d .. " DPS " end
        msg = msg .. "- Whisper 'inv T' for Tank, 'inv H' for Healer or 'inv D' for Damage!"

        -- Senden an alle gefundenen IDs
        if self.activeChannels and #self.activeChannels > 0 then
            for _, id in ipairs(self.activeChannels) do
                -- WICHTIG: Sicherstellen, dass id eine Zahl ist
                local channelIndex = tonumber(id)
                if channelIndex then
                    SendChatMessage(msg, "CHANNEL", nil, channelIndex)
                end
            end
        else
            print("|cffff0000RO: Senden fehlgeschlagen - Kein Channel-Index vorhanden.|r")
        end
    else
        self:ToggleSearch()
    end
end

function RaidOrganizer:PostLFMColored()
    if GetNumGroupMembers() >= self.maxPlayers then
        self:ToggleSearch()
        print("|cffff0000RO: Gruppe voll!|r")
        return
    end

    local t = tonumber(self.tankInput:GetText()) or 0
    local h = tonumber(self.healInput:GetText()) or 0
    local d = tonumber(self.dpsInput:GetText()) or 0

    if t > 0 or h > 0 or d > 0 then
        -- 1. Aktivität einfärben
        local coloredActivity = ""
        if self.adType:find("Leveling") then
            coloredActivity = "LFM |cffff4d4dMS|r |cff1eff00Leveling|r"
        elseif self.adType:find("Gold") then
            coloredActivity = "LFM |cffff4d4dMS|r |cffffd700Gold Farm|r"
        else
            coloredActivity = self.adType -- Fallback
        end

        local msg = coloredActivity .. ": "

        -- 2. Zahlen in Weiß einfärben
        if t > 0 then msg = msg .. "|cffffffff" .. t .. "x|r Tank " end
        if h > 0 then msg = msg .. "|cffffffff" .. h .. "x|r Heal " end
        if d > 0 then msg = msg .. "|cffffffff" .. d .. "x|r DPS " end
        
        msg = msg .. "- Whisper 'inv T' for Tank, 'inv H' for Healer or 'inv D' for Damage!"

        -- 3. Senden
        if self.activeChannels then
            for _, id in ipairs(self.activeChannels) do
                SendChatMessage(msg, "CHANNEL", nil, id)
            end
        end
    else
        self:ToggleSearch()
    end
end

function RaidOrganizer:ToggleSearch()
    self.isRunning = not self.isRunning

    if self.isRunning then
        self:RefreshChannels() 
        self.btn:SetText("|cff00ff00Stop Search|r")
        -- Reset Timer & Cache
        self.timer = 58 
        self.recentWhispers = {}
        
        print("|cff00ff00RO: Suche gestartet...|r")
    else
        self.btn:SetText("Start Search")
        print("|cff00ff00RO: Suche pausiert.|r")
    end
end

function RaidOrganizer:HandleWhisper(text, sender)
    if not self.isRunning then return end
    if UnitInParty(sender) or UnitInRaid(sender) or sender == UnitName("player") then return end

    local msg = text:lower()
    local roleFound, inputField = nil, nil

    if msg:find("inv t") or msg:find("tank") then roleFound, inputField = "Tank", self.tankInput
    elseif msg:find("inv h") or msg:find("heal") then roleFound, inputField = "Healer", self.healInput
    elseif msg:find("inv d") or msg:find("dps") or msg:find("dd") then roleFound, inputField = "DPS", self.dpsInput end

    if roleFound then
        local current = tonumber(inputField:GetText()) or 0
        if current > 0 then 
            inputField:SetText(current - 1)
            InviteUnit(sender)
            self.recentWhispers[sender] = nil 
        else
            if not self.recentWhispers[sender] then
		SendChatMessage("RO: Sorry, " .. roleFound .. " slots are full!", "WHISPER", nil, sender)
                self.recentWhispers[sender] = true 
            end
        end
    elseif (msg:find("inv") or msg:find("invite")) and not self.recentWhispers[sender] then
	SendChatMessage("RO: Min Level 10. Please whisper 'inv T', 'inv H' or 'inv D'!", "WHISPER", nil, sender)
        self.recentWhispers[sender] = true
    end
end

function RaidOrganizer:SetupEvents()
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:RegisterEvent("CHAT_MSG_WHISPER")
    self.eventFrame:SetScript("OnEvent", function(_, _, text, sender)
        self:HandleWhisper(text, sender)
    end)
end

-- ============================================================
-- START & SLASH COMMAND
-- ============================================================
local myRO = RaidOrganizer:New()

SLASH_RAIDORGANIZER1 = "/ro"
SlashCmdList["RAIDORGANIZER"] = function()
    if myRO.frame:IsShown() then myRO.frame:Hide() else myRO.frame:Show() end
end
