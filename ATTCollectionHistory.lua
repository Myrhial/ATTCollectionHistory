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
    app.PrintHistory()
end

function app.PrintHistory()
    print("AllTheThings Collection History:");

    if not ATTCollectionHistoryDB or not ATTCollectionHistoryDB.history or #ATTCollectionHistoryDB.history == 0 then
        print("No collection history found.");
        return;
    end

    for _, value in pairs(ATTCollectionHistoryDB.history) do
        print(value.text, "collected at", value.collectedAt);
    end
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
