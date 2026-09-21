local _, ns = ...
local Umbra = ns.Umbra
local oUF = ns.oUF

--[[ Group frames, and the one measurement they rest on
Single frames are easy: one frame, one fixed unit. Group frames are not. Who
stands on position three changes while you watch, and in combat an addon may
not decide which unit a frame points at — the client forbids it, because that
is targeting automation. So Blizzard supplies the **secure group header**: its
own machinery creates the children, assigns their units and re-sorts them, and
is allowed to do that mid-fight because it is its code and not ours.

For those children to become *our* frames, the header runs a piece of code we
hand it, inside its restricted environment, as each child is created. That is
`initialConfigFunction`, passed as a string of Lua.

**The header was measured before anything was built on it**, because it
decides the shape of every group frame there will ever be: children the client
creates and re-sorts mid-fight, or four fixed frames for party1..party4 with
every change waiting for combat to end. Those are two different addons.

It came out whole, on Retail on 21 September 2026 — children created, units
assigned, both snippets run, our style applied, and the client deciding when
the column is on screen. `/uuf header` is what asked, it is still here, and
the write-up is under *Relevant to group frames* in the development notes.

**It stays because Forever has not been asked.** The same probe on the beta
client is one slash command, and until it has been run there this file's
foundation is measured on one of the two clients it claims to support.
--]]

--[[ The Umbra style on a header child
A separate question from whether the header works, and the probe below is
careful not to answer it by accident: it brings its own minimal style, so that
"the header works" and "our style survives a header child" cannot be mistaken
for one another. The header is a known quantity now, so the real style goes on.

What differs from a single frame is only where the unit comes from. oUF hands
the style `oUF-guessUnit`, which for a party header child is the string
`party` — not `party1` — so `Umbra.frames.party` is the config every child of
this header is built from, and the client stays free to move people between
them afterwards without any of it being rebuilt.
--]]

--[[ ChildSnippet(config)
The size, set a second time and from inside.

The style sizes the child like every other frame, and that is not enough: the
header lays its children out within the restricted environment, before
anything of ours has run, and positions each one by the size it can see there.
A child whose size the secure code cannot read is placed as though it had
none, and the column arrives folded into a single spot.

Same numbers, from the same config, formatted in rather than written down.
--]]
local function ChildSnippet(config)
	return ('self:SetWidth(%d) self:SetHeight(%d)')
		:format(config.width, Umbra:FrameHeight(config))
end

--[[ Stand-ins for the whole column
What `/uuf unlock` shows where a party column has nobody in it.

Every other frame is revealed by letting go of its unit watch and standing
there empty — that is what the boss column does, five frames for units no
encounter has produced yet. A header cannot be revealed that way: its children
belong to the client, which makes one per real member and not one more, so
alone there is nothing to reveal and in a party of two there are two rows
where four are being placed.

The first version asked the header for the one child it can always make, you,
by turning on `showSolo` and `showPlayer`. That worked and was wrong twice
over: it put the player in a column that is deliberately about the other four,
and it showed one row where the thing being placed is four rows tall.

So the column is placed against stand-ins of its own — one per slot, the real
style, at exactly the offsets the header's own children take, and the header
stepped out of the way for as long as that lasts. In a real party they carry
that party's members, because they are pointed at `party1..party4` and the
client answers for whoever is standing there.
--]]
local function Reveal(mover, revealed)
	if InCombatLockdown() then return end

	local header = mover.umbraHeader

	--[[ Out of the way rather than hidden by hand
	`Hide()` on a header lasts until its driver next evaluates and takes the
	decision back. A condition that cannot be met is the driver agreeing to
	stay away, and it is put back the same way. `custom` hands oUF the
	conditional as written instead of building one from names.
	--]]
	header:SetVisibility(revealed and 'custom hide' or 'party')

	for _, frame in ipairs(mover.umbraStandIns) do
		frame:SetShown(revealed)
	end

	--[[ Something to actually take hold of
	A plain frame receives no mouse input until it is told to, so the column
	had drag handlers and no way to reach them: every other mover is a unit
	button, which takes the mouse by being one. And the header's children sit
	on top of this frame and are buttons themselves, so even once it listens,
	the part of the column worth grabbing is the part something else takes
	the click from first.

	Both are only wanted while frames are being placed. So the mover listens
	and rises above the column for exactly that long, and gives both back on
	locking — an invisible box over a party column would otherwise swallow
	every click meant for the people in it.
	--]]
	mover:EnableMouse(revealed)
	mover:SetFrameStrata(revealed and 'HIGH' or 'MEDIUM')
end

--[[ BuildParty()
The party column: a header the client fills, and a plain frame to drag it by.

**What moves is not the header.** `Umbra:PlaceFrame` gives a frame a drag
handler and an overlay, and that overlay is a child of what it marks. What a
secure group header makes of a child that is not one of its unit buttons is
not something this file has measured, and guessing wrong there buys a layout
that comes apart in combat — the expensive kind of wrong. So the mover is an
ordinary frame the size of the column, the header hangs off it, and dragging
one carries the other.

It buys a second thing. Nothing protected is touched when the column moves,
because the header is merely anchored to something that moved. The frame that
is dragged is not the frame the client protects.
--]]
local function BuildParty()
	local config = Umbra.frames.party
	local height = Umbra:ColumnHeight(config, Umbra.partyCount)

	local mover = CreateFrame('Frame', 'UmbraPartyMover', UIParent)
	mover:SetSize(config.width, height)

	oUF:SetActiveStyle('Umbra')

	--[[ Guarded, because of what SpawnHeader does on its way out
	It ends by turning off the client's own party frames, and that reaches
	for `PartyFrame`, its member pool and `CompactPartyFrameMember1..5` by
	name. Those belong to the client, not to oUF, and they are exactly the
	kind of name that gets renamed between expansions or is simply absent on
	Forever — where `SetRolesets`, which it calls on each of them, is a newer
	API than the build.

	This runs inside `oUF:Factory`, which is building every frame this addon
	has. An error raised here without a guard does not cost the party column,
	it costs the layout.
	--]]
	local ok, header = pcall(oUF.SpawnHeader, oUF, 'UmbraPartyHeader', nil,
		'showParty', true,
		'showRaid', false,
		'showSolo', false,
		'showPlayer', false,
		'point', 'TOP',
		-- The gap between two children, not the distance between them:
		-- the header already knows how tall a child is. What it does
		-- not know is that something hangs below each one, so the
		-- debuff row's reach is added here or the next member lands on
		-- it.
		'yOffset', -(Umbra:GroupSlotHeight(config)
			- Umbra:FrameHeight(config) + config.groupSpacing),
		'oUF-initialConfigFunction', ChildSnippet(config))

	if not ok then
		Umbra:Debug('party header not created:', tostring(header))
		mover:Hide()

		return
	end

	header:SetSize(config.width, height)
	header:SetPoint('TOPLEFT', mover, 'TOPLEFT')

	-- Party only. Alone there is nobody to show, and a raid is its own
	-- arrangement rather than a longer party — it gets its own header when
	-- it is built.
	header:SetVisibility('party')

	--[[ One stand-in per slot
	Real frames rather than drawn boxes, for the reason the boss column uses
	real frames: what is being placed is the thing itself, and a box the same
	size is a promise that the thing will look like that.

	They are pointed at `party1..party4`, so in a party they show that party.
	The client's own watch would show them the moment a slot fills, which is
	exactly when the header's real child is already standing there — so the
	watch is let go of immediately and these are shown by unlocking alone.
	--]]
	local standIns = {}
	local pitch = Umbra:GroupSlotHeight(config) + config.groupSpacing

	for index = 1, Umbra.partyCount do
		local ok, frame = pcall(oUF.Spawn, oUF, 'party' .. index,
			'UmbraPartyStandIn' .. index)

		if not ok then
			Umbra:Debug('party stand-in not created:', index, tostring(frame))
			break
		end

		if not pcall(UnregisterUnitWatch, frame) then
			Umbra:Debug('party stand-in still watched:', index)
		end

		frame:Hide()
		frame:SetParent(mover)
		frame:ClearAllPoints()
		frame:SetPoint('TOPLEFT', mover, 'TOPLEFT', 0, -(index - 1) * pitch)

		standIns[index] = frame
	end

	mover.umbraStandIns = standIns
	mover.umbraHeader = header
	mover.umbraReveal = Reveal

	Umbra:PlaceFrame(mover, 'party')

	Umbra.partyHeader = header
	Umbra.partyMover = mover
end

--[[ Umbra:ReportParty()
What the real column came out as, for the report window.

Separate from the probe, and asked of the thing that is actually on screen. A
screenshot shows a column and not what it is made of: a row that lands where
no child should be is either a child in the wrong place or something else
entirely standing there, and those need different fixes. Each child names its
own top edge in screen coordinates, so a row seen in a picture can be matched
to the frame that drew it instead of being reasoned about.
--]]
--[[ RoleAnswer(unit)
What the client says this unit signed up as, in the three words that
tell a marker apart from a guess: readable, hidden, or not asked at all.
`UnitGroupRolesAssigned` answers TANK, HEALER, DAMAGER or NONE — and
NONE is a real answer, not a refusal, which is why it is printed as one.
--]]
local function RoleAnswer(unit)
	if type(_G.UnitGroupRolesAssigned) ~= 'function' then
		return 'no such function on this client'
	end

	if not unit then return 'no unit to ask about' end

	local ok, value = pcall(UnitGroupRolesAssigned, unit)

	if not ok then
		return 'errors — ' .. tostring(value)
	elseif Umbra.Secrets.Is(value) then
		return 'hidden'
	end

	return 'readable — ' .. tostring(value)
end

function Umbra:ReportParty()
	local lines = {}

	local function add(text)
		lines[#lines + 1] = text
	end

	local header, mover = Umbra.partyHeader, Umbra.partyMover

	if not header then
		add('party header: not built — see /uuf debug')

		return lines
	end

	add('locked: ' .. tostring(Umbra.locked))
	add('group: '
		.. (IsInRaid() and 'raid' or IsInGroup() and 'party' or 'solo')
		.. ', ' .. tostring(GetNumGroupMembers()) .. ' member(s)')
	add('')
	add('showSolo: ' .. tostring(header:GetAttribute('showSolo'))
		.. '   showPlayer: ' .. tostring(header:GetAttribute('showPlayer')))
	add('visibility: ' .. tostring(header.visibility))
	add('stand-ins: ' .. #mover.umbraStandIns
		.. ', shown: ' .. tostring(mover.umbraStandIns[1]
			and mover.umbraStandIns[1]:IsShown()))
	add('header shown: ' .. tostring(header:IsShown()))

	-- **Where this run was taken.** The last one answered `readable —
	-- TANK` with nothing saying whether it was asked in a dungeon or in
	-- the city outside one, and for a value the client may withhold those
	-- are two different answers wearing the same words. A report that has
	-- to be asked where it happened is not one.
	local inside, kind = IsInInstance()

	add('where: ' .. (inside and ('inside — ' .. tostring(kind))
		or 'not in an instance'))

	-- The other half of the question: whether this client knows the art. A
	-- readable role with no icon to draw it with would mean inventing one,
	-- and an atlas the client already owns is the same mark its own frames
	-- use.
	local function HasAtlas(name)
		return C_Texture and C_Texture.GetAtlasInfo
			and C_Texture.GetAtlasInfo(name) ~= nil
	end

	add('role art: tank ' .. tostring(HasAtlas('roleicon-tiny-tank'))
		.. '   healer ' .. tostring(HasAtlas('roleicon-tiny-healer'))
		.. '   dps ' .. tostring(HasAtlas('roleicon-tiny-dps')))

	-- What a default position has to clear: how tall the screen is in the
	-- coordinates every point in Core/Defaults.lua is written in, and how
	-- far down the client's own group panel comes on the left edge — the
	-- one thing the column is under orders to avoid.
	local panel = _G.CompactRaidFrameManager
	local reach = panel and panel.GetBottom and panel:GetBottom()

	add('screen: ' .. string.format('%.0f tall', UIParent:GetHeight()))
	add('group panel: ' .. (reach
		and string.format('reaches down to %.0f', reach)
		or 'not on this client, or not laid out yet'))

	add('mover: ' .. string.format('%.0f x %.0f at top %.0f',
		mover:GetWidth(), mover:GetHeight(), mover:GetTop() or -1))

	local children = {header:GetChildren()}
	add('children: ' .. #children)

	for index, child in ipairs(children) do
		add('')
		local unit = child:GetAttribute('unit') or child.__unit

		add('child ' .. index .. ': unit: '
			.. tostring(child:GetAttribute('unit'))
			.. '   __unit: ' .. tostring(child.__unit))
		add('child ' .. index .. ': shown: ' .. tostring(child:IsShown())
			.. '   ' .. string.format('%.0f x %.0f at top %.0f',
				child:GetWidth(), child:GetHeight(), child:GetTop() or -1))

		-- Whether a tank and a healer can be marked at all. The role
		-- is what someone signed up as, so it is a fact about a person
		-- in this group rather than about a unit in the world — and
		-- that is exactly the kind of thing the client has been
		-- withholding. Asked here rather than assumed, because a
		-- marker built on a hidden value is a marker that works at the
		-- target dummy and not in the dungeon.
		-- `hidden` would not close the question either: it would mean
		-- the name has to come from somewhere the value never passes
		-- through us, the way the dispel underline does.
		add('child ' .. index .. ': role: ' .. RoleAnswer(unit))
	end

	--[[ Everything else standing in that corner
	The column is not the only thing that can draw there, and a row in the
	wrong place is just as likely to be a frame that was parked rather than
	placed — `AnchorFrame` puts a frame it has no place for in the middle of
	the screen and says so, but a frame dragged there once is remembered.
	So every frame this addon owns is asked where it is, and the ones
	overlapping the column are named.
	--]]
	local left, right = mover:GetLeft(), mover:GetRight()
	local bottom, top = mover:GetBottom(), mover:GetTop()

	if not left or not bottom then return lines end

	add('')
	add('overlapping the column:')

	local found = 0

	for _, frame in ipairs(oUF.objects) do
		local fLeft, fBottom = frame:GetLeft(), frame:GetBottom()

		if fLeft and fBottom and frame:IsShown()
			and fLeft < right and frame:GetRight() > left
			and fBottom < top and frame:GetTop() > bottom
			and frame:GetParent() ~= header then

			found = found + 1
			add('  ' .. tostring(frame.umbraKey or frame:GetName() or '?')
				.. ': ' .. tostring(Umbra:FrameUnit(frame))
				.. string.format(' at top %.0f', frame:GetTop()))
		end
	end

	if found == 0 then
		add('  nothing — the column is the only thing drawing there')
	end

	return lines
end

oUF:Factory(function()
	BuildParty()
end)

--[[ Everything below is the probe
Kept whole, and kept apart from what it settled. It answers on a client this
addon has not run it on yet.
--]]

--[[ ProbeStyle(frame, unit)
Deliberately almost nothing.

"Does the header machinery work" and "does the Umbra style survive being
applied to a header child" are two questions, and the second one failing would
look exactly like the first one failing. So the probe brings the smallest
style that can still be told apart from no style at all, and the real one is
asked separately, later, once the header itself is a known quantity.
--]]
local function ProbeStyle(frame, unit)
	frame.umbraProbeStyled = true
	frame.umbraProbeUnit = unit

	frame:SetSize(140, 22)

	local background = frame:CreateTexture(nil, 'BACKGROUND')
	background:SetAllPoints()
	background:SetColorTexture(0, 0, 0, 0.7)

	local label = frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
	label:SetPoint('LEFT', frame, 'LEFT', 6, 0)
	label:SetText(tostring(unit))
end

oUF:RegisterStyle('UmbraProbe', ProbeStyle)

--[[ SNIPPET
Our own half of the question, kept apart from oUF's.

oUF sets its own `initialConfigFunction` and will not let a layout override it;
what a layout may pass is `oUF-initialConfigFunction`, which oUF's snippet runs
on each child near its end. So there are two things that can fail separately:
the client running oUF's snippet at all, and oUF's snippet reaching the line
that runs ours. One attribute set from inside tells them apart.
--]]
local SNIPPET = [[
	self:SetAttribute('umbraProbeRan', 'yes')
]]

--[[ DriveTest(header)
Whether the client drives this header's visibility, asked so that only one
answer fits.

`state-visibility` stays empty and the plain driver showed that is not the
machinery giving out, so Show and Hide are the only place visibility speaks.
And a shown header says nothing there: a frame stands visible from the moment
it is created, so a driver that does nothing at all leaves exactly the picture
a working one does.

What cannot be faked is the header going **away** on a condition it cannot
meet. Solo, `[group:raid] show;hide` has to hide it; putting the real
condition back has to bring it straight back. Two readings, both of them
forced, and the second one also puts the header back the way it was found.

Registration evaluates on the spot — that is what the plain driver answering
`yes` in the same call established — so both fit in one call and need no
second run.
--]]
local function DriveTest(header)
	-- Re-registering a driver touches a protected frame, so in combat this
	-- is not asked at all rather than asked badly.
	if InCombatLockdown() then return nil end

	if not pcall(header.SetVisibility, header, 'raid') then return nil end
	local hides = not header:IsShown()

	if not pcall(header.SetVisibility, header, 'solo,party') then return nil end
	local returns = header:IsShown()

	return hides, returns
end

local probe

local function Spawn()
	-- A secure frame cannot be created in combat, and the header would be
	-- refused rather than answer the question wrongly.
	if InCombatLockdown() then return nil, 'in combat' end
	if probe then return probe end

	-- Asked rather than assumed: `style` is module state in oUF, and putting
	-- back a name this file happens to know is how a probe quietly decides
	-- what everything spawned after it looks like.
	local active = oUF:GetActiveStyle()

	oUF:SetActiveStyle('UmbraProbe')

	local ok, header = pcall(oUF.SpawnHeader, oUF, 'UmbraProbeHeader', nil,
		'showSolo', true,
		'showPlayer', true,
		'showParty', true,
		'showRaid', false,
		'point', 'TOP',
		'yOffset', -4,
		'oUF-initialConfigFunction', SNIPPET)

	if active then oUF:SetActiveStyle(active) end

	if not ok then return nil, tostring(header) end

	header:SetPoint('CENTER', UIParent, 'CENTER', 0, 120)

	--[[ The other half of the machinery
	A header that cannot be told *when* to appear is not much of a header:
	oUF drives that through `RegisterAttributeDriver`, which hands the client
	a macro conditional as a string and is the same kind of mechanism as the
	snippet. Asked here rather than assumed, and separately, because it can
	fail on its own.
	--]]
	local visOk, visErr = pcall(header.SetVisibility, header, 'solo,party')
	header.umbraProbeVisibility = visOk or tostring(visErr)
	header.umbraProbeCondition = header.visibility

	--[[ The attribute is not where visibility answers
	`pcall` only says the call did not error, which a driver that was never
	installed also manages. The attribute looked like the harder evidence —
	the client resolving the conditional and writing `show` or `hide` itself.

	It stays empty. Measured 21 September 2026, at registration and on a
	later run, on a client where the plain driver below answers on the spot.
	So visibility is steered apart from the attribute; this line is kept
	because an empty reading is the measurement, not a gap in it.
	--]]
	header.umbraProbeDriverState = header:GetAttribute('state-visibility')

	--[[ A driver on a name nothing special-cases
	`state-visibility` came back empty on both runs, and that has two
	readings: the driver machinery does not work for this frame, or
	visibility is handled apart from the attribute and never writes one.
	Those are opposite answers, and the reading cannot tell them apart —
	the same shape as asking permission instead of asking the question.

	So a second driver, on an attribute name that is ours and special to
	nobody. If `yes` comes back there, the client is compiling and
	evaluating conditionals for this frame, and an empty `state-visibility`
	is a fact about visibility rather than about drivers. If it comes back
	empty too, the machinery is what is missing.
	--]]
	local plainOk, plainErr = pcall(RegisterAttributeDriver, header,
		'umbraProbeDriver', '[@player,exists] yes; no')
	header.umbraProbePlain = plainOk or tostring(plainErr)
	header.umbraProbePlainState = header:GetAttribute('umbraProbeDriver')
	-- Answered `yes` on both readings, 21 September 2026. Drivers work; the
	-- empty attribute above is about visibility alone.

	probe = header
	return header
end

--[[ Umbra:ProbeHeader()
What the header actually produced, as lines for the report window.

Each line is one thing that can fail on its own, in the order it would fail,
so the first `no` in the list names the layer that gave out rather than the
symptom three layers up.
--]]
function Umbra:ProbeHeader()
	local lines = {}

	local function add(text)
		lines[#lines + 1] = text
	end

	-- The same measurement `/uuf check` prints, under the same name: whether
	-- **we** can compile a snippet, which nothing here does and which decides
	-- nothing below.
	add('secure snippets (ours): '
		.. (Umbra.hasSecureSnippets and 'available' or 'unavailable'))
	add('in combat: ' .. tostring(InCombatLockdown()))

	--[[ Who was standing there
	The header makes one child per unit it is told to show, so a child count
	means nothing without the roster that produced it. The first run reported
	two children and nobody wrote down whether there was a party — solo, with
	`showSolo` and `showPlayer`, one is what to expect.
	--]]
	add('group: '
		.. (IsInRaid() and 'raid' or IsInGroup() and 'party' or 'solo')
		.. ', ' .. tostring(GetNumGroupMembers()) .. ' member(s)')
	add('')

	local fresh = not probe
	local header, err = Spawn()

	if not header then
		add('header: not created — ' .. tostring(err))
		return lines
	end

	add('header: created')
	add('visibility driver: ' .. tostring(header.umbraProbeVisibility))
	add('  condition: ' .. tostring(header.umbraProbeCondition))
	add('  state when registered: ' .. tostring(header.umbraProbeDriverState))
	add('  state now: ' .. tostring(header:GetAttribute('state-visibility')))
	add('plain driver: ' .. tostring(header.umbraProbePlain))
	add('  state when registered: ' .. tostring(header.umbraProbePlainState))
	add('  state now: ' .. tostring(header:GetAttribute('umbraProbeDriver')))

	-- Kept as context, not as evidence: a frame is shown from birth, so this
	-- reads the same whether the driver works or does nothing at all. The
	-- two lines under it are the ones that answer.
	add('header shown: ' .. tostring(header:IsShown()))

	--[[ Asked last, and here is why
	`DriveTest` hides the header and shows it again. The children are a
	settled measurement, and running something that moves the frame they
	hang from before reading them would put a settled thing back at risk to
	ask an open one. So it is a closure, called on the way out of every path
	below.
	--]]
	local function addDriveVerdict()
		local hides, returns = DriveTest(header)

		add('')

		if hides == nil then
			add('visibility driven: not asked — '
				.. (InCombatLockdown() and 'in combat'
					or 'the driver could not be re-registered'))
			return
		end

		add('visibility driven: hidden by [group:raid] solo: '
			.. tostring(hides))
		add('                   back on solo,party: ' .. tostring(returns))
	end

	local children = {header:GetChildren()}
	add('children: ' .. #children)

	if #children == 0 then
		add('')

		if not header:IsShown() then
			--[[ Not a fault, an answer
			A hidden header configures nothing, so no child here says
			something about the line above rather than about children. Those
			were measured on 21 September 2026 and came out whole: one child
			solo, two in a party, unit assigned, snippet run, styled, shown.
			Nothing needs pushing to ask that again.
			--]]
			add('The header is hidden, so it configured no children. That is')
			add('the visibility driver answering, not the child machinery.')
		else
			add('No child at all. The header exists and stands there, so its')
			add('own machinery never ran.')
		end

		addDriveVerdict()

		return lines
	end

	for index, child in ipairs(children) do
		local label = 'child ' .. index

		add('')

		-- Set by oUF's snippet from inside the restricted environment. This
		-- one line is the whole question: present means the client compiled
		-- and ran it, absent means it did not.
		add(label .. ': oUF-guessUnit: '
			.. tostring(child:GetAttribute('oUF-guessUnit')))

		-- Ours, run by oUF's snippet a few lines further down. Present means
		-- a layout can put its own code in there too.
		add(label .. ': umbraProbeRan: '
			.. tostring(child:GetAttribute('umbraProbeRan')))

		-- What the header itself assigns, outside any snippet.
		add(label .. ': unit attribute: '
			.. tostring(child:GetAttribute('unit')))

		add(label .. ': __unit: ' .. tostring(child.__unit))

		-- The snippet ends by calling back out to oUF, which applies the
		-- style. Styled means it reached its last line.
		add(label .. ': styled: ' .. tostring(child.umbraProbeStyled == true))
		add(label .. ': styled as: ' .. tostring(child.umbraProbeUnit))
		--[[ Worth nothing on the run that created the header
		The client shows a child through `RegisterUnitWatch` and its own
		layout pass, and neither has happened yet when this reads it in the
		same call that spawned the header. A second `/uuf header` reuses the
		header it already made, and *that* reading means something.
		--]]
		add(label .. ': shown: ' .. tostring(child:IsShown())
			.. (fresh and ' (too early to mean anything — ask again)' or ''))
	end

	addDriveVerdict()

	return lines
end
