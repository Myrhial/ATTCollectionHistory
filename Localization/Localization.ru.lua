local appName, app = ...    -- App name and app table
local L = app.L;	-- Localisation table
if GetLocale() == "ruRU" then
    L["Hide minimap icon"] = "Скрыть значок миникарты";
    L["Hide minimap icon tooltip"] = "Скрыть значок миникарты для этого аддона. Вы все равно можете получить доступ к настройкам, набрав \"/attch settings\" или используя отсек аддонов.";
    L["Left-click to open collection history window"] = "Левый клик для открытия окна истории коллекции";
    L["Right-click to open settings"] = "Правый клик для открытия настроек";
end