local appName, app = ...    -- App name and app table
local L = app.L;	-- Localisation table
if GetLocale() == "koKR" then
    L["Hide minimap icon"] = "미니맵 아이콘 숨기기";
    L["Hide minimap icon tooltip"] = "이 애드온의 미니맵 아이콘을 숨깁니다. \"/attch settings\"를 입력하거나 애드온 구획을 사용하여 설정에 여전히 액세스할 수 있습니다.";
    L["Left-click to open collection history window"] = "왼쪽 클릭하여 수집 기록 창 열기";
    L["Right-click to open settings"] = "오른쪽 클릭하여 설정 열기";
end