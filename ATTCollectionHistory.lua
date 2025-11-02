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

-- AddOn Compartment Click
function ATTCollectionHistory_Click(self, button)
    app.PrintHistory("session")
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
        if ts and ts >= startTime then
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
SLASH_ATTCOLLECTIONHISTORY2 = "/attcollectionhistory";
SlashCmdList["ATTCOLLECTIONHISTORY"] = function(msg)
    local filter = msg:match("^(%S+)")
    app.PrintHistory(filter)
end

ATTC.AddEventHandler("OnThingCollected", function(typeORt)
    if type(typeORt) == "table" then
		if not typeORt or not typeORt.collectible then return end

        -- Record collection to collection history table in SavedVariables
        table.insert(ATTCollectionHistoryDB.history, {
            text = typeORt.text,
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
