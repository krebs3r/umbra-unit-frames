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

	frame:ClearAllPoints()

	if saved then
		frame:SetPoint(saved.point, UIParent, saved.relativePoint, saved.x, saved.y)
	else
		frame:SetPoint(unpack(self:ActiveLayout().points[frame.umbraKey]))
	end
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
	self:ApplyLayout()
end

--[[ Umbra:ApplyLayout()
Re-anchors every frame, and every aura row on it, to the set in force.

Nothing is created here, so switching sets needs no reload: the containers
already exist and only have to be told where to hang and which way to grow.
--]]
function Umbra:ApplyLayout()
	for _, frame in ipairs(movers) do
		self:AnchorFrame(frame)

		if frame.umbraConfig then
			self:AnchorAuras(frame, frame.umbraConfig)
		end
	end
end

--[[ Umbra:SetLocked(locked)
Returns false when the request was refused, which only happens in combat.
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
			frame.umbraOverlay:Hide()
		else
			frame:SetScript('OnDragStart', frame.StartMoving)
			frame:SetScript('OnDragStop', function(self)
				self:StopMovingOrSizing()
				SavePosition(self)
			end)
			frame.umbraOverlay:Show()
		end
	end

	return true
end
