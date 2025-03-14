-- TalentScraper UI Components
-- This file should be loaded after TalentScraper.lua

local _, ns = ...

-- Create warning frame for spec mismatch
function ns.UI.CreateWarningFrame()
    local f = CreateFrame("Frame", "TalentScraperWarningFrame", UIParent)
    f:SetSize(400, 100)
    f:SetPoint("TOP", UIParent, "TOP", 0, -100)
    f:SetFrameStrata("HIGH")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    
    -- Helper function to create common UI elements
    local function CreateElement(type, parent, layer, template)
        if type == "texture" then
            return parent:CreateTexture(nil, layer or "BACKGROUND")
        elseif type == "fontstring" then
            return parent:CreateFontString(nil, layer or "OVERLAY", template or "GameFontNormal")
        elseif type == "frame" then
            return CreateFrame("Frame", nil, parent, template)
        elseif type == "button" then
            return CreateFrame("Button", nil, parent, template)
        end
    end
    
    -- Background and border
    f.bg = CreateElement("texture", f)
    f.bg:SetAllPoints()
    f.bg:SetColorTexture(0, 0, 0, 0.8)
    
    f.border = CreateElement("frame", f, nil, "BackdropTemplate")
    f.border:SetPoint("TOPLEFT", -1, 1)
    f.border:SetPoint("BOTTOMRIGHT", 1, -1)
    f.border:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4},
    })
    f.border:SetBackdropBorderColor(0.8, 0.2, 0.2, 1) -- Red for warning
    
    -- Title and messages
    f.title = CreateElement("fontstring", f, nil, "GameFontNormalLarge")
    f.title:SetPoint("TOP", f, "TOP", 0, -10)
    f.title:SetText("TalentScraper Warning")
    f.title:SetTextColor(1, 0.3, 0.3)
    
    f.message = CreateElement("fontstring", f, nil, "GameFontNormal")
    f.message:SetPoint("TOP", f.title, "BOTTOM", 0, -10)
    f.message:SetPoint("LEFT", f, "LEFT", 20, 0)
    f.message:SetPoint("RIGHT", f, "RIGHT", -20, 0)
    f.message:SetJustifyH("CENTER")
    f.message:SetText("No message")
    
    -- Buttons
    f.switchButton = CreateElement("button", f, nil, "UIPanelButtonTemplate")
    f.switchButton:SetSize(120, 22)
    f.switchButton:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 20, 10)
    f.switchButton:SetText("Switch Spec")
    f.switchButton:SetScript("OnClick", function()
        ToggleTalentUI()
        f:Hide()
    end)
    
    f.dismissButton = CreateElement("button", f, nil, "UIPanelButtonTemplate")
    f.dismissButton:SetSize(120, 22)
    f.dismissButton:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -20, 10)
    f.dismissButton:SetText("Dismiss")
    f.dismissButton:SetScript("OnClick", function() f:Hide() end)
    
    -- Timer
    f.timer = 0
    f.duration = TalentScraperDB.warningThreshold or 30
    f.timerText = CreateElement("fontstring", f, nil, "GameFontNormalSmall")
    f.timerText:SetPoint("TOP", f, "BOTTOM", 0, 5)
    f.timerText:SetTextColor(0.7, 0.7, 0.7)
    
    f:SetScript("OnUpdate", function(self, elapsed)
        self.timer = self.timer + elapsed
        if self.timer >= self.duration then
            self:Hide()
            self.timer = 0
        else
            local remaining = math.floor(self.duration - self.timer)
            self.timerText:SetText("Auto-hiding in " .. remaining .. " seconds")
        end
    end)
    
    -- Close Button
    f.closeButton = CreateElement("button", f, nil, "UIPanelCloseButton")
    f.closeButton:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    f.closeButton:SetScript("OnClick", function() f:Hide() end)
    
    f:Hide()
    return f
end

-- Create main UI frame
function ns.UI.CreateMainFrame()
    local f = TalentScraper
    f:SetSize(TalentScraperDB.frameWidth, TalentScraperDB.frameHeight)
    f:SetPoint(unpack(TalentScraperDB.mainFramePosition))
    f:SetFrameStrata("MEDIUM")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Save position
        local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
        TalentScraperDB.mainFramePosition = {point, "UIParent", relativePoint, xOfs, yOfs}
    end)
    
    -- Helper function to create common UI elements
    local function CreateElement(type, parent, layer, template)
        if type == "texture" then
            return parent:CreateTexture(nil, layer or "BACKGROUND")
        elseif type == "fontstring" then
            return parent:CreateFontString(nil, layer or "OVERLAY", template or "GameFontNormal")
        elseif type == "frame" then
            return CreateFrame("Frame", nil, parent, template)
        elseif type == "button" then
            return CreateFrame("Button", nil, parent, template)
        end
    end
    
    -- Background and border
    f.bg = CreateElement("texture", f)
    f.bg:SetAllPoints()
    f.bg:SetColorTexture(0, 0, 0, 0.8)
    
    f.border = CreateElement("frame", f, nil, "BackdropTemplate")
    f.border:SetPoint("TOPLEFT", -1, 1)
    f.border:SetPoint("BOTTOMRIGHT", 1, -1)
    f.border:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4},
    })
    f.border:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    
    -- Title bar
    f.titleBar = CreateElement("frame", f)
    f.titleBar:SetHeight(24)
    f.titleBar:SetPoint("TOPLEFT")
    f.titleBar:SetPoint("TOPRIGHT")
    
    f.titleBg = CreateElement("texture", f.titleBar)
    f.titleBg:SetAllPoints()
    f.titleBg:SetColorTexture(0.1, 0.1, 0.1, 1)
    
    f.title = CreateElement("fontstring", f.titleBar)
    f.title:SetPoint("CENTER", f.titleBar, "CENTER")
    f.title:SetText("TalentScraper")
    
    -- Close button
    f.closeButton = CreateElement("button", f, nil, "UIPanelCloseButton")
    f.closeButton:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    f.closeButton:SetScript("OnClick", function() f:Hide() end)
    
    -- Content area
    f.content = CreateElement("frame", f)
    f.content:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -30)
    f.content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 10)
    
    -- Boss and spec title
    f.bossTitle = CreateElement("fontstring", f.content, nil, "GameFontNormalLarge")
    f.bossTitle:SetPoint("TOPLEFT", f.content, "TOPLEFT", 0, 0)
    f.bossTitle:SetPoint("TOPRIGHT", f.content, "TOPRIGHT", 0, 0)
    f.bossTitle:SetJustifyH("CENTER")
    f.bossTitle:SetText("No Boss Selected")
    
    f.specTitle = CreateElement("fontstring", f.content, nil, "GameFontNormal")
    f.specTitle:SetPoint("TOPLEFT", f.bossTitle, "BOTTOMLEFT", 0, -10)
    f.specTitle:SetPoint("TOPRIGHT", f.bossTitle, "BOTTOMRIGHT", 0, -10)
    f.specTitle:SetJustifyH("CENTER")
    f.specTitle:SetText("No Spec Detected")
    
    -- Dropdowns (boss, spec, difficulty)
    -- Boss dropdown
    f.bossDropdown = CreateFrame("Frame", "TalentScraperBossDropdown", f.content, "UIDropDownMenuTemplate")
    f.bossDropdown:SetPoint("TOP", f.bossTitle, "BOTTOM", 0, -5)
    
    UIDropDownMenu_SetWidth(f.bossDropdown, 160)
    UIDropDownMenu_SetText(f.bossDropdown, "Select Boss")
    
    UIDropDownMenu_Initialize(f.bossDropdown, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        
        -- First, add raid section as header
        info.text = "Undermine"
        info.isTitle = true
        info.notCheckable = true
        UIDropDownMenu_AddButton(info, level)
        
        -- Then add bosses
        for bossID, bossName in pairs(ns.Data.bossIDs) do
            info = UIDropDownMenu_CreateInfo()
            info.text = bossName
            info.value = bossID
            info.func = function(self)
                UIDropDownMenu_SetText(f.bossDropdown, bossName)
                TalentScraperDB.manualBossID = self.value
                TalentScraperDB.currentBossID = self.value
                ns.UI.UpdateTalentDisplay(self.value)
            end
            info.notCheckable = false
            info.checked = TalentScraperDB.currentBossID == bossID
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    
    -- Spec dropdown
    f.specDropdown = CreateFrame("Frame", "TalentScraperSpecDropdown", f.content, "UIDropDownMenuTemplate")
    f.specDropdown:SetPoint("TOP", f.specTitle, "BOTTOM", 0, -5)
    
    UIDropDownMenu_SetWidth(f.specDropdown, 160)
    UIDropDownMenu_SetText(f.specDropdown, "Current Spec")
    
    UIDropDownMenu_Initialize(f.specDropdown, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        
        -- Add option for current spec
        info.text = "Current Spec"
        info.value = 0
        info.func = function(self)
            UIDropDownMenu_SetText(f.specDropdown, "Current Spec")
            TalentScraperDB.manualSpecID = nil
            if TalentScraperDB.currentBossID then
                ns.UI.UpdateTalentDisplay(TalentScraperDB.currentBossID)
            end
        end
        info.notCheckable = false
        info.checked = TalentScraperDB.manualSpecID == nil
        UIDropDownMenu_AddButton(info, level)
        
        -- Add all specs for player's class
        for i = 1, GetNumSpecializations() do
            local specID, specName = GetSpecializationInfo(i)
            if specID and specName then
                info = UIDropDownMenu_CreateInfo()
                info.text = specName
                info.value = specID
                info.func = function(self)
                    UIDropDownMenu_SetText(f.specDropdown, specName)
                    TalentScraperDB.manualSpecID = self.value
                    if TalentScraperDB.currentBossID then
                        ns.UI.UpdateTalentDisplay(TalentScraperDB.currentBossID)
                    end
                end
                info.notCheckable = false
                info.checked = TalentScraperDB.manualSpecID == specID
                UIDropDownMenu_AddButton(info, level)
            end
        end
    end)
    
    -- Difficulty dropdown
    f.difficultyDropdown = CreateFrame("Frame", "TalentScraperDifficultyDropdown", f.content, "UIDropDownMenuTemplate")
    f.difficultyDropdown:SetPoint("TOPRIGHT", f.content, "TOPRIGHT", -20, -60)
    
    UIDropDownMenu_SetWidth(f.difficultyDropdown, 100)
    UIDropDownMenu_SetText(f.difficultyDropdown, TalentScraperDB.preferredDifficulty:gsub("^%l", string.upper))
    
    UIDropDownMenu_Initialize(f.difficultyDropdown, function(self, level)
        local difficulties = {"normal", "heroic", "mythic"}
        local info = UIDropDownMenu_CreateInfo()
        
        for i, diff in ipairs(difficulties) do
            info.text = diff:gsub("^%l", string.upper)
            info.value = diff
            info.func = function(self)
                UIDropDownMenu_SetText(f.difficultyDropdown, self.value:gsub("^%l", string.upper))
                TalentScraperDB.preferredDifficulty = self.value
                if TalentScraperDB.currentBossID then
                    ns.UI.UpdateTalentDisplay(TalentScraperDB.currentBossID)
                end
            end
            info.checked = TalentScraperDB.preferredDifficulty == diff
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    
    -- Build info
    f.buildTitle = CreateElement("fontstring", f.content, nil, "GameFontHighlight")
    f.buildTitle:SetPoint("TOPLEFT", f.difficultyDropdown, "BOTTOMLEFT", -10, -15)
    f.buildTitle:SetPoint("TOPRIGHT", f.difficultyDropdown, "BOTTOMRIGHT", 10, -15)
    f.buildTitle:SetJustifyH("CENTER")
    f.buildTitle:SetText("No Build Data")
    
    -- Talent code box
    f.talentBox = CreateFrame("EditBox", nil, f.content, "InputBoxTemplate")
    f.talentBox:SetPoint("TOPLEFT", f.buildTitle, "BOTTOMLEFT", 0, -20)
    f.talentBox:SetPoint("TOPRIGHT", f.buildTitle, "BOTTOMRIGHT", 0, -20)
    f.talentBox:SetHeight(24)
    f.talentBox:SetAutoFocus(false)
    f.talentBox:SetText("No talent code available")
    f.talentBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    
    -- Action buttons
    f.copyButton = CreateElement("button", f.content, nil, "UIPanelButtonTemplate")
    f.copyButton:SetSize(100, 22)
    f.copyButton:SetPoint("TOP", f.talentBox, "BOTTOM", 0, -10)
    f.copyButton:SetText("Copy Code")
    f.copyButton:SetScript("OnClick", function()
        f.talentBox:SetFocus()
        f.talentBox:HighlightText()
    end)
    
    f.refreshButton = CreateElement("button", f.content, nil, "UIPanelButtonTemplate")
    f.refreshButton:SetSize(100, 22)
    f.refreshButton:SetPoint("TOP", f.copyButton, "BOTTOM", 0, -5)
    f.refreshButton:SetText("Refresh Data")
    f.refreshButton:SetScript("OnClick", function()
        if TalentScraperDB.currentBossID then
            ns.UI.UpdateTalentDisplay(TalentScraperDB.currentBossID)
        end
    end)
    
    -- Debug button (hidden by default)
    f.debugButton = CreateElement("button", f.content, nil, "UIPanelButtonTemplate")
    f.debugButton:SetSize(100, 22)
    f.debugButton:SetPoint("TOP", f.refreshButton, "BOTTOM", 0, -5)
    f.debugButton:SetText("Debug Info")
    f.debugButton:Hide() -- Hidden by default
    f.debugButton:SetScript("OnClick", function()
        ns.Utils.PrintDebugInfo()
    end)
    
    -- Status text
    f.statusText = CreateElement("fontstring", f.content, nil, "GameFontNormalSmall")
    f.statusText:SetPoint("BOTTOMLEFT", f.content, "BOTTOMLEFT", 0, 0)
    f.statusText:SetPoint("BOTTOMRIGHT", f.content, "BOTTOMRIGHT", 0, 0)
    f.statusText:SetJustifyH("CENTER")
    f.statusText:SetTextColor(0.5, 0.5, 0.5)
    f.statusText:SetText("Last Updated: Never")
    
    -- Hide frame initially
    f:Hide()
    
    return f
end

-- Update talent display with data for a boss
function ns.UI.UpdateTalentDisplay(bossID)
    if not bossID then return end
    
    TalentScraperDB.currentBossID = bossID
    local playerClass = select(2, UnitClass("player"))
    
    -- Use manually selected spec ID if set, otherwise use current spec
    local playerSpecID
    if TalentScraperDB.manualSpecID then
        playerSpecID = TalentScraperDB.manualSpecID
        -- Find the spec name based on the ID
        local specName = "Unknown Spec"
        for i = 1, GetNumSpecializations() do
            local id, name = GetSpecializationInfo(i)
            if id == playerSpecID then
                specName = name
                break
            end
        end
        -- Update dropdown text if it exists
        if TalentScraper and TalentScraper.specDropdown then
            UIDropDownMenu_SetText(TalentScraper.specDropdown, specName)
        end
    else
        local playerSpecIndex = GetSpecialization()
        playerSpecID = ns.Utils.GetSpecIDFromIndex(playerSpecIndex)
        -- Get spec name from current spec
        local _, specName = GetSpecializationInfo(playerSpecIndex)
        -- Update dropdown text if it exists
        if TalentScraper and TalentScraper.specDropdown then
            UIDropDownMenu_SetText(TalentScraper.specDropdown, "Current Spec")
        end
    end
    
    -- Get boss name
    local bossName = ns.Data.bossIDs[bossID] or EJ_GetEncounterInfo(bossID) or "Unknown Boss"
    
    -- Update boss dropdown
    if TalentScraper and TalentScraper.bossDropdown then
        UIDropDownMenu_SetText(TalentScraper.bossDropdown, bossName)
    end
    
    -- Update the frame title
    if TalentScraper and TalentScraper.bossTitle then
        TalentScraper.bossTitle:SetText(bossName)
    end
    
    -- Get spec name
    local specName = "Unknown Spec"
    if TalentScraperDB.manualSpecID then
        for i = 1, GetNumSpecializations() do
            local id, name = GetSpecializationInfo(i)
            if id == playerSpecID then
                specName = name
                break
            end
        end
    else
        local playerSpecIndex = GetSpecialization()
        _, specName = GetSpecializationInfo(playerSpecIndex)
    end
    
    if TalentScraper and TalentScraper.specTitle then
        TalentScraper.specTitle:SetText(specName .. " " .. playerClass)
    end
    
    -- Fetch talent data
    local buildData = ns.Data.FetchTalentData(bossID, playerClass, playerSpecID, TalentScraperDB.preferredDifficulty)
    
    -- Update UI with build data
    if TalentScraper then
        if TalentScraper.buildTitle then
            TalentScraper.buildTitle:SetText(buildData.title or "No Build Title")
        end
        
        if TalentScraper.talentBox then
            TalentScraper.talentBox:SetText(buildData.talents or "No talent code available")
        end
        
        -- Update status text
        if TalentScraper.statusText then
            local timestamp = date("%Y-%m-%d %H:%M:%S")
            TalentScraperDB.lastUpdated = time()
            TalentScraper.statusText:SetText("Last Updated: " .. timestamp)
        end
    end
    
    -- Save the current boss ID for future reference
    TalentScraperDB.manualBossID = bossID
    
    -- No automatic display - removed auto-show code
end