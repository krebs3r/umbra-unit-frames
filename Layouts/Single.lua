local _, ns = ...
local Umbra = ns.Umbra
local oUF = ns.oUF

oUF:Factory(function(self)
	self:SetActiveStyle('Umbra')

	for unit, config in pairs(Umbra.frames) do
		-- A config a group header builds from is not a frame to spawn. It
		-- lives in the same table because the style looks up every frame it
		-- builds by unit, and `party` is the unit a header child is handed.
		if not config.header then
			local frame = self:Spawn(unit, 'Umbra' .. unit:gsub('^%l', string.upper) .. 'Frame')
			Umbra:PlaceFrame(frame, unit)
		end
	end
end)
