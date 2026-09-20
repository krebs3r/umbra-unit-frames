local _, ns = ...
local Umbra = ns.Umbra

local colors, media = Umbra.colors, Umbra.media

--[[ A window for output that is too long to read in chat
`/uuf check` answers around thirty lines, and a chat frame is the wrong place
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

local function Build()
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
	_G.UmbraReportFrame = frame

	frame:SetSize(WIDTH, HEIGHT)
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
		body:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -8, PADDING + FOOTER_HEIGHT)
	else
		local sunken = Templated('Frame', frame,
			{'InsetFrameTemplate3', 'InsetFrameTemplate'})

		body = sunken or CreateFrame('Frame', nil, frame)
		body:SetPoint('TOPLEFT', frame, 'TOPLEFT', PADDING, -(PADDING + TITLE_HEIGHT))
		body:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -PADDING, PADDING + FOOTER_HEIGHT)

		-- Only where the client gave us nothing: a template brings its own
		-- art, and a ground of ours would lie straight over it.
		if not sunken then
			local ground = body:CreateTexture(nil, 'BACKGROUND')
			ground:SetAllPoints()
			ground:SetColorTexture(unpack(colors.border))
		end
	end

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

	-- Escape has to be told about the frame by name.
	if type(_G.UISpecialFrames) == 'table' then
		tinsert(UISpecialFrames, 'UmbraReportFrame')
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
