
-- Config start
local anchor = "TOPLEFT"
local x, y = 185, -20
local width, height = 130, 14
local spacing = 2
local backdrop_color = {0, 0, 0, 0.4}
local border_color = {0, 0, 0, 0}
local texture = "Interface\\TargetingFrame\\UI-StatusBar"
-- Config end


local spells = {
	[GetSpellInfo(48477)] = 600,	-- Rebirth
	[GetSpellInfo(47883)] = 900,	-- Soulstone
	[GetSpellInfo(6346)]  = 180,	-- Fear Ward
	[GetSpellInfo(29166)] = 180,	-- Innervate
	[GetSpellInfo(32182)] = 300,	-- Heroism
	[GetSpellInfo(2825)]  = 300,	-- Bloodlust
	[GetSpellInfo(20608)] = 1800,	-- Reincarnation
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

local FormatTime = function(time)
	if time >= 60 then
		return sformat('%d:%d', floor(time / 60), time % 60)
	else
		return sformat('%d', time)
	end
end

local CreateFS = function(frame, fsize, fstyle)
	local fstring = frame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
	fstring:SetFont(GameFontNormal:GetFont(), fsize, fstyle)
	return fstring
end

local UpdatePositions = function()
	for i = 1, #bars do
		bars[i]:ClearAllPoints()
		if (i == 1) then
			bars[i]:SetPoint(anchor, UIParent, anchor, x, y)
		else
			bars[i]:SetPoint("TOPLEFT", bars[i-1], "BOTTOMLEFT", 0, -spacing)
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
	timer = timer + elapsed
	if timer > 0.5 then
		local curTime = GetTime()
		if self.endTime < curTime then
			StopTimer(self)
			return
		end
		self:SetValue(100 - (curTime - self.startTime) / (self.endTime - self.startTime) * 100)
		self.right:SetText(FormatTime(self.endTime - curTime))
		timer = 0
	end
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
	bar:SetSize(width, height)
	bar:SetStatusBarTexture(texture)
	bar:SetMinMaxValues(0, 100)
	bar.bg = CreateFrame("frame", nil, bar)
	bar.bg:SetPoint("TOPLEFT", 0, 0)
	bar.bg:SetPoint("BOTTOMRIGHT", 0, 0)
	bar.bg:SetBackdrop(backdrop)
	bar.bg:SetFrameStrata('LOW')
	bar.bg:SetBackdropColor(unpack(backdrop_color))
	bar.bg:SetBackdropBorderColor(unpack(border_color))
	bar.left = CreateFS(bar, 12)
	bar.left:SetPoint('LEFT', 2, 0)
	bar.left:SetJustifyH('LEFT')
	bar.right = CreateFS(bar, 12)
	bar.right:SetPoint('RIGHT', -2, 0)
	bar.right:SetJustifyH('RIGHT')
	return bar
end

local StartTimer = function(name, spell)
	local bar = CreateBar()
	bar.endTime = GetTime() + spells[spell]
	bar.startTime = GetTime()
	bar.left:SetText(name)
	bar.right:SetText(FormatTime(spells[spell]))
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
		local timestamp, eventType, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags = select(1, ...)
		if band(sourceFlags, filter) == 0 then return end
		if eventType == "SPELL_RESURRECT" or eventType == "SPELL_CAST_SUCCESS" then
			local spell = GetSpellInfo(select(9, ...))
			if spells[spell] and select(2, IsInInstance()) == 'raid' then
				StartTimer(sourceName, spell)
			end
		end
	end
end

local addon = CreateFrame("frame")
addon:SetScript('OnEvent', OnEvent)
addon:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

SlashCmdList["RaidCD"] = function(msg) 
	StartTimer(UnitName('player'), GetSpellInfo(48477))
	StartTimer(UnitName('player'), GetSpellInfo(29166))
	StartTimer(UnitName('player'), GetSpellInfo(32182))
end
SLASH_RaidCD1 = "/raidcd"
