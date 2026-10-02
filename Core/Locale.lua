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
	['Choose your layout'] = 'Wähle dein Layout',
	["Each layout remembers where you've moved your frames, so feel free to try both."]
		= 'Jedes Layout merkt sich, wohin du deine Frames gezogen hast. Probier ruhig beide aus.',
	['Pick a health bar color'] = 'Wähle die Farbe des Balkens',
	['Neutral keeps class color on the edge and the name. Class color paints the bar as well.']
		= 'Bei Neutral steht die Klassenfarbe nur an Rand und Name. Sonst färbt sie auch den Balken.',
	['Level'] = 'Level',
	['Where should the level go?'] = 'Wo soll das Level stehen?',
	['On the portrait, before the name, or not at all. On a target, the color shows how tough it is.']
		= 'Auf dem Porträt, vor dem Namen oder gar nicht. Beim Ziel zeigt die Farbe, wie gefährlich es ist.',
	["Hide Blizzard's frames?"] = 'Blizzards Fenster ausblenden?',
	['Umbra already shows your buffs and party. Keep the group manager if you use its raid markers.']
		= 'Umbra zeigt Buffs und Gruppe schon selbst. Die Gruppenverwaltung bietet aber die Zielmarkierungen.',
	['Done'] = 'Fertig',
	['Ready to go'] = 'Startklar',
	["That's it! Unlock the frames below to move them, or change any setting later."]
		= "Das war's! Entsperre unten die Frames, um sie zu verschieben, oder ändere alles später.",

	-- The onboarding: its preview and its buttons
	['Blizzard buffs'] = 'Blizzard-Buffs',
	['Group manager'] = 'Gruppenverwaltung',
	['Unlock frames'] = 'Frames entsperren',
	['Lock frames'] = 'Frames sperren',
	['Skip'] = 'Überspringen',
	['Back'] = 'Zurück',
	['Next'] = 'Weiter',
	['opens the options'] = 'öffnet die Optionen',
	['puts the frames back in place'] = 'setzt die Frames zurück',
	['shows this guide again'] = 'zeigt diese Einrichtung erneut',
	['lists all commands'] = 'zeigt alle Befehle',

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
