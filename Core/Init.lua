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

--[[ Umbra.hasSecureSnippets
Whether the client can compile a secure snippet at all.

`loadstring_untainted` is what turns a string of Lua into a function without
tainting it, and the whole secure-snippet machinery rests on it: state
drivers, `RunAttribute`, `initialConfigFunction` — which is to say secure
group headers and click-casting. Without it, group frames need a static
fallback.

This asks the question on **every** client, not only on Forever. It used to
live in `Compat/Forever.lua`, which returns early on anything else and is not
even listed in the Retail TOC, so on Retail the flag was nil: false by
accident rather than by measurement, and it would have stayed false if Retail
ever got the function back.
--]]
Umbra.hasSecureSnippets = type(_G.loadstring_untainted) == 'function'

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

--[[ Umbra:Debug(...)
Writes a line down always, and prints it only when debugging is on.

Most of what there is to report is refused while the frames are being built,
at PLAYER_LOGIN, before anyone can type the command that turns printing on.
Saving the switch was the first answer to that, and it is not enough: **the
Forever beta writes saved variables but never reads them back**, measured on
20 September 2026 by setting `/uuf layout classic`, reloading, and finding
`modern` again. On that client a saved switch is always off at login, which
is exactly when the build happens.

So the lines are kept whether or not anyone is listening, and `/uuf debug`
hands over what it already missed. That asks nothing of the client and works
the same everywhere.
--]]
local log = {}
local LOG_LIMIT = 60

function Umbra:Debug(...)
	local parts = {}

	for index = 1, select('#', ...) do
		parts[index] = tostring((select(index, ...)))
	end

	local line = table.concat(parts, ' ')

	log[#log + 1] = line

	-- A run that refuses everything must not grow without end.
	if #log > LOG_LIMIT then
		table.remove(log, 1)
	end

	if self.debug then
		print(PREFIX .. line)
	end
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

		-- What decides whether group frames can have a secure header or need
		-- a static fallback. Asked here rather than reasoned about, because
		-- the answer has changed between clients and patches.
		print(PREFIX .. 'secure snippets: ' .. (Umbra.hasSecureSnippets and
			'|cff88cc88available|r' or '|cffcc6666unavailable|r'))

		-- Whether a compatibility file ran all the way through. Retail loads
		-- none and says so; on Forever, `none` would mean the file that
		-- reports this client's deviations never finished, which makes an
		-- empty debug buffer mean nothing at all.
		print(PREFIX .. 'compat: ' .. (Umbra.compat
			and ('|cff88cc88' .. Umbra.compat .. '.lua ran|r')
			or '|cff88cc88none|r'))

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
			-- an index, and it is not one of the real specs. Measured on a
			-- level 3 monk: index 5, and GetSpecializationInfo answers for it
			-- with an id but an **empty name** rather than nothing at all, so
			-- a plain nil check prints a blank and calls it a specialization.
			local spec = C_SpecializationInfo.GetSpecialization()
			local ok, _, name = pcall(C_SpecializationInfo.GetSpecializationInfo, spec)

			if not ok or name == nil or name == '' then
				name = nil
			end

			print(PREFIX .. ('class power: %d of %d pips, %s'):format(shown, #pips,
				name and ('%s (spec %s)'):format(name, tostring(spec))
					or ('no specialization yet (spec %s)'):format(tostring(spec))))
		end

		--[[ Why a portrait column can come up empty
		The 3D models went missing on the enemy frame *inside* an instance and
		not outside it, which is the shape of a restricted value rather than
		of a broken anchor — the frame, its ground and its tint are all
		explicitly placed and do not care what the unit is.

		oUF chooses between the unit's own model and a question mark on
		`UnitIsConnected and UnitIsVisible`, then calls `SetUnit`. So the
		first thing to know is whether either of those two is hidden where
		this happens, and the second is whether a model was loaded at all.
		Both go through `report`, because either one may come back hidden and
		`tostring` on a hidden value is the throw this command exists to
		avoid.

		A model file of nil with a readable `UnitIsVisible` means SetUnit was
		reached and answered with nothing, which is a different fault from a
		branch that never took.

		**Every frame answers, including one with nothing behind it.** The
		first version printed only for frames with a live unit, and the run
		that mattered came back with no target line at all — which is the
		empty debug buffer again: silence that could mean the portrait failed,
		or that nothing was targeted when the command was typed. A diagnostic
		that can be read two ways is not one.
		--]]
		for _, frame in ipairs(ns.oUF.objects) do
			local unit = Umbra:FrameUnit(frame)
			local model = frame.Portrait
			local label = 'portrait ' .. (frame.umbraKey or tostring(unit))

			if not model then
				print(PREFIX .. label .. ': |cffcc6666no element|r')
			elseif not model.GetModelFileID then
				print(PREFIX .. label .. ': not a model, nothing to ask')
			elseif not unit then
				print(PREFIX .. label .. ': no unit on this frame')
			elseif not UnitExists(unit) then
				print(PREFIX .. label .. ': nothing to show, no ' .. unit)
			else
				-- Both halves of oUF's condition, because it is an `and`: if
				-- the connected half is the false one, asking only about the
				-- visible half names the wrong culprit.
				report(label .. ': UnitIsConnected', function()
					return UnitIsConnected(unit)
				end)

				report(label .. ': UnitIsVisible', function()
					return UnitIsVisible(unit)
				end)

				report(label .. ': model', function()
					return model:GetModelFileID()
				end)
			end
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

			-- Both frames are protected, so in combat this is a promise
			-- rather than a result, and saying so beats reporting a state
			-- the screen does not show yet.
			if Umbra:SetBlizzardAuras(not hide) then
				print(PREFIX .. 'auras: ' .. Value(which))
			else
				print(PREFIX .. 'auras: ' .. Value(which)
					.. ' — the game keeps its frames protected in combat, so this '
					.. 'takes effect when the fight ends.')
			end
		end
	elseif input == 'debug' then
		Umbra.debug = not Umbra.debug
		UmbraUnitFramesDB.debug = Umbra.debug

		print(PREFIX .. 'debug ' .. (Umbra.debug and 'on' or 'off'))

		-- Switching it on is usually someone asking what already went wrong,
		-- and that happened at login. No reload needed to find out, which
		-- matters on a client that forgets the switch anyway.
		if Umbra.debug then
			if #log == 0 then
				print(PREFIX .. 'nothing has been refused since login.')
			else
				print(PREFIX .. ('%d line(s) from before this was on:'):format(#log))

				for _, line in ipairs(log) do
					print('  ' .. line)
				end
			end
		end
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
