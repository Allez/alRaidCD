
-- Config start
local anchor = "TOPLEFT"
local x, y = 170, -20
local width, height = 150, 15
local spacing = 1
local bar_backdrop = false
local backdrop_color = {0, 0, 0, 0.5}
local border_color = {0, 0, 0, 1}
local texture = "Interface\\TargetingFrame\\UI-StatusBar"
-- Config end


local spells = {
	[GetSpellInfo(48477)] = 600,	-- Rebirth
	[GetSpellInfo(47883)] = 900,	-- Soulstone
	[GetSpellInfo(6346)]  = 180,	-- Fear Ward
	[GetSpellInfo(29166)] = 180,	-- Innervate
	[GetSpellInfo(32182)] = 300,	-- Heroism
	[GetSpellInfo(2825)]  = 300,	-- Bloodlust
	[GetSpellInfo(20608)] = 900,	-- Reincarnation
}

local backdrop = {
	bgFile = [=[Interface\ChatFrame\ChatFrameBackground]=],
	edgeFile = [=[Interface\ChatFrame\ChatFrameBackground]=], edgeSize = 1,
	insets = {top = 0, left = 0, bottom = 0, right = 0},
}

local bars = {}

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
	local curTime = GetTime()
	if self.endTime < curTime then
		StopTimer(self)
		return
	end
	self:SetValue(100 - (curTime - self.startTime) / (self.endTime - self.startTime) * 100)
end

local StartTimer = function(unit, spell)
	local bar = CreateFrame("Statusbar", nil, UIParent)
	bar:SetSize(width, height)
	bar:SetStatusBarTexture(texture)
	bar:SetMinMaxValues(0, 100)
	if bar_backdrop then
		bar.bg = CreateFrame("frame", nil, bar)
		bar.bg:SetPoint("TOPLEFT", -1, 1)
		bar.bg:SetPoint("BOTTOMRIGHT", 1, -1)
		bar.bg:SetBackdrop(backdrop)
		bar.bg:SetBackdropColor(unpack(backdrop_color))
		bar.bg:SetBackdropBorderColor(unpack(border_color))
	end
	bar.endTime = GetTime() + spells[spell]
	bar.startTime = GetTime()
	bar.name = bar:CreateFontString(nil, 'OVERLAY')
	bar.name:SetFont(GameFontNormal:GetFont(), 12, 'OUTLINE')
	bar.name:SetPoint('LEFT', 2, 0)
	bar.name:SetJustifyH('LEFT')
	bar.name:SetText(UnitName(unit))
	bar:Show()
	local color = RAID_CLASS_COLORS[select(2, UnitClass(unit))]
	bar:SetStatusbarColor(color.r, color.g, color.b)
	bar:SetScript("OnUpdate", BarUpdate)
	tinsert(bars, bar)
	UpdatePositions()
end

local OnEvent = function(self, event, ...)
	if event == "UNIT_SPELLCAST_SUCCEEDED" then
		local unit, spell = ...
		if spells[spell] and unit:find('raid') then
			StartTimer(unit, spell)
		end 
	end
end

local addon = CreateFrame("frame")
addon:SetScript('OnEvent', OnEvent)
addon:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")

SlashCmdList["RaidCD"] = function(msg) 
	StartTimer('player', GetSpellInfo(48477))
	StartTimer('player', GetSpellInfo(29166))
	StartTimer('player', GetSpellInfo(32182))
end
SLASH_EnemyCD1 = "/raidcd"
