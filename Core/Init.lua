local addonName, ns = ...

local Umbra = {}
ns.Umbra = Umbra

Umbra.addonName = addonName

-- The packager substitutes this token on release; a plain checkout keeps it.
Umbra.version = C_AddOns.GetAddOnMetadata(addonName, 'Version')
if not Umbra.version or Umbra.version:find('project%-version') then
	Umbra.version = 'dev'
end

local interface = select(4, GetBuildInfo())

-- Forever runs the Mainline API but reports interface 16xxx, so a numeric
-- threshold on the interface version picks the wrong code path there.
Umbra.isMainline = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
Umbra.isForever = Umbra.isMainline and interface >= 16000 and interface < 17000
Umbra.isRetail = Umbra.isMainline and interface >= 100000

local PREFIX = '|cff75dcc4Umbra|r '

--[[ Umbra:RegisterEvent(frame, event)
Registers an event, reporting failure instead of aborting the file.

Unknown events throw on registration, and a throw at file scope stops the rest
of the file from loading. Forever is missing a number of Retail events.
--]]
function Umbra:RegisterEvent(frame, event)
	local ok = pcall(frame.RegisterEvent, frame, event)
	if not ok then
		self:Debug('event not available:', event)
	end
	return ok
end

function Umbra:Debug(...)
	if not self.debug then return end
	print(PREFIX, ...)
end

-- Forever writes saved variables but never reads them back, so an empty table
-- here is an expected state rather than a first run that needs attention.
local loader = CreateFrame('Frame')
loader:RegisterEvent('ADDON_LOADED')
loader:SetScript('OnEvent', function(self, _, loaded)
	if loaded ~= addonName then return end
	self:UnregisterEvent('ADDON_LOADED')

	UmbraUnitFramesDB = UmbraUnitFramesDB or {}
	UmbraUnitFramesDB.positions = UmbraUnitFramesDB.positions or {}
end)

SLASH_UMBRAUNITFRAMES1 = '/uuf'
SlashCmdList.UMBRAUNITFRAMES = function(input)
	input = strtrim(input or ''):lower()

	if input == 'unlock' then
		if Umbra:SetLocked(false) then
			print(PREFIX .. 'frames unlocked, drag them where you want them. /uuf lock when done.')
		else
			print(PREFIX .. 'frames cannot be moved in combat.')
		end
	elseif input == 'lock' then
		Umbra:SetLocked(true)
		print(PREFIX .. 'frames locked.')
	elseif input == 'reset' then
		Umbra:ResetPositions()
		print(PREFIX .. 'positions reset.')
	elseif input:find('^green') then
		local value = tonumber(input:match('^green%s+(%-?%d+)'))

		if value then
			UmbraUnitFramesDB.healthTint = math.max(0, math.min(100, value))

			for _, bar in ipairs(Umbra.healthBars) do
				bar:SetStatusBarColor(Umbra:HealthColor())
			end
		end

		print(PREFIX .. ('health green: %d — 0 is muted, 100 is vivid. /uuf green <0-100>')
			:format(UmbraUnitFramesDB.healthTint or 50))
	elseif input == 'numbers' then
		UmbraUnitFramesDB.rawHealth = not UmbraUnitFramesDB.rawHealth

		for _, frame in ipairs(ns.oUF.objects) do
			if frame.UpdateTags then frame:UpdateTags() end
		end

		print(PREFIX .. 'unformatted health numbers ' ..
			(UmbraUnitFramesDB.rawHealth and 'on' or 'off'))
	elseif input == 'check' then
		-- Which unit values this client hands over in the clear decides how
		-- much of the display can be formatted at all, and the tag's own
		-- output says whether that reasoning survives contact with oUF.
		local function report(label, getter)
			local ok, value = pcall(getter)

			if not ok then
				print(PREFIX .. label .. ': |cffcc6666errors|r — ' .. tostring(value))
			elseif Umbra.Secrets.Is(value) then
				print(PREFIX .. label .. ': |cffcc6666hidden|r')
			else
				print(PREFIX .. label .. ': |cff88cc88readable|r — ' .. tostring(value))
			end
		end

		print(PREFIX .. 'issecretvalue: ' .. tostring(type(_G.issecretvalue) == 'function'))
		report('UnitHealth', function() return UnitHealth('player') end)
		report('UnitHealthMax', function() return UnitHealthMax('player') end)
		report('UnitHealthPercent', function()
			return UnitHealthPercent('player', true, CurveConstants.ScaleTo100)
		end)
		report('tag [umbra:health]', function()
			return ns.oUF.Tags.Methods['umbra:health']('player')
		end)
	elseif input == 'debug' then
		Umbra.debug = not Umbra.debug
		print(PREFIX .. 'debug ' .. (Umbra.debug and 'on' or 'off'))
	else
		local client = Umbra.isForever and 'Forever' or Umbra.isRetail and 'Retail' or 'unsupported'
		print(PREFIX .. ('%s — %s (interface %d)'):format(Umbra.version, client, interface))
		print(PREFIX .. 'unlock · lock · reset · green <0-100> · numbers · check · debug')
	end
end
