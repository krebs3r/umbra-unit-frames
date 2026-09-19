local addonName, ns = ...

local Umbra = {}
ns.Umbra = Umbra

Umbra.addonName = addonName

-- The packager substitutes this token on release; a plain checkout keeps it.
Umbra.version = C_AddOn.GetAddOnMetadata(addonName, 'Version')
if not Umbra.version or Umbra.version:find('project%-version') then
	Umbra.version = 'dev'
end

local interface = select(4, GetBuildInfo())

-- Forever runs the Mainline API but reports interface 16xxx, so a numeric
-- threshold on the interface version picks the wrong code path there.
Umbra.isMainline = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
Umbra.isForever = Umbra.isMainline and interface >= 16000 and interface < 17000
Umbra.isRetail = Umbra.isMainline and interface >= 100000

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
	print('|cff75dcc4Umbra|r', ...)
end

SLASH_UMBRAUNITFRAMES1 = '/uuf'
SlashCmdList.UMBRAUNITFRAMES = function(input)
	input = strtrim(input or ''):lower()

	if input == 'debug' then
		Umbra.debug = not Umbra.debug
		print('|cff75dcc4Umbra|r debug', Umbra.debug and 'on' or 'off')
	else
		local client = Umbra.isForever and 'Forever' or Umbra.isRetail and 'Retail' or 'unsupported'
		print(('|cff75dcc4Umbra Unit Frames|r %s — %s (interface %d)'):format(
			Umbra.version, client, interface))
	end
end
