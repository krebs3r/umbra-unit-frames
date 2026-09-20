local _, ns = ...
local Umbra = ns.Umbra
local oUF = ns.oUF

--[[ Tags
What the frames put into words. Every tag here has to survive a hidden value,
which rules out reading one and rules in handing it to the client to render.
--]]

local DECIMAL = _G.DECIMAL_SEPERATOR or '.'

local function Decimal(number)
	local text = ('%.1f'):format(number)

	if DECIMAL ~= '.' then
		text = text:gsub('%.', DECIMAL, 1)
	end

	return text
end

--[[ FormatHealth(value)
Health at a glance: three significant digits and a magnitude.

The client's own helpers are not dependable for this. AbbreviateNumbers works
off locale-specific breakpoints and hands back the raw digits in locales that
have no thousands step, which is how a bar came to read 29408.
--]]
local function FormatHealth(value)
	if value >= 1e6 then
		return Decimal(value / 1e6) .. 'M'
	elseif value >= 1e3 then
		return Decimal(value / 1e3) .. 'k'
	end

	return ('%d'):format(value)
end

--[[ Abbreviating a value we are not allowed to read
AbbreviateNumbers shortens hidden values, because the client does the work
natively rather than handing the number to us first. What it will not do is
invent a thousands step for a locale that has none, and German has none, which
is why health read as an unbroken run of digits for so long.

Passing our own breakpoints fixes that. The shape mirrors what
C_StringUtil.GetDefaultAbbreviationBreakpoints returns: the client divides by
significandDivisor, floors, divides by fractionDivisor, and appends the
abbreviation. abbreviationIsGlobal false means the text is literal rather than
the name of a global holding a localized string.
--]]
local abbreviation

local function AbbreviationOptions()
	if abbreviation then return abbreviation end

	abbreviation = {
		breakpointData = {
			{breakpoint = 1000000, abbreviation = 'M', significandDivisor = 10000,
				fractionDivisor = 100, abbreviationIsGlobal = false},
			{breakpoint = 1000, abbreviation = 'K', significandDivisor = 100,
				fractionDivisor = 10, abbreviationIsGlobal = false},
			{breakpoint = 1, abbreviation = '', significandDivisor = 1,
				fractionDivisor = 1, abbreviationIsGlobal = false},
		},
	}

	if CreateAbbreviateConfig then
		abbreviation.config = CreateAbbreviateConfig(abbreviation.breakpointData)
	end

	return abbreviation
end

oUF.Tags.Methods['umbra:health'] = function(unit)
	local current = UnitHealth(unit)

	if not AbbreviateNumbers then
		return Umbra.Secrets.Is(current) and current or FormatHealth(current)
	end

	local ok, text = pcall(AbbreviateNumbers, current, AbbreviationOptions())
	if ok then return text end

	-- Our breakpoints were refused; the client's own still beat raw digits.
	return AbbreviateNumbers(current)
end

oUF.Tags.Events['umbra:health'] = 'UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION'

--[[ Tag: umbra:identity
Opens a color escape for the unit's class or reaction color.

GenerateHexColorMarkup works on a hidden color, which is why the name can stay
class-colored inside an instance even though we cannot read the class.
--]]
oUF.Tags.Methods['umbra:identity'] = function(unit)
	local color = Umbra.Secrets.UnitColor(unit)
	return color and color:GenerateHexColorMarkup() or ''
end

oUF.Tags.Events['umbra:identity'] = 'UNIT_FACTION UNIT_FLAGS'
