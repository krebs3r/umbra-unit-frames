# Umbra Unit Frames — Stand und nächste Schritte

Übergabe aus der Gründungs-Session (19./20. September 2026). Dieses Dokument ersetzt den ursprünglichen Plan, wo beide sich widersprechen.

## Was das Projekt ist

Moderne, lesbare Unit Frames für World of Warcraft, in der Linie von ShadowedUnitFrames, aber als eigenständige Neuimplementierung. Sechs Designprinzipien stehen in der [README](../README.md); sie sind die eigentliche Produktdefinition.

Repo: `github.com/krebs3r/umbra-unit-frames` · Ordner im Spiel: `UmbraUnitFrames` · Slash-Befehl: `/uuf`

## Entscheidungen, die feststehen

1. **Retail und WoW: Forever sind eine Codebasis.** Forever läuft auf der Mainline-UI (`WOW_PROJECT_MAINLINE`, Interface 16001, 12.1.5-API-Set), nicht auf der Classic-API. Zwei TOCs, ein Quellbaum. Classic Era ist out of scope.
2. **oUF als Framework**, eingebettet über `.pkgmeta`, nicht als Abhängigkeit.
3. **MIT-Lizenz.** SUF hat gar keine Lizenzdatei, deshalb wird nichts davon übernommen.
4. **Design wird an die API angepasst**, Abweichungen werden dokumentiert.

## Stand

Abgenommen: **M0 (Fundament)** und **M1 (Player + Target)**. M1 wurde am 20.09. im Flammenschlund geprüft — Instanz, also unter echtem Secret-Regime, mit BugGrabber und BugSack installiert, keine Fehler.

Umgesetzt sind drei der sechs Designprinzipien: Klassenfarbe an der Kante, Porträt als eigene Spalte, Power als Haarlinie. Dazu Frames für Spieler, Ziel und Pet, Klassenressourcen-Pips, Castbar, ein Mover (`/uuf unlock`), Icon und Packaging.

**Offen sind die drei schwierigeren Prinzipien:** Auren mit Unterkante, Schilde schraffiert und Heilung als Geist, Reichweite durch Abblenden.

---

## API-Wissen, das diese Session gekostet hat

Das Wichtigste an diesem Dokument. Mehrere dieser Punkte haben je mehrere Runden gebraucht, weil sie den Patch Notes widersprechen.

### Secret Values greifen weiter, als dokumentiert

`UnitHealth` und `UnitHealthMax` sind **auch in der offenen Welt** verborgen, nicht nur in Instanzen, M+ und PvP. Der ursprüngliche Plan nahm das Gegenteil an; das ist widerlegt. Arithmetik, Vergleiche, `tostring` und `string.format` auf einem verborgenen Wert werfen.

### Was trotzdem geht

- `FontString:SetFormattedText` **rendert** verborgene Werte. Anzeigen geht, lesen nicht.
- `StatusBar:SetValue` und `SetMinMaxValues` nehmen verborgene Zahlen.
- `SetStatusBarColor` nimmt verborgene Farben, etwa aus `C_ClassColor.GetClassColor` bei verborgener Klasse. Für `SetColorTexture` und `SetVertexColor` gibt es diese Zusage nicht — deshalb ist in Umbra jede klassengefärbte Fläche eine StatusBar statt einer Textur.
- `UnitHealthPercent(unit, true, CurveConstants.ScaleTo100)` ist **nicht** verborgen. Blizzard gibt bewusst einen groben Prozentwert heraus.
- **`AbbreviateNumbers(value)` ist secret-sicher** — der Client rechnet nativ. Und es nimmt ein zweites Argument: `AbbreviateNumbers(value, options)` mit `options.breakpointData`. Das deutsche Locale hat keine Tausenderstufe, weshalb fünfstellige Werte unverändert durchfallen; Umbra liefert eigene Breakpoints für K und M mit. Vorbild für den Aufbau ist `EnhanceQoLDamageMeter\DamageMeter.lua`, Zeilen 860–956 — dort steht funktionierender Code auf demselben Client.
- Weitere Formatierer aus 12.0.5: `C_StringUtil.CreateAbbreviatedNumberFormatter`, `CreateNumericRuleFormatter`, `CreateSecondsFormatter`, `C_StringUtil.GetDefaultAbbreviationBreakpoints`, `CreateAbbreviateConfig`.

### Die Geometrie-Regel

**Nichts darf seine Größe aus einem Widget ableiten, das Unit-Daten bekommt.** Ein Widget, dem ein verborgener Wert übergeben wurde, meldet auch verborgene Geometrie, und das wandert die Anker-Kette entlang. oUF fragt die Health-Bar bei jedem Update nach ihrer Breite und rechnet damit — eine per `SetPoint` zwischen zwei Tag-FontStrings aufgespannte Bar lässt das krachen.

Deshalb: jedes Widget bekommt eine **explizite Größe** und **einen einzigen Anker auf das Frame selbst**. Parent und Anker dürfen verschieden sein; Text ist Kind der Bar, damit er darüber zeichnet, aber am Frame verankert.

### oUF-Spezifisches

- Das Health-Element ist bereits vollständig Midnight-nativ: es nutzt `CreateUnitHealPredictionCalculator`, `UnitGetDetailedHealPrediction` und `SetAlphaFromBoolean`. **Nicht selbst nachbauen.** Die Sub-Widgets `HealingAll`, `DamageAbsorb` und `HealAbsorb` sind der vorgesehene Weg für Heilungsvorhersage und Absorbs.
- Tag-Funktionen bekommen `setfenv` auf `_PROXY`, das per `__index` auf `_G` zurückfällt — Globals sind sichtbar, Upvalues sowieso.
- `oUF.colors.power` kommt aus Blizzards `PowerBarColor`; mit `element.colorPowerAtlas = true` werden sogar Blizzards Texturen verwendet.
- `oUF:Factory(func)` läuft bei `PLAYER_LOGIN`, `frame:UpdateTags()` erzwingt eine Tag-Aktualisierung, `oUF.objects` listet alle Frames.
- Der Namespace für Addon-Metadaten heißt `C_AddOns`, mit s.

### Für M2 wichtig

`SecureAuraHeaderTemplate` ist entfernt. Auren laufen über `CreateFrame('AuraContainer')` mit `AuraGroup`s, die ihre Buttons selbst erzeugen. Die farbige Unterkante pro Dispel-Typ lässt sich vermutlich über **je eine AuraGroup pro Dispel-Typ mit eigenem Template** lösen; das Risiko ist die Reihenfolge über Gruppen hinweg. Innerhalb von Instanzen bekommen Container und Buttons „forbidden aspects", der `initializeFrame`-Callback läuft davor.

### Für M3 wichtig

`loadstring_untainted` fehlt auf Forever **und** auf Retail 12.1. Das trifft Secure Snippets, State-Driver, `RunAttribute` und `initialConfigFunction` — also genau die Grundlage von Gruppen-Headern und Klick-Casting. Jede Snippet-Stelle gehört in `if loadstring_untainted then … end` mit statischem Fallback. `Compat/Forever.lua` setzt dafür schon `Umbra.hasSecureSnippets`.

---

## Nächste Schritte

### M2 — restliche Einzelframes und Auren

Zuerst die **Auren**, weil sie das größte Unbekannte sind und ein Designprinzip tragen. Danach Focus, Ziel-des-Ziels und Bossframes, die nach dem Pet-Muster billig sind. Dann Heilungsvorhersage und Absorbs über oUFs Health-Sub-Widgets.

Vorher lohnt ein Aufräumen: `Layouts/Shared.lua` ist auf über 320 Zeilen gewachsen und hält alles, was der ursprüngliche Plan in `Elements/` vorgesehen hatte. Auren dort noch hineinzuschreiben macht die Datei unhandlich.

### M3 — Gruppe und Raid

Secure Group Header mit dem `loadstring_untainted`-Guard, Clique-Anbindung, und hier die **Reichweiten-Abblendung** verifizieren über oUFs `Range`-Element.

### M4 — Konfiguration

AceDB und AceConfig sind noch nicht eingebunden; Positionen und Einstellungen laufen über eine handgeschriebene Mini-Version in `Core/Mover.lua`. Beim Umstieg soll das Profil-Schema des Design-Studios (`schemaVersion: 2`) zum Importformat werden. Dafür muss das Studio vorher von `classic|retail` auf `retail|forever|classic-era` umgestellt und mit dem Mockup-Artifact zusammengeführt werden.

### M5 — Forever

Launch ist der **4. November 2026**. Der Beta-Client ist derzeit nicht installiert, `_classic_beta_` fehlt, M5 ist also noch nicht testbar. Beta-Eigenheiten: SavedVariables werden geschrieben, aber nie zurückgelesen; `/reload UI` ist geschützt, `/reload` nicht.

---

## Arbeitsweise

**Installieren:** `.\tools\install.ps1` spiegelt den Checkout nach `…\_retail_\Interface\AddOns\UmbraUnitFrames`, holt oUF falls es fehlt und trägt die Commit-ID als Version ein. Der WoW-Pfad steht in `tools/.wowpath`.

**Wann `/reload` reicht:** bei Lua-Änderungen. TOC-Änderungen — Icon, Version, Interface, Dateiliste — brauchen einen **vollständigen Client-Neustart**.

**Prüfen vor dem Ausliefern:** Es gibt keinen lokalen Lua-Interpreter, aber ein Parser-Check läuft über eine Python-venv im Scratchpad. Luacheck läuft in CI. Syntax lässt sich also prüfen, Semantik nur im Client.

**Abnahme gehört in eine Instanz.** Die offene Welt beweist wenig, auch wenn Secrets dort ebenfalls greifen — Encounter, M+ und PvP haben zusätzliche Einschränkungen.

**Farben und Maße** stehen gesammelt in `Core/Defaults.lua`. Frame-Konfigurationen überschreiben per Metatable jeden Layout-Wert.

**Nicht raten, nachsehen.** Die teuersten Fehler dieser Session entstanden aus plausiblen Annahmen über die API. Was hilft: die installierten Addons des Nutzers nach echter Verwendung durchsuchen, die oUF-Quelle unter `Libs/oUF` lesen, Screenshots pixelgenau auswerten statt Farben zu schätzen.

## Offene Punkte

- **21 Commits liegen nur lokal** auf dem Branch `foundation`, nichts ist gepusht. Vor Arbeitsbeginn klären, ob `foundation` nach `main` gemerged wird.
- Der Forever-Client ist nicht installiert.
- Das Design-Studio kennt noch `classic|retail` statt der drei echten Clients.
