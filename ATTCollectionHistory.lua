-- Initialisation
local appName, app = ...    -- App name and app table
app.L = app.L or {} -- Localisation table
local L = app.L;	-- Localisation table
app.api = {}    -- Api table for our app
ATTCollectionHistory = app.api  -- Api namespace
local api = app.api -- Api prefix for easier access

-- Event registration
local event = CreateFrame("Frame")
event:SetScript("OnEvent", function(self, event, ...)
	if self[event] then
		self[event](self, ...)
	end
end)
event:RegisterEvent("ADDON_LOADED")

-- Initial load
function app.Initialise()
    -- Declare SavedVariables
	if not ATTCollectionHistoryDB then ATTCollectionHistoryDB = {} end

    -- Default collection history table
    if not ATTCollectionHistoryDB.history then ATTCollectionHistoryDB.history = {} end
end

-- Addon is loaded
function event:ADDON_LOADED(addOnName, containsBindings)
	if addOnName == appName then
        app.Initialise()
    end
end

-- GUI Window to show collection history
local function CreateHistoryWindow()
    if ATTCH_HistoryFrame then
        ATTCH_HistoryFrame:Show()
        return
    end

    -- Create the main frame
    local frame = CreateFrame("Frame", "ATTCH_HistoryFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(400, 400)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame.title = frame:CreateFontString(nil, "OVERLAY")
    frame.title:SetFontObject("GameFontHighlight")
    frame.title:SetPoint("LEFT", frame.TitleBg, "LEFT", 5, 0)
    frame.title:SetText("ATT Collection History")

    -- ScrollFrame
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -30)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)

    -- Content frame inside the scrollframe
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(1, 1)
    scrollFrame:SetScrollChild(content)
    frame.content = content
    frame.scrollFrame = scrollFrame

    -- Close button
    frame.close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.close:SetPoint("TOPRIGHT", frame, "TOPRIGHT")

    -- Function to update history
    function frame:UpdateHistory()
        -- Hide old buttons
        if content.lines then
            for _, btn in ipairs(content.lines) do
                btn:Hide()
            end
        else
            content.lines = {}
        end

        local y = -5
        local history = ATTCollectionHistoryDB and ATTCollectionHistoryDB.history or {}
        if #history == 0 then
            if not content.noData then
                content.noData = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                content.noData:SetPoint("TOPLEFT", 5, y)
                content.noData:SetText("No collection history found.")
            end
            content.noData:Show()
            content:SetHeight(30)
            return
        end
        if content.noData then content.noData:Hide() end

        for i = #history, 1, -1 do
            local entry = history[i]
            local btn = content.lines[i]
            if not btn then
                btn = CreateFrame("Button", nil, content)
                btn:SetSize(340, 16)
                btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                btn.text:SetPoint("LEFT")
                btn:SetFontString(btn.text)
                btn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
                btn:SetScript("OnEnter", function(self)
                    if self.link and self.link:find("|H") then
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:SetHyperlink(self.link)
                        GameTooltip:Show()
                    end
                end)
                btn:SetScript("OnLeave", function(self)
                    GameTooltip:Hide()
                end)
                content.lines[i] = btn
            end
            btn:SetPoint("TOPLEFT", 5, y)
            btn:Show()

            btn.link = entry.text -- Use the full link
            btn.text:SetText(entry.collectedAt .. " - " .. entry.text)
            y = y - 16
        end
        content:SetHeight(-y + 10)
    end

    frame:UpdateHistory()
    frame:Hide()
    ATTCH_HistoryFrame = frame
end

-- AddOn Compartment Click
function ATTCollectionHistory_Click(self, button)
    CreateHistoryWindow()
    ATTCH_HistoryFrame:UpdateHistory()
    ATTCH_HistoryFrame:Show()
end

-- Helper: Parse date string to timestamp
local function ParseDateString(dateStr)
    local y, m, d, H, M, S = dateStr:match("^(%d+)%-(%d+)%-(%d+) (%d+):(%d+):(%d+)$")
    if y and m and d and H and M and S then
        return time{year=tonumber(y), month=tonumber(m), day=tonumber(d), hour=tonumber(H), min=tonumber(M), sec=tonumber(S)}
    end
    return nil
end

-- Helper: Get start time for filter
local function GetFilterStartTime(filter)
    local now = time()
    local d = date("*t", now)
    if filter == "session" then
        return app.sessionStart or now
    elseif filter == "day" then
        return time{year=d.year, month=d.month, day=d.day, hour=0}
    elseif filter == "week" then
        local wday = d.wday -- 1=Sunday, 2=Monday, ..., 7=Saturday
        -- Calculate days since Monday (if today is Monday, wday=2, so offset=0)
        local offset = (wday == 1) and 6 or (wday - 2)
        local startDay = now - offset * 86400
        local start = date("*t", startDay)
        return time{year=start.year, month=start.month, day=start.day, hour=0}
    elseif filter == "month" then
        return time{year=d.year, month=d.month, day=1, hour=0}
    end
    return 0
end

-- Record session start
app.sessionStart = time()

-- Enhanced PrintHistory with filter and daily headers
function app.PrintHistory(filter)
    local filterText = ""
    if filter and filter ~= "" then
        filterText = " (" .. filter:lower() .. ")"
    end
    print("AllTheThings Collection History" .. filterText .. ":")

    if not ATTCollectionHistoryDB or not ATTCollectionHistoryDB.history or #ATTCollectionHistoryDB.history == 0 then
        print("No collection history found.")
        return
    end

    filter = filter and filter:lower()
    local startTime = filter and GetFilterStartTime(filter) or 0

    local lastDate = nil
    local found = false -- Track if any entry matches filter
    for _, value in ipairs(ATTCollectionHistoryDB.history) do
        local ts = ParseDateString(value.collectedAt)
        if not ts then
            print("Warning: Malformed date string", value.collectedAt, "for", value.text)
        elseif ts >= startTime then
            local entryDate = date("%Y-%m-%d", ts)
            if lastDate ~= entryDate then
                print("---- " .. entryDate .. " ----")
                lastDate = entryDate
            end
            print(value.text, "collected at", value.collectedAt)
            found = true
        end
    end
    if not found then
        print("No filtered collection history found.")
    end
end

-- Slash command with parameter
SLASH_ATTCOLLECTIONHISTORY1 = "/attch";
SlashCmdList["ATTCOLLECTIONHISTORY"] = function(msg)
    local filter = msg:match("^(%S+)")
    if filter == "show" then
        CreateHistoryWindow()
        ATTCH_HistoryFrame:UpdateHistory()
        ATTCH_HistoryFrame:Show()
        return
    end
    if filter == "session" or filter == "day" or filter == "week" or filter == "month" then
        app.PrintHistory(filter)
        return
    end
    if not filter or filter == "" then
        app.PrintHistory("session")
        return
    end
    print("Usage: /attch [session|day|week|month|show]")
end

ATTC.AddEventHandler("OnThingCollected", function(typeORt)
    if type(typeORt) == "table" then
		if not typeORt or not typeORt.collectible then return end

        -- Record collection to collection history table in SavedVariables
        local text = typeORt.text or "[Unknown collectible]"
        table.insert(ATTCollectionHistoryDB.history, {
            text = text,
            collectedAt = date("%Y-%m-%d %H:%M:%S"),
        });

        -- DEBUG: Print all own and __index and __class keys
        -- for k, v in pairs(typeORt) do
        --     print("Own:", k, v)
        -- end
        -- local mt = getmetatable(typeORt)
        -- if mt and type(mt.__class) == "table" then
        --     for k, v in pairs(mt.__class) do
        --         print("__class:", k, v)
        --     end
        -- end
	else
        print("COLLECTED A THING", typeORt);
	end
end);

-- TODO: OnThingRemoved?
