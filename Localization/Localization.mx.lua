local appName, app = ...    -- App name and app table
local L = app.L;	-- Localisation table
if GetLocale() == "esMX" then
    L["Hide minimap icon"] = "Ocultar icono del minimapa";
    L["Hide minimap icon tooltip"] = "Oculta el icono del minimapa para este addon. Aún puedes acceder a la configuración escribiendo \"/attch settings\" o usando el menú de accesorios en el minimapa.";
    L["Left-click to open collection history window"] = "Click izquierdo para abrir la ventana del historial de colección";
    L["Right-click to open settings"] = "Click derecho para abrir la configuración";
end