local _, ns = ...
local Umbra = ns.Umbra

--[[ Umbra.L
The words the options window, its page under Options › AddOns and the two
tooltips put on screen, in German on a German client and in English on every
other one.

The key is the English text itself, so a string with no translation — or a
client in any other language — falls back to the words the code was written
with rather than to a key nobody should see. Only the window is translated:
what `/uuf` prints stays English, because the words it asks you to type back
are English whatever the client speaks.

German is longer than English, and the window is not wider for it. Every
string below was chosen to fit the row it stands in at the window's own
sizes, which is why the two checkboxes drop "Blizzard" and the two buttons
say one word each: the heading above them already says the rest.
--]]
local GERMAN = {
	-- Sections
	['Layout'] = 'Layout',
	['Health bar'] = 'Gesundheitsbalken',
	['Blizzard frames'] = 'Blizzard-Fenster',
	['Display'] = 'Anzeige',
	['Frames'] = 'Frames',
	['Show level'] = 'Level anzeigen',

	-- Switches
	['Modern'] = 'Modern',
	['Classic'] = 'Klassisch',
	['Neutral'] = 'Neutral',
	['Class color'] = 'Klassenfarbe',
	['Portrait'] = 'Porträt',
	['Name'] = 'Name',
	['Off'] = 'Aus',
	['Hide Blizzard buffs & debuffs'] = 'Buffs & Debuffs ausblenden',
	['Hide Blizzard group manager'] = 'Gruppenverwaltung ausblenden',
	['Show minimap button'] = 'Minimap-Button anzeigen',

	-- Buttons
	['Unlock'] = 'Entsperren',
	['Lock'] = 'Sperren',
	['Reset'] = 'Zurücksetzen',

	-- Why a control is the way it is
	['applies after combat'] = 'nach dem Kampf',
	['not on this client'] = 'nicht auf diesem Client',

	-- The page under Options › AddOns
	['Every setting lives in a small window of its own, and takes effect where you stand.']
		= 'Alle Einstellungen liegen in einem kleinen eigenen Fenster und wirken sofort.',
	['Open Umbra options'] = 'Umbra-Optionen öffnen',
	['or type /uuf'] = 'oder /uuf eingeben',

	-- The onboarding: what each page asks
	['Welcome'] = 'Willkommen',
	['Where your frames go'] = 'Wohin deine Frames kommen',
	['Two layout sets. Each keeps its own dragged positions, so trying one costs nothing.']
		= 'Zwei Layouts. Jedes merkt sich seine eigenen Positionen, Ausprobieren kostet also nichts.',
	['What colors the health bar'] = 'Welche Farbe der Balken trägt',
	['Neutral green leaves class color to the edge and the name. Class color spends it on the bar as well.']
		= 'Neutrales Grün lässt die Klassenfarbe an Kante und Name. Klassenfarbe färbt auch den Balken.',
	['Level'] = 'Level',
	['Where the level stands'] = 'Wo das Level steht',
	['On the portrait, in front of the name, or not at all. The target reads it in the difficulty color.']
		= 'Auf dem Porträt, vor dem Namen oder gar nicht. Beim Ziel in der Farbe der Schwierigkeit.',
	["Keep Blizzard's own as well?"] = 'Blizzards eigene behalten?',
	["Umbra draws your buffs and your party. Blizzard's group manager also holds the raid markers."]
		= 'Umbra zeigt deine Buffs und deine Gruppe. Blizzards Gruppenverwaltung hat auch die Zielmarkierungen.',
	['Done'] = 'Fertig',
	['Ready to go'] = 'Startklar',
	['Your choices are in place. Drag the frames where you want them, or change anything later.']
		= 'Deine Einstellungen sind übernommen. Zieh die Frames an ihren Platz oder ändere alles später.',

	-- The onboarding: its preview and its buttons
	['Blizzard buffs'] = 'Blizzard-Buffs',
	['Group manager'] = 'Gruppenverwaltung',
	['Unlock frames to drag them'] = 'Frames zum Verschieben entsperren',
	['Lock frames'] = 'Frames sperren',
	['Skip'] = 'Überspringen',
	['Back'] = 'Zurück',
	['Next'] = 'Weiter',
	['opens the options, any time'] = 'öffnet jederzeit die Optionen',
	['Addon compartment'] = 'Addon-Menü',
	['under the minimap'] = 'unter der Minimap',
	['Minimap button'] = 'Minimap-Button',
	['opens the options with a click'] = 'öffnet die Optionen per Klick',
	['brings these questions back'] = 'stellt diese Fragen erneut',
	['Options › AddOns'] = 'Optionen › AddOns',
	['lists Umbra like any addon'] = 'führt Umbra wie jedes Addon',

	-- Tooltips
	['Click for the options.'] = 'Klicken für die Optionen.',
	['Click for the options, drag to move.'] = 'Klicken für die Optionen, ziehen zum Verschieben.',
}

local strings = GetLocale() == 'deDE' and GERMAN or {}

Umbra.L = setmetatable({}, {
	__index = function(_, key)
		return strings[key] or key
	end,
})
