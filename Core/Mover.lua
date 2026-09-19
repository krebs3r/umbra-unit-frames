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

local function SavePosition(frame)
	local point, _, relativePoint, x, y = frame:GetPoint()
	if not point then return end

	UmbraUnitFramesDB.positions[frame.umbraKey] = {
		point = point,
		relativePoint = relativePoint,
		x = math.floor(x + 0.5),
		y = math.floor(y + 0.5),
	}
end

--[[ Umbra:PlaceFrame(frame, key, default)
Anchors a frame to its saved position, or to the layout default.
--]]
function Umbra:PlaceFrame(frame, key, default)
	frame.umbraKey = key

	local saved = UmbraUnitFramesDB.positions[key]

	frame:ClearAllPoints()
	if saved then
		frame:SetPoint(saved.point, UIParent, saved.relativePoint, saved.x, saved.y)
	else
		frame:SetPoint(unpack(default))
	end

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
	label:SetFont(self.media.font, self.layout.fontSize)
	label:SetPoint('CENTER')
	label:SetText(key)
	label:SetShadowColor(0, 0, 0, 0.85)
	label:SetShadowOffset(1, -1)

	frame.umbraOverlay = overlay
	movers[#movers + 1] = frame
end

--[[ Umbra:ResetPositions()
Puts every frame back where the layout wanted it. The way out of having
dragged a frame off the edge of the screen.
--]]
function Umbra:ResetPositions()
	wipe(UmbraUnitFramesDB.positions)

	for _, frame in ipairs(movers) do
		local config = self.frames[frame.umbraKey]

		frame:ClearAllPoints()
		frame:SetPoint(unpack(config.point))
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
