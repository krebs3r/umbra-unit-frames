local _, ns = ...
local Umbra = ns.Umbra

local colors, media = Umbra.colors, Umbra.media

--[[ A window for output that is too long to read in chat
`/uuf dev check` answers around thirty lines, and a chat frame is the wrong place
to read them: everything else is pushed out of view, and the answers have to
be held against each other rather than watched scrolling past.

It carries no unit data at all — it is handed strings that were formatted
before it existed — so the geometry rule has nothing to say about it and its
widgets may size themselves however they like.

**It wears the client's own furniture.** A panel that looks like the rest of
the interface is one less thing to work out, and Blizzard's templates bring
the border, the title bar, the close button and the scroll bar for free. Every
one of them is asked for through `pcall` with something plain built here if it
is missing, the same care every other client-supplied thing in this addon
gets: Forever is missing parts of the Retail surface, and a missing template
throws rather than answering nil.

**It holds the report twice.** An EditBox copies what it holds rather than
what it draws, so coloring the verdicts and copying the result would put
`|cffb25d5d` in every pasted line. The colored version is what you read and
the plain one is what you copy, and the button swaps between them — see
*Colorizing a report that still has to paste cleanly*.

**There is no clipboard API.** No addon can put text on the system clipboard,
so nothing here pretends to: the button selects the whole report and focuses
it, and Ctrl+C is the part the game leaves to you.
--]]

--[[ Reachable without typing
`Bindings.xml` offers the report as a key binding, which the client picks up
from the addon folder without a TOC entry. The names of the two entries in
Blizzard's own key binding panel are globals it looks for by convention.

This exists because of how the window first failed: an error in it took the
chat frame's Enter handling down with it, and chat then accepted nothing at
all — including the `/reload` that would have loaded the repair. A diagnostic
that can only be reached by typing is unreachable in exactly the case where
typing has stopped working, and the key binding panel is worked with the
mouse.
--]]
_G.BINDING_HEADER_UMBRAUNITFRAMES = 'Umbra Unit Frames'
_G.BINDING_NAME_UMBRAUNITFRAMES_CHECK = 'Open the check report'

local WIDTH, HEIGHT = 620, 460
local PADDING = 12
local TITLE_HEIGHT = 24
local FOOTER_HEIGHT = 30

local window

--[[ Hex(color)
A palette entry as the escape code the client understands.
--]]
local function Hex(color)
	return ('|cff%02x%02x%02x'):format(
		math.floor(color[1] * 255 + 0.5),
		math.floor(color[2] * 255 + 0.5),
		math.floor(color[3] * 255 + 0.5))
end

--[[ Colorizing a report that still has to paste cleanly
An EditBox copies **what it holds**, not what it draws, so a color escape put
in for readability lands in the paste as `|cffb25d5d` and has to be picked out
of it by hand. That is why these lines were made plain in the first place.

So the window keeps two versions of the same report: a colored one to look at
and a plain one to copy. The button swaps to plain before it selects, and
letting go of the text puts the colors back — see the button and
`OnEditFocusLost` below.

Only the verdict is colored, never the number beside it. `hidden` and
`readable` are the words the eye is hunting for; `394262` is read by whoever
asked for it, and painting it would say something about a value that Umbra
has no opinion on.
--]]
local VERDICTS = {
	hidden = colors.auraHarmful,
	errors = colors.auraHarmful,
	unavailable = colors.auraHarmful,
	readable = colors.accent,
	available = colors.accent,
	none = colors.accent,
}

local function Colorize(line)
	if line == '' then return line end

	-- Greedy up to the last colon: a label may hold one of its own, as
	-- `tag [umbra:health]` and `portrait player: UnitIsVisible` both do.
	local label, value = line:match('^(.*): (.*)$')

	if not label then
		-- The heading, which names the build and the client.
		return Hex(colors.accent) .. line .. '|r'
	end

	local verdict = value:match('^%a+')
	local tone = verdict and VERDICTS[verdict]

	if tone then
		value = Hex(tone) .. verdict .. '|r' .. value:sub(#verdict + 1)
	end

	return Hex(colors.muted) .. label .. ':|r ' .. value
end

--[[ Report(frame, plain)
Which of the two versions the box is holding, and puts one there.
--]]
local function Report(frame, plain)
	frame.plain = plain and true or false

	if frame.Text then
		frame.Text:SetText((plain and frame.report or frame.display) or '')
	end
end

--[[ Templated(kind, parent, templates)
The first of these templates the client will build, or nil.

A missing template throws out of CreateFrame rather than answering nil, so
each one is tried inside a pcall and the caller gets a plain answer.
--]]
local function Templated(kind, parent, templates)
	for _, template in ipairs(templates) do
		local ok, built = pcall(CreateFrame, kind, nil, parent, template)

		if ok and built then
			return built
		end
	end
end

--[[ PlainButton(parent, text, width)
A button in Umbra's palette, for a client with no UIPanelButtonTemplate.
--]]
local function PlainButton(parent, text, width)
	local button = CreateFrame('Button', nil, parent)
	button:SetSize(width, 22)

	local background = button:CreateTexture(nil, 'BACKGROUND')
	background:SetAllPoints()
	background:SetColorTexture(unpack(colors.border))

	local label = button:CreateFontString(nil, 'OVERLAY')
	label:SetFont(media.font, 12)
	label:SetPoint('CENTER')
	label:SetText(text)
	label:SetTextColor(unpack(colors.text))

	button:SetScript('OnEnter', function() label:SetTextColor(unpack(colors.accent)) end)
	button:SetScript('OnLeave', function() label:SetTextColor(unpack(colors.text)) end)

	button.UmbraLabel = label

	return button
end

--[[ Title(frame, text)
Whichever title the template gave us, named differently across versions.

`SetTitle` is the modern one, `TitleText` the older one, and
`TitleContainer.TitleText` the one in between. A frame built without a
template has none of them and carries ours instead.
--]]
local function Title(frame, text)
	if frame.SetTitle and pcall(frame.SetTitle, frame, text) then return end

	local fontString = frame.TitleText
		or (frame.TitleContainer and frame.TitleContainer.TitleText)
		or frame.UmbraTitle

	if fontString then
		fontString:SetText(text)
	end
end

--[[ Panel(globalName, width, height, footer)
The window itself with nothing in it: the border, the title bar, the close
button and the sunken body, each taken from the client's own templates where
it has them and built here where it has not.

Two windows want this now — the report and the portrait box — and they differ
only in what they put inside. Escape is told about a frame by name, so each
one brings its own.
--]]
local function Panel(globalName, width, height, footer)
	-- BasicFrameTemplate brings the border, the title bar and the close
	-- button. The inset variant also brings a sunken body, which is the
	-- ordinary look for a panel that holds text.
	local frame = Templated('Frame', UIParent,
		{'BasicFrameTemplateWithInset', 'BasicFrameTemplate'})

	local native = frame ~= nil

	if not frame then
		frame = CreateFrame('Frame', nil, UIParent)

		local border = frame:CreateTexture(nil, 'BACKGROUND')
		border:SetAllPoints()
		border:SetColorTexture(unpack(colors.border))

		local background = frame:CreateTexture(nil, 'BACKGROUND', nil, 1)
		background:SetPoint('TOPLEFT', frame, 'TOPLEFT', 1, -1)
		background:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -1, 1)
		background:SetColorTexture(unpack(colors.background))

		local title = frame:CreateFontString(nil, 'OVERLAY')
		title:SetFont(media.font, 13)
		title:SetPoint('TOPLEFT', frame, 'TOPLEFT', PADDING, -PADDING)
		title:SetTextColor(unpack(colors.accent))
		frame.UmbraTitle = title
	end

	-- The global name is set here rather than passed to CreateFrame, because
	-- the templated path builds without one. Escape is told about the frame
	-- by name, and that is the only reason it has one.
	_G[globalName] = frame

	frame:SetSize(width, height)
	frame:SetPoint('CENTER')
	frame:SetFrameStrata('DIALOG')
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:RegisterForDrag('LeftButton')
	frame:SetScript('OnDragStart', frame.StartMoving)
	frame:SetScript('OnDragStop', frame.StopMovingOrSizing)

	--[[ Giving the keyboard back
	The select-all button focuses the edit box, and a focused edit box that is
	then hidden keeps the keyboard: Enter goes on reaching a field nobody can
	see. Hiding therefore clears the focus, whichever way it was closed.
	--]]
	frame:SetScript('OnHide', function(self)
		if self.Text then self.Text:ClearFocus() end
	end)

	frame:Hide()

	local close = frame.CloseButton

	if not close then
		close = Templated('Button', frame, {'UIPanelCloseButton'})
			or PlainButton(frame, 'X', 22)
		close:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', 2, 2)
	end

	close:SetScript('OnClick', function() frame:Hide() end)

	-- The template's own sunken body where there is one, and a frame of our
	-- own where there is not.
	local body = frame.Inset

	if body then
		-- The template's inset reaches nearly to the bottom edge, and the
		-- footer needs that strip back.
		body:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -8, PADDING + footer)
	else
		local sunken = Templated('Frame', frame,
			{'InsetFrameTemplate3', 'InsetFrameTemplate'})

		body = sunken or CreateFrame('Frame', nil, frame)
		body:SetPoint('TOPLEFT', frame, 'TOPLEFT', PADDING, -(PADDING + TITLE_HEIGHT))
		body:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -PADDING, PADDING + footer)

		-- Only where the client gave us nothing: a template brings its own
		-- art, and a ground of ours would lie straight over it.
		if not sunken then
			local ground = body:CreateTexture(nil, 'BACKGROUND')
			ground:SetAllPoints()
			ground:SetColorTexture(unpack(colors.border))
		end
	end

	-- Escape has to be told about the frame by name.
	if type(_G.UISpecialFrames) == 'table' then
		tinsert(UISpecialFrames, globalName)
	end

	-- Whether the client's own furniture is what is being looked at, which
	-- decides whether a muted color of ours would sit on it or fight it.
	frame.umbraNative = native

	return frame, body
end

local function Build()
	local frame, body = Panel('UmbraReportFrame', WIDTH, HEIGHT, FOOTER_HEIGHT)
	local native = frame.umbraNative

	local scroll = Templated('ScrollFrame', body, {'UIPanelScrollFrameTemplate'})

	if not scroll then
		scroll = CreateFrame('ScrollFrame', nil, body)

		-- Without the template there is no scroll bar, so the wheel is the
		-- only way down and has to be wired by hand.
		scroll:EnableMouseWheel(true)
		scroll:SetScript('OnMouseWheel', function(self, delta)
			self:SetVerticalScroll(math.max(0, self:GetVerticalScroll() - delta * 20))
		end)
	end

	scroll:SetPoint('TOPLEFT', body, 'TOPLEFT', 8, -8)
	scroll:SetPoint('BOTTOMRIGHT', body, 'BOTTOMRIGHT', -28, 8)

	local edit = CreateFrame('EditBox', nil, scroll)
	edit:SetMultiLine(true)
	edit:SetAutoFocus(false)
	edit:SetWidth(WIDTH - PADDING * 2 - 44)

	--[[ An EditBox wants the third argument
	`FontString:SetFont(file, height)` is happy with two, and every other
	label in this addon is a FontString. An EditBox is not: it answers
	`bad argument #3 to 'SetFont'` and throws, which is how this window broke
	the chat frame — see Umbra:ShowReport for why a throw here was so much
	worse than a missing window.
	--]]
	if not pcall(edit.SetFont, edit, media.font, 12, '') then
		edit:SetFontObject(ChatFontNormal)
	end

	edit:SetTextColor(unpack(colors.text))

	-- Multiline, so Enter would otherwise type a newline into the report
	-- while the person is trying to get back to chat. Both keys let go.
	edit:SetScript('OnEnterPressed', function(self) self:ClearFocus() end)
	edit:SetScript('OnEscapePressed', function(self)
		self:ClearFocus()
		frame:Hide()
	end)

	--[[ Read-only without being uncopyable
	It has to stay an EditBox, because selecting text is the only way the game
	offers to copy any. So typing into it is undone rather than prevented, and
	the selection is put back, which is what the person was in the middle of.
	--]]
	edit:SetScript('OnTextChanged', function(self, userInput)
		if not userInput then return end

		Report(frame, frame.plain)
		self:HighlightText()
	end)

	-- Letting go of the text puts the colors back, whether the person clicked
	-- away or the window was closed under them.
	edit:SetScript('OnEditFocusLost', function(self)
		Report(frame, false)
		self:SetCursorPosition(0)
	end)

	scroll:SetScrollChild(edit)
	frame.Text = edit

	local copy = Templated('Button', frame, {'UIPanelButtonTemplate'})
		or PlainButton(frame, 'Select all, then Ctrl+C', 200)

	copy:SetSize(200, 22)
	copy:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -PADDING, PADDING)

	if copy.SetText then
		copy:SetText('Select all, then Ctrl+C')
	end

	-- Plain first, then select: what gets copied is what the box holds, and
	-- an escape code in a pasted report is the thing this avoids.
	copy:SetScript('OnClick', function()
		Report(frame, true)
		edit:SetFocus()
		edit:HighlightText()
	end)

	--[[ The hint has to stop where the button starts
	A FontString with one anchor sizes itself to its text and keeps going, and
	the button is a child frame, so it draws over the end of the sentence
	rather than pushing it aside — which reads as text mysteriously cut off.

	A second point gives it a width, so it ends at the button and the client
	shortens it with an ellipsis if it ever has to. The sentence lost its
	second half as well: what the button does is written on the button.
	--]]
	local hint = frame:CreateFontString(nil, 'OVERLAY', 'GameFontDisableSmall')
	hint:SetPoint('BOTTOMLEFT', frame, 'BOTTOMLEFT', PADDING + 4, PADDING + 6)
	hint:SetPoint('RIGHT', copy, 'LEFT', -8, 0)
	hint:SetJustifyH('LEFT')
	hint:SetText('Escape closes this. Copying hands over plain text.')

	if not native then
		hint:SetTextColor(unpack(colors.muted))
	end

	return frame
end

--[[ Umbra:ShowReport(title, lines)
Puts a list of plain lines in the window and shows it, or prints them.

**A slash command runs inside the chat edit box's own Enter handling.** So an
error thrown from here does not merely fail to open a window: it takes the
submit down with it, the typed text stays in the box, and the key looks
broken. That is exactly how this window first went wrong — `SetFont` on an
EditBox wants a third argument, `Build` threw, and from then on nothing could
be entered at all, including the `/reload` that would have loaded the repair.

So the window is optional and chat is the floor. `Build` is called through
`pcall` and only a window that came back whole is kept, which also means a
failed build is not half-remembered and tried again in a different broken
state.
--]]
function Umbra:ShowReport(title, lines)
	if not window then
		local ok, built = pcall(Build)

		if ok then
			window = built
		end
	end

	if not window or not window.Text then
		for _, line in ipairs(lines) do
			print(line)
		end

		return
	end

	local colored = {}

	for index, line in ipairs(lines) do
		colored[index] = Colorize(line)
	end

	window.report = table.concat(lines, '\n')
	window.display = table.concat(colored, '\n')

	Title(window, title)
	Report(window, false)
	window.Text:SetCursorPosition(0)
	window.Text:ClearFocus()
	window:Show()

	return window
end

--[[ The portrait box
A window for a question no line of text can answer: whether the column drew
anything. `/uuf dev check` says what the client answered about a unit, and
every one of those answers can come back healthy over an empty square — see
*A file id is not a drawn model* in the development notes.

So this one draws. One row per unit, four squares each, side by side in one
picture: the portrait as the column does it, the whole model from its own
camera, the file alone with no unit behind it, and the client's 2D portrait
for the same unit. `Layouts/Shared.lua` says what each of the four separates,
and why the player and the pet stand in the picture beside the target.

The squares are live `PlayerModel`s rather than pictures of one, which is the
point: they ask the client the same four questions the frames ask, at the
same moment, about the same units, and a screenshot of them is the
measurement. They are filled every time the box is shown, because a box that
remembers the last target answers about a unit that is no longer there.

**A hidden PlayerModel does not load**, which is why nothing here is built
before the box is shown, and why an unused square is left empty rather than
hidden: an empty square has to mean the client gave nothing, not that this
one was not looking.
--]]
local PORTRAIT_WIDTH = 620
local SQUARE = 72
local CELL = 132
local ROW_HEIGHT = SQUARE + 62
local HEADING_HEIGHT = 34

--[[ A model asked for is not a model loaded
`GetModelFileID` can answer nil in the same frame the unit was set in, so a
caption written straight after `SetUnit` would say `holds nothing` under a
square that fills a moment later — the exact kind of measurement this box
exists to stop making. Every caption that reads the model is therefore read
twice: once now, and once after the client has had a moment.
--]]
local SETTLE = 0.3

local portraits

--[[ The four attempts, in the order they are read
`as drawn` comes first because it is what is on screen and what the complaint
is about. The other three are what it could have been.
--]]
local ATTEMPTS = {
	{key = 'drawn', label = 'as drawn'},
	{key = 'whole', label = 'whole model'},
	{key = 'file', label = 'file alone'},
	{key = 'flat', label = '2D'},
}

--[[ Caption(square, text, tone)
The line under a square: what the client answered for that one attempt, so a
square that is empty because it was refused reads differently from one that
is empty because nothing was drawn.
--]]
local function Caption(square, text, tone)
	square.Caption:SetText(text)
	square.Caption:SetTextColor(unpack(tone or colors.muted))
end

local function BuildSquare(parent, attempt)
	local square = CreateFrame('Frame', nil, parent)
	square:SetSize(SQUARE, SQUARE)

	-- The same ground the real column stands on, so an empty square here
	-- looks like the empty square out there rather than like a hole in the
	-- window.
	local ground = square:CreateTexture(nil, 'BACKGROUND')
	ground:SetAllPoints()
	ground:SetColorTexture(unpack(colors.portraitGround))

	local model = CreateFrame('PlayerModel', nil, square)
	model:SetAllPoints()
	square.Model = model

	-- The 2D attempt is a texture rather than a model, and in that one
	-- square it lies over the model the way the stand-in lies over the
	-- column.
	local flat = square:CreateTexture(nil, 'ARTWORK')
	flat:SetAllPoints()
	flat:Hide()
	square.Flat = flat

	local name = square:CreateFontString(nil, 'OVERLAY')
	name:SetFont(media.font, 11)
	name:SetPoint('TOP', square, 'BOTTOM', 0, -4)
	name:SetWidth(CELL - 8)
	name:SetText(attempt.label)
	name:SetTextColor(unpack(colors.text))

	local caption = square:CreateFontString(nil, 'OVERLAY')
	caption:SetFont(media.font, 10)
	caption:SetPoint('TOP', name, 'BOTTOM', 0, -2)
	caption:SetWidth(CELL - 8)
	caption:SetJustifyH('CENTER')
	square.Caption = caption

	return square
end

local function BuildRow(parent, index)
	local row = CreateFrame('Frame', nil, parent)
	row:SetSize(PORTRAIT_WIDTH - PADDING * 4, ROW_HEIGHT)
	row:SetPoint('TOPLEFT', parent, 'TOPLEFT', PADDING,
		-(HEADING_HEIGHT + (index - 1) * (ROW_HEIGHT + 10)))

	local title = row:CreateFontString(nil, 'OVERLAY')
	title:SetFont(media.font, 12)
	title:SetPoint('TOPLEFT', row, 'TOPLEFT', 4, 0)
	title:SetTextColor(unpack(colors.accent))
	row.Title = title

	local facts = row:CreateFontString(nil, 'OVERLAY')
	facts:SetFont(media.font, 11)
	facts:SetPoint('TOPLEFT', title, 'BOTTOMLEFT', 0, -3)
	facts:SetTextColor(unpack(colors.muted))
	row.Facts = facts

	row.Squares = {}

	for position, attempt in ipairs(ATTEMPTS) do
		local square = BuildSquare(row, attempt)

		square:SetPoint('TOPLEFT', row, 'TOPLEFT',
			(position - 1) * CELL + 4, -(ROW_HEIGHT - SQUARE - 26))

		row.Squares[attempt.key] = square
	end

	return row
end

--[[ Framed in full, every time
The portrait camera is what the column uses; the model's own camera is what
it could have used. Both are set out in full rather than changed from
whatever the last unit left behind, because a square that inherits half a
camera measures nothing.
--]]
local function Frame3D(model, zoom)
	pcall(model.SetCamDistanceScale, model, 1)
	pcall(model.SetPortraitZoom, model, zoom)
	pcall(model.SetPosition, model, 0, 0, 0)
	pcall(model.ClearModel, model)
end

--[[ Held(model, data)
What a square ended up holding, and whether that is worth looking at twice.

**A model that came back as the player's own, on a unit that is not the
player, is the finding rather than a number to carry up to the row above.**
Measured in *Das Verlies* on 22 September 2026: a target whose identity is
secret, `SetUnit` refused — and the square holding 878772 and drawing the
dwarf that was standing there typing the command. So the row names it.
--]]
local function Held(model, data)
	local ok, file = pcall(model.GetModelFileID, model)

	if not ok then return 'errors', colors.auraHarmful end
	if Umbra.Secrets.Is(file) then return 'hidden', colors.auraHarmful end
	if file == nil then return 'holds nothing' end

	if data and data.mine and data.unit ~= 'player' and file == data.mine then
		return 'holds ' .. tostring(file) .. ' — yours', colors.accent
	end

	return 'holds ' .. tostring(file)
end

local function FillRow(row, data)
	row.Title:SetText(data.unit .. (data.name and (' — ' .. data.name) or ''))
	row.Facts:SetText(data.facts or '')

	local unit = UnitExists(data.unit) and data.unit or nil
	local loading = {}

	for _, attempt in ipairs(ATTEMPTS) do
		local square = row.Squares[attempt.key]
		local model, flat = square.Model, square.Flat

		flat:Hide()
		Frame3D(model, 1)

		if not unit then
			Caption(square, '—')
		elseif attempt.key == 'flat' then
			--[[ Cleared before it is asked
			`SetPortraitTexture` leaves the texture alone where it has
			nothing to give, so a face left over from the last unit would
			read as an answer about this one. Emptied first, whatever is
			there afterwards is the client's answer and nobody else's.
			--]]
			pcall(flat.SetTexture, flat, nil)

			if type(_G.SetPortraitTexture) == 'function' then
				pcall(SetPortraitTexture, flat, unit)
			end

			local ok, texture = pcall(flat.GetTexture, flat)
			local given = ok and texture ~= nil

			flat:Show()
			Caption(square, given and ('gave ' .. tostring(texture))
				or 'gave nothing', given and colors.muted or colors.auraHarmful)
		elseif attempt.key == 'file' then
			if not data.file then
				Caption(square, data.held or 'no file', colors.auraHarmful)
			else
				Frame3D(model, 0)

				local ok, err = pcall(model.SetModel, model, data.file)

				Caption(square, ok and Held(model, data)
					or ('SetModel ' .. tostring(err)),
					ok and select(2, Held(model, data)) or nil)

				if ok then loading[#loading + 1] = square end
			end
		else
			Frame3D(model, attempt.key == 'whole' and 0 or 1)

			local ok, err = pcall(model.SetUnit, model, unit)

			Caption(square, ok and Held(model, data)
				or ('SetUnit ' .. tostring(err)),
				ok and select(2, Held(model, data)) or nil)

			if ok then loading[#loading + 1] = square end
		end
	end

	-- A refusal keeps its own words: only the squares the client took are
	-- read again, so `SetUnit threw` is never overwritten by what the empty
	-- model says afterwards.
	if #loading > 0 then
		C_Timer.After(SETTLE, function()
			for _, square in ipairs(loading) do
				Caption(square, Held(square.Model, data))
			end
		end)
	end
end

--[[ Umbra:ShowPortraits(title, heading, rows)
Puts the rows in the box and shows it, or says in chat that it could not.

The window is optional here for the reason it is optional for the report: a
slash command runs inside the chat frame's own Enter handling, and a throw
out of a window build has taken the keyboard down with it once already. The
difference is what is lost — the report falls back to chat because its
answers are words, and this one has none to fall back to. So it says that in
one line instead of printing three rows of nothing.
--]]
function Umbra:ShowPortraits(title, heading, rows)
	if not portraits then
		local ok, built = pcall(function()
			local body = HEADING_HEIGHT + #rows * (ROW_HEIGHT + 10) + PADDING
			local frame, inset = Panel('UmbraPortraitFrame', PORTRAIT_WIDTH,
				body + TITLE_HEIGHT + PADDING * 2, 0)

			local top = inset:CreateFontString(nil, 'OVERLAY')
			top:SetFont(media.font, 12)
			top:SetPoint('TOPLEFT', inset, 'TOPLEFT', PADDING + 4, -PADDING)
			top:SetTextColor(unpack(colors.accent))
			frame.Heading = top
			frame.Rows = {}

			for index = 1, #rows do
				frame.Rows[index] = BuildRow(inset, index)
			end

			return frame
		end)

		if ok then portraits = built end
	end

	if not portraits then
		print(title .. ': the box could not be built on this client, and '
			.. 'nothing it asks can be answered in words.')

		return
	end

	Title(portraits, title)
	portraits.Heading:SetText(heading)

	for index, row in ipairs(portraits.Rows) do
		if rows[index] then
			row:Show()
			FillRow(row, rows[index])
		else
			row:Hide()
		end
	end

	portraits:Show()

	return portraits
end
