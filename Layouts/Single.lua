local _, ns = ...
local Umbra = ns.Umbra
local oUF = ns.oUF

oUF:Factory(function(self)
	self:SetActiveStyle('Umbra')

	for unit, config in pairs(Umbra.frames) do
		local frame = self:Spawn(unit, 'Umbra' .. unit:gsub('^%l', string.upper) .. 'Frame')
		Umbra:PlaceFrame(frame, unit, config.point)
	end
end)
