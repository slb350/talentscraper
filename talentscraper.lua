-- TalentScraper - A World of Warcraft addon to display popular talent builds

local addonName, ns = ...
local TalentScraper = CreateFrame("Frame", "TalentScraperFrame", UIParent)

-- Create namespaces
ns.UI = {}     -- UI-related functions
ns.Data = {}   -- Data handling functions
ns.Utils = {}  -- Utility functions

-- Register all events at once
local EVENTS = {
    "ADDON_LOADED",
    "PLAYER_ENTERING_WORLD",
    "ENCOUNTER_START",
    "PLAYER_SPECIALIZATION_CHANGED",
    "PLAYER_TARGET_CHANGED",
    "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED"
}

for _, event in ipairs(EVENTS) do
    TalentScraper:RegisterEvent(event)
end

-- Local state variables
local playerClass, playerSpecIndex, playerSpecID, currentBossID

-- Default saved variables
TalentScraperDB = TalentScraperDB or {
    enabled = true,            -- Master toggle for addon functionality
    dataSource = "archon",     -- Source of talent data
    showWarningOnTargetBoss = true, -- Show warning when targeting a boss with wrong spec
    warningThreshold = 30,     -- How long to show warnings in seconds
    mainFramePosition = {"CENTER", UIParent, "CENTER", 0, 0},
    frameWidth = 350,
    frameHeight = 400,
    lastUpdated = 0,
    cacheTimeout = 86400,      -- 24 hours in seconds
    preferredDifficulty = "normal", -- Default to normal difficulty
    manualSpecID = nil,        -- For manually selecting a different spec
    manualBossID = nil,        -- For manually selecting a boss
    currentBossID = nil        -- Current boss ID for reference
}

-- Boss ID mapping
ns.Data.bossIDs = {
    -- The Undermine raid bosses
    [3009] = "Vexie and the Geargrinders",
    [3010] = "Cauldron of Carnage", 
    [3011] = "Rik Reverb",
    [3012] = "Stix Bunkjunker",
    [3013] = "Lockenstock",
    [3014] = "One-Armed Bandit",
    [3015] = "Mug'Zee, Heads of Security",
    [3016] = "Chrome King Gallywix",
}

-- Fallback talent data (minimal example)
ns.Data.fallbackTalentData = {
    [2635] = { -- Gnarlroot
        ["WARRIOR"] = {
            [1] = { -- Arms
                title = "Single Target DPS",
                talents = "BEQAAAAAAAAAAAAAAAAAAAAAAAAAAAAQSEJJJkkkWSiIJBAAAAAAAAAAAAAAAAQigkQSkIRJJB"
            },
        },
        ["MAGE"] = {
            [2] = { -- Fire 
                title = "Mythic Progression",
                talents = "BEkAAAAAAAAAAAAAAAAAAAAAAAAAAAAJJRSQikWpkkQSSiAAAAAAAAAAAAAAAAAAAAIFRkEhEJB"
            },
        },
    },
}

-- Spec ID mappings
local specMappings = {
    ["DEATHKNIGHT"] = {[250] = 1, [251] = 2, [252] = 3},
    ["DEMONHUNTER"] = {[577] = 1, [581] = 2},
    ["DRUID"] = {[102] = 1, [103] = 2, [104] = 3, [105] = 4},
    ["EVOKER"] = {[1467] = 1, [1468] = 2, [1473] = 3},
    ["HUNTER"] = {[253] = 1, [254] = 2, [255] = 3},
    ["MAGE"] = {[62] = 1, [63] = 2, [64] = 3},
    ["MONK"] = {[268] = 1, [270] = 2, [269] = 3},
    ["PALADIN"] = {[65] = 1, [66] = 2, [70] = 3},
    ["PRIEST"] = {[256] = 1, [257] = 2, [258] = 3},
    ["ROGUE"] = {[259] = 1, [260] = 2, [261] = 3},
    ["SHAMAN"] = {[262] = 1, [263] = 2, [264] = 3},
    ["WARLOCK"] = {[265] = 1, [266] = 2, [267] = 3},
    ["WARRIOR"] = {[71] = 1, [72] = 2, [73] = 3}
}

-- Talent data will be loaded from external file
TalentScraper.TalentData = TalentScraper.TalentData or {}

-- UTILITY FUNCTIONS --------------------------------------------------

-- Convert WoW spec ID to our index
function ns.Utils.GetSpecIndexFromID(class, specID)
    return specMappings[class] and specMappings[class][specID] or 1
end

-- Get spec ID from index
function ns.Utils.GetSpecIDFromIndex(specIndex)
    return specIndex and select(1, GetSpecializationInfo(specIndex))
end

-- Get current player's spec ID
function ns.Utils.GetCurrentSpecID()
    local specIndex = GetSpecialization()
    return ns.Utils.GetSpecIDFromIndex(specIndex)
end

-- Print debug information
function ns.Utils.PrintDebugInfo()
    local currentSpecID = TalentScraperDB.manualSpecID or ns.Utils.GetCurrentSpecID()
    local bossID = currentBossID or TalentScraperDB.manualBossID or TalentScraperDB.currentBossID
    local specIndex = ns.Utils.GetSpecIndexFromID(playerClass, currentSpecID)
    
    print("--- TalentScraper Debug Info ---")
    print("Current Boss ID:", bossID)
    print("Player Class:", playerClass)
    print("Current Spec ID:", currentSpecID)
    print("Converted to Spec Index:", specIndex)
    
    if bossID and TalentScraper.TalentData[bossID] then
        print("Available class data for boss", bossID, ":")
        for class, _ in pairs(TalentScraper.TalentData[bossID]) do
            print("  -", class)
        end
        
        if TalentScraper.TalentData[bossID][playerClass] then
            print("Available specs for", playerClass, ":")
            for specIdx, _ in pairs(TalentScraper.TalentData[bossID][playerClass]) do
                print("  -", specIdx)
            end
        end
    end
    
    print("------------------------------")
end

-- DATA FUNCTIONS -----------------------------------------------------

-- Fetch talent data from our data tables
function ns.Data.FetchTalentData(bossID, playerClass, specID, difficulty)
    -- Default to user's preferred difficulty
    difficulty = difficulty or TalentScraperDB.preferredDifficulty or "normal"
    
    -- Validate inputs
    if not bossID or not playerClass or not specID then
        return {
            title = "Incomplete data",
            talents = "Missing required information"
        }
    end
    
    -- Convert WoW spec ID to our index
    local specIndex = ns.Utils.GetSpecIndexFromID(playerClass, specID)
    
    -- First, try to use the data from the TalentData file
    if TalentScraper.TalentData[bossID] and 
       TalentScraper.TalentData[bossID][playerClass] and 
       TalentScraper.TalentData[bossID][playerClass][specIndex] then
        
        local data = TalentScraper.TalentData[bossID][playerClass][specIndex]
        
        -- Check if the data matches the requested difficulty
        local dataSource = data.source or ""
        if not dataSource:lower():match(difficulty:lower()) then
            -- Try to find data for the requested difficulty in other boss entries
            for otherBossID, bossData in pairs(TalentScraper.TalentData) do
                if bossData[playerClass] and 
                   bossData[playerClass][specIndex] and
                   (bossData[playerClass][specIndex].source or ""):lower():match(difficulty:lower()) then
                    return {
                        title = bossData[playerClass][specIndex].title,
                        talents = bossData[playerClass][specIndex].talents
                    }
                end
            end
            
            -- If we can't find data for the exact difficulty, just use what we have
            return {
                title = data.title,
                talents = data.talents
            }
        end
        
        return {
            title = data.title,
            talents = data.talents
        }
    end
    
    -- If we don't have data from the file, fall back to the default data
    if ns.Data.fallbackTalentData[bossID] and 
       ns.Data.fallbackTalentData[bossID][playerClass] and 
       ns.Data.fallbackTalentData[bossID][playerClass][specIndex] then
        return {
            title = ns.Data.fallbackTalentData[bossID][playerClass][specIndex].title,
            talents = ns.Data.fallbackTalentData[bossID][playerClass][specIndex].talents
        }
    end
    
    -- If no data is found, return a default message
    return {
        title = "No data available",
        talents = "No talent code found for this spec on this boss"
    }
end

-- Check if target is a boss and show warning if spec doesn't match recommended
function ns.Data.CheckTargetAndWarn()
    if not TalentScraperDB.showWarningOnTargetBoss or UnitAffectingCombat("player") then 
        return 
    end
    
    -- Get target's ID
    local targetGUID = UnitGUID("target")
    if not targetGUID then return end
    
    local _, _, _, _, _, npcID = strsplit("-", targetGUID)
    npcID = tonumber(npcID)
    
    -- Check if target is a known boss
    for bossID, bossName in pairs(ns.Data.bossIDs) do
        if npcID and npcID == bossID then
            -- Get player's current spec
            local currentSpecID = ns.Utils.GetCurrentSpecID()
            local currentSpecIndex = ns.Utils.GetSpecIndexFromID(playerClass, currentSpecID)
            
            -- Check if there's data for other specs that might be better
            local playerClass = select(2, UnitClass("player"))
            local foundBetterSpec = false
            local recommendedSpecs = {}
            
            -- Check all specs for this class
            for i = 1, GetNumSpecializations() do
                local specID = ns.Utils.GetSpecIDFromIndex(i)
                local specIndex = ns.Utils.GetSpecIndexFromID(playerClass, specID)
                
                -- Skip current spec
                if specID ~= currentSpecID then
                    local specData = ns.Data.FetchTalentData(bossID, playerClass, specID)
                    -- If we found actual data for this spec
                    if specData and specData.title and specData.title ~= "No data available" then
                        foundBetterSpec = true
                        local _, specName = GetSpecializationInfo(i)
                        table.insert(recommendedSpecs, specName)
                    end
                end
            end
            
            -- If we found other specs with data but current spec has no data
            local currentSpecData = ns.Data.FetchTalentData(bossID, playerClass, currentSpecID)
            if foundBetterSpec and currentSpecData and currentSpecData.title == "No data available" then
                -- Show warning about possible spec change
                if TalentScraper.warningFrame then
                    TalentScraper.warningFrame.timer = 0  -- Reset the timer
                    
                    -- Set message
                    local message = "You're targeting " .. bossName .. " but your current spec doesn't have recommended talents.\n\n"
                    if #recommendedSpecs > 0 then
                        message = message .. "Recommended specs: " .. table.concat(recommendedSpecs, ", ")
                    end
                    
                    TalentScraper.warningFrame.message:SetText(message)
                    TalentScraper.warningFrame:Show()
                end
                
                -- Update talent data but don't show the main frame
                TalentScraperDB.currentBossID = bossID
            end
            
            -- Exit after checking the first matching boss
            break
        end
    end
end

-- Handle slash commands
local function HandleSlashCommand(msg)
    msg = msg:lower()
    
    if msg == "show" then
        -- Create UI if it doesn't exist yet
        if not TalentScraper.content then
            ns.UI.CreateMainFrame()
            -- Create warning frame
            TalentScraper.warningFrame = ns.UI.CreateWarningFrame()
        end
        
        -- Update data if we have a boss ID
        if TalentScraperDB.currentBossID or TalentScraperDB.manualBossID then
            ns.UI.UpdateTalentDisplay(TalentScraperDB.currentBossID or TalentScraperDB.manualBossID)
        end
        
        -- Make sure the frame is shown
        TalentScraper:Show()
        return
    elseif msg == "hide" then
        TalentScraper:Hide()
    elseif msg == "toggle" then
        if TalentScraper:IsShown() then
            TalentScraper:Hide()
        else
            -- Create UI if it doesn't exist yet
            if not TalentScraper.content then
                ns.UI.CreateMainFrame()
                -- Create warning frame
                TalentScraper.warningFrame = ns.UI.CreateWarningFrame()
            end
            
            if TalentScraperDB.currentBossID or TalentScraperDB.manualBossID then
                ns.UI.UpdateTalentDisplay(TalentScraperDB.currentBossID or TalentScraperDB.manualBossID)
            end
            TalentScraper:Show()
        end
    elseif msg == "refresh" then
        if TalentScraperDB.currentBossID then
            ns.UI.UpdateTalentDisplay(TalentScraperDB.currentBossID)
            TalentScraper:Show()
        else
            print("|cFF33FF99TalentScraper:|r No boss selected to refresh")
        end
    elseif msg:match("^boss %d+$") then
        local bossID = tonumber(msg:match("boss (%d+)"))
        if bossID then
            -- Create UI if it doesn't exist yet
            if not TalentScraper.content then
                ns.UI.CreateMainFrame()
                -- Create warning frame
                TalentScraper.warningFrame = ns.UI.CreateWarningFrame()
            end
            
            ns.UI.UpdateTalentDisplay(bossID)
            TalentScraper:Show()
        end
    elseif msg == "config" or msg == "options" then
        print("|cFF33FF99TalentScraper:|r Config panel not yet implemented")
    elseif msg == "debug" or msg == "info" then
        ns.Utils.PrintDebugInfo()
    else
        print("|cFF33FF99TalentScraper:|r Available commands:")
        print("  /ts show - Show the main window")
        print("  /ts hide - Hide the main window")
        print("  /ts toggle - Toggle window visibility")
        print("  /ts refresh - Refresh data for current boss")
        print("  /ts boss [id] - Show data for specific boss ID")
        print("  /ts debug - Show debug information")
        print("  /ts config - Open configuration (not yet implemented)")
    end
end

-- Main event handler
TalentScraper:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == addonName then
            -- Create the main UI
            ns.UI.CreateMainFrame()
            
            -- Create warning frame
            TalentScraper.warningFrame = ns.UI.CreateWarningFrame()
            
            -- If we have a saved boss ID, load it but don't show
            if TalentScraperDB.manualBossID then
                TalentScraperDB.currentBossID = TalentScraperDB.manualBossID
            end
            
            print("|cFF33FF99TalentScraper|r loaded. Type /ts for commands.")
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Update player class and spec info
        playerClass = select(2, UnitClass("player"))
        playerSpecIndex = GetSpecialization()
        playerSpecID = ns.Utils.GetSpecIDFromIndex(playerSpecIndex)
        
        -- If we're not using a manual spec selection and we have a boss ID, update the data
        if not TalentScraperDB.manualSpecID and currentBossID then
            ns.UI.UpdateTalentDisplay(currentBossID)
        end
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        local unit = ...
        if unit == "player" then
            -- Update player spec info
            playerSpecIndex = GetSpecialization()
            playerSpecID = ns.Utils.GetSpecIDFromIndex(playerSpecIndex)
            
            -- Only update data if we're using current spec (not manual selection)
            if not TalentScraperDB.manualSpecID and currentBossID then
                ns.UI.UpdateTalentDisplay(currentBossID)
            end
        end
    elseif event == "ENCOUNTER_START" then
        local encounterId = ...
        currentBossID = encounterId
        TalentScraperDB.currentBossID = encounterId
        -- Simply store the boss ID, no auto-show
    elseif event == "PLAYER_TARGET_CHANGED" then
        -- Check if target is a boss and show warning if needed
        ns.Data.CheckTargetAndWarn()
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Entering combat - hide the frame
        if TalentScraper:IsShown() then
            TalentScraper.wasVisibleBeforeCombat = true
            TalentScraper:Hide()
        else
            TalentScraper.wasVisibleBeforeCombat = false
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Exiting combat - restore previous visibility
        if TalentScraper.wasVisibleBeforeCombat then
            TalentScraper:Show()
        end
    end
end)

-- Register slash commands
SLASH_TALENTSCRAPER1 = "/talentscraper"
SLASH_TALENTSCRAPER2 = "/ts"
SlashCmdList["TALENTSCRAPER"] = HandleSlashCommand

-- Expose the TalentScraper global frame so it can be referenced in UI.lua
_G.TalentScraper = TalentScraper