local _, ns = ...
local Umbra = ns.Umbra

--[[ Blizzard's own aura display
Once Umbra puts buffs and debuffs on the unit frames, the stack in the top
right corner says the same thing a second time. `/uuf auras umbra` puts it
away, `/uuf auras both` brings it back.

The frames are neither hidden nor unregistered. `Hide` is undone by the next
thing that shows them, and `UnregisterAllEvents` cannot be undone at all.
Instead they are parented to a frame that is never shown: their own logic keeps
running untouched, nothing of theirs is overwritten, and putting the original
parent back restores them.
--]]

local holder = CreateFrame('Frame')
holder:Hide()

-- Which frames were taken, and what to give them back to.
local taken = {}

local FRAMES = {'BuffFrame', 'DebuffFrame'}

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

--[[ Umbra:SetBlizzardAuras(shown)
Shows or conceals Blizzard's buff and debuff frames.
--]]
function Umbra:SetBlizzardAuras(shown)
	for _, name in ipairs(FRAMES) do
		Conceal(name, not shown)
	end
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
end)
