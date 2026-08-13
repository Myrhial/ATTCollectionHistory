-- Initialisation
local appName, app = ...						-- App name and app table
app.L = app.L or {}								-- Localisation table
local L = app.L									-- Localisation table
app.api = {}									-- Api table for our app
ATTCollectionHistory = app.api  				-- Api namespace
local api = app.api								-- Api prefix for easier access
app.Name = "AllTheThings Collection History"	-- Do not localize

-- Event registration
local event = CreateFrame("Frame")
event:SetScript("OnEvent", function(self, eventName, ...)
	if self[eventName] then
		self[eventName](self, ...)
	end
end)
event:RegisterEvent("ADDON_LOADED")
event:RegisterEvent("HEIRLOOMS_UPDATED")

-- Initial load
function app.Initialise()
	-- Declare SavedVariables
	if not ATTCollectionHistoryDB then
		ATTCollectionHistoryDB = {}
	end

	-- Default collection history table
	if not ATTCollectionHistoryDB.history then
		ATTCollectionHistoryDB.history = {}
	end
	if not ATTCollectionHistoryDB.windowPosition then
		ATTCollectionHistoryDB.windowPosition = { ["left"] = 500, ["bottom"] = 500, ["width"] = 400, ["height"] = 400 }
	end
	if ATTCollectionHistoryDB.windowLocked == nil then
		ATTCollectionHistoryDB.windowLocked = false
	end
	if ATTCollectionHistoryDB.windowVisible == nil then
		ATTCollectionHistoryDB.windowVisible = false
	end
	if ATTCollectionHistoryDB.hide == nil then
		ATTCollectionHistoryDB.hide = false
	end
end

-- Minimap icon
function app.MinimapIcon()
	local LDB = LibStub("LibDataBroker-1.1")
	local icon = LDB:NewDataObject(appName, {
		type = "data source",
		text = app.Name,
		icon = "Interface\\AddOns\\ATTCollectionHistory\\ATTCollectionHistory.blp",
		OnClick = function(frame, button)
			if button == "RightButton" then
				app.OpenSettings()
			else
				app.ShowHistoryWindow()
			end
		end,
		OnTooltipShow = function(tooltip)
			tooltip:AddLine(app.Name)
			tooltip:AddLine(L["Left-click to open collection history window"])
			tooltip:AddLine(L["Right-click to open settings"])
		end,
	})

	app.MinimapIcon = LibStub("LibDBIcon-1.0")
	app.MinimapIcon:Register(appName, icon, ATTCollectionHistoryDB)
end

-- Addon is loaded
function event:ADDON_LOADED(addOnName, containsBindings)
	if addOnName == appName then
		app.Initialise()
		app.Settings()
		app.MinimapIcon()
		if ATTCollectionHistoryDB.windowVisible then
			app.CreateHistoryWindow()
			-- Too soon to do this, wait for event to fire
			--ATTCH_HistoryFrame:ApplyWindowColors()
			ATTCH_HistoryFrame:UpdateSummary()
			ATTCH_HistoryFrame:UpdateHistory()
			ATTCH_HistoryFrame:Show()
		end
	end
end

-- Helper: Parse date string to timestamp
local function ParseDateString(dateStr)
	local y, m, d, H, M, S = dateStr:match("^(%d+)%-(%d+)%-(%d+) (%d+):(%d+):(%d+)$")
	if y and m and d and H and M and S then
		return time{year=tonumber(y), month=tonumber(m), day=tonumber(d), hour=tonumber(H), min=tonumber(M), sec=tonumber(S)}
	end
	return nil
end

-- Helper: Format date for display
local function FormatDateForDisplay(ts)
	if not ts then
		return nil
	end
	local d = date("*t", ts)
	return FormatShortDate(d.day, d.month, d.year)
end

-- Helper: Format date and time for display (unused, but kept for potential future use)
local function FormatDateTimeForDisplay(ts)
	local dateText = FormatDateForDisplay(ts)
	if not dateText then
		return nil
	end
	return dateText .. " " .. date("%H:%M:%S", ts)
end

-- Helper: Get start time for filter
local function GetFilterStartTime(filter)
	local now = time()
	local d = date("*t", now)
	if filter == "session" then
		return app.sessionStart or now
	elseif filter == "day" then
		return time{year=d.year, month=d.month, day=d.day, hour=0}
	elseif filter == "week" then
		local wday = d.wday -- 1=Sunday, 2=Monday, ..., 7=Saturday
		-- Calculate days since Monday (if today is Monday, wday=2, so offset=0)
		local offset = (wday == 1) and 6 or (wday - 2)
		local startDay = now - offset * 86400
		local start = date("*t", startDay)
		return time{year=start.year, month=start.month, day=start.day, hour=0}
	elseif filter == "month" then
		return time{year=d.year, month=d.month, day=1, hour=0}
	end
	return 0
end

-- Helper: Count entries since a given timestamp
local function CountSince(startTime)
	local count = 0
	local history = ATTCollectionHistoryDB.history or {}
	for index = #history, 1, -1 do
		local timestamp = history[index].collectedAt and ParseDateString(history[index].collectedAt)
		if timestamp then
			if timestamp < startTime then break end
			count = count + 1
		end
	end
	return count
end

local summaryCache

-- Helper: Get summary period starts (today, week, month)
local function GetSummaryPeriodStarts()
	local now = time()
	local d = date("*t", now)
	return time{ year = d.year, month = d.month, day = d.day, hour = 0, min = 0, sec = 0 },
		GetFilterStartTime("week"),
		time{ year = d.year, month = d.month, day = 1, hour = 0, min = 0, sec = 0 }
end

-- Helper: Get summary counts (today, week, month)
local function GetSummaryCounts()
	local todayStart, weekStart, monthStart = GetSummaryPeriodStarts()
	if summaryCache and summaryCache.todayStart == todayStart and summaryCache.weekStart == weekStart and summaryCache.monthStart == monthStart then
		return summaryCache.today, summaryCache.week, summaryCache.month
	end

	summaryCache = {
		todayStart = todayStart,
		weekStart = weekStart,
		monthStart = monthStart,
		today = 0,
		week = 0,
		month = 0,
	}
	for _, entry in ipairs(ATTCollectionHistoryDB.history or {}) do
		local timestamp = entry.collectedAt and ParseDateString(entry.collectedAt)
		if timestamp then
			if timestamp >= todayStart then summaryCache.today = summaryCache.today + 1 end
			if timestamp >= weekStart then summaryCache.week = summaryCache.week + 1 end
			if timestamp >= monthStart then summaryCache.month = summaryCache.month + 1 end
		end
	end
	return summaryCache.today, summaryCache.week, summaryCache.month
end

-- Helper: Update summary cache when adding/removing an entry
local function UpdateSummaryCache(entry, change)
	if not summaryCache then return end

	local todayStart, weekStart, monthStart = GetSummaryPeriodStarts()
	if summaryCache.todayStart ~= todayStart or summaryCache.weekStart ~= weekStart or summaryCache.monthStart ~= monthStart then
		summaryCache = nil
		return
	end

	local timestamp = entry.collectedAt and ParseDateString(entry.collectedAt)
	if not timestamp then return end
	if timestamp >= todayStart then summaryCache.today = summaryCache.today + change end
	if timestamp >= weekStart then summaryCache.week = summaryCache.week + change end
	if timestamp >= monthStart then summaryCache.month = summaryCache.month + change end
end

-------------------------------------------------------------------------------
-- History window construction helpers
-------------------------------------------------------------------------------

local function CreateMainFrame()
	local frame = CreateFrame("Frame", "ATTCH_HistoryFrame", UIParent, "BackdropTemplate")
	frame:SetBackdrop({
		bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
		edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	frame:SetSize(ATTCollectionHistoryDB.windowPosition.width, ATTCollectionHistoryDB.windowPosition.height)
	frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", ATTCollectionHistoryDB.windowPosition.left, ATTCollectionHistoryDB.windowPosition.bottom)
	frame:SetClampedToScreen(true)
	frame:SetResizable(true)
	frame:SetResizeBounds(200, 200, 800, 800)
	frame:SetToplevel(true)
	return frame
end

local function CreateTitleBar(frame)
	local title = frame:CreateFontString(nil, "OVERLAY")
	title:SetFontObject("GameFontHighlight")
	title:SetFontHeight(16)
	title:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -10)
	title:SetText("ATT Collection History")
end

local function CreateSummary(frame)
	frame.summaryText = frame:CreateFontString(nil, "OVERLAY")
	frame.summaryText:SetFontObject("GameFontHighlight")
	frame.summaryText:SetFontHeight(12)
	frame.summaryText:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -30)
end

local function CreateScrollArea(frame)
	local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "ScrollFrameTemplate")
	scrollFrame:SetPoint("TOPLEFT", 5, -45)
	scrollFrame:SetPoint("BOTTOMRIGHT", -20, 10)

	scrollFrame.ScrollBar.Back:Hide()
	scrollFrame.ScrollBar.Forward:Hide()
	scrollFrame.ScrollBar:ClearAllPoints()
	scrollFrame.ScrollBar:SetPoint("TOP", scrollFrame, 0, 40)
	scrollFrame.ScrollBar:SetPoint("RIGHT", scrollFrame, 12, 0)
	scrollFrame.ScrollBar:SetPoint("BOTTOM", scrollFrame, 0, -20)

	local content = CreateFrame("Frame", nil, scrollFrame)
	content:SetSize(1, 1)
	scrollFrame:SetScrollChild(content)

	frame.content = content
	frame.scrollFrame = scrollFrame
end

local function CreateCloseButton(frame)
	frame.close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	frame.close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -3, -2)
	frame.close:SetSize(20, 20)
	frame.close:SetScript("OnClick", function()
		frame:Hide()
		ATTCollectionHistoryDB.windowVisible = false
	end)
end

local function CreateResizeCorner(frame)
	local corner = CreateFrame("Button", nil, frame)
	corner:EnableMouse("true")
	corner:SetPoint("BOTTOMRIGHT")
	corner:SetSize(20, 20)
	corner:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
	corner:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	corner:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	corner:SetScript("OnMouseDown", function() frame:StartSizing("BOTTOMRIGHT") end)
	corner:SetScript("OnMouseUp", function() frame:SavePosition() end)
	frame.corner = corner
end

local function CreateLockButtons(frame)
	local lockButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	lockButton:SetPoint("TOPRIGHT", frame.close, "TOPLEFT", -1, 0)
	lockButton:SetSize(20, 20)
	lockButton:SetNormalTexture("Interface\\AddOns\\ATTCollectionHistory\\assets\\buttons.blp")
	lockButton:GetNormalTexture():SetTexCoord(183/256, 219/256, 1/128, 39/128)
	lockButton:SetDisabledTexture("Interface\\AddOns\\ATTCollectionHistory\\assets\\buttons.blp")
	lockButton:GetDisabledTexture():SetTexCoord(183/256, 219/256, 41/128, 79/128)
	lockButton:SetPushedTexture("Interface\\AddOns\\ATTCollectionHistory\\assets\\buttons.blp")
	lockButton:GetPushedTexture():SetTexCoord(183/256, 219/256, 81/128, 119/128)
	frame.lockButton = lockButton

	local unlockButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	unlockButton:SetPoint("TOPRIGHT", frame.close, "TOPLEFT", -1, 0)
	unlockButton:SetSize(20, 20)
	unlockButton:SetNormalTexture("Interface\\AddOns\\ATTCollectionHistory\\assets\\buttons.blp")
	unlockButton:GetNormalTexture():SetTexCoord(148/256, 184/256, 1/128, 39/128)
	unlockButton:SetDisabledTexture("Interface\\AddOns\\ATTCollectionHistory\\assets\\buttons.blp")
	unlockButton:GetDisabledTexture():SetTexCoord(148/256, 184/256, 41/128, 79/128)
	unlockButton:SetPushedTexture("Interface\\AddOns\\ATTCollectionHistory\\assets\\buttons.blp")
	unlockButton:GetPushedTexture():SetTexCoord(148/256, 184/256, 81/128, 119/128)
	frame.unlockButton = unlockButton

	lockButton:SetScript("OnClick", function() frame:SetLocked(true) end)
	unlockButton:SetScript("OnClick", function() frame:SetLocked(false) end)
end

-------------------------------------------------------------------------------
-- Frame methods
-------------------------------------------------------------------------------

local function AttachFrameMethods(frame)
	-- SetLocked: single source of truth for lock/unlock state
	function frame:SetLocked(locked)
		ATTCollectionHistoryDB.windowLocked = locked
		frame:EnableMouse(not locked)
		frame:SetMovable(not locked)
		if locked then
			frame:RegisterForDrag()
			frame:SetScript("OnDragStart", nil)
			frame:SetScript("OnDragStop", nil)
			frame.corner:Hide()
			frame.lockButton:Hide()
			frame.unlockButton:Show()
		else
			frame:RegisterForDrag("LeftButton")
			frame:SetScript("OnDragStart", frame.StartMoving)
			frame:SetScript("OnDragStop", function() frame:SavePosition() end)
			frame.corner:Show()
			frame.lockButton:Show()
			frame.unlockButton:Hide()
		end
	end

	function frame:SavePosition()
		frame:StopMovingOrSizing()
		local left = frame:GetLeft()
		local bottom = frame:GetBottom()
		local width, height = frame:GetSize()
		ATTCollectionHistoryDB.windowPosition = { left = left, bottom = bottom, width = width, height = height }
	end

	-- Sync with ATT settings for colors, with safe fallback
	function frame:ApplyWindowColors()
		local rBg, gBg, bBg, aBg, rBd, gBd, bBd, aBd
		if ATTC and ATTC.Settings and ATTC.Settings.GetWindowColors then
			rBg, gBg, bBg, aBg, rBd, gBd, bBd, aBd = ATTC.Settings.GetWindowColors()
		end
		if not rBg then
			rBg, gBg, bBg, aBg = 0, 0, 0, 0.9
			rBd, gBd, bBd, aBd = 1, 1, 1, 1
		end
		frame:SetBackdropColor(rBg, gBg, bBg, aBg)
		frame:SetBackdropBorderColor(rBd, gBd, bBd, aBd)
		return rBg ~= nil
	end

	function frame:UpdateSummary()
		local todayCount, weekCount, monthCount = GetSummaryCounts()
		local totalCount = #(ATTCollectionHistoryDB.history or {})

		frame.summaryText:SetText(("Today: %d | Week: %d | Month: %d | Total: %d"):format(todayCount, weekCount, monthCount, totalCount))
	end

	function frame:UpdateHistory()
		local content = frame.content

		-- Hide old rows (reuse pool)
		if content.lines then
			for _, btn in ipairs(content.lines) do
				btn:Hide()
			end
		end
		content.lines = {}

		local y = 0
		local history = ATTCollectionHistoryDB and ATTCollectionHistoryDB.history or {}

		if #history == 0 then
			if not content.noData then
				content.noData = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
				content.noData:SetFontHeight(14)
				content.noData:SetPoint("TOPLEFT", 5, y)
				content.noData:SetText("No collection history found.")
			end
			content.noData:Show()
			content:SetHeight(30)
			return
		end
		if content.noData then content.noData:Hide() end

		local lastDate
		local lineIndex = 1
		for i = #history, 1, -1 do
			local entry = history[i]
			local entryText = entry.text or "[Missing text]"
			local ts = entry.collectedAt and ParseDateString(entry.collectedAt)
			local entryDate = ts and date("%Y-%m-%d", ts)
			if not entryDate and entry.collectedAt and type(entry.collectedAt) == "string" then
				entryDate = entry.collectedAt:match("^(%d%d%d%d%-%d%d%-%d%d)")
			end
			entryDate = entryDate or "Unknown date"

			if entryDate ~= lastDate then
				-- Add an empty spacer after the previous day's entries (except before the first header)
				if lastDate then
					local spacer = content.lines[lineIndex]
					if not spacer then
						spacer = CreateFrame("Frame", nil, content)
						spacer:SetSize(340, 8)
						content.lines[lineIndex] = spacer
					end
					spacer:SetPoint("TOPLEFT", 5, y)
					spacer:Show()
					y = y - 8
					lineIndex = lineIndex + 1
				end

				-- Add a bigger header for the new date
				local header = content.lines[lineIndex]
				if not header then
					header = CreateFrame("Frame", nil, content)
					header:SetSize(340, 22)
					header.text = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
					header.text:SetFontHeight(14)
					header.text:SetPoint("LEFT")
					header.text:SetTextColor(1, 0.82, 0) -- gold/yellow
					content.lines[lineIndex] = header
				else
					header.text:SetFontObject(GameFontHighlightLarge)
					header.text:SetFontHeight(14)
					header.text:SetTextColor(1, 0.82, 0)
				end
				header:SetPoint("TOPLEFT", 5, y)
				header:Show()
				header.text:SetText(FormatDateForDisplay(ts) or entryDate)
				y = y - 22
				lineIndex = lineIndex + 1
				lastDate = entryDate
			end

			-- Add the entry line
			local btn = content.lines[lineIndex]
			if not btn then
				btn = CreateFrame("Button", nil, content)
				btn:SetSize(340, 16)
				btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
				btn.text:SetFontHeight(12)
				btn.text:SetPoint("LEFT")
				btn:SetFontString(btn.text)
				btn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
				btn:SetScript("OnEnter", function(self)
					if self.link and self.link:find("|H") then
						GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
						GameTooltip:SetHyperlink(self.link)
						GameTooltip:Show()
					end
				end)
				btn:SetScript("OnLeave", function(self)
					GameTooltip:Hide()
				end)
				content.lines[lineIndex] = btn
			end
			btn:SetPoint("TOPLEFT", 5, y)
			btn:Show()
			btn.link = entry.text
			local displayCollectedAt = date("%H:%M:%S", ts) or "??:??:??"
			btn.text:SetText(displayCollectedAt .. " - " .. entryText)
			y = y - 16
			lineIndex = lineIndex + 1
		end
		content:SetHeight(-y + 10)
	end
end

-------------------------------------------------------------------------------
-- Public window API
-------------------------------------------------------------------------------

-- Create the history window (no-op if already exists)
function app.CreateHistoryWindow()
	if ATTCH_HistoryFrame then
		return
	end

	local frame = CreateMainFrame()
	CreateTitleBar(frame)
	CreateSummary(frame)
	CreateScrollArea(frame)
	CreateCloseButton(frame)
	CreateResizeCorner(frame)
	CreateLockButtons(frame)
	AttachFrameMethods(frame)

	-- Apply initial lock state (sets drag, movability, button visibility)
	frame:SetLocked(ATTCollectionHistoryDB.windowLocked)

	frame:UpdateSummary()
	frame:UpdateHistory()
	ATTCH_HistoryFrame = frame
end

-- Show the history window, creating it if needed
function app.ShowHistoryWindow()
	app.CreateHistoryWindow()
	ATTCH_HistoryFrame:ApplyWindowColors()
	ATTCH_HistoryFrame:UpdateSummary()
	ATTCH_HistoryFrame:UpdateHistory()
	ATTCH_HistoryFrame:Show()
	ATTCollectionHistoryDB.windowVisible = true
end

-- Hide the history window
function app.HideHistoryWindow()
	if ATTCH_HistoryFrame then
		ATTCH_HistoryFrame:Hide()
	end
	ATTCollectionHistoryDB.windowVisible = false
end

-- Refresh the history window if it is currently visible
function app.UpdateHistoryWindow()
	if ATTCH_HistoryFrame and ATTCH_HistoryFrame:IsShown() then
		ATTCH_HistoryFrame:UpdateSummary()
		ATTCH_HistoryFrame:UpdateHistory()
	end
end

-- Open settings
function app.OpenSettings()
	Settings.OpenToCategory(app.Category:GetID())
end

-------------------------------------------------------------------------------
-- Addon Compartment callbacks
-------------------------------------------------------------------------------

function ATTCollectionHistory_Click(addOnName, button)
	if button == "RightButton" then
		app.OpenSettings()
	else
		app.ShowHistoryWindow()
	end
end

function ATTCollectionHistory_OnEnter(addOnName, button)
	MenuUtil.ShowTooltip(button, function(tooltip)
		tooltip:SetText(app.Name, 1, 1, 1)
		tooltip:AddLine(L["Left-click to open collection history window"])
		tooltip:AddLine(L["Right-click to open settings"])
	end)
end

function ATTCollectionHistory_OnLeave(addOnName, button)
	MenuUtil.HideTooltip(button)
end

-------------------------------------------------------------------------------
-- Print history to chat
-------------------------------------------------------------------------------

-- Record session start
app.sessionStart = time()

-- Enhanced PrintHistory with filter and daily headers
function app.PrintHistory(filter)
	local filterText = ""
	if filter and filter ~= "" then
		filterText = " (" .. filter:lower() .. ")"
	end
	print("AllTheThings Collection History" .. filterText .. ":")

	if not ATTCollectionHistoryDB or not ATTCollectionHistoryDB.history or #ATTCollectionHistoryDB.history == 0 then
		print("No collection history found.")
		return
	end

	filter = filter and filter:lower()
	local startTime = filter and GetFilterStartTime(filter) or 0
	print("Count: " .. CountSince(startTime))

	local lastDate = nil
	local found = false -- Track if any entry matches filter
	for _, value in ipairs(ATTCollectionHistoryDB.history) do
		local entryText = value.text or "[Missing text]"
		local ts = value.collectedAt and ParseDateString(value.collectedAt)
		if not ts then
			print("Warning: Malformed date string", value.collectedAt, "for", entryText)
		elseif ts >= startTime then
			local entryDate = date("%Y-%m-%d", ts)
			if lastDate ~= entryDate then
				print("---- " .. (FormatDateForDisplay(ts) or entryDate) .. " ----")
				lastDate = entryDate
			end
			print(entryText, "collected at", date("%H:%M:%S", ts) or "??:??:??")
			found = true
		end
	end
	if not found then
		print("No filtered collection history found.")
	end
end

-------------------------------------------------------------------------------
-- Slash command
-------------------------------------------------------------------------------

SLASH_ATTCOLLECTIONHISTORY1 = "/attch"
SlashCmdList["ATTCOLLECTIONHISTORY"] = function(msg)
	local filter = msg:match("^(%S+)")
	if filter == "show" then
		app.ShowHistoryWindow()
		return
	end
	if filter == "settings" then
		app.OpenSettings()
		return
	end
	if filter == "session" or filter == "day" or filter == "week" or filter == "month" then
		app.PrintHistory(filter)
		return
	end
	if not filter or filter == "" then
		app.PrintHistory("session")
		return
	end
	print("Usage: /attch [session|day||week|month|show|settings]")
end

-------------------------------------------------------------------------------
-- ATT event handlers
-------------------------------------------------------------------------------

ATTC.AddEventHandler("OnThingCollected", function(typeORt)
	--ATTC.PrintTable(typeORt)

	if type(typeORt) == "table" then
		-- Following the ATT logic
		if not typeORt or not typeORt.collectible then return end

		local base = typeORt.base or typeORt

		local thingType = "Unknown"
		if type(base) == "function" then
			thingType = base(typeORt, "__type")
		elseif type(base) == "table" and base.__type ~= nil then
			thingType = base.__type
		end

		-- Record collection to collection history table in SavedVariables
		local text = typeORt.text or typeORt.link or typeORt.name or "[Unknown collectible]"
		local entry = {
			text = text,
			collectedAt = date("%Y-%m-%d %H:%M:%S"),
			type = thingType,
		}
		table.insert(ATTCollectionHistoryDB.history, entry)
		UpdateSummaryCache(entry, 1)
	else
		-- Heirlooms (upgrades only) go here: see workaround below
	end

	app.UpdateHistoryWindow()
end)

ATTC.AddEventHandler("OnStartup", function()
	if ATTCH_HistoryFrame and ATTCH_HistoryFrame.ApplyWindowColors then
		ATTCH_HistoryFrame:ApplyWindowColors()
	end
end)

ATTC.AddEventHandler("Settings.OnSet", function(context, setting, value)
	if (context == "General" and (setting == "Window:BackgroundColor" or setting == "Window:BorderColor")) or (context == "Tooltips" and setting == "Window:UseClassForBorder") then
		if ATTCH_HistoryFrame and ATTCH_HistoryFrame.ApplyWindowColors then
			ATTCH_HistoryFrame:ApplyWindowColors()
		end
	end
end)

-- Workaround for collecting heirlooms, since we cannot rely on the OnThingsCollected event for those
function event:HEIRLOOMS_UPDATED(itemID, updateReason, hideUntilLearned)
	if itemID then
		local name, itemLink = GetItemInfo(itemID)
		local entry = {
			text = itemLink or name or ("Heirloom " .. itemID),
			collectedAt = date("%Y-%m-%d %H:%M:%S"),
			type = "Heirlooms",
		}
		table.insert(ATTCollectionHistoryDB.history, entry)
		UpdateSummaryCache(entry, 1)

		app.UpdateHistoryWindow()
	end
end

-- OnThingRemoved
ATTC.AddEventHandler("OnThingRemoved", function(typeORt)
	if type(typeORt) == "table" then
		if not typeORt or not typeORt.collectible then return end

		-- Remove most recent entry for this collectible from collection history table
		local text = typeORt.text or typeORt.link or typeORt.name or "[Unknown collectible]"
		for i = #ATTCollectionHistoryDB.history, 1, -1 do
			if ATTCollectionHistoryDB.history[i].text == text then
				local entry = table.remove(ATTCollectionHistoryDB.history, i)
				UpdateSummaryCache(entry, -1)
				break
			end
		end

		app.UpdateHistoryWindow()
	end
end)

-------------------------------------------------------------------------------
-- Settings
-------------------------------------------------------------------------------

function app.Settings()
	-- Settings page
	local category, layout = Settings.RegisterVerticalLayoutCategory(app.Name)
	Settings.RegisterAddOnCategory(category)
	app.Category = category

	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(C_AddOns.GetAddOnMetadata(appName, "Version")))

	local CreateCheckbox = Settings.CreateCheckbox or Settings.CreateCheckBox

	local function OnSettingChanged(_, setting, value)
		local variable = setting:GetVariable()
		if strsub(variable, 1, 21) == "ATTCollectionHistory_" then
			variable = strsub(variable, 22)
		end
	end

	local function RegisterSetting(variableKey, defaultValue, name)
		local uniqueVariable = "ATTCollectionHistory_" .. variableKey
		local setting = Settings.RegisterAddOnSetting(category, uniqueVariable, variableKey, ATTCollectionHistoryDB, type(defaultValue), name, defaultValue)
		setting:SetValue(ATTCollectionHistoryDB[variableKey])
		Settings.SetOnValueChangedCallback(uniqueVariable, OnSettingChanged)
		return setting
	end

	do -- checkbox
		local variable = "hide"
		local name = L["Hide minimap icon"]
		local tooltip = L["Hide minimap icon tooltip"]
		local defaultValue = false

		local setting = RegisterSetting(variable, defaultValue, name)
		CreateCheckbox(category, setting, tooltip)
		setting:SetValueChangedCallback(function()
			if ATTCollectionHistoryDB.hide == false then
				app.MinimapIcon:Show(appName)
			else
				app.MinimapIcon:Hide(appName)
			end
		end)
	end
end