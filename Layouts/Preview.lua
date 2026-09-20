local _, ns = ...
local Umbra = ns.Umbra
local oUF = ns.oUF

--[[ A full row of auras, without waiting for one
A row only ever shows what the unit happens to be carrying, and that is never
the case the arrangement has to survive: every slot taken, on both frames, in
both sets. `/uuf test` fills each reserved block with stand-ins so that the
worst case can be looked at on demand.

**Nothing here touches the aura container.** The stand-ins hang off the unit
frame and find their place through `Umbra:StackOffset`, the same answer the
container itself was anchored with. That is not tidiness: inside an instance
the container and its buttons gain forbidden aspects, and a frame of ours
parented to one would be asking the client for exactly what it refuses there.
Staying off it also means the preview still draws on a client that refused the
containers outright, which is when the arrangement is hardest to picture.

What the stand-ins do and do not speak for:

- They are re-cut by `Umbra.AuraButtonLook`, the same function that re-cuts a
  real button, so the icon, the labels and the line are the real geometry
  rather than a second copy of it that could drift.
- They are packed by `Umbra:AuraPerRow`, the same arithmetic that reserves the
  block. The client packs the real rows itself, so a real row that disagrees
  with the preview is a finding about that arithmetic.
- The icon is a question mark and the durations are stand-in strings. Neither
  says anything about what the client would put there.
- The dispel colors are not invented. They cycle through `oUF.colors.dispel`,
  which oUF fills from the client's own `AuraUtil.GetDebuffDisplayInfoTable()`
  and which is the very table handed to `AddDispelTypeTexture`. So they are
  the colors a dispellable aura really gets, side by side, out in the open
  world where the real ones cannot be read.

Real auras stay where they are while this is on, and the stand-ins draw over
them. Turning it off is what gives an honest picture of the unit again.
--]]

local QUESTION_MARK = [[Interface\Icons\INV_Misc_QuestionMark]]

-- One that overhangs if any would, the ordinary case, and a few in between.
local DURATIONS = {'24 m', '9 s', '1.2 m', '59 m', '3 s'}

local shown = false

--[[ DispelNames()
The client's dispel types, in an order that does not change between calls.
Read out of the table rather than listed, so a type the client adds appears
here without this file knowing about it.
--]]
local function DispelNames()
	local dispel = oUF.colors and oUF.colors.dispel
	if not dispel then return end

	local names = {}

	for name in pairs(dispel) do
		names[#names + 1] = name
	end

	if #names == 0 then return end

	table.sort(names)

	return names, dispel
end

--[[ Stand(frame, look, index, harmful)
One stand-in, built to look like the button oUF hands PostCreateButton.

`look` is a stand-in element too: PostCreateButton reads its metrics off the
element it is given, and never off the container.
--]]
local function Stand(frame, look, index, harmful)
	local l = look.umbra
	local button = CreateFrame('Frame', nil, frame)
	button:SetSize(l.icon, l.icon + l.gap + l.underline)

	button.Icon = button:CreateTexture(nil, 'ARTWORK')
	button.Icon:SetTexture(QUESTION_MARK)

	button.Count = button:CreateFontString(nil, 'OVERLAY')
	button.Time = button:CreateFontString(nil, 'OVERLAY')

	Umbra.AuraButtonLook(look, button)

	-- After the re-cut, which is what gives the labels their font.
	-- Every third one stacks, so the count can be looked at without every
	-- icon carrying a number it would not really have.
	button.Count:SetText(index % 3 == 0 and tostring(index) or '')
	button.Time:SetText(DURATIONS[(index - 1) % #DURATIONS + 1])

	-- The first two keep the neutral line, which is what most auras get.
	local names, dispel = DispelNames()

	if harmful and index > 2 and names and button.Underline then
		local color = dispel[names[(index - 3) % #names + 1]]

		if color and color.GetRGB then
			button.Underline:SetVertexColor(color:GetRGB())
		end
	end

	return button
end

--[[ Place(frame, config, layout, filter, row)
Packs one block, measured from the frame's own edge.

A row above the frame fills from its bottom edge upwards and one below from
its top edge downwards, the same turn `Grow` gives the real container.
--]]
local function Place(frame, config, layout, filter, row)
	local above = Umbra:StackOffset(config, layout, 'above', filter)
	local offset = above or Umbra:StackOffset(config, layout, 'below', filter)
	if not offset then return end

	local step = config.auraSize + config.auraSpacing
	local lineStep = Umbra:AuraButtonHeight(config) + config.auraSpacing
	local perRow = Umbra:AuraPerRow(config)

	for index, button in ipairs(row) do
		local column = (index - 1) % perRow
		local line = math.floor((index - 1) / perRow)

		button:ClearAllPoints()

		if above then
			button:SetPoint('BOTTOMLEFT', frame, 'TOPLEFT',
				column * step, offset + line * lineStep)
		else
			button:SetPoint('TOPLEFT', frame, 'BOTTOMLEFT',
				column * step, -(offset + line * lineStep))
		end
	end
end

--[[ Build(frame, config)
A stand-in for every slot the frame reserves, built once and kept.
--]]
local function Build(frame, config)
	if frame.UmbraPreview then return end

	frame.UmbraPreview = {}

	for filter, count in pairs(config.auras) do
		local harmful = filter == 'harmful'

		-- What PostCreateButton reads off an element, without an element.
		local look = {umbra = {
			icon = config.auraSize,
			underline = config.auraUnderline,
			gap = config.gap,
			font = config.auraFontSize,
			harmful = harmful,
		}}

		local row = {}

		for index = 1, count do
			row[index] = Stand(frame, look, index, harmful)
		end

		frame.UmbraPreview[filter] = row
	end
end

--[[ Umbra:PlacePreview()
Re-packs whatever is already built. Called after a set switch, where a row can
have moved to the other side of the frame and turned round with it.
--]]
function Umbra:PlacePreview()
	local layout = self:ActiveLayout()

	for _, frame in ipairs(oUF.objects) do
		local config = frame.umbraConfig

		if config and frame.UmbraPreview then
			for filter, row in pairs(frame.UmbraPreview) do
				Place(frame, config, layout, filter, row)
			end
		end
	end
end

--[[ Umbra:SetPreview(show)
Turns the stand-ins on or off, building them the first time they are asked
for. Answers how many are showing, which is none on a layout that reserves no
aura rows at all.
--]]
function Umbra:SetPreview(show)
	shown = show

	local count = 0

	for _, frame in ipairs(oUF.objects) do
		local config = frame.umbraConfig

		if config and config.auras then
			if show then
				Build(frame, config)
			end

			if frame.UmbraPreview then
				for _, row in pairs(frame.UmbraPreview) do
					for _, button in ipairs(row) do
						button:SetShown(show)
						count = count + 1
					end
				end
			end
		end
	end

	if show then
		self:PlacePreview()
	end

	return count
end

function Umbra:PreviewShown()
	return shown
end
