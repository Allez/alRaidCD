-- Config start
local anchor = "TOPLEFT"
local x, y = 31, -300
local width, height = 110, 14
local spacing = 5
local icon_size = 14
local font = 'Fonts\\VisitorR.TTF'
local font_size = 10
local font_style = 'OUTLINEMONOCHROME'
local backdrop_color = {0, 0, 0, 0.4}
local border_color = {0, 0, 0, 1}
local show_icon = true
local texture = "Interface\\TargetingFrame\\UI-StatusBar"
local show = {
	raid = true,
	party = true,
	arena = true,
}
-- Config end

local config = {
	["Bar width"] = width,
	["Bar height"] = height,
	["Bar spacing"] = spacing,
	["Font"] = font,
	["Font size"] = font_size,
	["Font style"] = font_style,
	["Texture"] = texture,
	["Show icon"] = show_icon,
	["Icon size"] = icon_size,
}
if UIConfig then
	UIConfig["Raid cooldowns"] = config
end

local spells = {
	[20484] = 600,	-- Rebirth
	[6203] = 900,	-- Soulstone
	[6346] = 180,	-- Fear Ward
	[29166] = 180,	-- Innervate
	[32182] = 300,	-- Heroism
	[2825] = 300,	-- Bloodlust
}

local filter = COMBATLOG_OBJECT_AFFILIATION_RAID + COMBATLOG_OBJECT_AFFILIATION_PARTY + COMBATLOG_OBJECT_AFFILIATION_MINE
local band = bit.band
local sformat = string.format
local floor = math.floor
local timer = 0

local backdrop = {
	bgFile = [=[Interface\ChatFrame\ChatFrameBackground]=],
	edgeFile = [=[Interface\ChatFrame\ChatFrameBackground]=], edgeSize = 1,
	insets = {top = 0, left = 0, bottom = 0, right = 0},
}

local bars = {}

local anchorframe = CreateFrame("Frame", "RaidCD", UIParent)
anchorframe:SetSize(width, height)
anchorframe:SetPoint(anchor, x, y)
if UIMovableFrames then tinsert(UIMovableFrames, anchorframe) end

local FormatTime = function(time)
	if time >= 60 then
		return sformat('%.2d:%.2d', floor(time / 60), time % 60)
	else
		return sformat('%.2d', time)
	end
end

local CreateFS = function(frame)
	local fstring = frame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
	fstring:SetFont(config["Font"], config["Font size"], config["Font style"])
	fstring:SetShadowColor(0, 0, 0, 1)
	fstring:SetShadowOffset(0, 0)
	return fstring
end

local CreateBG = CreateBG or function(parent)
	local bg = CreateFrame("Frame", nil, parent)
	bg:SetPoint("TOPLEFT", parent, "TOPLEFT", -1, 1)
	bg:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 1, -1)
	bg:SetFrameStrata("LOW")
	bg:SetBackdrop(backdrop)
	bg:SetBackdropColor(unpack(backdrop_color))
	bg:SetBackdropBorderColor(unpack(border_color))
	return bg
end

local UpdatePositions = function()
	for i = 1, #bars do
		bars[i]:ClearAllPoints()
		if i == 1 then
			bars[i]:SetPoint("TOPLEFT", anchorframe, 0, 0)
		else
			bars[i]:SetPoint("TOPLEFT", bars[i-1], "BOTTOMLEFT", 0, -config["Bar spacing"])
		end
		bars[i].id = i
	end
end

local StopTimer = function(bar)
	bar:SetScript("OnUpdate", nil)
	bar:Hide()
	tremove(bars, bar.id)
	UpdatePositions()
end

local BarUpdate = function(self, elapsed)
	local curTime = GetTime()
	if self.endTime < curTime then
		StopTimer(self)
		return
	end
	self:SetValue(100 - (curTime - self.startTime) / (self.endTime - self.startTime) * 100)
	self.right:SetText(FormatTime(self.endTime - curTime))
end

local OnEnter = function(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:AddLine(self.spell)
	GameTooltip:SetClampedToScreen(true)
	GameTooltip:Show()
end

local OnLeave = function(self)
	GameTooltip:Hide()
end

local OnMouseDown = function(self, button)
	if button == "LeftButton" then
		SendChatMessage(sformat("Cooldown %s %s: %s", self.left:GetText(), self.spell, self.right:GetText()), "RAID")
	elseif button == "RightButton" then
		StopTimer(self)
	end
end

local CreateBar = function()
	local bar = CreateFrame("Statusbar", nil, UIParent)
	bar:SetSize(config["Bar width"], config["Bar height"])
	bar:SetStatusBarTexture(config["Texture"])
	bar:SetMinMaxValues(0, 100)
	bar.bg = CreateBG(bar)
	bar.left = CreateFS(bar)
	bar.left:SetPoint('LEFT', 2, 1)
	bar.left:SetJustifyH('LEFT')
	bar.right = CreateFS(bar)
	bar.right:SetPoint('RIGHT', -2, 1)
	bar.right:SetJustifyH('RIGHT')
	bar.icon = CreateFrame("button", nil, bar)
	bar.icon:SetSize(config["Icon size"], config["Icon size"])
	bar.icon:SetPoint("BOTTOMRIGHT", bar, "BOTTOMLEFT", -5, 0)
	bar.icon.bg = CreateBG(bar.icon)
	return bar
end

local StartTimer = function(name, spellId)
	local bar = CreateBar()
	local spell, rank, icon = GetSpellInfo(spellId)
	bar.endTime = GetTime() + spells[spellId]
	bar.startTime = GetTime()
	bar.left:SetText(name)
	bar.right:SetText(FormatTime(spells[spellId]))
	if icon then
		bar.icon:SetNormalTexture(icon)
		bar.icon:GetNormalTexture():SetTexCoord(0.07, 0.93, 0.07, 0.93)
	end
	bar.spell = spell
	bar:Show()
	local color = RAID_CLASS_COLORS[select(2, UnitClass(name))]
	bar:SetStatusBarColor(color.r, color.g, color.b)
	bar:SetScript("OnUpdate", BarUpdate)
	bar:EnableMouse(true)
	bar:SetScript("OnEnter", OnEnter)
	bar:SetScript("OnLeave", OnLeave)
	bar:SetScript("OnMouseDown", OnMouseDown)
	tinsert(bars, bar)
	UpdatePositions()
end

local OnEvent = function(self, event, ...)
	if event == "COMBAT_LOG_EVENT_UNFILTERED" then
		local timestamp, eventType, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags = ...
		if band(sourceFlags, filter) == 0 then return end
		if eventType == "SPELL_RESURRECT" or eventType == "SPELL_CAST_SUCCESS" then
			local spellId = select(9, ...)
			if spells[spellId] and show[select(2, IsInInstance())] then
				StartTimer(sourceName, spellId)
			end
		end
	elseif event == "ZONE_CHANGED_NEW_AREA" and select(2, IsInInstance()) == "arena" then
		for k, v in pairs(bars) do
			StopTimer(v)
		end
	end
end

local addon = CreateFrame("frame")
addon:SetScript('OnEvent', OnEvent)
addon:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
addon:RegisterEvent("ZONE_CHANGED_NEW_AREA")

SlashCmdList["RaidCD"] = function(msg) 
	StartTimer(UnitName('player'), 20484)
	StartTimer(UnitName('player'), 6203)
	StartTimer(UnitName('player'), 6346)
end
SLASH_RaidCD1 = "/raidcd"