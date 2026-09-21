local _, ns = ...
local Umbra = ns.Umbra

--[[ The client's own displays, put away
Two of them say a second time what Umbra already says. The buff and debuff
stack in the top right is one, and the group panel on the left edge is the
other: `/uuf auras umbra` and `/uuf group umbra` put them away, `both`
brings them back.

The frames are neither hidden nor unregistered. `Hide` is undone by the next
thing that shows them — and the group panel shows itself again every time
the roster changes — while `UnregisterAllEvents` cannot be undone at all.
Instead they are parented to a frame that is never shown: their own logic
keeps running untouched, nothing of theirs is overwritten, and putting the
original parent back restores them.
--]]

local holder = CreateFrame('Frame')
holder:Hide()

-- Which frames were taken, and what to give them back to.
local taken = {}

--[[ What each switch reaches
The group panel is one frame and the raid frames are inside it, so taking
the panel takes the container with it. That is the whole of the client's
group display and exactly what the Umbra column replaces.
--]]
local FRAMES = {
	auras = {'BuffFrame', 'DebuffFrame'},
	group = {'CompactRaidFrameManager'},
}

local function Conceal(name, conceal)
	local frame = _G[name]

	-- Blizzard reworked these in 12.0 and Forever is missing parts of the
	-- Retail surface, so a name that is not there is an expected answer.
	if not frame then
		Umbra:Debug('no such frame:', name)
		return
	end

	if conceal then
		if taken[name] then return end

		local parent = frame:GetParent()

		if pcall(frame.SetParent, frame, holder) then
			taken[name] = parent
		else
			Umbra:Debug('cannot conceal:', name)
		end
	elseif taken[name] then
		pcall(frame.SetParent, frame, taken[name])
		taken[name] = nil
	end
end

--[[ Waiting for the fight to end
Every frame these switches reach is protected, so `SetParent` on one is
refused in combat the way any other secure call is. That refusal used to be
swallowed by the `pcall` in Conceal and never made good: `/uuf auras umbra`
typed during a fight did nothing, said it had worked, and nothing happened
when the fight ended either.

So a refusal is not a failure, it is a wait. EnhanceQoLSkinner reaches the
two aura frames and does the same thing — it checks `InCombatLockdown`
against `IsProtected` and picks the work up again at PLAYER_REGEN_ENABLED.
--]]
local pending = {}
local waiter = CreateFrame('Frame')

local Apply

waiter:SetScript('OnEvent', function(self)
	self:UnregisterEvent('PLAYER_REGEN_ENABLED')

	local wanted = pending
	pending = {}

	for key, shown in pairs(wanted) do
		Apply(key, shown)
	end
end)

--[[ Apply(key, shown) — and the two names it answers to
Shows or conceals one of the client's displays. Answers whether it happened
now: false means it is waiting for combat to end, not that it was refused
for good.

Only the last answer per switch is kept. Asked for both states during one
fight, what should happen at the end of it is whatever was asked for last —
and the two switches wait independently, because a fight is no reason for
one of them to decide the other.
--]]
function Apply(key, shown)
	if InCombatLockdown() then
		pending[key] = shown
		waiter:RegisterEvent('PLAYER_REGEN_ENABLED')
		Umbra:Debug('blizzard', key, 'held until combat ends, wanted shown:',
			shown)

		return false
	end

	for _, name in ipairs(FRAMES[key]) do
		Conceal(name, not shown)
	end

	return true
end

function Umbra:SetBlizzardAuras(shown)
	return Apply('auras', shown)
end

function Umbra:SetBlizzardGroup(shown)
	return Apply('group', shown)
end

-- ADDON_LOADED has run by now, so the setting is there to read. On Forever it
-- is always the default, because that client writes saved variables without
-- ever reading them back.
local applier = CreateFrame('Frame')
applier:RegisterEvent('PLAYER_LOGIN')
applier:SetScript('OnEvent', function()
	if UmbraUnitFramesDB.hideBlizzardAuras then
		Umbra:SetBlizzardAuras(false)
	end

	if UmbraUnitFramesDB.hideBlizzardGroup then
		Umbra:SetBlizzardGroup(false)
	end
end)
