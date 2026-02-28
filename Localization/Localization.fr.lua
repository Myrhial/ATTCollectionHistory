local appName, app = ...    -- App name and app table
local L = app.L;	-- Localisation table
if GetLocale() == "frFR" then
    L["Hide minimap icon"] = "Masquer l'icône de la minicarte";
    L["Hide minimap icon tooltip"] = "Masquez l'icône de la minicarte pour cet addon. Vous pouvez toujours accéder aux paramètres en tapant \"/attch settings\" ou en utilisant le compartiment d'addon.";
    L["Left-click to open collection history window"] = "Clic gauche pour ouvrir la fenêtre de l'historique de collection";
    L["Right-click to open settings"] = "Clic droit pour ouvrir les paramètres";
end