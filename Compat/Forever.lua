local _, ns = ...
local Umbra = ns.Umbra

if not Umbra.isForever then return end

--[[ Forever compatibility
Forever ships the Mainline UI with Vanilla content. Almost everything works as
it does on Retail; what follows are the deviations found on the beta client
(build 1.60.1, interface 16001). Each one is guarded so that the file keeps
working once Blizzard fixes it.
--]]

-- Core/Init.lua asks whether loadstring_untainted is there, because the answer
-- matters on every client and this file loads on one. All that is left here is
-- saying so out loud on the client where it was first found missing.
if not Umbra.hasSecureSnippets then
	Umbra:Debug('loadstring_untainted missing, secure snippets disabled')
end

-- The beta client writes SavedVariables on exit and never reads them back, so
-- every session starts from defaults. Nothing to work around, but the addon
-- must not treat an empty profile as a first-run that needs setup.
Umbra.savedVariablesUnreliable = true
