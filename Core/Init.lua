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

-- Shared, because one line elsewhere has to say something in chat without a
-- command behind it: the party column standing down on a client whose header
-- cannot build a child. One prefix, so a line from there is recognisably the
-- same addon talking.
Umbra.prefix = PREFIX

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
	{'health', {'class', 'plain'}, 'what colors the health bars'},
	{'group', {'umbra', 'both'}, "who shows your party"},
	{'unlock', nil, 'drag the frames, every one of them, filled out'},
	{'lock', nil, 'put them back to work'},
	{'reset', nil, "forget this set's dragged positions"},
	{'dev', nil, 'measurements and diagnostics, listed behind that word'},
}

--[[ DEV
The same shape, kept apart for one reason: none of these changes how anything
looks. They report what the client hides, what a header came out as, what the
column is made of, and what the build refused — questions this addon asks
while it is being built, and noise to someone who wants their frames somewhere
else.

They stay listed rather than hidden, and `/uuf dev` on its own prints them. A
measurement nobody can find is one that gets guessed at instead, which is the
mistake this project keeps paying for.
--]]
local DEV = {
	{'test', nil, 'fill every aura slot with stand-ins'},
	{'check', nil, 'which unit values this client hides'},
	{'header', nil, 'whether a secure group header works on this client'},
	{'party', nil, 'what the party column is made of, child by child'},
	{'portrait', nil, 'four ways of asking what the portrait column has to draw'},
	{'debug', nil, 'report what the build refused'},
}

local DEV_NAMES = {}

for _, entry in ipairs(DEV) do
	DEV_NAMES[entry[1]] = true
end

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
Whether **we** can compile a snippet ourselves without tainting it.

`loadstring_untainted` is what an addon calls to turn a string of Lua into an
untainted function. It is missing on both clients, and for a while these notes
read that as the whole secure-snippet machinery being gone: state drivers,
`RunAttribute`, `initialConfigFunction`, and with them any hope of a secure
group header.

**That was wrong, and `/uuf header` measured it wrong.** A header spawns, its
children get units, and both oUF's `initialConfigFunction` and one handed to
it by the layout run to completion — on a client where this flag is false.
Those snippets are compiled by the *client's own* secure code, reached through
`SetAttribute`, and never touch this global. The two were read as one
mechanism because both are called "secure snippets" in conversation.

**And on Forever the client's own code cannot compile one either**, measured
22 September 2026: `RestrictedExecution.lua` calls this same missing function
to build the snippet `SecureGroupHeaders.lua` runs on every new child, so the
header creates a child it cannot configure and the state driver comes back to
try again. The flag is false on both clients and the header works on exactly
one of them, which is why it decides nothing here — and why what it names is
worth knowing in both directions. See *The secure header does not work on
Forever*.

So the flag stays, because it is a true measurement, and it is the name and
the conclusion around it that were wrong. Nothing here calls
`loadstring_untainted`, so nothing here is gated on it yet; keep it as what it
says on the tin, and ask the real question wherever one comes up.

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

--[[ Umbra:Heading()
Which build answered, and on which client.

Pasted or screenshotted anywhere else a report loses every scrap of context,
so each one carries this line. It is one line in three windows rather than
three lines that have to be kept in step.
--]]
function Umbra:Heading()
	return ('%s — %s (interface %d)'):format(Umbra.version,
		Umbra.isForever and 'Forever' or Umbra.isRetail and 'Retail'
			or 'unsupported', interface)
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

	-- Off, because the neutral bar is the design and this spends it. The
	-- edge and the portrait tint carry identity either way.
	if UmbraUnitFramesDB.classHealth == nil then
		UmbraUnitFramesDB.classHealth = false
	end

	-- The client's group panel stays by default: it carries the raid markers
	-- and the way out of a group, and the column was placed to clear it
	-- rather than to replace it.
	if UmbraUnitFramesDB.hideBlizzardGroup == nil then
		UmbraUnitFramesDB.hideBlizzardGroup = false
	end

	-- ADDON_LOADED runs before the frames are built, which is the only place
	-- this can be picked up in time to report on that build.
	Umbra.debug = UmbraUnitFramesDB.debug or false
end)

SLASH_UMBRAUNITFRAMES1 = '/uuf'

local function PrintCommands(entries, prefix)
	for _, entry in ipairs(entries) do
		local line = '  ' .. Value(prefix .. entry[1])

		if entry[2] then
			line = line .. ' ' .. Values(entry[2])
		end

		print(line .. ' — ' .. entry[3])
	end
end

local function Command(input)
	input = strtrim(input or ''):lower()

	--[[ `dev` is a prefix, not a command of its own
	It is stripped here and the rest of this function never learns about it,
	so every command stays one branch of one chain. Dispatching the
	measurements separately would mean a second place to add a command to,
	and a second place to forget one in.

	A bare name that has moved is answered rather than refused. Five commands
	changed address at once, and `/uuf check` is in the fingers of the only
	person who uses this — being told where it went costs one line and beats
	the command list scrolling past for the fourth time.
	--]]
	if input == 'dev' or input:find('^dev%s') then
		input = strtrim(input:sub(4))

		if input == '' then
			print(PREFIX .. 'measurements — they report, they change nothing.')
			PrintCommands(DEV, '/uuf dev ')

			return
		end

		if not DEV_NAMES[input] then
			print(PREFIX .. 'no such measurement: ' .. input)
			PrintCommands(DEV, '/uuf dev ')

			return
		end
	elseif DEV_NAMES[input] then
		print(PREFIX .. Value('/uuf ' .. input) .. ' is now '
			.. Value('/uuf dev ' .. input) .. '.')

		return
	end

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
		-- Forgotten either way; in a fight it is the moving that waits, and
		-- saying `positions reset` over frames that have not moved is the
		-- kind of report this addon tries not to make.
		if Umbra:ResetPositions() then
			print(PREFIX .. 'positions reset.')
		else
			print(PREFIX .. 'positions reset — the frames belong to the '
				.. 'client while the fight is on, so they move when it ends.')
		end
	elseif input == 'check' then
		--[[ Collected rather than printed
		This outgrew the chat frame: thirty-odd lines push everything else out
		of view, and the answers have to be read against each other rather
		than as they scroll past. So they go into a window, and go there as
		plain text — the colors were there to be glanced at, and an escape
		code in a pasted report is noise.
		--]]
		local lines = {}

		local function add(text)
			lines[#lines + 1] = text
		end

		add(Umbra:Heading())
		add('')

		-- Which unit values this client hands over in the clear decides how
		-- much of the display can be formatted at all, and the tag's own
		-- output says whether that reasoning survives contact with oUF.
		local function report(label, getter)
			local ok, value = pcall(getter)

			if not ok then
				add(label .. ': errors — ' .. tostring(value))
			elseif Umbra.Secrets.Is(value) then
				add(label .. ': hidden')
			else
				add(label .. ': readable — ' .. tostring(value))
			end
		end

		add('issecretvalue: ' .. tostring(type(_G.issecretvalue) == 'function'))
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
		add('aura underline: ' .. (Umbra.hasAuraUnderline and
			'available' or 'unavailable'))

		-- Whether we could compile a snippet of our own, which is narrower
		-- than it sounds and is **not** what decides whether a secure group
		-- header works — `/uuf header` asks that one directly, and answered
		-- yes on a client where this says no.
		add('secure snippets (ours): ' .. (Umbra.hasSecureSnippets and
			'available' or 'unavailable'))

		-- Whether a compatibility file ran all the way through. Retail loads
		-- none and says so; on Forever, `none` would mean the file that
		-- reports this client's deviations never finished, which makes an
		-- empty debug buffer mean nothing at all.
		add('compat: ' .. (Umbra.compat
			and (Umbra.compat .. '.lua ran')
			or 'none'))

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
			add('class power: no element')
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

			add(('class power: %d of %d pips, %s'):format(shown, #pips,
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
			--[[ Two frames answered to `party1`
			Measured inside an instance on 21 September 2026: the header's
			child and the hidden party stand-in are both pointed at `party1`,
			and with the unit token for a name they printed the same label
			with different answers under it — one with a model, one without.
			A report that has to be guessed at is the thing this command
			exists not to be, so the frame's own name breaks the tie wherever
			there is no key.
			--]]
			local label = 'portrait ' .. (frame.umbraKey
				or frame:GetName() or tostring(unit))

			if not model then
				add(label .. ': no element')
			elseif not model.GetModelFileID then
				add(label .. ': not a model, nothing to ask')
			elseif not unit then
				add(label .. ': no unit on this frame')
			elseif not UnitExists(unit) then
				add(label .. ': nothing to show, no ' .. unit)
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

				--[[ The condition SetUnit is actually gated on
				Patch 12.0.5: `Model:SetUnit` and
				`ModelSceneActor:SetModelByUnit` no longer accept a unit
				token for a unit whose identity is secret. They do not throw
				— they hand back nil where they used to hand back success.
				So the instance was never the condition, only a place that
				meets it, and `model: nil` on its own cannot say which of
				the two happened: the client refused this unit, or the model
				has not arrived yet.

				A unit's GUID is its identity, so asking whether that is
				secret asks the same question the API is gated on. Read
				against `model` below: secret with no model is a refusal, in
				the clear with no model is one still on its way — and that
				is the split the bounded retry has been guessing at, eight
				tries at a time, on every unit the client was never going to
				name.

				Printed as one word rather than through `report`, because
				here a hidden value *is* the answer rather than something in
				the way of reading one, and a GUID in the clear is forty
				characters of noise next to a one-word finding.
				--]]
				local gotGuid, guid = pcall(UnitGUID, unit)
				local identity

				if not gotGuid then
					identity = 'errors — ' .. tostring(guid)
				elseif guid == nil then
					identity = 'no guid'
				elseif Umbra.Secrets.Is(guid) then
					identity = 'secret'
				else
					identity = 'in the clear'
				end

				add(label .. ': identity — ' .. identity)

				report(label .. ': model', function()
					return model:GetModelFileID()
				end)

				--[[ What separates the explanations that are still standing
				A retry that waits for the model to stream in was written on
				the strength of `model: nil` alone and did not fix it, so the
				"not loaded yet" reading is either wrong or was never given a
				chance. These three say which.

				`ready` is the client's own answer to whether it still has
				work to do — asked here rather than believed, which is the
				mistake the retry made. `display info` is the other way of
				asking what a model holds, and a creature is set by display
				rather than by file, so a display with no file would mean
				`GetModelFileID` is simply the wrong question. `is player`
				settles nothing on its own but is cheap and keeps the split
				honest: the pet is a creature too, and its model loads.
				--]]
				if type(_G.IsUnitModelReadyForUI) == 'function' then
					report(label .. ': ready', function()
						return IsUnitModelReadyForUI(unit)
					end)
				else
					add(label .. ': ready — no such function')
				end

				if model.GetDisplayInfo then
					report(label .. ': display info', function()
						return model:GetDisplayInfo()
					end)
				else
					add(label .. ': display info — cannot be asked')
				end

				report(label .. ': is player', function()
					return UnitIsPlayer(unit)
				end)

				--[[ The two halves of a comparison that is allowed to lie
				oUF guards every unit comparison with
				`C_Secrets.CanCompareUnitTokens` and hands the answer
				straight to a boolean test. Issue #1 is that guard saying
				yes and the comparison coming back hidden anyway, on this
				pair, inside a delve. So both are asked here and printed
				next to each other: a `readable — true` above a `hidden`
				below it is that contradiction, measured rather than
				inferred from a stack trace.
				--]]
				report(label .. ': may compare with player', function()
					return C_Secrets.CanCompareUnitTokens(unit, 'player')
				end)

				report(label .. ': same as player', function()
					return UnitIsUnit(unit, 'player')
				end)

				--[[ Which layer is uncovered, and nothing more
				This said `showing 3D model` until 22 September 2026, and
				that was read — here, in these notes, and by the person
				running it — as *a model is drawn*. It never measured that.
				It measures whether the 2D stand-in is up, and with the
				stand-in down an empty model and a full one are the same
				line. A column that was plainly empty answered `showing 3D
				model` over a readable file id, which is what retired the
				wording; `/uuf dev portrait` is where the other question
				gets asked.
				--]]
				add(label .. ': 2D stand-in ' ..
					((model.umbraFlat and model.umbraFlat:IsShown())
						and 'up, over the model'
						or "down, the square is the model's"))
			end
		end


		Umbra:ShowReport('Umbra — check', lines)

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

			if Umbra:ApplyLayout() then
				print(PREFIX .. 'layout: ' .. Value(name))
			else
				print(PREFIX .. 'layout: ' .. Value(name)
					.. ' — the frames belong to the client while the fight '
					.. 'is on, so they move when it ends.')
			end
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
	elseif input:find('^health') then
		-- Named states for the same reason `auras` has them, and because
		-- what the two do is easier to name than to switch between: one
		-- puts identity on the bar as well, the other keeps it at the edge.
		local which = input:match('^health%s+(%S+)$')
		local current = UmbraUnitFramesDB.classHealth and 'class' or 'plain'

		if not which then
			print(PREFIX .. 'health: ' .. Value(current))
			print(PREFIX .. Value('class')
				.. " — the bar takes the unit's color as well")
			print(PREFIX .. Value('plain')
				.. ' — one green for every unit, color only at the edge')
		elseif which ~= 'class' and which ~= 'plain' then
			print(PREFIX .. 'no such setting: ' .. which)
		else
			UmbraUnitFramesDB.classHealth = which == 'class'

			-- Nothing here is protected, so unlike `auras` this is a result
			-- rather than a promise, in a fight as much as out of one.
			Umbra:ApplyHealthStyle()
			print(PREFIX .. 'health: ' .. Value(which))
		end
	elseif input:find('^group') then
		-- The same two words as `auras`, for the same reason: what is being
		-- chosen is who displays your party, and the answer is one of two
		-- displays rather than a thing being on or off.
		local which = input:match('^group%s+(%S+)$')
		local current = UmbraUnitFramesDB.hideBlizzardGroup and 'umbra' or 'both'

		if not which then
			print(PREFIX .. 'group: ' .. Value(current))
			print(PREFIX .. Value('umbra') .. ' — only the Umbra column')
			print(PREFIX .. Value('both')
				.. " — the game keeps its group panel, markers and all")
		elseif which ~= 'umbra' and which ~= 'both' then
			print(PREFIX .. 'no such setting: ' .. which)
		else
			local hide = which == 'umbra'

			UmbraUnitFramesDB.hideBlizzardGroup = hide

			if Umbra:SetBlizzardGroup(not hide) then
				print(PREFIX .. 'group: ' .. Value(which))
			else
				print(PREFIX .. 'group: ' .. Value(which)
					.. ' — the panel is protected in combat, so this takes '
					.. 'effect when the fight ends.')
			end
		end
	elseif input == 'header' then
		--[[ One question, asked once
		Whether the client's secure group header still works without
		`loadstring_untainted`. It decides whether group frames can sort
		themselves in a fight or have to be four fixed frames, which is the
		difference between two different addons, so it is measured before
		anything is built on it. `Layouts/Group.lua` says why at length.
		--]]
		Umbra:ShowReport('Umbra — header', Umbra:ProbeHeader())
	elseif input == 'party' then
		-- The probe answers for a header it makes itself. This answers for
		-- the one that is actually on screen, which is the only one a
		-- screenshot can be checked against.
		Umbra:ShowReport('Umbra — party', Umbra:ReportParty())
	elseif input == 'portrait' then
		--[[ A box, because the answer is a picture
		Every other measurement here ends in words, and this one cannot: no
		value the client hands over says whether the column drew anything —
		see *A file id is not a drawn model*. So the box asks the four
		questions itself, in squares next to each other, and the screenshot
		is the report.

		The rows are gathered where the portrait code lives and drawn where
		the other window lives, the same split `party` has.
		--]]
		local inside, kind = IsInInstance()

		Umbra:ShowPortraits('Umbra — portrait',
			Umbra:Heading() .. '   ·   ' .. (inside
				and ('inside — ' .. tostring(kind)) or 'not in an instance'),
			Umbra:PortraitRows())
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
		print(PREFIX .. Umbra:Heading())

		PrintCommands(COMMANDS, '/uuf ')

		if Umbra.author then
			print(('  with %s by %s'):format(HEART, Umbra.author))
		end
	end
end

--[[ A failed command must not take the chat frame with it
A slash command runs inside the chat edit box's own Enter handling. An error
thrown out of here therefore does not merely fail: it takes the submit down
with it, the typed text stays in the box, and the key looks broken — which is
indistinguishable, from the outside, from a dead keyboard.

Measured the hard way on 20 September 2026. `EditBox:SetFont` wants a third
argument where a FontString does not; the report window threw on being built,
and from that moment nothing could be entered at all, `/reload` included. The
client had to be restarted to get the fix in, and the fix could only be
installed from outside the game.

So a fault is caught, named, and stops here. It still reaches error capture as
a printed message and through the debug buffer, and it no longer reaches the
frame that was only trying to send a line of text.
--]]
SlashCmdList.UMBRAUNITFRAMES = function(input)
	local ok, err = pcall(Command, input)

	if not ok then
		print(PREFIX .. 'that command ran into an error, and the rest of the '
			.. 'interface is fine: ' .. tostring(err))
		Umbra:Debug('command failed:', err)
	end
end
