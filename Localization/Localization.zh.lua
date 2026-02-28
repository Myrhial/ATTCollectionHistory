local appName, app = ...    -- App name and app table
local L = app.L;	-- Localisation table
if GetLocale() == "zhCN" then
    L["Hide minimap icon"] = "隐藏小地图图标";
    L["Hide minimap icon tooltip"] = "隐藏此插件的小地图图标。您仍然可以通过输入\"/attch settings\"或使用插件区来访问设置。";
    L["Left-click to open collection history window"] = "左键点击打开收藏历史窗口";
    L["Right-click to open settings"] = "右键点击打开设置";
end