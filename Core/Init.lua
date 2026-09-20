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
	UmbraUnitFramesDB.layout = UmbraUnitFramesDB.layout or Umbra.defaultLayout

	if UmbraUnitFramesDB.hideBlizzardAuras == nil then
		UmbraUnitFramesDB.hideBlizzardAuras = false
	end
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

		-- oUF writes both of these as string.format('%d', ...) over a
		-- percentage. If the percentage is hidden and string.format refuses
		-- it, the frames throw on every health tick rather than misprinting,
		-- so these two ask the real tag rather than reasoning about it.
		report('tag [perhp]', function()
			return ns.oUF.Tags.Methods['perhp']('player')
		end)
		report('tag [perpp]', function()
			return ns.oUF.Tags.Methods['perpp']('player')
		end)

		-- Whether the aura underline can be colored at all: without the
		-- PreserveAsset style the client has no way to hand a dispel color to
		-- a texture of ours, and every line stays neutral.
		print(PREFIX .. 'aura underline: ' .. (Umbra.hasAuraUnderline and
			'|cff88cc88available|r' or '|cffcc6666unavailable|r'))

	elseif input:find('^layout') then
		local name = input:match('^layout%s+(%S+)$')

		if not name then
			print(PREFIX .. 'layout: ' .. Umbra:LayoutName())
			print(PREFIX .. 'classic — top left, pet above the player')
			print(PREFIX .. 'modern — lower third, buffs above the frame')
		elseif not Umbra.layouts[name] then
			print(PREFIX .. 'no such layout: ' .. name)
		else
			UmbraUnitFramesDB.layout = name
			Umbra:ApplyLayout()
			print(PREFIX .. 'layout: ' .. name)
		end
	elseif input == 'blizzard' then
		local hide = not UmbraUnitFramesDB.hideBlizzardAuras
		UmbraUnitFramesDB.hideBlizzardAuras = hide

		Umbra:SetBlizzardAuras(not hide)
		print(PREFIX .. (hide
			and "Blizzard's buff and debuff frames hidden."
			or "Blizzard's buff and debuff frames restored."))
	elseif input == 'debug' then
		Umbra.debug = not Umbra.debug
		print(PREFIX .. 'debug ' .. (Umbra.debug and 'on' or 'off'))
	else
		local client = Umbra.isForever and 'Forever' or Umbra.isRetail and 'Retail' or 'unsupported'
		print(PREFIX .. ('%s — %s (interface %d)'):format(Umbra.version, client, interface))
		print(PREFIX .. 'layout · unlock · lock · reset · blizzard · check · debug')
	end
end
