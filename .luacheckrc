std = 'lua51'
max_line_length = 120

exclude_files = {
	'Libs/',
	'.release/',

	-- The lint workflow installs luarocks into the workspace, and `luacheck .`
	-- walks straight into it: 244 warnings out of LuaRocks' own source, which
	-- failed the run no matter what this project's files looked like.
	'.luarocks/',
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
	'CreateFrame', 'UIParent', 'GetBuildInfo', 'print', 'strtrim', 'C_Timer',
	'AbbreviateNumbers', 'BreakUpLargeNumbers', 'CreateColor', 'GameFontNormal', 'Enum',
	'DECIMAL_SEPERATOR', 'LARGE_NUMBER_SEPERATOR', 'CurveConstants',
	'C_StringUtil', 'CreateAbbreviateConfig',
	'wipe', 'math', 'string',

	-- Project identity
	'WOW_PROJECT_ID', 'WOW_PROJECT_MAINLINE', 'WOW_PROJECT_CLASSIC',

	-- Unit information
	'UnitHealth', 'UnitHealthMax', 'UnitHealthPercent', 'UnitHealthMissing',
	'UnitPower', 'UnitPowerMax', 'UnitPowerPercent', 'UnitPowerMissing',
	'UnitClass', 'UnitName', 'UnitExists', 'UnitIsUnit', 'UnitInRange',
	'UnitIsPlayer', 'UnitReaction', 'C_ClassColor',
	'UnitIsVisible', 'UnitIsConnected', 'IsUnitModelReadyForUI',
	'SetPortraitTexture',

	-- Secret values, added in 12.0
	'issecretvalue', 'C_Secrets', 'C_CurveUtil', 'C_DurationUtil',
	'CreateUnitHealPredictionCalculator', 'UnitGetDetailedHealPrediction',
	'SecondsFormatter',

	-- Namespaced API
	'C_AddOns', 'C_Spell', 'C_UnitAuras', 'C_Traits', 'C_CVar',
	'C_SpecializationInfo',

	-- Tooltips. oUF sets no unit tooltip of its own, and Blizzard's handler
	-- cannot be borrowed for one, so the layout brings its own.
	'GameTooltip', 'GameTooltip_SetDefaultAnchor',

	-- Secure templates
	'RegisterUnitWatch', 'UnregisterUnitWatch', 'InCombatLockdown',
	'SecureHandlerSetFrameRef', 'loadstring_untainted',
}
