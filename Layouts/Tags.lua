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

--[[ Tag: umbra:level
The unit's level, with `+` for an elite and `??` for one too far above you to
be told, the way the client's own target frame writes it.

UnitEffectiveLevel is the level a scaled unit is fought at, which is the one
worth reading; the Classic clients do not have it and nothing of Blizzard's
there asks for it, so they get the plain level. Neither comes back hidden on
any client checked, but the level is only compared once it is known to be in
the clear: a hidden one goes to the client to render as it is.
--]]
local UnitEffectiveLevel = _G.UnitEffectiveLevel or UnitLevel

local ELITE = {elite = true, rareelite = true, worldboss = true}

local function Level(unit)
	local level = UnitEffectiveLevel(unit)

	if Umbra.Secrets.Is(level) then return level end

	if UnitIsWildBattlePet and (UnitIsWildBattlePet(unit) or UnitIsBattlePetCompanion(unit)) then
		level = UnitBattlePetLevel(unit)
	end

	if not level or level <= 0 then return '??' end

	local classification = UnitClassification(unit)
	if not Umbra.Secrets.Is(classification) and ELITE[classification] then
		return level .. '+'
	end

	return level
end

oUF.Tags.Methods['umbra:level'] = Level
oUF.Tags.Events['umbra:level'] = 'UNIT_LEVEL PLAYER_LEVEL_UP UNIT_CLASSIFICATION_CHANGED'

local function Hex(r, g, b)
	return ('|cff%02x%02x%02x'):format(r * 255, g * 255, b * 255)
end

--[[ Tag: umbra:difficulty
Opens a color escape for how hard the unit is to fight, from the client's own
GetCreatureDifficultyColor. Only for something you can attack: the level of a
friend is context, not a warning, and stays in the muted color underneath.
--]]
local function Difficulty(unit)
	if not GetCreatureDifficultyColor or not UnitCanAttack('player', unit) then return end

	local level = UnitEffectiveLevel(unit)
	if Umbra.Secrets.Is(level) then return end

	local color = GetCreatureDifficultyColor((level and level > 0) and level or 999)
	if not color then return end

	return Hex(color.r, color.g, color.b)
end

oUF.Tags.Methods['umbra:difficulty'] = Difficulty
oUF.Tags.Events['umbra:difficulty'] = 'UNIT_LEVEL PLAYER_LEVEL_UP UNIT_FACTION'

--[[ Tag: umbra:namelevel(difficulty)
The level again, for the other place it can stand: in front of the name,
closed with its own color escape and a space, so the name's class color
starts clean after it. Empty unless the setting asks for it here, which is
what lets one name tag serve both placements; the frames are told to
re-read their tags when the setting changes.

`difficulty` as the argument colors it the way the plate does on the target.
A hidden level cannot be glued to a space, so it is left out rather than
thrown on — the plate is the placement that can show one.
--]]
local muted

oUF.Tags.Methods['umbra:namelevel'] = function(unit, _, mode)
	if not UmbraUnitFramesDB or UmbraUnitFramesDB.level ~= 'name' then return end

	local text = Level(unit)
	if text == nil or Umbra.Secrets.Is(text) then return end

	muted = muted or Hex(unpack(Umbra.colors.muted))

	local color = mode == 'difficulty' and Difficulty(unit) or muted

	return color .. text .. '|r '
end

oUF.Tags.Events['umbra:namelevel'] = 'UNIT_LEVEL PLAYER_LEVEL_UP UNIT_CLASSIFICATION_CHANGED UNIT_FACTION'
