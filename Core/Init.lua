local addonName, ns = ...

local Umbra = {}
ns.Umbra = Umbra

Umbra.addonName = addonName
Umbra.author = C_AddOns.GetAddOnMetadata(addonName, 'Author')

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

local ACCENT = '|cff75dcc4'
local PREFIX = ACCENT .. 'Umbra|r '

--[[ HEART
The name comes from the TOC rather than from here, so it stays in one place
and this line cannot go stale by being a second copy of it.

The heart is U+2665, written as itself. This file is already UTF-8 and the
command list beside it is full of em dashes that render correctly in the
client, so the encoding is not in question. A texture would be: there is no
reliable way to ask whether a path still exists after a patch, and a missing
one prints nothing at all. Its color is `auraHarmful` from the palette, the
red this addon already uses.
--]]
local HEART = '|cffb25d5d♥|r'

--[[ Value(name) / Values(names)
A word the reader is meant to type back, in the accent color.

Only the words themselves: the `or` between two of them is prose and stays
prose, which is what keeps three accented runs on one line from reading as one
long name.
--]]
local function Value(name)
	return ACCENT .. name .. '|r'
end

local function Values(names)
	local out = {}

	for index, name in ipairs(names) do
		out[index] = Value(name)
	end

	return table.concat(out, ' or ')
end

--[[ COMMANDS
What `/uuf` on its own prints, one to a line: the command, the values it takes
if it takes any, and what it does.

A run of names separated by dots says what exists and nothing about what any
of it does, which is no help to the one person who needs the list: someone who
has forgotten. The values stay a list rather than a sentence, so that the
printing decides what is colored and the table only says what is true.
--]]
local COMMANDS = {
	{'layout', {'classic', 'modern'}, 'the whole arrangement'},
	{'auras', {'umbra', 'both'}, 'who shows your buffs and debuffs'},
	{'unlock', nil, 'drag the frames, every one of them, filled out'},
	{'lock', nil, 'put them back to work'},
	{'reset', nil, "forget this set's dragged positions"},
	{'test', nil, 'fill every aura slot with stand-ins'},
	{'check', nil, 'which unit values this client hides'},
	{'debug', nil, 'report what the build refused'},
}

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

--[[ Umbra:Debug(...)
Prints only when debugging is on, which it survives a reload to be.

Most of what there is to report is refused while the frames are being built,
at PLAYER_LOGIN — before anyone can type the command that turns this on. A
switch that did not outlive the reload could therefore never show the one
thing it exists for.
--]]
--[[ Umbra:FrameUnit(frame)
Which unit a frame stands for, asked where oUF actually keeps it.

An oUF frame has no `unit` field. `__unit` is what `Private.UpdateUnits` keeps
current and follows a vehicle swap; the secure `unit` attribute is what the
frame was told to watch and still names the seat's owner. Reaching for
`frame.unit` is what made the tooltip throw on every hover.
--]]
function Umbra:FrameUnit(frame)
	return frame.__unit or frame:GetAttribute('unit')
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

	-- ADDON_LOADED runs before the frames are built, which is the only place
	-- this can be picked up in time to report on that build.
	Umbra.debug = UmbraUnitFramesDB.debug or false
end)

SLASH_UMBRAUNITFRAMES1 = '/uuf'
SlashCmdList.UMBRAUNITFRAMES = function(input)
	input = strtrim(input or ''):lower()

	if input == 'unlock' then
		if Umbra:SetLocked(false) then
			print(PREFIX .. 'every frame shown and filled out, drag them where '
				.. 'you want them. ' .. Value('/uuf lock') .. ' when done.')
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

		-- The class-power row is reserved on the player frame whatever the
		-- class, and oUF fills it only for a spec that owns such a resource:
		-- chi on a windwalker monk but not on a brewmaster, who has none to
		-- show, and none at all before a specialization is chosen. So an
		-- empty row is two questions, and the spec has to be named or the
		-- answer is a number to be puzzled over.
		local player

		for _, frame in ipairs(ns.oUF.objects) do
			if Umbra:FrameUnit(frame) == 'player' then
				player = frame
			end
		end

		local pips = player and player.ClassPower

		if not pips then
			print(PREFIX .. 'class power: |cffcc6666no element|r')
		else
			local shown = 0

			for index = 1, #pips do
				if pips[index]:IsShown() then shown = shown + 1 end
			end

			-- A character below the level that chooses one still answers with
			-- an index, and it is not one of the real specs.
			local spec = C_SpecializationInfo.GetSpecialization()
			local ok, _, name = pcall(C_SpecializationInfo.GetSpecializationInfo, spec)

			print(PREFIX .. ('class power: %d of %d pips, %s'):format(shown, #pips,
				(ok and name) and ('%s (spec %d)'):format(name, spec)
					or 'no specialization yet'))
		end

	elseif input:find('^layout') then
		local name = input:match('^layout%s+(%S+)$')

		if not name then
			print(PREFIX .. 'layout: ' .. Value(Umbra:LayoutName()))
			print(PREFIX .. Value('classic') .. ' — top left, pet above the player')
			print(PREFIX .. Value('modern')
				.. ' — lower third, buffs above, pet under the castbar')
		elseif not Umbra.layouts[name] then
			print(PREFIX .. 'no such layout: ' .. name)
		else
			UmbraUnitFramesDB.layout = name
			Umbra:ApplyLayout()
			print(PREFIX .. 'layout: ' .. Value(name))
		end
	elseif input == 'test' then
		local show = not Umbra:PreviewShown()

		if Umbra:SetPreview(show) > 0 then
			print(PREFIX .. (show
				and 'every aura slot filled with stand-ins. ' .. Value('/uuf test') .. ' to stop.'
				or 'stand-ins off.'))
		else
			print(PREFIX .. 'nothing to fill — this client refused the aura containers.')
		end
	elseif input:find('^auras') then
		-- Named states rather than a toggle, because a toggle answers the
		-- question you did not ask: you wanted one of the two, and have to
		-- read the reply to find out which one you got.
		local which = input:match('^auras%s+(%S+)$')
		local current = UmbraUnitFramesDB.hideBlizzardAuras and 'umbra' or 'both'

		if not which then
			print(PREFIX .. 'auras: ' .. Value(current))
			print(PREFIX .. Value('umbra') .. ' — only Umbra shows them')
			print(PREFIX .. Value('both') .. " — the game keeps its own display as well")
		elseif which ~= 'umbra' and which ~= 'both' then
			print(PREFIX .. 'no such setting: ' .. which)
		else
			local hide = which == 'umbra'

			UmbraUnitFramesDB.hideBlizzardAuras = hide
			Umbra:SetBlizzardAuras(not hide)
			print(PREFIX .. 'auras: ' .. Value(which))
		end
	elseif input == 'debug' then
		Umbra.debug = not Umbra.debug
		UmbraUnitFramesDB.debug = Umbra.debug

		print(PREFIX .. 'debug ' .. (Umbra.debug and 'on' or 'off')
			.. (Umbra.debug
				and ' — ' .. Value('/reload') .. ' to see what the build refuses.'
				or ''))
	else
		local client = Umbra.isForever and 'Forever' or Umbra.isRetail and 'Retail' or 'unsupported'
		print(PREFIX .. ('%s — %s (interface %d)'):format(Umbra.version, client, interface))

		for _, entry in ipairs(COMMANDS) do
			local line = '  ' .. Value('/uuf ' .. entry[1])

			if entry[2] then
				line = line .. ' ' .. Values(entry[2])
			end

			print(line .. ' — ' .. entry[3])
		end

		if Umbra.author then
			print(('  with %s by %s'):format(HEART, Umbra.author))
		end
	end
end
