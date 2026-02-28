local appName, app = ...    -- App name and app table
local L = app.L;	-- Localisation table
if GetLocale() == "enUS" then
    L["Hide minimap icon"] = "Hide minimap icon";
    L["Hide minimap icon tooltip"] = "Hide the minimap icon for this addon. You can still access the settings by typing \"/attch settings\" or by using the addon compartment.";
    L["Left-click to open collection history window"] = "Left-click to open collection history window";
    L["Right-click to open settings"] = "Right-click to open settings";
end