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
	elseif input == 'check' then
		-- Which unit values this client hands over in the clear decides how
		-- much of the display can be formatted at all.
		local function state(value)
			return Umbra.Secrets.Is(value) and '|cffcc6666hidden|r' or '|cff88cc88readable|r'
		end

		print(PREFIX .. 'UnitHealth: ' .. state(UnitHealth('player')))
		print(PREFIX .. 'UnitHealthMax: ' .. state(UnitHealthMax('player')))
		print(PREFIX .. 'UnitHealthPercent: ' ..
			state(UnitHealthPercent('player', true, CurveConstants.ScaleTo100)))
	elseif input == 'debug' then
		Umbra.debug = not Umbra.debug
		print(PREFIX .. 'debug ' .. (Umbra.debug and 'on' or 'off'))
	else
		local client = Umbra.isForever and 'Forever' or Umbra.isRetail and 'Retail' or 'unsupported'
		print(PREFIX .. ('%s — %s (interface %d)'):format(Umbra.version, client, interface))
		print(PREFIX .. 'unlock · lock · reset · check · debug')
	end
end
