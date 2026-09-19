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
