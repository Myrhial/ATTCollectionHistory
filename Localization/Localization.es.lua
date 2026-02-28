local appName, app = ...    -- App name and app table
local L = app.L;	-- Localisation table
if GetLocale() == "esES" then
    L["Hide minimap icon"] = "Ocultar icono del minimapa";
    L["Hide minimap icon tooltip"] = "Oculta el icono del minimapa para este addon. Aún puedes acceder a la configuración escribiendo \"/attch settings\" o usando el compartimento de addons.";
    L["Left-click to open collection history window"] = "Clic izquierdo para abrir la ventana de historial de colección";
    L["Right-click to open settings"] = "Clic derecho para abrir la configuración";
end