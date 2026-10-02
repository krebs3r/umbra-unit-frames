local _, ns = ...
local Umbra = ns.Umbra

local colors = Umbra.colors
local metrics = Umbra.metrics
local L = Umbra.L
local W = Umbra.Widgets

local Texture, Label, Hatch = W.Texture, W.Label, W.Hatch

--[[ The onboarding
The first login asks what `/uuf` sets, one question to a page, each with a
drawing of what the answer does. The sheet it was drawn from is
`assets/design/onboarding.svg`, and the numbers below are the ones
`tools/mockups.py` draws it with (`ONB` there); change one, change both.

**Every answer is applied the moment it is clicked**, through
`Umbra:SetOption`, the call the options window and `/uuf` end in. So there is
nothing to confirm at the end and nothing lost by closing the window halfway:
what is on screen is what was chosen, and Skip simply leaves the defaults.

**It asks once.** `UmbraUnitFramesDB.onboarded` is false only on an install
that had no saved variables at all (`Core/Init.lua`), and the window sets it
true however it is left — Done, Skip, the close button or Escape. `/uuf setup`
brings it back.

**One height on every page.** The controls have a fixed band, so Back and Next
stand still under the pointer from the first page to the last.
--]]

local WIDTH = 320
local EDGE = metrics.classEdge
local PAD = 12
local LEFT = EDGE + PAD
local INNER = WIDTH - LEFT - PAD
local HEADER = 36
local PREVIEW = 132
local CONTROLS_HEIGHT = 52
local SEGMENT = 22
local BOX = 14
local BUTTON = 22
local NAV = 64
local DOT = 6

-- The bands, top to bottom: `onboarding_layout` in the sheet. The three text
-- lines are baselines there; a font string here is placed by its top.
local EYEBROW = HEADER + 22
local HEADING = EYEBROW + 22
local BODY = HEADING + 18
local PREVIEW_Y = BODY + 26
local CONTROLS = PREVIEW_Y + PREVIEW + 12
local RULE = CONTROLS + CONTROLS_HEIGHT + 12
local NAV_Y = RULE + 12
local HEIGHT = NAV_Y + BUTTON + 12

-- The sheet's own grounds, for the preview: the paper the box stands on, and
-- the screen inside it with its outline.
local PAPER = {9 / 255, 11 / 255, 17 / 255}
local SCREEN = {13 / 255, 16 / 255, 24 / 255}
local SCREEN_RULE = {44 / 255, 52 / 255, 70 / 255}
local HOSTILE = {199 / 255, 64 / 255, 64 / 255}
local MANA = {Umbra.power.MANA[1] / 255, Umbra.power.MANA[2] / 255, Umbra.power.MANA[3] / 255}

-- The client's class colors, written down for the stand-ins in the party
-- column and the target's target: the preview shows where things go, and
-- nobody in it is a real unit.
local STAND_INS = {
	targettarget = {198 / 255, 155 / 255, 109 / 255},
	party = {
		{1, 124 / 255, 10 / 255},
		{1, 1, 1},
		{0, 112 / 255, 221 / 255},
		{135 / 255, 136 / 255, 238 / 255},
	},
}

local STEPS = {
	{key = 'layout', eyebrow = 'Welcome', heading = 'Choose your layout',
		body = "Each layout remembers where you've moved your frames, so feel free to try both."},
	{key = 'health', eyebrow = 'Health bar', heading = 'Pick a health bar color',
		body = 'Neutral keeps class color on the edge and the name. Class color paints the bar as well.'},
	{key = 'level', eyebrow = 'Level', heading = 'Where should the level go?',
		body = 'On the portrait, before the name, or not at all. On a target, the color shows how tough it is.'},
	{key = 'blizzard', eyebrow = 'Blizzard frames', heading = "Hide Blizzard's frames?",
		body = 'Umbra already shows your buffs and party. Keep the group manager if you use its raid markers.'},
	{key = 'done', eyebrow = 'Done', heading = 'Ready to go',
		body = "That's it! Unlock the frames below to move them, or change any setting later."},
}

local window

-- Whether a fight is on, believed from the events as the options window does.
local fighting = false

local function SetColor(texture, color, alpha)
	texture:SetColorTexture(color[1], color[2], color[3], alpha or color[4] or 1)
end

--[[ The player's own color
Through `Secrets.UnitColor`, the route every frame takes, so a client that
hides the class still hands back something the texture accepts. The accent
stands in where nothing comes back.
--]]
local function PlayerColor()
	local ok, color = pcall(Umbra.Secrets.UnitColor, 'player')

	if ok and color and color.GetRGB then
		return {color:GetRGB()}
	end

	return colors.accent
end

--[[ Outline(parent, alpha)
A one-pixel frame drawn as four lines: what the preview shows for something
of Blizzard's that has been put away. The sheet dashes it; the client has no
dashed line to draw, and an outline with nothing in it says the same thing.
--]]
local function Outline(parent, color, alpha)
	local lines = {}

	for index, points in ipairs({
		{'TOPLEFT', 'TOPRIGHT'}, {'BOTTOMLEFT', 'BOTTOMRIGHT'},
		{'TOPLEFT', 'BOTTOMLEFT'}, {'TOPRIGHT', 'BOTTOMRIGHT'},
	}) do
		local line = Texture(parent, 'OVERLAY', color, alpha)
		line:SetPoint(points[1])
		line:SetPoint(points[2])

		if index <= 2 then line:SetHeight(1) else line:SetWidth(1) end

		lines[index] = line
	end

	return lines
end

--[[ MiniScreen(parent, which)
A screen at a glance: where a set puts each frame, as blocks — the ground, the
class edge and a strip of health; aura rows and the columns as blocks of
their own.

Placed by the set's own points, scaled. The client resolves every anchor the
way it resolves the real frames', so the drawing cannot disagree with the
arrangement it stands for — the sheet has to redo that arithmetic, this does
not.
--]]
local function MiniScreen(parent, which)
	local set = Umbra.layouts[which]
	local uiWidth, uiHeight = UIParent:GetWidth(), UIParent:GetHeight()

	local height = PREVIEW - 16
	local width = height * uiWidth / uiHeight

	if width > INNER - 16 then
		width = INNER - 16
		height = width * uiHeight / uiWidth
	end

	local s = width / uiWidth

	local screen = CreateFrame('Frame', nil, parent)
	screen:SetSize(width, height)
	screen:SetPoint('CENTER', parent, 'CENTER')

	Texture(screen, 'BACKGROUND', SCREEN):SetAllPoints()
	Outline(screen, SCREEN_RULE)

	local function Px(value)
		return math.max(1, value * s)
	end

	local function Block(anchorTo, point, relativePoint, x, y, config, color, health)
		local frameHeight = Umbra:FrameHeight(config)

		local block = CreateFrame('Frame', nil, screen)
		block:SetSize(Px(config.width), Px(frameHeight))
		block:SetPoint(point, anchorTo, relativePoint, x * s, y * s)

		Texture(block, 'BACKGROUND', colors.background):SetAllPoints()

		local edge = Texture(block, 'ARTWORK', color)
		edge:SetPoint('TOPLEFT')
		edge:SetPoint('BOTTOMLEFT')
		edge:SetWidth(math.max(1, config.classEdge * s * 1.5))

		if health then
			local strip = Texture(block, 'ARTWORK', colors.health)
			strip:SetPoint('TOPLEFT', block, 'TOPLEFT', config.width * s * 0.24, -frameHeight * s * 0.42)
			strip:SetSize(math.max(1, config.width * s * 0.7 * health), Px(frameHeight * 0.3))
		end

		return block
	end

	local function Auras(block, config)
		for _, side in ipairs({'above', 'below'}) do
			for _, entry in ipairs(set[side]) do
				local count = config.auras and config.auras[entry]

				if count then
					local offset = Umbra:StackOffset(config, set, side, entry)
					local row = Texture(block, 'BORDER',
						entry == 'harmful' and colors.auraHarmful or colors.auraHelpful, 0.35)
					row:SetSize(Px(config.width), Px(Umbra:AuraBlockHeight(config, count)))

					if side == 'above' then
						row:SetPoint('BOTTOMLEFT', block, 'TOPLEFT', 0, offset * s)
					else
						row:SetPoint('TOPLEFT', block, 'BOTTOMLEFT', 0, -offset * s)
					end
				end
			end
		end
	end

	local player = PlayerColor()

	for key, point in pairs(set.points) do
		local config = Umbra.frames[key]

		if key == 'party' and config then
			-- The column as the header lays it out: one slot per member, the
			-- spacing between them, the whole of it anchored by its point.
			local slot = Umbra:GroupSlotHeight(config)
			local column = CreateFrame('Frame', nil, screen)
			column:SetSize(Px(config.width), Px(Umbra:ColumnHeight(config, Umbra.partyCount)))
			column:SetPoint(point[1], screen, point[3], point[4] * s, point[5] * s)

			for index = 1, Umbra.partyCount do
				local color = STAND_INS.party[(index - 1) % #STAND_INS.party + 1]

				Block(column, 'TOPLEFT', 'TOPLEFT', 0,
					-(index - 1) * (slot + config.groupSpacing), config, color)
			end
		elseif config then
			local color = (key == 'player' or key == 'pet') and player
				or STAND_INS[key] or HOSTILE
			local block = Block(screen, point[1], point[3], point[4], point[5], config, color,
				key == 'pet' and 1 or 0.7)

			Auras(block, config)
		end
	end

	--[[ Blizzard's own, where they stand by default
	The buff row left of the minimap and the group manager as a tab on the
	left edge. Solid while kept, an empty outline once put away.
	--]]
	local function Blizzard(point, x, y, w, h, text, labelPoint, labelX, labelY)
		local box = CreateFrame('Frame', nil, screen)
		box:SetPoint(point, screen, point, x * s, y * s)
		box:SetSize(w * s, h * s)

		box.fill = Texture(box, 'ARTWORK', colors.muted, 0.45)
		box.fill:SetAllPoints()
		box.outline = Outline(box, colors.muted, 0.6)

		box.label = Label(box, 8, colors.text, L[text])
		box.label:SetPoint(labelPoint[1], box, labelPoint[2], labelX, labelY)

		function box:SetKept(kept)
			self.fill:SetShown(kept)

			for _, line in ipairs(self.outline) do line:SetShown(not kept) end

			self.label:SetTextColor(unpack(kept and colors.text or colors.muted))
			self.label:SetAlpha(kept and 1 or 0.7)
		end

		return box
	end

	-- The label of the group tab stands above it, clear of the party column.
	screen.auras = Blizzard('TOPRIGHT', -230, -14, 330, 70, 'Blizzard buffs', {'RIGHT', 'LEFT'}, -4, 0)
	screen.group = Blizzard('TOPLEFT', 0, -150, 22, 190, 'Group manager', {'BOTTOMLEFT', 'TOPLEFT'}, 2, 2)

	function screen:ShowBlizzard(shown)
		self.auras:SetShown(shown)
		self.group:SetShown(shown)
	end

	screen:ShowBlizzard(false)

	return screen
end

--[[ FramePreview(parent)
The player frame as `Layouts/Shared.lua` lays it, from the same metrics, in
plain textures: the portrait column with the player's own portrait in it,
the name, a health bar, the power hairline and the pip row. Stand-in values,
the player's own name, class color and level — and the two things the pages
ask about, the health bar's color and where the level stands.
--]]
local function FramePreview(parent)
	local c = Umbra.frames.player
	local width, height = c.width, Umbra:FrameHeight(c)
	local columnX = c.classEdge + c.gap + c.portrait + c.gap
	local columnWidth = width - columnX - c.inset
	local healthY = c.nameHeight + c.gap
	local powerY = healthY + c.healthHeight + c.gap
	local pipY = powerY + c.powerHeight + c.gap
	local valueRight = c.inset * 2
	local color = PlayerColor()

	local scale = 1.15
	local frame = CreateFrame('Frame', nil, parent)
	frame:SetSize(width, height)
	frame:SetScale(scale)
	frame:SetPoint('CENTER', parent, 'CENTER', 0, 0)

	Texture(frame, 'BACKGROUND', colors.background):SetAllPoints()

	local edge = Texture(frame, 'ARTWORK', color)
	edge:SetPoint('TOPLEFT')
	edge:SetPoint('BOTTOMLEFT')
	edge:SetWidth(c.classEdge)

	local portraitX = c.classEdge + c.gap

	local ground = Texture(frame, 'BORDER', colors.portraitGround)
	ground:SetPoint('TOPLEFT', frame, 'TOPLEFT', portraitX, 0)
	ground:SetSize(c.portrait, height)

	-- The 2D portrait, cut to the column the way the frame's stand-in is: it
	-- is square and the column is not, so the sides go.
	local portrait = frame:CreateTexture(nil, 'ARTWORK')
	portrait:SetPoint('TOPLEFT', ground)
	portrait:SetSize(c.portrait, height)

	if pcall(SetPortraitTexture, portrait, 'player') then
		local cut = (1 - c.portrait / height) / 2
		portrait:SetTexCoord(cut, 1 - cut, 0, 1)
	end

	local tint = Texture(frame, 'ARTWORK', color, 0.13, 1)
	tint:SetAllPoints(ground)

	local plateHeight = c.fontSize + 4

	local plate = CreateFrame('Frame', nil, frame)
	plate:SetPoint('BOTTOMLEFT', frame, 'BOTTOMLEFT', portraitX, 0)
	plate:SetSize(c.portrait, plateHeight)
	Texture(plate, 'BACKGROUND', colors.border, 0.5):SetAllPoints()

	local level = UnitLevel('player')

	local plateText = Label(plate, c.fontSize, colors.muted, level)
	plateText:SetPoint('CENTER')

	local nameLevel = Label(frame, c.fontSize, colors.muted, level)
	nameLevel:SetPoint('TOPLEFT', frame, 'TOPLEFT', columnX, -1)

	local name = Label(frame, c.fontSize, color, UnitName('player'))
	name:SetJustifyH('LEFT')
	name:SetWordWrap(false)

	local powerValue = Label(frame, c.fontSize, MANA, '58%')
	powerValue:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', -valueRight, -1)

	local health = Texture(frame, 'BORDER', colors.border)
	health:SetPoint('TOPLEFT', frame, 'TOPLEFT', columnX, -healthY)
	health:SetSize(columnWidth, c.healthHeight)

	local fill = frame:CreateTexture(nil, 'ARTWORK')
	fill:SetPoint('TOPLEFT', health)
	fill:SetSize(columnWidth * 0.72, c.healthHeight)

	local healthValue = Label(frame, c.fontSize, colors.text, '412k')
	healthValue:SetPoint('LEFT', health, 'LEFT', c.inset, 0)

	local healthPercent = Label(frame, c.fontSize, colors.text, '72%')
	healthPercent:SetPoint('RIGHT', frame, 'TOPRIGHT', -valueRight, -(healthY + c.healthHeight / 2))

	local power = Texture(frame, 'BORDER', colors.border)
	power:SetPoint('TOPLEFT', frame, 'TOPLEFT', columnX, -powerY)
	power:SetSize(columnWidth, c.powerHeight)

	local powerFill = Texture(frame, 'ARTWORK', MANA)
	powerFill:SetPoint('TOPLEFT', power)
	powerFill:SetSize(columnWidth * 0.58, c.powerHeight)

	local pips = 5
	local slot = (columnWidth - (pips - 1) * c.gap) / pips

	for index = 1, pips do
		local pip = Texture(frame, 'ARTWORK', index <= 3 and colors.accent or colors.border)
		pip:SetPoint('TOPLEFT', frame, 'TOPLEFT', columnX + (index - 1) * (slot + c.gap), -pipY)
		pip:SetSize(slot, c.pipHeight)
	end

	function frame:Refresh()
		if Umbra:GetOption('health') then
			SetColor(fill, color, metrics.classBarAlpha)
		else
			SetColor(fill, colors.health)
		end

		local placement = Umbra:GetOption('level')

		plate:SetShown(placement == 'portrait')
		nameLevel:SetShown(placement == 'name')

		name:ClearAllPoints()
		name:SetPoint('RIGHT', powerValue, 'LEFT', -c.gap, 0)

		if placement == 'name' then
			name:SetPoint('LEFT', nameLevel, 'RIGHT', 4, 0)
		else
			name:SetPoint('TOPLEFT', frame, 'TOPLEFT', columnX, -1)
		end
	end

	return frame
end

--[[ Doors(parent)
The commands worth knowing once the window is gone, centred in the preview
box. Not `/uuf lock`: the button under the box already locks.
--]]
local DOOR_STEP = 28

local function Doors(parent)
	local doors = {
		{'/uuf', 'opens the options'},
		{'/uuf reset', 'puts the frames back in place'},
		{'/uuf setup', 'shows this guide again'},
		{'/uuf help', 'lists all commands'},
	}

	local top = (PREVIEW - ((#doors - 1) * DOOR_STEP + 12)) / 2

	for index, door in ipairs(doors) do
		local y = -(top + (index - 1) * DOOR_STEP)

		local dot = Texture(parent, 'ARTWORK', colors.accent)
		dot:SetSize(4, 4)
		dot:SetPoint('TOPLEFT', parent, 'TOPLEFT', 14, y - 4)

		local label = Label(parent, 11, colors.text, L[door[1]])
		label:SetPoint('TOPLEFT', parent, 'TOPLEFT', 26, y)

		local note = Label(parent, 10, colors.muted, L[door[2]])
		note:SetPoint('TOPLEFT', parent, 'TOPLEFT', 104, y - 1)
		note:SetPoint('RIGHT', parent, 'RIGHT', -8, 0)
		note:SetJustifyH('LEFT')
		note:SetWordWrap(false)
	end
end

local function Build()
	local frame = CreateFrame('Frame', nil, UIParent)

	-- Named for Escape alone, as the options window is.
	_G.UmbraOnboardingFrame = frame

	frame:SetFrameStrata('DIALOG')
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:RegisterForDrag('LeftButton')
	frame:SetScript('OnDragStart', frame.StartMoving)
	frame:SetScript('OnDragStop', frame.StopMovingOrSizing)
	frame:SetSize(WIDTH, HEIGHT)
	frame:SetPoint('CENTER', UIParent, 'CENTER', 0, 80)

	local border = Texture(frame, 'BACKGROUND', colors.border)
	border:SetPoint('TOPLEFT', -1, 1)
	border:SetPoint('BOTTOMRIGHT', 1, -1)

	Texture(frame, 'BACKGROUND', colors.background, nil, 1):SetAllPoints()

	local edge = Texture(frame, 'ARTWORK', colors.accent)
	edge:SetPoint('TOPLEFT')
	edge:SetPoint('BOTTOMLEFT')
	edge:SetWidth(EDGE)

	local title = Label(frame, 13, colors.text, 'Umbra Unit Frames')
	title:SetPoint('TOPLEFT', frame, 'TOPLEFT', LEFT, -12)

	local close = CreateFrame('Button', nil, frame)
	close:SetSize(18, 18)
	close:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', -PAD + 3, -9)
	Texture(close, 'BACKGROUND', colors.border):SetAllPoints()

	local cross = Label(close, 14, colors.muted, '×')
	cross:SetPoint('CENTER', 0, 1)

	close:SetScript('OnClick', function() frame:Hide() end)
	close:SetScript('OnEnter', function() cross:SetTextColor(unpack(colors.accent)) end)
	close:SetScript('OnLeave', function() cross:SetTextColor(unpack(colors.muted)) end)

	local function Rule(y)
		local rule = Texture(frame, 'ARTWORK', colors.muted, 0.18)
		rule:SetPoint('TOPLEFT', frame, 'TOPLEFT', EDGE, -y)
		rule:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', 0, -y)
		rule:SetHeight(1)
	end

	Rule(HEADER)
	Rule(RULE)

	-- The question: the same three lines on every page, rewritten per page.
	local eyebrow = Label(frame, 10, colors.accent)
	eyebrow:SetPoint('TOPLEFT', frame, 'TOPLEFT', LEFT, -(EYEBROW - 9))

	local heading = Label(frame, 15, colors.text)
	heading:SetPoint('TOPLEFT', frame, 'TOPLEFT', LEFT, -(HEADING - 13))

	local body = Label(frame, 11, colors.muted)
	body:SetPoint('TOPLEFT', frame, 'TOPLEFT', LEFT, -(BODY - 9))
	body:SetWidth(INNER)
	body:SetJustifyH('LEFT')
	body:SetJustifyV('TOP')
	body:SetSpacing(3)
	body:SetMaxLines(2)

	--[[ The pages
	One frame each over the whole window, so the controls a page holds are
	placed in the window's own coordinates — `Segmented` and `Check` place
	themselves against their parent's top left — and showing a page is
	showing one frame.
	--]]
	local pages = {}
	local controls = {}

	for index in ipairs(STEPS) do
		local page = CreateFrame('Frame', nil, frame)
		page:SetAllPoints()
		page:Hide()

		local preview = CreateFrame('Frame', nil, page)
		preview:SetPoint('TOPLEFT', page, 'TOPLEFT', LEFT, -PREVIEW_Y)
		preview:SetSize(INNER, PREVIEW)
		Texture(preview, 'BACKGROUND', PAPER):SetAllPoints()
		Outline(preview, colors.border)

		page.preview = preview
		pages[index] = page
	end

	local function Segment(index, key, choices)
		local control = W.Segmented(pages[index], CONTROLS, key, choices, INNER)

		-- Below the switch rather than above it: above is the preview.
		control.note:ClearAllPoints()
		control.note:SetPoint('TOPRIGHT', pages[index], 'TOPRIGHT', -PAD, -(CONTROLS + SEGMENT + 4))

		controls[key] = control
	end

	Segment(1, 'layout', {{'modern', 'Modern'}, {'classic', 'Classic'}})
	Segment(2, 'health', {{false, 'Neutral'}, {true, 'Class color'}})
	Segment(3, 'level', {{'portrait', 'Portrait'}, {'name', 'Name'}, {'off', 'Off'}})

	controls.auras = W.Check(pages[4], CONTROLS, 'auras', 'Hide Blizzard buffs & debuffs', INNER)
	controls.group = W.Check(pages[4], CONTROLS + BOX + 10, 'group', 'Hide Blizzard group manager', INNER)

	local unlock = Umbra.PlainButton(pages[5], L['Unlock frames'], INNER)
	unlock:SetPoint('TOPLEFT', pages[5], 'TOPLEFT', LEFT, -CONTROLS)

	unlock.line = Texture(unlock, 'ARTWORK', colors.accent)
	unlock.line:SetPoint('BOTTOMLEFT')
	unlock.line:SetPoint('BOTTOMRIGHT')
	unlock.line:SetHeight(2)

	unlock.hatch = Hatch(unlock)
	unlock.hatch:SetAllPoints()

	unlock:SetScript('OnClick', function() Umbra:SetLocked(not Umbra.locked) end)

	-- Where the client has an addon compartment, the minimap button is off
	-- by default and the question is not worth a row.
	if not Umbra:HasCompartment() then
		controls.minimap = W.Check(pages[5], CONTROLS + BUTTON + 10, 'minimap', 'Show minimap button', INNER)
	end

	-- What each page shows, built once and refreshed.
	local screens = {}

	for _, index in ipairs({1, 4}) do
		screens[index] = {
			modern = MiniScreen(pages[index].preview, 'modern'),
			classic = MiniScreen(pages[index].preview, 'classic'),
		}
	end

	local previews = {
		[2] = FramePreview(pages[2].preview),
		[3] = FramePreview(pages[3].preview),
	}

	Doors(pages[5].preview)

	-- The way through: Skip on the left, the pages as dots, Back and Next.
	local skip = CreateFrame('Button', nil, frame)
	skip:SetPoint('TOPLEFT', frame, 'TOPLEFT', LEFT, -NAV_Y)
	skip:SetHeight(BUTTON)

	local skipLabel = Label(skip, 12, colors.muted, L['Skip'])
	skipLabel:SetPoint('LEFT')
	-- The label's own width, so the dots centre on what is really free; a
	-- font not measured yet answers 0, and the button still has to be hit.
	skip:SetWidth(math.max(40, skipLabel:GetStringWidth() + 4))

	skip:SetScript('OnClick', function() frame:Hide() end)
	skip:SetScript('OnEnter', function() skipLabel:SetTextColor(unpack(colors.text)) end)
	skip:SetScript('OnLeave', function() skipLabel:SetTextColor(unpack(colors.muted)) end)

	local nextButton = Umbra.PlainButton(frame, L['Next'], NAV)
	nextButton:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', -PAD, -NAV_Y)

	nextButton.line = Texture(nextButton, 'ARTWORK', colors.accent)
	nextButton.line:SetPoint('BOTTOMLEFT')
	nextButton.line:SetPoint('BOTTOMRIGHT')
	nextButton.line:SetHeight(2)

	-- The next step is the one to take, so it carries the accent at rest as
	-- well as under the pointer.
	nextButton.UmbraLabel:SetTextColor(unpack(colors.accent))
	nextButton:SetScript('OnLeave', function(self) self.UmbraLabel:SetTextColor(unpack(colors.accent)) end)

	local back = Umbra.PlainButton(frame, L['Back'], NAV)
	back:SetPoint('TOPRIGHT', nextButton, 'TOPLEFT', -6, 0)

	-- The dots stand centred in what is left between Skip and Back, whichever
	-- language Skip is in. Back's place is kept on the first page, where the
	-- button itself is not shown.
	local track = CreateFrame('Frame', nil, frame)
	track:SetPoint('LEFT', skip, 'RIGHT', 0, 0)
	track:SetPoint('RIGHT', frame, 'TOPRIGHT', -(PAD + NAV + 6 + NAV), -(NAV_Y + BUTTON / 2))
	track:SetHeight(DOT)

	local dots = {}
	local span = #STEPS * DOT + (#STEPS - 1) * 6

	for index in ipairs(STEPS) do
		local dot = Texture(track, 'ARTWORK', colors.muted, 0.35)
		dot:SetSize(DOT, DOT)
		dot:SetPoint('LEFT', track, 'CENTER', -span / 2 + (index - 1) * (DOT + 6), 0)
		dots[index] = dot
	end

	local current = 1

	--[[ What the window refuses, and why
	The options window's rules, word for word: the layout is kept in a fight
	and applied when it ends, unlocking is refused there, and on a client
	where the party column stood down the switch for Blizzard's group manager
	has nothing to hand over.
	--]]
	function frame:Refresh()
		local step = STEPS[current]

		eyebrow:SetText(('%s  ·  %d / %d'):format(L[step.eyebrow]:upper(), current, #STEPS))
		heading:SetText(L[step.heading])
		body:SetText(L[step.body])

		for index, page in ipairs(pages) do
			page:SetShown(index == current)
		end

		for index, dot in ipairs(dots) do
			SetColor(dot, index == current and colors.accent or colors.muted,
				index == current and 1 or 0.35)
		end

		back:SetShown(current > 1)
		nextButton.UmbraLabel:SetText(L[current == #STEPS and 'Done' or 'Next'])

		controls.layout:Refresh(fighting and 'applies after combat' or nil)
		controls.health:Refresh()
		controls.level:Refresh()
		controls.auras:Refresh()
		controls.group:Refresh(Umbra.groupStoodDown and 'not on this client' or nil)

		if controls.minimap then controls.minimap:Refresh() end

		local unlocked = not Umbra.locked
		local refused = fighting and not unlocked

		unlock.UmbraLabel:SetText(L[unlocked and 'Lock frames' or 'Unlock frames'])
		unlock.UmbraLabel:SetTextColor(unpack(unlocked and colors.accent or colors.text))
		unlock.UmbraLabel:SetAlpha(refused and 0.45 or 1)
		unlock.line:SetShown(unlocked)
		unlock.hatch:SetShown(refused)
		unlock:SetEnabled(not refused)

		local layout = Umbra:LayoutName()

		for index, pair in pairs(screens) do
			for name, screen in pairs(pair) do
				screen:SetShown(name == layout)

				if index == 4 then
					screen:ShowBlizzard(true)
					screen.auras:SetKept(not Umbra:GetOption('auras'))
					screen.group:SetKept(not Umbra:GetOption('group'))
				end
			end
		end

		for _, preview in pairs(previews) do
			preview:Refresh()
		end
	end

	function frame:ShowStep(index)
		current = math.max(1, math.min(#STEPS, index))
		self:Refresh()
	end

	nextButton:SetScript('OnClick', function()
		if current == #STEPS then
			frame:Hide()
		else
			frame:ShowStep(current + 1)
		end
	end)

	back:SetScript('OnClick', function() frame:ShowStep(current - 1) end)

	unlock:HookScript('OnLeave', function() frame:Refresh() end)
	unlock:HookScript('OnEnter', function(self)
		if not self:IsEnabled() then frame:Refresh() end
	end)

	frame:RegisterEvent('PLAYER_REGEN_DISABLED')
	frame:RegisterEvent('PLAYER_REGEN_ENABLED')
	frame:SetScript('OnEvent', function(self, event)
		fighting = event == 'PLAYER_REGEN_DISABLED'

		if self:IsShown() then self:Refresh() end
	end)

	-- However the window is left, the question has been asked.
	frame:SetScript('OnHide', function()
		UmbraUnitFramesDB.onboarded = true
	end)

	frame:Hide()

	if type(_G.UISpecialFrames) == 'table' then
		tinsert(UISpecialFrames, 'UmbraOnboardingFrame')
	end

	return frame
end

--[[ Umbra:ShowOnboarding()
Opens the window on its first page, building it the first time. Built through
`pcall` for the reason the options window is: `/uuf setup` runs inside the chat
box's Enter handling, and a window that throws while it is built must not take
the chat frame with it.
--]]
function Umbra:ShowOnboarding()
	if not window then
		fighting = InCombatLockdown()

		local ok, built = pcall(Build)

		if not ok then
			self:Debug('onboarding failed:', built)
			print(self.prefix .. 'the onboarding could not be built: ' .. tostring(built)
				.. '. /uuf opens the options, which set the same.')

			return
		end

		window = built
	end

	window:ShowStep(1)
	window:Show()
end

-- An answer given anywhere else — the options window, a word in chat, a
-- mover locked from its own button — shows up in an open window at once.
hooksecurefunc(Umbra, 'OptionsChanged', function()
	if window and window:IsShown() then
		window:Refresh()
	end
end)

--[[ The first login
A second after PLAYER_LOGIN, so the frames it talks about are on screen
behind it. A login into a fight waits for the fight to end: a window of
questions is the last thing to put in front of one.
--]]
local starter = CreateFrame('Frame')
starter:RegisterEvent('PLAYER_LOGIN')
starter:SetScript('OnEvent', function(self, event)
	self:UnregisterEvent(event)

	if UmbraUnitFramesDB.onboarded ~= false then return end

	if event == 'PLAYER_REGEN_ENABLED' then
		Umbra:ShowOnboarding()

		return
	end

	C_Timer.After(1, function()
		if UmbraUnitFramesDB.onboarded ~= false then return end

		if InCombatLockdown() then
			self:RegisterEvent('PLAYER_REGEN_ENABLED')
		else
			Umbra:ShowOnboarding()
		end
	end)
end)
