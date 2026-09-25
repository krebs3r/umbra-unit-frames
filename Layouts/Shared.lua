local _, ns = ...
local Umbra = ns.Umbra
local oUF = ns.oUF

local colors = Umbra.colors

local CreateColorLayer = Umbra.Widgets.ColorLayer
local CreateText = Umbra.Widgets.Text
local CreateBar = Umbra.Widgets.Bar
local CreatePrediction = Umbra.Widgets.Prediction

--[[ The Umbra style
One style for every single frame. What differs between them lives in
Umbra.frames as a config, and anything a config does not name falls back to
the shared layout through its metatable.

The widgets themselves are in Layouts/Widgets.lua, the tags in Layouts/Tags.lua
and the aura containers in Layouts/Auras.lua. The geometry rule that all of
them follow is written down in Widgets.lua.
--]]

--[[ Tooltip(frame)
The tooltip you get from pointing at a unit in the world, on the frame that
stands for it.

oUF leaves this to the layout, which is easy to miss because it does set the
click attributes: it builds a SecureUnitButton with `*type1 = target` and no
`OnEnter` at all, and the only tooltips in the library are ones single
elements put on themselves.

**Blizzard's own `UnitFrame_OnEnter` cannot be used here.** It reads
`self.unit`, and an oUF frame has no such field: the unit lives in
`frame.__unit`, which `Private.UpdateUnits` keeps current, and again as the
secure `unit` attribute. Handing our frames to it threw
`bad argument #1 to GetUnit` on every hover, because what reached
`C_TooltipInfo.GetUnit` was nil.

So the unit is asked for through `Umbra:FrameUnit`, which knows where oUF
actually keeps it.
--]]
local function Tooltip(frame)
	frame:SetScript('OnEnter', function(self)
		local unit = Umbra:FrameUnit(self)

		-- Normally a frame for a unit that is not there is hidden by
		-- RegisterUnitWatch. Unlocking lets go of that watch on purpose, so
		-- pointing at an empty frame is an expected state and says nothing.
		if not unit or not UnitExists(unit) then return end

		if GameTooltip:IsForbidden() then return end

		-- SetDefaultAnchor puts the tooltip where the client's own setting
		-- says it goes, including "anchored to the cursor". A plain owner is
		-- what is left where that helper is missing, as it may be on Forever.
		if not pcall(GameTooltip_SetDefaultAnchor, GameTooltip, self) then
			GameTooltip:SetOwner(self, 'ANCHOR_BOTTOMRIGHT')
		end

		GameTooltip:SetUnit(unit)
	end)

	frame:SetScript('OnLeave', function()
		if GameTooltip:IsForbidden() then return end

		GameTooltip:Hide()
	end)
end

--[[ A portrait the client was not ready to give yet
oUF sets the model once, when the unit changes, and never asks again. That is
enough for the player and the pet, whose models are loaded because they are
standing there. It is not enough for a target picked up in a dungeon.

Measured in *Der Steinerne Kern* on 20 September 2026, with `/uuf dev check`:

	portrait target: UnitIsConnected: readable — true
	portrait target: UnitIsVisible:   readable — true
	portrait target: model: readable — nil

Both halves of oUF's condition readable and true, so it took the real branch
and called `SetUnit` — and the client had nothing to give it. Nothing is
hidden here and nothing is misanchored; the model had simply not streamed in
yet, and oUF's one shot had already been spent. The portrait then stays empty
for that target for as long as it is the target.

DialogueUI answers a related problem by asking `IsUnitModelReadyForUI` and
coming back later when the answer is no. **Gating the retry on that was a
mistake**, and the first version of this made it: the target came back
`model: nil` again on the next run, and the chain had very likely never
started. A gate on an API nobody here had measured is exactly the assumption
this file exists to prevent — if the client answers "ready" while handing over
nothing, the retry never runs and the measurement never happens.

So it now runs on the **symptom** alone, a model file that is plainly nil, and
`/uuf dev check` asks the ready question separately, where the answer is data
rather than a decision. The retry goes through the element's own
`ForceUpdate`, so the model is still set by oUF's code rather than by a second
copy of it that could drift.

Bounded on purpose: a unit that will never have a model must not leave a timer
running behind it, and that bound is what makes a symptom safe to act on while
the cause is still unknown. It reports itself through `Umbra:Debug`, because a
chain that never ran and one that ran and failed are otherwise the same empty
square.
--]]
local PORTRAIT_RETRIES = 8
local PORTRAIT_DELAY = 0.5

--[[ ModelPending(element)
Whether a model is missing that could still turn up.

A plain nil is the whole test. Anything else — a file id, or a hidden value we
are not allowed to look at — means there is nothing here to wait for.
--]]
local function ModelPending(element)
	if not element.GetModelFileID then return false end

	local ok, file = pcall(element.GetModelFileID, element)

	return ok and not Umbra.Secrets.Is(file) and file == nil
end

--[[ WithheldIdentity(unit)
Whether the client has classified this unit, which is what `SetUnit` is
gated on since 12.0.5: it takes no token for a unit with a secret
identity, and it does not throw about it — it answers nil where it used
to answer success.

A unit's GUID is its identity, so this is the same question asked of a
value we are allowed to hold. Measured on Retail 120100 on 21 September
2026, the same character minutes apart: the target and the
target-of-target read `in the clear` with a model in the open world and
`secret` with none inside an instance, while a party member inside the
same instance is in the clear and loads. Both directions, and the
instance on both sides of it, so identity is the condition rather than a
companion of it.
--]]
local function WithheldIdentity(unit)
	local ok, guid = pcall(UnitGUID, unit)

	return ok and Umbra.Secrets.Is(guid)
end

local function RetryPortrait(element, tries)
	C_Timer.After(PORTRAIT_DELAY, function()
		local frame = element.__owner
		local unit = frame and Umbra:FrameUnit(frame)

		if not unit or not UnitExists(unit) then
			element.umbraWaiting = nil
			return
		end

		element:ForceUpdate()

		if not ModelPending(element) then
			element.umbraWaiting = nil
			Umbra:Debug('portrait arrived for', unit, 'on try', tries)
			return
		end

		if tries >= PORTRAIT_RETRIES then
			element.umbraWaiting = nil
			Umbra:Debug('portrait never arrived for', unit, 'after', tries, 'tries')
			return
		end

		RetryPortrait(element, tries + 1)
	end)
end

--[[ PortraitPostUpdate(element, unit)
Starts one chain of retries, and only one.

The ForceUpdate inside the chain comes back through here, which is what the
flag is for: without it each attempt would start a chain of its own. Clearing
it when the chain ends is what lets the next target have its own.
--]]
--[[ StandIn(element, unit)
Covers the model with the client's own 2D portrait, or uncovers it.

`SetPortraitTexture` is what Blizzard's own unit frames use, and it is asked
for the same unit the model was asked for, so nothing is invented here: if the
client will not name this unit either, the stand-in is its question mark and
that is still an honest answer.
--]]
local function StandIn(element, unit, show)
	local flat = element.umbraFlat
	if not flat then return end

	if show and unit and type(_G.SetPortraitTexture) == 'function' then
		pcall(SetPortraitTexture, element.umbraFlatArt, unit)
	end

	flat:SetShown(show and true or false)
end

local function PortraitPostUpdate(element, unit)
	local missing = ModelPending(element)

	-- Covered the moment there is nothing to show, uncovered the moment there
	-- is. A column that is briefly 2D and then 3D is better than one that is
	-- briefly empty, and the retry below is what makes the second half happen.
	StandIn(element, unit, missing and unit and UnitExists(unit))

	if element.umbraWaiting then return end
	if not unit or not UnitExists(unit) then return end
	if not missing then return end

	-- A chain that cannot succeed. The client has refused this unit, so
	-- every try would ask the same question and get the same nothing,
	-- eight of them over four seconds, for every hostile unit in an
	-- instance. The stand-in above is already up; there is nothing here
	-- to wait for.
	if WithheldIdentity(unit) then
		return Umbra:Debug('portrait withheld for', unit,
			'— identity is secret, not waiting for one')
	end

	-- And a chain that cannot be read. A hidden PlayerModel does not
	-- load, which is why the stand-in covers the model rather than
	-- replacing it — so a hidden frame reports a missing model forever
	-- and would start a chain on every update. The four party stand-ins
	-- are exactly that while the frames are locked.
	local frame = element.__owner

	if frame and not frame:IsVisible() then return end

	element.umbraWaiting = true
	Umbra:Debug('portrait missing for', unit, '— standing in for it')
	RetryPortrait(element, 1)
end

--[[ What the column has to draw, asked four times in one picture
`/uuf dev check` answered `showing 3D model` for a column that was plainly
empty, and it was not lying: that line reported which of the two layers was
uncovered, which is all it ever measured. It says so in those words now.
Nothing in here can see whether the model under it drew anything, and the
file id is not that answer either.

Measured on Retail 120100 on 22 September 2026, on a hostile unit in the open
world whose identity is in the clear: `model: readable — 124639` over a
portrait square that holds 53 distinct colors across 1680 pixels, 1183 of
them the same one — the ground and the reaction tint, with nothing standing
on them. The player and the pet beside it come back 1732 distinct colors in
1920. So a file id says a model was named, not that one was drawn, and
`ModelPending` above reads the first as the second.

So the eye is asked instead, and asked once: `/uuf dev portrait` opens a box
with the same four attempts on every row, side by side, and the picture holds
all four answers at once.

	as drawn     the portrait camera and the unit — what the column does
	whole model  the model's own camera, which brings a body framed outside
	             the square into view if that is where it is
	file alone   the file the live element holds, loaded with no unit behind
	             it, which tells geometry the client owns apart from a unit
	             it will not build one for
	2D           SetPortraitTexture for the same unit, on a texture cleared
	             first, so what comes back is the client's answer and not the
	             last unit's face

**The target is the question and the player and the pet are the controls.**
Two units whose models are known to load, in the same picture, on the same
client, at the same moment: a row that is empty in all four squares is worth
something only next to a row that is not.

The box itself is in `Core/Report.lua`, next to the other window. What is
here is what it needs to know, and it is asked the way every measurement in
this addon is asked: a throw and a hidden value are answers, and neither of
them is a file.
--]]
local PORTRAIT_UNITS = {'target', 'player', 'pet'}

--[[ FileHeld(element)
What the element says it is holding: a number to load again, and a word to
print beside it.
--]]
local function FileHeld(element)
	local ok, file = pcall(element.GetModelFileID, element)

	if not ok then return nil, 'file errors — ' .. tostring(file) end
	if Umbra.Secrets.Is(file) then return nil, 'file hidden' end
	if file == nil then return nil, 'no file' end

	return file, 'file ' .. tostring(file)
end

--[[ Answer(name, getter, unit)
One client answer as one word. A function this client does not have is an
answer as well, and saying so beats a throw dressed up as a refusal.
--]]
local function Answer(name, getter, unit)
	if type(getter) ~= 'function' then return name .. ' — no such function' end

	local ok, value = pcall(getter, unit)

	if not ok then return name .. ' errors' end
	if Umbra.Secrets.Is(value) then return name .. ' hidden' end

	return name .. ' ' .. tostring(value)
end

--[[ Identity(unit)
Whether the client has classified this unit, which is what `SetUnit` is gated
on. Printed as one word: a GUID in the clear is forty characters of noise
next to a one-word finding.
--]]
local function Identity(unit)
	local ok, guid = pcall(UnitGUID, unit)

	if not ok then return 'identity errors' end
	if guid == nil then return 'no guid' end

	return 'identity ' .. (Umbra.Secrets.Is(guid) and 'secret' or 'in the clear')
end

--[[ PortraitElement(unit)
The live column for this unit, so the box loads the file the frames are
actually holding rather than one it asked for itself. A file asked for again
is a different measurement, and the empty square on screen belongs to this
one.
--]]
local function PortraitElement(unit)
	for _, frame in ipairs(oUF.objects) do
		if Umbra:FrameUnit(frame) == unit and frame:IsVisible()
			and frame.Portrait and frame.Portrait.GetModelFileID then
			return frame.Portrait
		end
	end
end

--[[ Umbra:PortraitRows()
One row per unit the box draws, whether or not there is anything behind it.
A missing target is a state worth seeing rather than a row left out: the
question is about a target, and a box that quietly shows two rows instead of
three is a box that has to be counted.
--]]
function Umbra:PortraitRows()
	local rows = {}

	for _, unit in ipairs(PORTRAIT_UNITS) do
		local row = {unit = unit}

		if not UnitExists(unit) then
			row.facts = 'nothing there'
		else
			local element = PortraitElement(unit)

			if element then
				row.file, row.held = FileHeld(element)
			else
				row.held = 'no frame of ours is showing this unit'
			end

			local ok, name = pcall(UnitName, unit)

			row.name = (ok and not Umbra.Secrets.Is(name) and name)
				or (ok and 'name hidden') or 'name errors'

			row.facts = table.concat({
				Identity(unit),
				row.held,
				Answer('ready', _G.IsUnitModelReadyForUI, unit),
			}, '   ·   ')
		end

		rows[#rows + 1] = row
	end

	--[[ Every row carries the player's own file
	`SetUnit` hands back the player's model for a unit it will not name, so
	`holds 878772` can appear on the target's row and mean *you*. The box
	says so where it happens, and can only say it if every row knows which
	number that is.
	--]]
	local mine

	for _, row in ipairs(rows) do
		if row.unit == 'player' then mine = row.file end
	end

	for _, row in ipairs(rows) do
		row.mine = mine
	end

	return rows
end

--[[ The frame that is told about every model in the world
`targettarget` is a derived token, so oUF spawns it **eventless**: a 0.5s tick
instead of events, `ouf.lua:405`. Two events are let through anyway, because
the portrait has nothing else to go on — and being on an eventless frame they
are registered without a unit filter, `events.lua:99`. So this one frame hears
UNIT_PORTRAIT_UPDATE and UNIT_MODEL_CHANGED for every unit in the world, and
oUF's portrait element opens by asking whether the unit that changed is ours.

**That question is what throws.** Issue #1, measured on Retail inside a delve: `portrait.lua:48: attempt to perform boolean test on a secret boolean
value`, 716 times in one session. Why the comparison comes back hidden despite
oUF asking permission first is written down in `Secrets.SameUnit`.

**A token compared with itself is refused by nothing**, and that is what the
whole guard below rests on, so it is worth saying where it was measured rather
than assumed: the same session. Every other frame only ever makes that
comparison, and this frame's own 0.5s tick makes it too — thousands of times
in the run that produced the 716 errors, without producing one of them.

So the handler is wrapped rather than the element replaced. oUF keeps its
event handlers in plain fields on the frame, `self[event]`, and calls them
through `onEvent`; standing in front of one costs a closure and leaves the
portrait still being set by oUF's own code rather than by a second copy of it
that could drift — the same reason `RetryPortrait` goes through `ForceUpdate`.

Three answers, three things to do. The event is not ours: drop it, which is
what oUF meant to do. The event is ours: hand it on, naming the frame's own
token so that the comparison oUF makes next is the one it cannot refuse. The
client will not say: settle it on a timer, because "some model somewhere
changed" arriving a few times a second must not reload ours a few times a
second, and one refresh answers all of them.
--]]
local PORTRAIT_SETTLE = 0.5

--[[ Every unit event the portrait element takes
The first two are what issue #1 arrived through, because they are the two an
eventless frame is allowed to keep. The other three reach `portrait.lua:48`
along the same line and have simply not been seen to throw — which is no
reason to leave a line that is known to be unsafe reachable three more ways.

**The portrait is the only element that compares units this way.** Health and
Power gate on `self.__unit ~= unit`, a plain string comparison that no client
can hide, so the three events they share with the portrait are safe for them
and unsafe for it in the same breath. That is what the identity match below is
for: those three fields hold a list of handlers, and only one entry in it is
the portrait's.

`PORTRAITS_UPDATED` is deliberately not here. It is registered unitless and
arrives with no unit at all, which oUF already drops a line above the
comparison.
--]]
local GUARDED_EVENTS = {
	'UNIT_PORTRAIT_UPDATE',
	'UNIT_MODEL_CHANGED',
	'UNIT_CONNECTION',
	'PARTY_MEMBER_ENABLE',
	'PARTY_MEMBER_DISABLE',
}

local function SettlePortrait(frame, element)
	if element.umbraSettling then return end
	element.umbraSettling = true

	C_Timer.After(PORTRAIT_SETTLE, function()
		element.umbraSettling = nil

		local unit = Umbra:FrameUnit(frame)

		if not unit or not UnitExists(unit) then return end
		if not frame:IsVisible() then return end

		element:ForceUpdate()
	end)
end

local function GuardPortraitEvents(frame)
	local element = frame.Portrait
	if not element then return end

	--[[ Which handler is the portrait's
	One function is registered for all five events, so whichever field still
	holds it alone names it, and identity picks it out of the lists the other
	events share. UNIT_PORTRAIT_UPDATE is that field: the portrait element is
	the only thing in oUF that asks for it.

	Anything else there is a frame this cannot reason about, and a guess is
	worth less than saying so.
	--]]
	local path = frame.UNIT_PORTRAIT_UPDATE

	if type(path) ~= 'function' then
		return Umbra:Debug('portrait guard found no handler on',
			tostring(Umbra:FrameUnit(frame)))
	end

	local function guard(self, event, unit, ...)
		local own = Umbra:FrameUnit(self)
		local same = Umbra.Secrets.SameUnit(own, unit)

		if same == false then return end

		if same == nil then
			--[[ Once, and only once
			A guard that does its job silently and one that was never
			reached are the same empty log, and that is the reading-two-ways
			trap this project keeps walking into. So the first refusal on
			each element writes itself down — `/uuf dev debug` then says whether
			the settling branch was ever taken, without needing a live
			target-of-target at the moment `/uuf dev check` is typed.

			Once per element rather than per event: this fires for every
			model in the world, and a 60-line buffer is there to hold what
			the build refused, not a transcript.
			--]]
			if not element.umbraRefused then
				element.umbraRefused = true
				Umbra:Debug('unit comparison refused:', tostring(own), 'against',
					tostring(unit), '— settling the portrait on a timer')
			end

			return SettlePortrait(self, element)
		end

		return path(self, event, own, ...)
	end

	for _, name in ipairs(GUARDED_EVENTS) do
		local handler = frame[name]

		if handler == path then
			frame[name] = guard
		elseif type(handler) == 'table' then
			-- `next` rather than `ipairs`: unregistering one handler out of a
			-- list leaves a hole in it, and a hole stops ipairs early.
			for index, func in next, handler do
				if func == path then
					handler[index] = guard
				end
			end
		end
	end
end

oUF:RegisterInitCallback(GuardPortraitEvents)

--[[ UpdateIdentity(element, unit, color)
Where a unit's identity is painted. oUF hands this the color it used,
which is nothing here — no color flag is set on the element — so the
color is asked for again through `Secrets.UnitColor`, which answers
class for a player and reaction for everything else, and answers with a
secret color where the class itself is secret.

The edge and the portrait tint carry it. **The bar does not**, and that
is the design principle rather than an omission: one green on every unit
means a color on a frame is identity and nothing else.

`/uuf health class` spends that on purpose. The bar takes the same
color, and the incoming-heal ghost follows it — a ghost left in the old
green over a class-colored bar reads as a second quantity arriving
rather than as more of the same one. Nothing else moves, and with the
setting off this is the three lines it has always been.
--]]
local function MuteFill(bar, alpha)
	local fill = bar and bar:GetStatusBarTexture()

	if fill then fill:SetAlpha(alpha) end
end

local function UpdateIdentity(element, unit, _)
	local color = Umbra.Secrets.UnitColor(unit)
	local frame = element.__owner

	if color then
		frame.ClassEdge:SetStatusBarColor(color:GetRGB())
		frame.PortraitTint:SetStatusBarColor(color:GetRGB())
	end

	local ghost = element.HealingAll

	if color and UmbraUnitFramesDB and UmbraUnitFramesDB.classHealth then
		-- The color goes on at full strength and the fill is faded
		-- instead, which is the only way to mute a class color at all:
		-- dimming one means arithmetic on its three numbers, and inside an
		-- instance those are secret. An alpha belongs to the texture
		-- rather than to the color, so it never touches them.
		--
		-- It also keeps the edge the loud one. Muted on the bar and full
		-- on the 3-pixel edge is the same information at two volumes,
		-- which is what the principle asks for even where the bar has been
		-- allowed to carry it.
		element:SetStatusBarColor(color:GetRGB())
		MuteFill(element, Umbra.metrics.classBarAlpha)

		if ghost then
			ghost:SetStatusBarColor(color:GetRGB())
			MuteFill(ghost, Umbra.metrics.classBarAlpha
				* colors.healPrediction[4])
		end
	else
		element:SetStatusBarColor(unpack(colors.health))
		MuteFill(element, 1)

		if ghost then
			-- The ghost's own alpha rides in its color here, where the
			-- bar is a color this addon chose and nothing has to be
			-- faded around it.
			ghost:SetStatusBarColor(unpack(colors.healPrediction))
			MuteFill(ghost, 1)
		end
	end
end

--[[ Umbra:ApplyHealthColors()
Repaint every frame that already stands there, for the one moment the
setting changes. Everything else reaches the color through oUF's own
update, which is why this is the only caller.

A frame with no unit is left alone rather than reset: it is showing
nothing, and the first thing that happens when a unit arrives is the
update that colors it correctly.
--]]
--[[ LabelOutline(element)
The two numbers that sit inside the health fill, cut to match whatever
is behind them. They are the only text in the frame with a colored
surface under it — the name and the power number sit on the frame's own
background, which is dark by construction.

Outlined only while the bar carries the unit's color, because that is
the only time the surface can be bright. The default green was chosen
with white text on it and needs nothing.
--]]
local function LabelOutline(element)
	if not element.umbraLabels then return end

	local wanted = UmbraUnitFramesDB and UmbraUnitFramesDB.classHealth
		and Umbra.metrics.barLabelOutline or nil

	for _, fs in ipairs(element.umbraLabels) do
		Umbra.Widgets.Outline(fs, wanted)
	end
end

function Umbra:ApplyHealthStyle()
	for _, frame in ipairs(oUF.objects) do
		local unit = Umbra:FrameUnit(frame)

		if frame.Health then
			LabelOutline(frame.Health)

			-- The color needs a unit to read; the outline does not, which is
			-- why one of the two is inside this and the other is not.
			if unit then
				UpdateIdentity(frame.Health, unit)
			end
		end
	end
end

--[[ What someone signed up as
`UnitGroupRolesAssigned` answers TANK, HEALER, DAMAGER or NONE, and —
measured in a five-man party inside an instance on 21 September 2026 —
it answers in the clear where it matters. That was not a given: a role
is a fact about a person in your group rather than about a unit in the
world, which is the kind of thing this client has been withholding.

All three roles are drawn. The first build marked only the tank and the
healer, on the argument that a mark on three rows out of four is not a
mark and that damage is named by carrying nothing — which reads well and
was wrong in use: a blank space says "no role" and "damage" in the same
breath, and the column has four rows where the gap is never explained.
NONE still draws nothing, because that one really is an absence.

The art is the client's own atlas, so the icon in the column is the same
icon as everywhere else in the game rather than a second drawing of the
same idea. A hidden role draws nothing: the table is indexed with the
answer, and indexing with a secret is one of the things that throws.
--]]
local ROLE_ATLAS = {
	TANK = 'roleicon-tiny-tank',
	HEALER = 'roleicon-tiny-healer',
	DAMAGER = 'roleicon-tiny-dps',
}

local function UpdateRole(self)
	local element = self.UmbraRole
	if not element then return end

	local unit = Umbra:FrameUnit(self)
	local atlas

	if unit and UnitExists(unit)
		and type(_G.UnitGroupRolesAssigned) == 'function' then

		local ok, role = pcall(UnitGroupRolesAssigned, unit)

		if ok and role ~= nil and not Umbra.Secrets.Is(role) then
			atlas = ROLE_ATLAS[role]
		end
	end

	-- An atlas this client does not have is the one failure that would
	-- not announce itself: `SetAtlas` on an unknown name leaves the
	-- texture as it was rather than refusing, so a blank square would
	-- stand where the mark should be. The healer's name is measured,
	-- the tank's is not.
	if atlas and C_Texture and C_Texture.GetAtlasInfo
		and not C_Texture.GetAtlasInfo(atlas) then

		Umbra:Debug('role art missing:', atlas)
		atlas = nil
	end

	if atlas and pcall(element.SetAtlas, element, atlas) then
		element:Show()
	else
		element:Hide()
	end
end

--[[ EnableRole(self) / DisableRole(self)
Both events are unitless and say so, which is what keeps them off oUF's
per-unit registration: the roster changing is news about the group, not
about one member of it. Everything else arrives through oUF's own update
of every element, which is what catches a header child being handed a
different unit.
--]]
local function EnableRole(self)
	if not self.UmbraRole then return end

	self:RegisterEvent('PLAYER_ROLES_ASSIGNED', UpdateRole, true)
	self:RegisterEvent('GROUP_ROSTER_UPDATE', UpdateRole, true)

	return true
end

local function DisableRole(self)
	if not self.UmbraRole then return end

	self:UnregisterEvent('PLAYER_ROLES_ASSIGNED', UpdateRole)
	self:UnregisterEvent('GROUP_ROSTER_UPDATE', UpdateRole)
end

local function Style(self, unit)
	--[[ Which config this frame is built from
	Named exactly where one exists, which covers every single frame and the
	boss column, whose frames really are `boss1` through `boss5` and differ
	from each other in nothing but their unit.

	Numbered down to its bare name otherwise. A group header hands the style
	`party`, but a frame pointed at one slot of that group is `party1`, and
	both have to arrive at the same config or the stand-ins for placing the
	column would come out as four player frames — full size, castbar, class
	power and all. The fallback to `player` stays underneath as the answer
	for a unit nothing here has ever named.

	Frame configs fall back to the shared layout through their metatable, so
	`l` answers for a metric as well as for a frame's own override.
	--]]
	local config = Umbra.frames[unit]
		or Umbra.frames[unit:gsub('%d+$', '')]
		or Umbra.frames.player
	local l = config

	-- Before anything registers: a client that lacks an event oUF asks for
	-- lets go of it here instead of reporting it. Only Compat/Classic.lua
	-- defines this.
	if Umbra.GuardUnknownEvents then
		Umbra.GuardUnknownEvents(self)
	end

	local width, height = config.width, Umbra:FrameHeight(config)
	local columnX = l.classEdge + l.gap + l.portrait + l.gap
	local columnWidth = width - columnX - l.inset
	local healthY = -(l.nameHeight + l.gap)
	local powerY = healthY - (l.healthHeight + l.gap)
	local pipY = powerY - (l.powerHeight + l.gap)

	self:SetSize(width, height)
	self:RegisterForClicks('AnyUp')

	Tooltip(self)

	local background = self:CreateTexture(nil, 'BACKGROUND')
	background:SetAllPoints()
	background:SetColorTexture(unpack(colors.background))

	-- Class color lives here and on the name, never on the health bar.
	local edge = CreateColorLayer(self)
	edge:SetPoint('TOPLEFT', self, 'TOPLEFT', 0, 0)
	edge:SetSize(l.classEdge, height)
	self.ClassEdge = edge

	-- A PlayerModel renders on nothing, so without a ground of its own the
	-- portrait shows whatever is behind the frame, and the class tint above it
	-- lands on that instead of on a neutral surface.
	local ground = self:CreateTexture(nil, 'BACKGROUND', nil, 1)
	ground:SetPoint('TOPLEFT', self, 'TOPLEFT', l.classEdge + l.gap, 0)
	ground:SetSize(l.portrait, height)
	ground:SetColorTexture(unpack(colors.portraitGround))

	local portrait = CreateFrame('PlayerModel', nil, self)
	portrait:SetPoint('TOPLEFT', self, 'TOPLEFT', l.classEdge + l.gap, 0)
	portrait:SetSize(l.portrait, height)
	portrait.PostUpdate = PortraitPostUpdate
	self.Portrait = portrait

	--[[ The 2D stand-in
	Laid over the model rather than swapped for it. A PlayerModel that is
	hidden does not load, so hiding it would take away the chance of the real
	model ever turning up; this sits a level above and covers it while there
	is nothing to see.

	The client's portrait art is square and this column is not, so the texture
	is cropped rather than stretched: the full height, and as much width as
	that height allows, taken from the middle where the face is.
	--]]
	local flat = CreateFrame('Frame', nil, self)
	flat:SetPoint('TOPLEFT', self, 'TOPLEFT', l.classEdge + l.gap, 0)
	flat:SetSize(l.portrait, height)
	flat:SetFrameLevel(portrait:GetFrameLevel() + 1)
	flat:Hide()

	local flatArt = flat:CreateTexture(nil, 'ARTWORK')
	flatArt:SetAllPoints(flat)

	do
		local trim = 0.08
		local span = 1 - trim * 2
		local half = span * (l.portrait / height) / 2

		flatArt:SetTexCoord(0.5 - half, 0.5 + half, trim, 1 - trim)
	end

	portrait.umbraFlat = flat
	portrait.umbraFlatArt = flatArt

	local tint = CreateColorLayer(self, 0.13)
	tint:SetPoint('TOPLEFT', self, 'TOPLEFT', l.classEdge + l.gap, 0)
	tint:SetSize(l.portrait, height)
	tint:SetFrameLevel(portrait:GetFrameLevel() + 2)
	self.PortraitTint = tint

	-- Every number on the right edge shares this inset, so they stack into one
	-- column. The health percentage needs it because it sits inside its own
	-- bar and has to clear the bar's edge; the power percentage sits in the
	-- header with no bar around it and would otherwise sit an inset further
	-- out than the number directly below it.
	local valueRight = l.inset * 2

	-- Room for the role, reserved on every group frame whether or not
	-- there is one to draw. Four names starting at the same x and two
	-- of them carrying a mark reads as a column; names that shift
	-- sideways when somebody changes role reads as a fault. The pip
	-- row on the player frame is reserved for the same reason.
	local roleWidth = config.header and (l.nameHeight + l.gap) or 0
	local nameX = columnX + roleWidth

	local nameWidth = columnWidth - roleWidth

	-- Power is a hairline and cannot hold a label, so the number goes in the
	-- header where there is room for it. Only worth the space on the frames
	-- that are read rather than glanced at: player, target and party.
	if config.powerValue then
		-- The name stops a gap short of the number column.
		nameWidth = (width - valueRight - l.valueWidth - l.gap) - nameX

		local powerValue = CreateText(self, 'RIGHT', l.fontSize)
		powerValue:SetPoint('TOPRIGHT', self, 'TOPRIGHT', -valueRight, 0)
		powerValue:SetSize(l.valueWidth, l.nameHeight)
		powerValue:SetTextColor(unpack(colors.muted))

		-- The number reads in the color of the bar it belongs to. oUF's
		-- powercolor tag opens a color escape from the client's own
		-- PowerBarColor, the same route [umbra:identity] takes for a class
		-- color, so nothing has to be read off a hidden value. The muted
		-- color above stays as what shows if the escape ever comes back
		-- empty.
		self:Tag(powerValue, '[powercolor][perpp]%|r')
	end

	local name = CreateText(self, 'LEFT', l.fontSize)
	name:SetPoint('TOPLEFT', self, 'TOPLEFT', nameX, 0)
	name:SetSize(nameWidth, l.nameHeight)

	if roleWidth > 0 then
		local role = self:CreateTexture(nil, 'OVERLAY')
		role:SetSize(l.nameHeight, l.nameHeight)
		role:SetPoint('TOPLEFT', self, 'TOPLEFT', columnX, 0)
		role:Hide()

		self.UmbraRole = role
	end

	-- No color flag is set, so oUF leaves the color applied here alone and
	-- never evaluates a curve against a hidden value.
	local health = CreateBar(self, colors.health)
	health:SetPoint('TOPLEFT', self, 'TOPLEFT', columnX, healthY)
	health:SetSize(columnWidth, l.healthHeight)
	health.PostUpdateColor = UpdateIdentity
	self.Health = health

	--[[ What is coming to the bar, and what stands in front of it
	oUF's Health element owns these three and updates them itself, including
	their width: it sets each one as wide as the health bar on every size
	change. So only the height and the one anchor are ours.

	**That anchor is the exception to the geometry rule**, and it is the only
	way the arithmetic can happen at all. Incoming healing starts where
	current health ends, and `current + incoming` cannot be worked out here:
	both are hidden, and adding them throws. The client can do it, so the
	sum is expressed as an anchor — the healing bar begins at the right edge
	of the health fill, the absorb at the right edge of the healing fill —
	and the sum never passes through Lua.

	The rule itself is unharmed, because it is about *reading* geometry:
	nothing asks these bars how wide they came out. oUF sizes them from the
	health bar, whose rectangle is explicit, and otherwise only calls
	SetMinMaxValues and SetValue on them, both of which take hidden numbers.

	Each is as wide as the whole bar while starting somewhere inside it, so
	the overhang is clipped rather than drawn past the frame's edge.
	--]]
	health:SetClipsChildren(true)

	local predictionLevel = health:GetFrameLevel() + 1

	local healing = CreatePrediction(health, colors.healPrediction)
	healing:SetPoint('TOPLEFT', health:GetStatusBarTexture(), 'TOPRIGHT')
	healing:SetHeight(l.healthHeight)
	healing:SetFrameLevel(predictionLevel)
	health.HealingAll = healing

	local absorb = CreatePrediction(health, colors.absorb, true)
	absorb:SetPoint('TOPLEFT', healing:GetStatusBarTexture(), 'TOPRIGHT')
	absorb:SetHeight(l.healthHeight)
	absorb:SetFrameLevel(predictionLevel)
	health.DamageAbsorb = absorb

	-- The one that runs the other way: a heal absorb stands in front of
	-- health that is already there, so it fills backwards from the fill's
	-- own edge into the bar rather than outwards from it.
	local healAbsorb = CreatePrediction(health, colors.healAbsorb)
	healAbsorb:SetPoint('TOPRIGHT', health:GetStatusBarTexture(), 'TOPRIGHT')
	healAbsorb:SetReverseFill(true)
	healAbsorb:SetHeight(l.healthHeight)
	healAbsorb:SetFrameLevel(predictionLevel)
	health.HealAbsorb = healAbsorb

	-- The prediction bars are children of the health bar and therefore draw
	-- above everything the bar itself carries, its labels included. So the
	-- numbers move onto a layer above them, and an absorb can never cover the
	-- value it belongs to. Explicitly sized and anchored to the frame, like
	-- every other widget here; only the parent decides what draws on top.
	local labels = CreateFrame('Frame', nil, health)
	labels:SetPoint('TOPLEFT', self, 'TOPLEFT', columnX, healthY)
	labels:SetSize(columnWidth, l.healthHeight)
	labels:SetFrameLevel(predictionLevel + 1)

	local healthValue = CreateText(labels, 'LEFT', l.fontSize)
	healthValue:SetPoint('TOPLEFT', self, 'TOPLEFT', columnX + l.inset, healthY)
	healthValue:SetSize(columnWidth - l.valueWidth - l.inset * 2, l.healthHeight)

	local healthPercent = CreateText(labels, 'RIGHT', l.fontSize)
	healthPercent:SetPoint('TOPRIGHT', self, 'TOPRIGHT', -valueRight, healthY)
	healthPercent:SetSize(l.valueWidth, l.healthHeight)

	health.umbraLabels = {healthValue, healthPercent}
	LabelOutline(health)

	-- Power colors come from oUF's table, which Core/Defaults.lua restates
	-- where Umbra disagrees with the client. No colorPowerAtlas: a bar painted
	-- with one of Blizzard's textures has no color for the number above it to
	-- match, and at four pixels tall there is no texture to see anyway.
	local power = CreateBar(self, colors.muted)
	power:SetPoint('TOPLEFT', self, 'TOPLEFT', columnX, powerY)
	power:SetSize(columnWidth, l.powerHeight)
	power.colorPower = true
	self.Power = power

	if config.classPower then
		local pips = {}

		for index = 1, 10 do
			local pip = CreateBar(self, colors.accent)
			pip:SetPoint('TOPLEFT', self, 'TOPLEFT', columnX, pipY)
			pip:SetSize(columnWidth, l.pipHeight)
			pip:Hide()
			pips[index] = pip
		end

		-- How many points the class has is not known until oUF reports it,
		-- and it changes with specialisation, so the row is laid out then.
		pips.PostUpdate = function(element, _, max, _, hasMaxChanged)
			if not hasMaxChanged or not max or max < 1 then return end

			local slot = (columnWidth - (max - 1) * l.gap) / max

			for index = 1, max do
				element[index]:ClearAllPoints()
				element[index]:SetPoint('TOPLEFT', self, 'TOPLEFT',
					columnX + (index - 1) * (slot + l.gap), pipY)
				element[index]:SetSize(slot, l.pipHeight)
			end
		end

		self.ClassPower = pips
	end

	if config.castbar then
		local castbar = CreateBar(self, colors.cast)
		castbar:SetPoint('TOPLEFT', self, 'BOTTOMLEFT', 0, -l.gap)
		castbar:SetSize(width, l.castbarHeight)

		castbar.Text = CreateText(castbar, 'LEFT', l.fontSize)
		castbar.Text:SetPoint('LEFT', castbar, 'LEFT', l.inset, 0)
		castbar.Text:SetSize(width - l.valueWidth - l.inset * 3, l.castbarHeight)

		castbar.Time = CreateText(castbar, 'RIGHT', l.fontSize)
		castbar.Time:SetPoint('RIGHT', castbar, 'RIGHT', -l.inset, 0)
		castbar.Time:SetSize(l.valueWidth, l.castbarHeight)
		castbar.Time:SetTextColor(unpack(colors.muted))

		self.Castbar = castbar
	end

	--[[ Range, which only a group frame can answer
	The sixth principle: a unit out of reach fades rather than disappearing,
	so the column keeps its shape and you can still see who is where.

	It waited for the header rather than being half-built on the single
	frames, and oUF's element says why in one line — it gates on
	`UnitInParty`, and for anything that is not a group member it sets the
	inside alpha and stops. On the player frame it would be a no-op that
	quietly always reports "in range", which is the kind of half-working
	thing that gets believed.

	`SetAlphaFromBoolean` is what it fades with, so the answer never has to
	be tested. `UnitIsConnected(unit) and UnitInParty(unit)` above it is
	tested though, and that is the exact shape issue #1 threw 716 times on —
	on a hostile unit, where this one only ever asks about party members.
	Watched in the error log rather than guarded against in advance.
	--]]
	if config.header then
		self.Range = {
			insideAlpha = 1,
			outsideAlpha = l.rangeAlpha,
		}
	end

	-- Kept so that a set switch can re-anchor this frame's rows later
	-- without having to work out which config it was built from.
	self.umbraConfig = config

	Umbra:AddAuras(self, unit, config)

	self:Tag(name, '[umbra:identity][name]|r')
	self:Tag(healthValue, '[umbra:health]')
	self:Tag(healthPercent, '[perhp]%')
end

oUF:AddElement('UmbraRole', UpdateRole, EnableRole, DisableRole)
oUF:RegisterStyle('Umbra', Style)
