-- ============================================================
-- RAID ORGANIZER v1.9.2 (Level-Check & Auto-Response)
-- ============================================================

RaidOrganizer = {}
RaidOrganizer.__index = RaidOrganizer

RaidOrganizer.roleKeywords = {
    Tank   = { "inv t", "tank" },
    Healer = { "inv h", "heal" },
    DPS    = { "inv d", "dps", "dd" }
}

function RaidOrganizer:New()
    local obj = setmetatable({}, RaidOrganizer)

    -- Config
    obj.isRunning = false
    obj.maxPlayers = 5
    obj.adType = "LFM MS Leveling"
    -- obj.targetChannels = { "rotest" }
    obj.targetChannels = { "newcomers", "ascension", "world", "lfg" }
    
    -- Cache & Logic
    obj.activeChannels = {}
    obj.recentWhispers = {}
    obj.groupRadios = {}
    obj.activityRadios = {}
    obj.internalTimer = 0

    obj:CreateMainFrame()
    obj:BuildUI()
    obj:SetupEvents()

    print("|cff69ccf0RaidOrganizer v1.9.2 loaded. Use /ro to toggle UI.|r")
    return obj
end

-- ============================================================
-- UI GENERATION (Fixed HitRects & English)
-- ============================================================

function RaidOrganizer:CreateMainFrame()
    local f = CreateFrame("Frame", "RaidOrganizerMain", UIParent, "BackdropTemplate")
    f:SetSize(280, 300); f:SetPoint("CENTER"); f:SetFrameStrata("HIGH")
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 16, insets = {left=5, right=5, top=5, bottom=5}
    })
    f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -18); title:SetText("Raid Organizer v1.9.2")
    self.frame = f
end

function RaidOrganizer:CreateRoleInput(label, y)
    local txt = self.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    txt:SetPoint("LEFT", self.frame, "TOPLEFT", 35, y); txt:SetText(label)
    local eb = CreateFrame("EditBox", nil, self.frame, "BackdropTemplate")
    eb:SetSize(35, 20); eb:SetPoint("LEFT", self.frame, "TOPLEFT", 165, y)
    eb:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    eb:SetBackdropColor(0, 0, 0, 0.8); eb:SetFontObject("ChatFontNormal"); eb:SetJustifyH("CENTER")
    eb:SetAutoFocus(false); eb:SetNumeric(true); eb:SetMaxLetters(2)
    eb:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
    local function CreateStepBtn(text, offset, step)
        local btn = CreateFrame("Button", nil, self.frame, "UIPanelButtonTemplate")
        btn:SetSize(22, 22); btn:SetText(text)
        btn:SetPoint(offset > 0 and "LEFT" or "RIGHT", eb, offset > 0 and "RIGHT" or "LEFT", offset, 0)
        btn:SetScript("OnClick", function()
            local val = (tonumber(eb:GetText()) or 0) + step
            eb:SetText(val < 0 and 0 or val)
        end)
    end
    CreateStepBtn("-", -5, -1); CreateStepBtn("+", 5, 1)
    return eb
end

function RaidOrganizer:CreateRadio(label, x, y, group, onClick)
    local name = "RO_Radio_" .. label:gsub("%W", "")
    local cb = CreateFrame("CheckButton", name, self.frame, "ChatConfigCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", x, y); cb:SetSize(22, 22)
    local text = _G[name .. "Text"]
    text:SetText(label); text:SetFontObject("GameFontHighlightSmall")
    text:ClearAllPoints(); text:SetPoint("LEFT", cb, "RIGHT", 4, 1)
    cb:SetHitRectInsets(0, -50, 0, 0) 
    cb:SetScript("OnClick", function(button)
        for _, btn in ipairs(group) do btn:SetChecked(false) end
        button:SetChecked(true); onClick()
    end)
    table.insert(group, cb)
    return cb
end

-- ============================================================
-- LOGIC & ENGINE
-- ============================================================

function RaidOrganizer:RefreshChannels()
    self.activeChannels = {}
    local found = false
    for i = 1, 20 do
        local id, name = GetChannelName(i)
        if name then
            local lowName = name:lower()
            for _, pattern in ipairs(self.targetChannels) do
                if lowName:find(pattern:lower()) then
                    table.insert(self.activeChannels, id)
                    found = true
                    print("|cff69ccf0RO: Channel found:|r [" .. id .. "] " .. name)
                    break 
                end
            end
        end
    end
    if not found then print("|cffff0000RO Warning: No target channels found!|r") end
end

function RaidOrganizer:PostLFM()
    if not self.isRunning then return end
    if GetNumGroupMembers() >= self.maxPlayers then
        print("|cffff0000RO: Group full! Stopping search.|r")
        self:ToggleSearch()
        return
    end

    local t = tonumber(self.tankInput:GetText()) or 0
    local h = tonumber(self.healInput:GetText()) or 0
    local d = tonumber(self.dpsInput:GetText()) or 0

    if t <= 0 and h <= 0 and d <= 0 then 
        self:ToggleSearch()
        return 
    end

    local msg = self.adType .. " needs: "
    if t > 0 then msg = msg .. t .. " Tank " end
    if h > 0 then msg = msg .. h .. " Heal " end
    if d > 0 then msg = msg .. d .. " DPS " end
    msg = msg .. "- Whisper 'inv T' for Tank, 'inv H' for Heal and 'inv D' for Damage."

    for _, id in ipairs(self.activeChannels) do
        SendChatMessage(msg, "CHANNEL", nil, id)
    end
end

-- NEW: Level Check Logic
function RaidOrganizer:CheckGroupLevel()
    if not self.isRunning then return end

    local isGoldFarm = self.adType:find("Gold")
    local numMembers = GetNumGroupMembers()
    if numMembers <= 1 then return end

    for i = 1, numMembers do
        local unit = IsInRaid() and "raid"..i or "party"..i
        -- Fix for player unit in party
        if not IsInRaid() and i == numMembers then unit = "player" end
        
        local name = UnitName(unit)
        local level = UnitLevel(unit)

        if name and name ~= UnitName("player") and level > 0 then
            local isInvalid = false
            local reasonMsg = ""

            if isGoldFarm then
                -- Gold Farm Logic: Only Level 70 allowed
                if level < 70 then
                    isInvalid = true
                    reasonMsg = "Hello! This Gold Farm group is for Level 70 players only. You are currently Level " .. level .. "."
                end
            else
                -- Leveling Logic: Only Level 10 to 69 allowed
                if level < 10 or level > 69 then
                    isInvalid = true
                    if level < 10 then
                        reasonMsg = "Hello! This leveling group is for Level 10-69. You are currently below the minimum level."
                    else
                        reasonMsg = "Hello! This group is for Leveling (10-69). Since you are already Level 70, you might want to join a Gold Farm or End-game raid instead."
                    end
                end
            end

            -- Send polite whisper and print warning for the leader
            if isInvalid and not self.recentWhispers[name .. "_lvlwarn"] then
                print("|cffff0000RO: " .. name .. " (Lv " .. level .. ") does not match group type. Warning sent.|r")
                SendChatMessage("RO: " .. reasonMsg, "WHISPER", nil, name)
                self.recentWhispers[name .. "_lvlwarn"] = true
            end
        end
    end
end

function RaidOrganizer:HandleWhisper(text, sender)
    if not self.isRunning or sender == UnitName("player") then return end
    local msg = text:lower()
    local roleFound, inputField

    for role, words in pairs(self.roleKeywords) do
        for _, w in ipairs(words) do
            if msg:find(w) then
                roleFound = role
                inputField = (role == "Tank" and self.tankInput) or (role == "Healer" and self.healInput) or self.dpsInput
                break
            end
        end
        if roleFound then break end
    end

    if roleFound then
        local current = tonumber(inputField:GetText()) or 0
        if current > 0 then
            inputField:SetText(current - 1)
            InviteUnit(sender)
            self.recentWhispers[sender] = nil
        elseif not self.recentWhispers[sender] then
            SendChatMessage("RO: Sorry, " .. roleFound .. " slots are full!", "WHISPER", nil, sender)
            self.recentWhispers[sender] = true
        end
    elseif (msg:find("inv") or msg:find("invite")) and not self.recentWhispers[sender] then
        local minLevel = self.adType:find("Gold") and 70 or 10
        SendChatMessage("RO: Min Level " .. minLevel .. ". Please whisp 'inv T', 'inv H' or 'inv D'!", "WHISPER", nil, sender)
        self.recentWhispers[sender] = true
    end
end

-- ============================================================
-- EVENT ENGINE
-- ============================================================

function RaidOrganizer:ToggleSearch()
    self.isRunning = not self.isRunning
    if self.isRunning then
        self:RefreshChannels()
        self.btn:SetText("|cff00ff00Stop Search|r")
        self.recentWhispers = {}
        self.internalTimer = 58 
        print("|cff00ff00RO: Search started...|r")
    else
        self.btn:SetText("Start Search")
        print("|cffffd100RO: Search paused.|r")
    end
end

function RaidOrganizer:SetupEvents()
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:RegisterEvent("CHAT_MSG_WHISPER")
    self.eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    
    self.eventFrame:SetScript("OnUpdate", function(_, elapsed)
        if self.isRunning then
            self.internalTimer = self.internalTimer + elapsed
            if self.internalTimer >= 60 then
                self:PostLFM()
                self.internalTimer = 0
            end
        end
    end)

    self.eventFrame:SetScript("OnEvent", function(_, event, text, sender)
        if event == "CHAT_MSG_WHISPER" then
            self:HandleWhisper(text, sender)
        elseif event == "GROUP_ROSTER_UPDATE" then
            self:CheckGroupLevel()
        end
    end)
end

function RaidOrganizer:BuildUI()
    local function Sep(y)
        local l = self.frame:CreateTexture(nil, "ARTWORK")
        l:SetSize(220, 1); l:SetPoint("TOP", 0, y); l:SetColorTexture(1, 1, 1, 0.15)
    end
    self.tankInput = self:CreateRoleInput("Tanks needed:", -60)
    self.healInput = self:CreateRoleInput("Heals needed:", -90)
    self.dpsInput  = self:CreateRoleInput("DPS needed:", -120)
    self.tankInput:SetText("1"); self.healInput:SetText("1"); self.dpsInput:SetText("3")
    Sep(-145)
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
    Sep(-185)
    local rLev = self:CreateRadio("Leveling", 30, -195, self.activityRadios, function() self.adType = "LFM MS Leveling" end)
    rLev:SetChecked(true)
    self:CreateRadio("Gold Farm", 140, -195, self.activityRadios, function() self.adType = "LFM MS Gold" end)
    self.btn = CreateFrame("Button", "RO_MainBtn", self.frame, "GameMenuButtonTemplate")
    self.btn:SetPoint("BOTTOM", 0, 25); self.btn:SetSize(140, 30); self.btn:SetText("Start Search")
    self.btn:SetScript("OnClick", function() self:ToggleSearch() end)
end

local myRO = RaidOrganizer:New()
SLASH_RAIDORGANIZER1 = "/ro"
SlashCmdList["RAIDORGANIZER"] = function()
    if myRO.frame:IsShown() then myRO.frame:Hide() else myRO.frame:Show() end
end
