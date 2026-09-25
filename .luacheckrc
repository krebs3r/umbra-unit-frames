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
	'BINDING_HEADER_UMBRAUNITFRAMES', 'BINDING_NAME_UMBRAUNITFRAMES_CHECK',

	-- Answered in Compat/Classic.lua where the client lacks it.
	'GetUnitChargedPowerPoints',
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
	'MAX_BOSS_FRAMES',
	'SetPortraitTexture',

	-- A unit's identity, which is what `Model:SetUnit` is gated on, and the
	-- role a person signed up as, which the party column marks.
	'UnitGUID', 'UnitGroupRolesAssigned',

	-- The group itself, and where the run is taking place. Both reports ask.
	'IsInRaid', 'IsInGroup', 'GetNumGroupMembers', 'IsInInstance',
	'MAX_PARTY_MEMBERS',

	-- Atlas art, asked for before it is shown: SetAtlas on a name this
	-- client does not have leaves the texture as it was rather than refusing.
	'C_Texture',

	-- Secret values, added in 12.0
	'issecretvalue', 'C_Secrets', 'C_CurveUtil', 'C_DurationUtil',
	'CreateUnitHealPredictionCalculator', 'UnitGetDetailedHealPrediction',
	'SecondsFormatter',

	-- Namespaced API
	'C_AddOns', 'C_Spell', 'C_UnitAuras', 'C_Traits', 'C_CVar',
	'C_SpecializationInfo', 'C_EventUtils', 'hooksecurefunc',

	-- Tooltips. oUF sets no unit tooltip of its own, and Blizzard's handler
	-- cannot be borrowed for one, so the layout brings its own.
	'GameTooltip', 'GameTooltip_SetDefaultAnchor',

	-- Aura rows of our own, where the client has no AuraContainer: a
	-- countdown needs the clock, and a buff is cancelled the way the
	-- client's own buff frame cancels one.
	'GetTime', 'CancelUnitBuff',

	-- The report window
	'ChatFontNormal', 'UISpecialFrames', 'tinsert', 'UmbraReportFrame',

	-- Secure templates
	'RegisterUnitWatch', 'UnregisterUnitWatch', 'InCombatLockdown',
	'SecureHandlerSetFrameRef', 'loadstring_untainted',
	'RegisterAttributeDriver', 'UnregisterAttributeDriver',
}
