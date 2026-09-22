local _, ns = ...
local Umbra = ns.Umbra

--[[ Moving frames
Blizzard's Edit Mode only arranges its own frames, so an addon's frames need
their own way to be placed. `/uuf unlock` turns every frame into something you
can drag; `/uuf lock` puts them back to work.

Unit frames are protected, and the client forbids moving a protected frame in
combat, so unlocking is refused there rather than failing halfway.
--]]

local movers = {}
Umbra.locked = true

-- What the stand-ins were doing before unlocking turned them on, so that
-- locking gives back the display you had rather than the one it borrowed.
local previewWasShown = false

-- An unfinished reveal, when combat stopped it from being applied.
local pendingReveal = nil

-- And an unfinished placing, for the same reason. Declared here with the
-- other one rather than beside the function that sets it: a local declared
-- after its first use is a global, silently, and both of these are read in
-- one place and written in another.
local pendingLayout = nil

--[[ Positions()
Where dragged frames are remembered, for the set in force.

Each set is a different arrangement of the same frames, so a frame dragged in
one has nothing to say about where it belongs in the other. Keyed by set, a
switch goes back to what that set was left looking like.
--]]
local function Positions()
	local name = Umbra:LayoutName()

	UmbraUnitFramesDB.positions[name] = UmbraUnitFramesDB.positions[name] or {}

	return UmbraUnitFramesDB.positions[name]
end

local function SavePosition(frame)
	local point, _, relativePoint, x, y = frame:GetPoint()
	if not point then return end

	Positions()[frame.umbraKey] = {
		point = point,
		relativePoint = relativePoint,
		x = math.floor(x + 0.5),
		y = math.floor(y + 0.5),
	}
end

--[[ Umbra:AnchorFrame(frame)
Puts a frame where it belongs: its saved position, or what the set says.

Separate from PlaceFrame because switching sets runs this again on frames that
already exist, and must not build a second mover overlay for them.
--]]
function Umbra:AnchorFrame(frame)
	local saved = Positions()[frame.umbraKey]

	-- SetClampedToScreen keeps the frame's own box on screen and knows
	-- nothing of the castbar and the aura rows hanging off it, so a frame
	-- dragged to the bottom edge takes its debuffs off the screen with it.
	-- Each inset is added to the coordinate of its edge, with +x to the right
	-- and +y up, so the reach above is positive and the reach below negative.
	-- The rows are exactly as wide as the frame, so the sides stay at zero.
	--
	-- A set switch changes both reaches, which is why this is here rather
	-- than in PlaceFrame.
	if frame.umbraConfig then
		local layout = self:ActiveLayout()
		local above = self:StackOffset(frame.umbraConfig, layout, 'above')
		local below = self:StackOffset(frame.umbraConfig, layout, 'below')

		frame:SetClampRectInsets(0, 0, above, -below)
	end

	frame:ClearAllPoints()

	if saved then
		frame:SetPoint(saved.point, UIParent, saved.relativePoint, saved.x, saved.y)

		return
	end

	--[[ A set that does not name this frame
	Every frame a set spawns should have a place in it, and one missing is a
	fault in Core/Defaults.lua rather than anything the client did. But it is
	found here, at PLAYER_LOGIN, in the middle of building every frame — and
	unpacking nil would take the rest of that build down with it.

	So it is reported and parked in the middle, where it can be seen and
	dragged somewhere better, and the frames after it still get built.
	--]]
	local point = self:ActiveLayout().points[frame.umbraKey]

	if not point then
		self:Debug('no place in this layout for', frame.umbraKey)
		frame:SetPoint('CENTER')

		return
	end

	frame:SetPoint(unpack(point))
end

--[[ Snapping, and the guides that show it
A frame dragged by hand lands a unit or two off the one beside it, and the eye
reads that as a mistake rather than as a choice.

So while a frame is being dragged, its three vertical lines — left edge,
centre, right edge — and its three horizontal ones are compared against the
same lines on every other frame, and against the middle of the screen.
Anything within `snapDistance` lights a guide, and letting go puts the frame
on it.

The move happens on release rather than during the drag, because a dragged
frame follows the cursor: moving it underneath makes it stick and fight rather
than snap.

**Asking a frame for its own rectangle is allowed here**, though the geometry
rule forbids deriving size from a widget that carries unit data. It is allowed
precisely because of that rule: every frame is explicitly sized and anchored
to UIParent, so nothing in its rectangle came from a unit.
--]]
local guides = CreateFrame('Frame', nil, UIParent)
guides:SetAllPoints()
guides:SetFrameStrata('TOOLTIP')
guides:Hide()

local function Guide()
	local line = guides:CreateTexture(nil, 'OVERLAY')
	local accent = Umbra.colors.accent

	line:SetColorTexture(accent[1], accent[2], accent[3], 0.8)
	line:Hide()

	return line
end

local guideX, guideY = Guide(), Guide()

--[[ Box(frame)
The rectangle a frame occupies, and the middle of it. Nil before the frame has
been laid out.

Asking a frame for its own rectangle is allowed here, though the geometry rule
forbids deriving size from a widget that carries unit data. It is allowed
because of that rule: every frame is explicitly sized and anchored to UIParent,
so nothing in this rectangle came from a unit.
--]]
local function Box(frame)
	local left, right = frame:GetLeft(), frame:GetRight()
	local bottom, top = frame:GetBottom(), frame:GetTop()

	if not left or not bottom then return end

	return {
		left = left, right = right, midX = (left + right) / 2,
		bottom = bottom, top = top, midY = (bottom + top) / 2,
	}
end

--[[ Slots(frame, box)
The lines another frame may be stacked onto, above and below this one.

**A frame's box is not the end of it.** A castbar hangs below it and the aura
rows below that, so offering the box edge as a place to stack onto is offering
to cover them — which is exactly how a pet frame ended up on top of the
player's castbar.

Two kinds of line come out of the stack instead:

- Where the set keeps room for *another frame*, which is an entry naming one:
  in `modern` the pet sits between the castbar and the debuffs, and that slot
  is where a dragged pet belongs. An aura row is never such a slot, because a
  frame put on one covers it.
- Clear of everything this frame draws for itself, which is the whole reach.

A frame with neither, the pet among them, offers its own edges, since for it
the box really is the end.
--]]
local function Slots(frame, box)
	local config = frame.umbraConfig

	if not config then
		return {box.bottom}, {box.top}
	end

	local layout = Umbra:ActiveLayout()
	local under, over = {}, {}

	-- An entry that names a frame is room for one. Asking Umbra.frames keeps
	-- this true of any frame a later set puts in a stack.
	for _, entry in ipairs(layout.below) do
		if Umbra.frames[entry] and Umbra:StackHeight(config, entry) then
			under[#under + 1] = box.bottom - Umbra:StackOffset(config, layout, 'below', entry)
		end
	end

	for _, entry in ipairs(layout.above) do
		if Umbra.frames[entry] and Umbra:StackHeight(config, entry) then
			over[#over + 1] = box.top + Umbra:StackOffset(config, layout, 'above', entry)
		end
	end

	under[#under + 1] = box.bottom - Umbra:StackOffset(config, layout, 'below')
	over[#over + 1] = box.top + Umbra:StackOffset(config, layout, 'above')

	return under, over
end

--[[ Candidates(dragged)
Every pairing of a line on the dragged frame with a line it could land on, per
axis, as `{mine, theirs}`.

The pairings are named rather than crossed. Aligning is edge to *matching*
edge — two frames read as a row only when the same edges agree — and stacking
goes to a slot, never to a box edge. Crossing every line with every other is
what offered the pet a place on the castbar.
--]]
local function Candidates(dragged)
	local mine = Box(dragged)
	if not mine then return end

	local xs, ys = {}, {}

	local function pair(axis, line, onto)
		axis[#axis + 1] = {line, onto}
	end

	pair(xs, mine.midX, UIParent:GetWidth() / 2)
	pair(ys, mine.midY, UIParent:GetHeight() / 2)

	for _, frame in ipairs(movers) do
		if frame ~= dragged and frame:IsShown() then
			local theirs = Box(frame)

			if theirs then
				pair(xs, mine.left, theirs.left)
				pair(xs, mine.midX, theirs.midX)
				pair(xs, mine.right, theirs.right)

				-- Beside it, and only sideways: nothing hangs off the sides,
				-- because the aura rows are exactly as wide as the frame.
				pair(xs, mine.left, theirs.right)
				pair(xs, mine.right, theirs.left)

				pair(ys, mine.bottom, theirs.bottom)
				pair(ys, mine.midY, theirs.midY)
				pair(ys, mine.top, theirs.top)

				local under, over = Slots(frame, theirs)

				for _, line in ipairs(under) do pair(ys, mine.top, line) end
				for _, line in ipairs(over) do pair(ys, mine.bottom, line) end
			end
		end
	end

	return xs, ys
end

--[[ Bands(frame, box, shift)
The horizontal strips a frame actually draws: its own box, the castbar beneath
it, and each aura block the set hangs on it.

What lies *between* them is not drawn and is free for another frame to sit in
— in `modern` that is exactly the space the pet occupies, which is why an
entry naming a frame contributes no band of its own. Every strip is as wide as
the frame, so only the vertical extent has to be written down.

`shift` moves them all, for asking where the frame would collide rather than
where it does.
--]]
local function Bands(frame, box, shift)
	shift = shift or 0

	local bands = {{box.bottom + shift, box.top + shift}}
	local config = frame.umbraConfig

	if not config then return bands end

	local layout = Umbra:ActiveLayout()
	local castbar = Umbra:CastbarReach(config)

	if castbar > 0 then
		bands[#bands + 1] = {box.bottom - castbar + shift, box.bottom + shift}
	end

	for _, entry in ipairs(layout.below) do
		local height = not Umbra.frames[entry] and Umbra:StackHeight(config, entry)

		if height then
			local edge = box.bottom - Umbra:StackOffset(config, layout, 'below', entry) + shift

			bands[#bands + 1] = {edge - height, edge}
		end
	end

	for _, entry in ipairs(layout.above) do
		local height = not Umbra.frames[entry] and Umbra:StackHeight(config, entry)

		if height then
			local edge = box.top + Umbra:StackOffset(config, layout, 'above', entry) + shift

			bands[#bands + 1] = {edge, edge + height}
		end
	end

	return bands
end

--[[ Collides(dragged, shift)
Whether the dragged frame, moved by `shift`, would cover anything another
frame draws.

Touching edges do not count: a frame resting exactly on the bottom of another
one's debuff row is placed, not overlapping. Frames beside each other are
never in each other's way, so the horizontal ranges are tested first — every
strip is as wide as its frame, so that is one comparison for all of them.
--]]
local function Collides(dragged, shift)
	local mine = Box(dragged)
	if not mine then return false end

	local ours = Bands(dragged, mine, shift)

	for _, frame in ipairs(movers) do
		if frame ~= dragged and frame:IsShown() then
			local theirs = Box(frame)

			if theirs and mine.left < theirs.right and theirs.left < mine.right then
				for _, a in ipairs(ours) do
					for _, b in ipairs(Bands(frame, theirs)) do
						if a[1] < b[2] and b[1] < a[2] then return true end
					end
				end
			end
		end
	end

	return false
end

--[[ Nearest(candidates)
How far to move, and onto what, for the closest pairing inside the snap
distance. Nil when nothing is near enough.
--]]
local function Nearest(candidates)
	local shift, onto

	for _, candidate in ipairs(candidates) do
		local delta = candidate[2] - candidate[1]

		if math.abs(delta) <= Umbra.metrics.snapDistance
			and (not shift or math.abs(delta) < math.abs(shift)) then

			shift, onto = delta, candidate[2]
		end
	end

	return shift, onto
end

local function ShowGuide(line, vertical, at)
	if not at then
		line:Hide()
		return
	end

	line:ClearAllPoints()

	if vertical then
		line:SetPoint('BOTTOM', UIParent, 'BOTTOMLEFT', at, 0)
		line:SetSize(1, UIParent:GetHeight())
	else
		line:SetPoint('LEFT', UIParent, 'BOTTOMLEFT', 0, at)
		line:SetSize(UIParent:GetWidth(), 1)
	end

	line:Show()
end

local function OnDragUpdate(dragged)
	local xs, ys = Candidates(dragged)
	if not xs then return end

	local _, ontoX = Nearest(xs)
	local _, ontoY = Nearest(ys)

	ShowGuide(guideX, true, ontoX)
	ShowGuide(guideY, false, ontoY)
end

--[[ Clear(dragged, shiftY)
A vertical shift that covers nothing, starting from the one snapping asked
for.

Snapping alone is not enough to keep a frame off another one's castbar: laid
by hand on the box edge, the slot underneath is a whole castbar away, far
outside the snap distance, so nothing catches it. Only refusing the overlap
does — but refusing it everywhere would fight someone arranging frames that
never meet. So the lines are only reached for once the frame would actually
cover something, and then the nearest one that does not is taken however far
away it is.

The candidates already hold the slot lines and the one clear of the whole
reach, so there is always somewhere to go.
--]]
local function Clear(dragged, ys, shiftY)
	if not Collides(dragged, shiftY) then return shiftY end

	local shifts = {}

	for _, candidate in ipairs(ys) do
		shifts[#shifts + 1] = candidate[2] - candidate[1]
	end

	table.sort(shifts, function(a, b) return math.abs(a) < math.abs(b) end)

	for _, shift in ipairs(shifts) do
		if not Collides(dragged, shift) then return shift end
	end

	return shiftY
end

local function Snap(dragged)
	local xs, ys = Candidates(dragged)
	if not xs then return end

	local shiftX = Nearest(xs) or 0
	local shiftY = Clear(dragged, ys, Nearest(ys) or 0)

	if shiftX == 0 and shiftY == 0 then return end

	local point, relativeTo, relativePoint, x, y = dragged:GetPoint()
	if not point then return end

	-- Offsets run along the screen's own axes whatever corner the point
	-- names, so one addition serves every anchor either set uses.
	dragged:ClearAllPoints()
	dragged:SetPoint(point, relativeTo or UIParent, relativePoint, x + shiftX, y + shiftY)
end

local function OnDragStart(dragged)
	dragged:StartMoving()
	dragged:SetScript('OnUpdate', OnDragUpdate)
	guides:Show()
end

local function OnDragStop(dragged)
	dragged:SetScript('OnUpdate', nil)
	dragged:StopMovingOrSizing()

	guideX:Hide()
	guideY:Hide()
	guides:Hide()

	Snap(dragged)
	SavePosition(dragged)
end

--[[ Umbra:PlaceFrame(frame, key)
Anchors a frame and makes it draggable.
--]]
function Umbra:PlaceFrame(frame, key)
	frame.umbraKey = key

	self:AnchorFrame(frame)

	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	frame:RegisterForDrag('LeftButton')

	local overlay = CreateFrame('Frame', nil, frame)
	overlay:SetAllPoints()
	overlay:SetFrameLevel(frame:GetFrameLevel() + 10)
	overlay:Hide()

	local fill = overlay:CreateTexture(nil, 'OVERLAY')
	fill:SetAllPoints()
	fill:SetColorTexture(self.colors.accent[1], self.colors.accent[2], self.colors.accent[3], 0.25)

	local label = overlay:CreateFontString(nil, 'OVERLAY')
	label:SetFont(self.media.font, self.metrics.fontSize)
	label:SetPoint('CENTER')
	label:SetText(key)
	label:SetShadowColor(0, 0, 0, 0.85)
	label:SetShadowOffset(1, -1)

	frame.umbraOverlay = overlay
	movers[#movers + 1] = frame
end

--[[ Umbra:ResetPositions()
Puts every frame back where the set wanted it. The way out of having dragged a
frame off the edge of the screen.

Only the set in force is forgotten; the other one keeps what it was left
looking like.
--]]
function Umbra:ResetPositions()
	wipe(Positions())

	-- Answered rather than assumed, because the placing below it can be
	-- refused: the positions are forgotten either way, and only the moving
	-- waits.
	return self:ApplyLayout()
end

--[[ Umbra:ApplyLayout()
Re-anchors every frame, and every aura row on it, to the set in force.

Nothing is created here, so switching sets needs no reload: the containers
already exist and only have to be told where to hang and which way to grow.

**Refused in combat, and finished when it ends.** Every frame here is a secure
unit button, and `SetClampRectInsets` on one of those is the client's business
while a fight is on. Measured on Retail: `/uuf reset` in combat came back as
`ADDON_ACTION_BLOCKED` for `UmbraBoss5Frame:SetClampRectInsets()`, out of
`AnchorFrame` — not an error, a refusal, and one that taints the path it was
called on.

So it is remembered and run at `PLAYER_REGEN_ENABLED`, the way a reveal is.
Answers false when that happened, so whoever asked can say the frames move
when the fight ends rather than reporting a move that did not happen.
--]]
function Umbra:ApplyLayout()
	if InCombatLockdown() then
		pendingLayout = true

		return false
	end

	pendingLayout = nil

	for _, frame in ipairs(movers) do
		self:AnchorFrame(frame)

		if frame.umbraConfig then
			self:AnchorAuras(frame, frame.umbraConfig)
		end
	end

	-- A row that changed sides now fills from the other corner, and the
	-- stand-ins are packed by hand rather than by the container.
	self:PlacePreview()

	return true
end

--[[ Reveal(revealed)
Shows every frame while unlocked, including the ones that have nothing to
show.

oUF calls `RegisterUnitWatch` on each frame it spawns, so a frame whose unit
is not there is hidden — and with no target and no pet there is nothing to
drag but the player. Letting go of the watch shows the frame where it belongs;
taking it back hands the decision to the client again.

Both calls reach the secure side and are refused in combat, so a reveal that
cannot be applied is remembered and finished when combat ends. Unlocking is
already refused in combat, but locking is not: being stuck with frames you can
still drag is a poorer place to leave someone than a late tidy-up.
--]]
local function Reveal(revealed)
	if InCombatLockdown() then
		pendingReveal = revealed
		return false
	end

	pendingReveal = nil

	for _, frame in ipairs(movers) do
		--[[ A frame that is not shown by a unit watch
		A group column is one box standing in for children the client makes
		and hides on its own, and `RegisterUnitWatch` on it would tie a
		header with no unit of its own to a unit that is never there. What
		reveals it is a different thing, so the frame carries its own way of
		being revealed and this loop asks for it rather than knowing which
		frames are which.
		--]]
		if frame.umbraReveal then
			frame.umbraReveal(frame, revealed)
		elseif revealed then
			if pcall(UnregisterUnitWatch, frame) then
				frame:Show()
			else
				Umbra:Debug('cannot reveal:', frame.umbraKey)
			end
		elseif pcall(RegisterUnitWatch, frame) then
			-- Registering re-evaluates, but saying it outright costs nothing
			-- and does not depend on when that happens.
			local unit = Umbra:FrameUnit(frame)

			if not unit or not UnitExists(unit) then
				frame:Hide()
			end
		end
	end

	return true
end

local combat = CreateFrame('Frame')
combat:RegisterEvent('PLAYER_REGEN_ENABLED')
combat:SetScript('OnEvent', function()
	-- Both halves of what combat can refuse, in the order they matter: a
	-- frame is placed before it is shown.
	if pendingLayout then
		Umbra:ApplyLayout()
	end

	if pendingReveal ~= nil then
		Reveal(pendingReveal)
	end
end)

--[[ Umbra:SetLocked(locked)
Returns false when the request was refused, which only happens in combat.

Unlocking does three things at once, because placing a frame means placing all
of it: every frame is shown, including the ones with no unit behind them, and
the aura rows are filled with stand-ins so that what you drag is the whole
extent rather than the box in the middle of it.
--]]
function Umbra:SetLocked(locked)
	if not locked and InCombatLockdown() then
		return false
	end

	self.locked = locked

	for _, frame in ipairs(movers) do
		if locked then
			frame:SetScript('OnDragStart', nil)
			frame:SetScript('OnDragStop', nil)

			-- A drag interrupted rather than finished never reaches
			-- OnDragStop, and would leave the guides running.
			frame:SetScript('OnUpdate', nil)
			frame.umbraOverlay:Hide()
		else
			frame:SetScript('OnDragStart', OnDragStart)
			frame:SetScript('OnDragStop', OnDragStop)
			frame.umbraOverlay:Show()
		end
	end

	if locked then
		guideX:Hide()
		guideY:Hide()
		guides:Hide()

		self:SetPreview(previewWasShown)
	else
		previewWasShown = self:PreviewShown()
		self:SetPreview(true)
	end

	Reveal(not locked)

	return true
end
