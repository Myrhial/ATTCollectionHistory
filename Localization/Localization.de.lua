local appName, app = ...    -- App name and app table
local L = app.L;	-- Localisation table
if GetLocale() == "deDE" then
    L["Hide minimap icon"] = "Minikarten-Symbol ausblenden";
    L["Hide minimap icon tooltip"] = "Blendet das Minikartensymbol für dieses Addon aus. Sie können die Einstellungen weiterhin aufrufen, indem Sie \"/attch settings\" eingeben oder das Addon-Fach verwenden.";
    L["Left-click to open collection history window"] = "Linksklick, um das Fenster der Sammlungshistorie zu öffnen";
    L["Right-click to open settings"] = "Rechtsklick, um die Einstellungen zu öffnen";
end