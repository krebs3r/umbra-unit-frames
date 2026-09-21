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

**This file exists to answer one question before anything is built on it.**
These notes have been saying that group frames need a static fallback, because
`loadstring_untainted` is missing on both clients and "the whole secure-snippet
machinery rests on it". That is an assumption, and it decides the shape of
every group frame there will ever be:

	header works      real group frames — they sort themselves, follow the
	                  roster, during a fight and after it
	header does not   four fixed frames for party1..party4, no sorting, and
	                  every change waiting for the fight to end

The two are different addons. So the assumption gets measured rather than
believed, and the reason to doubt it is concrete: `loadstring_untainted` is
what an **addon** calls to compile a snippet without tainting it.
`initialConfigFunction` is compiled by the **client's own** header code, in
`SecureGroupHeaders.lua`, reached through `SetAttribute`. Those may well not
be the same mechanism, and nothing here has ever asked.

`/uuf header` asks. It spawns one real header with `showSolo`, so it produces
a child without needing a group, and reports what that child came out as.
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

	header:Show()

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

	add('secure snippets (loadstring_untainted): '
		.. (Umbra.hasSecureSnippets and 'available' or 'unavailable'))
	add('in combat: ' .. tostring(InCombatLockdown()))
	add('')

	local fresh = not probe
	local header, err = Spawn()

	if not header then
		add('header: not created — ' .. tostring(err))
		return lines
	end

	add('header: created')
	add('header shown: ' .. tostring(header:IsShown()))
	add('visibility driver: ' .. tostring(header.umbraProbeVisibility))
	add('state-visibility: ' .. tostring(header:GetAttribute('state-visibility')))

	local children = {header:GetChildren()}
	add('children: ' .. #children)

	if #children == 0 then
		add('')
		add('No child at all. The header exists but its own machinery never')
		add('ran, so nothing below this can be asked yet.')
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

	return lines
end
