local _, ns = ...
local Umbra = ns.Umbra

--[[ Umbra.Secrets
What Umbra is allowed to do with values the client hides from us.

Since 12.0 the client hands back opaque "secret" values for health, power and
aura data inside encounters, Mythic+ runs and PvP matches. Tainted code may
store one and pass it to a whitelisted API, but may not do arithmetic on it,
compare it, index a table with it, or run it through string.format.

Most of the work this implies is already done by oUF: its Health element drives
the bar through a UnitHealPredictionCalculator, and its tag system passes
values straight into FontString:SetFormattedText, which accepts secrets. So
Umbra deliberately owns very little here. What is left are the few places where
Umbra colors something itself.
--]]
local Secrets = {}
Umbra.Secrets = Secrets

local isSecretValue = _G.issecretvalue

-- These arrived across 12.0 to 12.1.5, and Forever is still missing parts of
-- the Retail surface, so presence is checked rather than assumed.
Secrets.has = {
	secretValues = type(isSecretValue) == 'function',
	classColor = type(_G.C_ClassColor) == 'table',
	curveUtil = type(_G.C_CurveUtil) == 'table',
	secretsApi = type(_G.C_Secrets) == 'table',
}

--[[ Secrets.Is(value)
Whether the value is opaque to us. False on clients without the system.
--]]
function Secrets.Is(value)
	if not isSecretValue then return false end

	local ok, result = pcall(isSecretValue, value)
	return ok and result == true
end

--[[ Secrets.UnitColor(unit)
The color that carries a unit's identity: class color for players, reaction
color for everything else. Returns a ColorMixin, or nil when neither applies.

A unit's class is secret inside instances, which rules out looking it up in our
own color table. C_ClassColor answers for a secret class with a secret color,
and the widget APIs accept that.
--]]
function Secrets.UnitColor(unit)
	local colors = ns.oUF.colors

	if UnitIsPlayer(unit) then
		local _, class = UnitClass(unit)

		if class ~= nil then
			if Secrets.Is(class) then
				return Secrets.has.classColor and C_ClassColor.GetClassColor(class)
			end

			return colors.class[class]
		end
	end

	local reaction = UnitReaction(unit, 'player')
	if reaction then
		return colors.reaction[reaction]
	end
end

--[[ Secrets.SameUnit(unit1, unit2)
Whether two unit tokens stand for the same unit: true, false, or **nil when
the client will not say**.

oUF asks `C_Secrets.CanCompareUnitTokens` first and treats a yes as a
guarantee that the comparison itself will answer in the clear:

	function Private.unitIsUnit(unit1, unit2)
		return C_Secrets.CanCompareUnitTokens(unit1, unit2) and UnitIsUnit(unit1, unit2)
	end

**That guarantee does not hold**, which is issue #1. Measured on Retail inside
a delve on 21 September 2026: `unitIsUnit('targettarget', 'player')`
handed back a secret boolean, and `not` on it threw 716 times in one session.
The captured stack says which half did it. `UnitIsUnit` sits in tail position,
so a throw inside the `and` would have named `private.lua:34` and kept that
frame; instead the top of the stack is `portrait.lua:48` with the tail call
already collapsed. So the permission was granted in the clear and the answer
came back hidden anyway.

Asking permission and asking the question are two different things, and only
the second one has an answer worth looking at. So this asks the question and
looks at what came back, which also means it needs no `C_Secrets` at all and
behaves the same on a client that has none.

Identical tokens are answered without asking. No client can refuse that one,
it is the comparison every `ForceUpdate` goes through, and the frames that
never threw are the ones that only ever make it.
--]]
function Secrets.SameUnit(unit1, unit2)
	if not unit1 or not unit2 then return false end
	if unit1 == unit2 then return true end

	local ok, same = pcall(UnitIsUnit, unit1, unit2)

	if not ok or Secrets.Is(same) then return nil end

	return same and true or false
end
