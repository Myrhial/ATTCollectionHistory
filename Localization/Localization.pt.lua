local appName, app = ...    -- App name and app table
local L = app.L;	-- Localisation table
if GetLocale() == "ptBR" then
    L["Hide minimap icon"] = "Ocultar ícone do minimapa";
    L["Hide minimap icon tooltip"] = "Oculta o ícone do minimapa para este addon. Você ainda pode acessar as configurações digitando \"/attch settings\" ou usando o compartimento de addons.";
    L["Left-click to open collection history window"] = "Clique esquerdo para abrir a janela de histórico de coleção";
    L["Right-click to open settings"] = "Clique direito para abrir as configurações";
end