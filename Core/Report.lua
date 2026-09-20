local _, ns = ...
local Umbra = ns.Umbra

local colors, media = Umbra.colors, Umbra.media

--[[ A window for output that is too long to read in chat
`/uuf check` grew past what a chat frame is for: thirty-odd lines pushed
everything else out of view, and the answer has to be read line against line
rather than as it scrolls past.

So the report gets a window of its own. It carries no unit data at all — it is
built from strings that were already formatted — so the geometry rule has
nothing to say about it and the widgets may size themselves however they like.

**The text is plain.** Chat lines carry color escapes to be read at a glance;
these are meant to be selected and pasted somewhere else, and an escape in
pasted text is noise. What decides a value is its word — `hidden`, `readable`,
`nil` — not its color.

**There is no clipboard API.** No addon can put text on the system clipboard,
so nothing here pretends to: the button selects the whole report and focuses
it, and Ctrl+C is the part the game leaves to you. Saying so on the button is
better than a button called Copy that silently does half of that.
--]]

--[[ Reachable without typing
`Bindings.xml` offers the report as a key binding, which the client picks up
from the addon folder without a TOC entry. The names of the two entries in
Blizzard's own key binding panel are globals it looks for by convention.

This exists because of how the window first failed: it kept the keyboard when
it was hidden, and chat then accepted nothing at all — including the `/reload`
that would have loaded the repair. A diagnostic that can only be reached by
typing is unreachable in exactly the case where typing has stopped working,
and the key binding panel is worked with the mouse.
--]]
_G.BINDING_HEADER_UMBRAUNITFRAMES = 'Umbra Unit Frames'
_G.BINDING_NAME_UMBRAUNITFRAMES_CHECK = 'Open the check report'

local WIDTH, HEIGHT = 620, 440
local PADDING = 14
local TITLE_HEIGHT = 26
local FOOTER_HEIGHT = 30

local window

--[[ Button(parent, text, width)
A flat button in the palette, because the client's own templates are not
guaranteed on every client this addon loads on.
--]]
local function Button(parent, text, width)
	local button = CreateFrame('Button', nil, parent)
	button:SetSize(width, 20)

	local background = button:CreateTexture(nil, 'BACKGROUND')
	background:SetAllPoints()
	background:SetColorTexture(unpack(colors.border))

	local label = button:CreateFontString(nil, 'OVERLAY')
	label:SetFont(media.font, 12)
	label:SetPoint('CENTER')
	label:SetText(text)
	label:SetTextColor(unpack(colors.text))

	button:SetScript('OnEnter', function()
		label:SetTextColor(unpack(colors.accent))
	end)

	button:SetScript('OnLeave', function()
		label:SetTextColor(unpack(colors.text))
	end)

	return button
end

local function Build()
	local frame = CreateFrame('Frame', 'UmbraReportFrame', UIParent)
	frame:SetSize(WIDTH, HEIGHT)
	frame:SetPoint('CENTER')
	frame:SetFrameStrata('DIALOG')
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:RegisterForDrag('LeftButton')
	frame:SetScript('OnDragStart', frame.StartMoving)
	frame:SetScript('OnDragStop', frame.StopMovingOrSizing)

	--[[ Giving the keyboard back
	The select-all button focuses the edit box, and a focused edit box that is
	then hidden keeps the keyboard: Enter goes on reaching a field nobody can
	see, so chat stops accepting anything — including the command that would
	have reloaded out of it.

	Hiding therefore clears the focus, whichever way the window was closed.
	--]]
	frame:SetScript('OnHide', function(self)
		if self.Text then self.Text:ClearFocus() end
	end)

	frame:Hide()

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
	frame.Title = title

	-- The client's own close button where it exists, and a letter where it
	-- does not. Forever is missing parts of the Retail surface, and a missing
	-- template throws rather than answering nil.
	local ok, close = pcall(CreateFrame, 'Button', nil, frame, 'UIPanelCloseButton')

	if ok and close then
		close:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', 2, 2)
	else
		close = Button(frame, 'X', 20)
		close:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', -PADDING, -PADDING + 4)
	end

	close:SetScript('OnClick', function() frame:Hide() end)

	local top = -(PADDING + TITLE_HEIGHT)
	local body = CreateFrame('Frame', nil, frame)
	body:SetPoint('TOPLEFT', frame, 'TOPLEFT', PADDING, top)
	body:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -PADDING, PADDING + FOOTER_HEIGHT)

	local bodyBorder = body:CreateTexture(nil, 'BACKGROUND')
	bodyBorder:SetAllPoints()
	bodyBorder:SetColorTexture(unpack(colors.border))

	local scrolled, scroll = pcall(CreateFrame, 'ScrollFrame', nil, body,
		'UIPanelScrollFrameTemplate')

	if not scrolled or not scroll then
		scroll = CreateFrame('ScrollFrame', nil, body)

		-- Without the template there is no scroll bar, so the wheel is the
		-- only way down and has to be wired by hand.
		scroll:EnableMouseWheel(true)
		scroll:SetScript('OnMouseWheel', function(self, delta)
			self:SetVerticalScroll(math.max(0, self:GetVerticalScroll() - delta * 20))
		end)
	end

	scroll:SetPoint('TOPLEFT', body, 'TOPLEFT', 6, -6)
	scroll:SetPoint('BOTTOMRIGHT', body, 'BOTTOMRIGHT', -26, 6)

	local edit = CreateFrame('EditBox', nil, scroll)
	edit:SetMultiLine(true)
	edit:SetAutoFocus(false)
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
	edit:SetWidth(WIDTH - PADDING * 2 - 38)

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

		self:SetText(frame.report or '')
		self:HighlightText()
	end)

	scroll:SetScrollChild(edit)
	frame.Text = edit

	local select = Button(frame, 'Select all  —  then Ctrl+C', 190)
	select:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -PADDING, PADDING)
	select:SetScript('OnClick', function()
		edit:SetFocus()
		edit:HighlightText()
	end)

	local hint = frame:CreateFontString(nil, 'OVERLAY')
	hint:SetFont(media.font, 11)
	hint:SetPoint('BOTTOMLEFT', frame, 'BOTTOMLEFT', PADDING, PADDING + 4)
	hint:SetTextColor(unpack(colors.muted))
	hint:SetText('Escape closes this. The game allows no addon to reach the clipboard.')

	-- Escape has to be told about the frame by name, which is the one reason
	-- this frame has a global one.
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

	window.report = table.concat(lines, '\n')

	window.Title:SetText(title)
	window.Text:SetText(window.report)
	window.Text:SetCursorPosition(0)
	window.Text:ClearFocus()
	window:Show()

	return window
end
