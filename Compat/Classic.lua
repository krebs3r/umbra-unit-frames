local _, ns = ...
local Umbra = ns.Umbra

if not Umbra.isClassic then return end

--[[ Classic compatibility — Mists of Pandaria, the Anniversary realms, Era
All three clients share most of their API with Midnight: secret values, the heal
prediction calculator, the curve and duration objects and the secure-header
machinery are all there, so oUF 14 runs on them as it stands. Checked
against Blizzard's own interface code rather than assumed: Mists 5.5.4.69934
on 25 September 2026, and Burning Crusade Anniversary 2.5.6.69795 on
26 September — which came back with exactly the gaps Mists has, no more and
no fewer, and Classic Era 1.15.9.69722 the same day with the same answer —
so everything below applies to all three. The file was Compat/Mists.lua
until the second client made it plain that nothing here is about Mists.

Two things are missing from that surface, and only one of them is answered
here. The AuraContainer widget is the other, and Layouts/Auras.lua builds the
rows itself where the client refuses one — asked there, where the answer is
used, rather than decided here by client name.
--]]

--[[ GetUnitChargedPowerPoints
oUF's class power element reads combo points through it, on every update,
for rogues and feral druids: `UnitPower(unit, ComboPoints),
GetUnitChargedPowerPoints(unit)`. Mists has no charged combo points and no
such function, so the call would throw on every point gained.

Nil is what Retail answers for a unit with no charged points, and oUF reads
it that way. Only defined where it is missing, so the client's own takes
over the day one appears. Nothing of Blizzard's on this client calls it, so a
global of ours in its place cannot reach their code.
--]]
if type(_G.GetUnitChargedPowerPoints) ~= 'function' then
	_G.GetUnitChargedPowerPoints = function() return nil end
	Umbra:Debug('GetUnitChargedPowerPoints missing, answering nil')
end

--[[ SetRolesets
The first thing that broke in the client, on 25 September 2026, and it broke
the whole layout: `ouf.lua:853: attempt to call a nil value`, in `Spawn`, on
the first frame built. oUF tags every frame it makes with
`SetRolesets('unitFrames')`, every group header too, and every Blizzard frame
it puts away with `SetRolesets('alwaysBlocked')`. It is a widget method,
which is why the check against the client's API missed it: that looked up
functions, not methods, and nothing in Blizzard's code for this client
defines or calls it.

**The first answer was a method that did nothing, and it was half wrong.**
Right for `unitFrames`: Mists has no rules for what an addon may do to a
frame, so there is nothing to opt into. Wrong for `alwaysBlocked`, measured
on the next login: that roleset is how oUF 14 hides Blizzard's own frames —
on Midnight the client stops drawing a blocked frame, and oUF does nothing
else to it but take its events away. So Blizzard's player frame stayed on
screen beside ours, frozen at whatever it showed when its events went.

So `alwaysBlocked` does here what oUF did before Midnight (12.1.0,
`blizzard.lua`): hide the frame, hand it to a parent that is never shown, and
hook `SetParent` so that Edit Mode or anything else putting it back is
undone. A frame whose parent was already put away — a boss frame inside its
container, a party member inside `PartyFrame` — is only hidden, as oUF did
then, because its container's layout code has to keep sizing it.

It goes on the method tables of the two widget types oUF calls it on — every
frame it touches is a Frame or a Button — and only where they lack it.
Nothing of Blizzard's on this client calls it, so the added method cannot
reach their code.
--]]
local blockedParent = CreateFrame('Frame', nil, UIParent)
blockedParent:SetAllPoints()
blockedParent:Hide()

local blocked = {}

local function KeepBlocked(frame, parent)
	if parent ~= blockedParent then
		frame:SetParent(blockedParent)
	end
end

local function Block(frame)
	if blocked[frame] then return end
	blocked[frame] = true

	frame:Hide()

	if blocked[frame:GetParent()] then return end

	frame:SetParent(blockedParent)
	hooksecurefunc(frame, 'SetParent', KeepBlocked)
end

local function SetRolesets(frame, roleset)
	if roleset == 'alwaysBlocked' then
		Block(frame)
	end
end

for _, kind in ipairs({'Frame', 'Button'}) do
	local methods = getmetatable(CreateFrame(kind)).__index

	if type(methods) == 'table' and methods.SetRolesets == nil then
		methods.SetRolesets = SetRolesets
		Umbra:Debug('SetRolesets missing on', kind, '— blocking by hiding')
	end
end

--[[ Umbra.GuardUnknownEvents(frame)
The second login, a minute after the first: `Attempt to register unknown
event "UNIT_POWER_POINT_CHARGE"`, from oUF's class power element on a monk.
oUF registers that event for every class, because charged combo points can
reach anyone on Retail; Mists has no such event. A check of every event oUF
and Umbra name against the client's documentation found one other,
`HONOR_LEVEL_UPDATE`, in an element Umbra does not use.

oUF already survives it — it tries the event under `xpcall` and registers
nothing when that fails — but it reports the failure through the error
handler on the way, so every login and every change of specialisation would
put the same error in front of the player for an event that cannot fire.

So each frame's `RegisterEvent` is fronted, once, in the style: an event the
client calls invalid is let go of before oUF tries it. The client answers
through `C_EventUtils.IsEventValid`, so this is a question rather than a list
and an event the client gains is registered again. The style runs before
oUF enables a single element, which is what makes this early enough. Once
per event it says so in the debug buffer.
--]]
local skipped = {}

function Umbra.GuardUnknownEvents(frame)
	if not (C_EventUtils and C_EventUtils.IsEventValid) then return end

	local register = frame.RegisterEvent

	frame.RegisterEvent = function(self, event, ...)
		if type(event) == 'string' and not C_EventUtils.IsEventValid(event) then
			if not skipped[event] then
				skipped[event] = true
				Umbra:Debug('event not on this client, not registered:', event)
			end

			return
		end

		return register(self, event, ...)
	end
end

-- Last line on purpose: `/uuf dev check` reports it, so a run that stopped part
-- way through this file can be told apart from one that never started it.
Umbra.compatFile = 'Classic'
Umbra.compat = Umbra.isMists and 'Mists' or Umbra.isTBC and 'TBC'
	or Umbra.isEra and 'Era' or 'Classic'
