std = 'lua51'
max_line_length = 120

exclude_files = {
	'Libs/',
	'.release/',
}

ignore = {
	'212', -- unused argument
	'631', -- line is too long
}

globals = {
	'SLASH_UMBRAUNITFRAMES1',
	'SlashCmdList',
	'UmbraUnitFramesDB',
}

read_globals = {
	-- Widgets and core
	'CreateFrame', 'UIParent', 'GetBuildInfo', 'print', 'strtrim',
	'AbbreviateNumbers', 'BreakUpLargeNumbers', 'CreateColor', 'GameFontNormal', 'Enum',
	'DECIMAL_SEPERATOR', 'LARGE_NUMBER_SEPERATOR', 'CurveConstants',
	'wipe', 'math', 'string',

	-- Project identity
	'WOW_PROJECT_ID', 'WOW_PROJECT_MAINLINE', 'WOW_PROJECT_CLASSIC',

	-- Unit information
	'UnitHealth', 'UnitHealthMax', 'UnitHealthPercent', 'UnitHealthMissing',
	'UnitPower', 'UnitPowerMax', 'UnitPowerPercent', 'UnitPowerMissing',
	'UnitClass', 'UnitName', 'UnitExists', 'UnitIsUnit', 'UnitInRange',
	'UnitIsPlayer', 'UnitReaction', 'C_ClassColor',

	-- Secret values, added in 12.0
	'issecretvalue', 'C_Secrets', 'C_CurveUtil', 'C_DurationUtil',
	'CreateUnitHealPredictionCalculator', 'UnitGetDetailedHealPrediction',
	'SecondsFormatter',

	-- Namespaced API
	'C_AddOns', 'C_Spell', 'C_UnitAuras', 'C_Traits', 'C_CVar',

	-- Secure templates
	'RegisterUnitWatch', 'UnregisterUnitWatch', 'InCombatLockdown',
	'SecureHandlerSetFrameRef', 'loadstring_untainted',
}
