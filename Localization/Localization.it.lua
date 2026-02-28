local appName, app = ...    -- App name and app table
local L = app.L;	-- Localisation table
if GetLocale() == "itIT" then
    L["Hide minimap icon"] = "Nascondi icona minimappa";
    L["Hide minimap icon tooltip"] = "Nascondi l'icona della minimappa per questo addon. Puoi comunque accedere alle impostazioni digitando \"/attch settings\" o utilizzando il compartimento degli addon.";
    L["Left-click to open collection history window"] = "Clic sinistro per aprire la finestra della cronologia della collezione";
    L["Right-click to open settings"] = "Clic destro per aprire le impostazioni";
end