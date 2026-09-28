# Verbindlicher UI-Standard

Gilt für alle bestehenden und neuen eigenen Oberflächen, einschließlich Dialogen, Lade-/Fehlerzuständen und Browser-Vorschauen. Ausgangspunkt ist der Charaktereditor. Die Referenzen `gta/nativemnu.jpg`, `gta/nativemenu2.webp` und `gta/pausemenu.jpg` geben die flachen Auswahlzeilen und klare Hierarchie vor; die bestehende Mint-Farbwelt bleibt erhalten.

## Aufbau

- **Geldautomaten:** Auf ausdrücklichen Nutzerwunsch eine geräteähnliche GTA-ATM-Oberfläche mit Metallrahmen, hellem Bildschirm und bankabhängigen Farben: Fleeca grün, Maze Bank rot, Liberty blau. Diese Ausnahme gilt ausschließlich innerhalb des Automaten; die Spielwelt bleibt transparent sichtbar. Markenfarben kommen aus `--ui-atm-*` in `design.css`. Gemeinsame Icons, Textauswahlsperre, zugängliche Eingaben und rem-/4K-Skalierung bleiben erhalten. [Banking-Vertrag](../server-data/resources/%5Bcustom%5D/rp_banking/README.md).

- **Server-Ladebildschirm:** Vor dem Laden der Spielwelt ist eine flächige GTA-inspirierte Illustration mit ruhiger Bewegung vorgesehen. Darüber stehen freigestellte Typografie und eine kleine Ladezeile; gemeinsame Mint-/Offwhite-Farben und rem-Skalierung gelten weiter. Dieser separate FiveM-Frame ist kein Schleier über dem laufenden Spiel und wird vor der interaktiven Einreise ausgeblendet. [Details](loading-screen.md).

- **Handy:** Die ausdrücklich vom Nutzer vorgegebene iFruit-Grafik bildet die Ausnahme von den flachen Mint-Menüs: echtes Gerätegehäuse, farbige App-Symbole, blauer Auswahlglanz und Skyline-Wallpaper. Anrufe, Kontakte, Nachrichten, iFruit Social und Galerie nutzen innerhalb dieses Gehäuses auf Nutzerwunsch helle iOS-inspirierte App-Flächen: runde Wähltasten, alphabetische Kontakte, Gesprächszeilen, Sprechblasen und ein Fotogrid, mit blauer Tastaturauswahl. Camera zeigt einen bildfüllenden Sucher mit dunkler Bedienleiste, weißem Auslöser, gelber Zoomauswahl und rotem Videozustand. Keine zusätzliche große App-Überschrift über dem Sucher. Die Phone-Ausnahme wird nicht auf andere Menüs übertragen. Rechts unten, mit Inventar-Gate und passiver Uhrzeile; Pfeiltasten/Enter/Zurück, keine Maus. Gemeinsamer rem-/4K-Maßstab und Textauswahlsperre bleiben verbindlich. [Handy-Vertrag](../server-data/resources/[custom]/rp_phone/README.md).

- **NativeUI-Variante:** Wiederverwendbare Interaktionsmenüs verwenden `rp_nativeui` mit dem Renderer in `rp_ui`. Die GTA-nahe Gestaltung verwendet immer ein mintgrünes Titelbanner mit Globus, schwarzen Untertitel, helle Auswahlzeile, Pfeile/Checkboxen und Beschreibung unter der Liste. Mint gilt verbindlich für Hauptmenüs, Untermenüs und Vorschauen. Keine Maussteuerung: nur Pfeile, Enter, Backspace/Esc. API und Beispiele stehen in [rp_nativeui/README.md](../server-data/resources/%5Bcustom%5D/rp_nativeui/README.md).
- **Textauswahl:** Alle Oberflächen sperren Textmarkierung und Strg/Cmd+A außerhalb von Texteingaben. Eingabefelder und bearbeitbare Texte bleiben auswählbar. Die zentrale Regel liegt in `design.css` und `lib/selection.ts`; HTML-Drag-and-drop von Gegenständen bleibt aktiv.

- Die Spielwelt bleibt sichtbar. Reguläre Menüs erhalten keinen vollflächigen Schleier, Blur oder dunklen Hintergrund. Nur modale Bestätigungen verwenden `--ui-dialog-scrim`.
- Kopf, Inhalt und Fuß sind getrennte dunkle Flächen mit `--ui-gap` Abstand. Der äußere Rahmen bleibt transparent. Kopfbereiche verwenden `--ui-header` mit einer schmalen Mint-Linie. Keine große abgerundete Dashboard-Box.
- Inhalte werden in klaren Zeilen, kurzen Gruppen und passenden Spalten organisiert. Rahmen sparsam einsetzen; keine mehrfach ineinander verschachtelten Karten. Nur Inhaltsbereiche scrollen, wichtige Abschlussaktionen bleiben erreichbar.
- Panels so breit wie fachlich nötig: Creator schmal am Rand; Profil kompakt; Inventar mit zwei Beständen; Verwaltung und Tastatur mit Übersicht links und Inhalt rechts. Kleine Fenster erhalten Umbrüche statt abgeschnittener Bedienelemente.
- Inventar: eigenes Inventar mittig, nur bei verfügbarem zweitem Bestand zwei gleich hohe Bereiche nebeneinander. Kein gemeinsamer Hintergrundkasten: kompakter Kopf mit Bestandssymbol und Gewichtsleiste, darunter frei stehende Kacheln. Höhe aus den Slotreihen, gedeckelt durch Fenstergröße; nur das Slotraster scrollt. `--ui-inventory-*` gibt belegten Slots einen nahezu deckenden, neutralen Hintergrund, leere Slots bleiben etwas durchsichtiger. Namen stehen auf einer eigenen dunklen Zeile. Auswahl und Ablageziel verwenden hier ausdrücklich Mint-Ränder statt weißer Füllung. Beim Ziehen bleibt die vollständige Kachel am Greifpunkt in Originalgröße und Originalfarben; der Ausgangsslot wird zum Platzhalter. Keine Speicheranzeige und kein Ausgrauen des Rasters während Serveranfragen, die Sperre gegen parallele Aktionen bleibt erhalten. Fehler bleiben sichtbar. Kein Vollbild-Blur, Refresh-Button oder zusätzliche Equipment-/Fußleiste. Gegenstandsaktionen und Menge gehören ins Kontextmenü am Mauszeiger. Escape bricht das Ziehen ab. Auf schmalen Ansichten weniger Slotspalten, vorhandene Bestände bleiben nebeneinander.

- **Interaktionspunkte:** Den gemeinsamen Hinweis aus `rp_ui` verwenden: horizontal mittig im unteren Bildschirmviertel, dunkle kompakte Fläche mit Mint-Linie, physisch dargestellter Taste, Symbol und Aktion. Kein GTA-Hilfetext oben links und keine 3D-Pfeilmarker. Die Anzeige übernimmt die aktuelle eigene Tastenbelegung und beansprucht keinen Eingabefokus. API: [Interaktionshinweise](interaction-prompts.md).
- **HUD:** Drei kleine transparente Anzeigen oben rechts innerhalb der GTA-Safe-Zone: Bargeld mit Geldbörsensymbol, darunter getrennt Onlinezahl/ID und Sprache. Kein gemeinsamer äußerer Kasten. Ruhige Typografie, kleine Symbole, sanfte Zustandswechsel und sparsames Mint. Keine großen Akzentlinien, kein Hintergrund über der gesamten Spielwelt. Details: [HUD](hud.md).

## Gemeinsame Bausteine

Die Quelle für Farben, Flächen, Rundungen, Schriftgrößen und Abstände ist `server-data/resources/[custom]/rp_ui/web/src/design.css`. Bestehende Aliasvariablen `--mint`, `--muted`, `--line` und `--panel` verweisen darauf. Fachliche Stylesheets definieren ihr Layout, keine neue Farbpalette.

| Zweck | Variable / Baustein |
| --- | --- |
| Haupttext / Hilfstext | `--ui-text`, `--ui-muted`, `--ui-dim` |
| Menüfläche / Popup | `--ui-surface`, `--ui-surface-solid` |
| Zeile / Hover | `--ui-row`, `--ui-hover` |
| Auswahl | `--ui-selected` + `--ui-ink`; sekundärer Text `--ui-selected-muted` |
| Akzent / Grenze | `--ui-accent`, `--ui-line`, `--ui-rule` |
| Warnung / Fehler | `--ui-warning`, `--ui-danger` mit zugehörigen Flächen |
| Kleine Ecken / Zwischenraum | `--ui-radius`, `--ui-gap` |
| Typografie | DM Sans für Bedienung; Manrope für Überschriften; `--ui-caption`, `--ui-label`, `--ui-body` |
| Titel und Beschriftungen mit Icon | `.ui-title`, `.ui-inline`, `UiIcon` |

Ausgewählte Zeilen sind gebrochen weiß mit dunkler Schrift und dunklen Icons – auch bei Hover. Primäre Abschlussaktionen sind Mint. Warnungen sind warm orange, Fehler gedämpft rot. Die Tastenbelegung behält zusätzlich ihre fachliche Bedeutung: Grün = frei belegbar, Orange = bereits belegt. Farbe immer mit Beschriftung, Auswahlzustand oder Dialog kombinieren.

## Icons und Bedienbarkeit

Eigene Menüs mit Öffnungstaste müssen über dieselbe aktuell belegte Taste schließbar sein. Beim `rpOpen` die `toggleAction` angeben und die gemeinsame Anbindung `lib/menuToggle.ts` verwenden. Texteingaben, Tastaturwiederholung, Neubelegungen, Bestätigungsdialoge und gesperrte Abläufe dürfen nicht übergangen werden. Keine fest codierten I-/M-/F12-Abfragen in einzelnen Ansichten.

`components/UiIcon.tsx` enthält gemeinsame SVG-Piktogramme. Neue allgemeine Symbole dort ergänzen; `CreatorIcon` und `ItemIcon` bleiben für Kamera-/Körperbereiche und Gegenstände zuständig. Gleicher ruhiger Liniencharakter, `currentColor`, keine Emoji-Mischung mit plattformabhängigen Größen.

Reine Icon-Buttons brauchen einen verständlichen zugänglichen Namen und bei unklarer Bedeutung einen Tooltip. Dekorative SVGs sind für Screenreader ausgeblendet. Auswahl bleibt über `aria-pressed` oder passende native Elemente erkennbar. Tastaturfokus muss sichtbar sein; deaktivierte Aktionen bleiben unterscheidbar. Reduzierte Bewegung respektieren.

## Auflösung und Vorschau

Spiel-UIs verwenden `rem`. `html.game-ui` skaliert Schrift, Icons und Abstände gemeinsam: Full HD = 1×, QHD ≈ 1,33×, 4K = 2×. Der kleinere Faktor aus Breite und Höhe begrenzt Ultrawide. Keine zusätzliche CSS-Transformation zur Verkleinerung kompletter Spielmenüs. Studio-Bedienelemente außerhalb des Vorschaufensters skalieren unabhängig.

Mit `npm run ui:preview` alle Ansichten und ihre Zustände prüfen. Zusätzlich zu normaler Bedienung helle Hintergründe, Auswahl, Fokus, deaktivierte Aktionen, Bestätigungen und lange Beschriftungen prüfen. Mindestabdeckung: 1280×720, 1920×1080, 3840×2160, 3440×1440 und schmale Studio-Vorschau. Neue Views in `dev/catalog.ts`, Icon-Zuordnung und Browser-Demozustand aufnehmen.

Nach Änderungen `npm run check` und `npm run ui:build` ausführen. Die Browser-Tests unter `tests/*-ui.py` und `tests/ui-smoke.py` sichern die vorhandenen Interaktionen. Browserbilder zeigen keine echte GTA-Kulisse; Beleuchtung, Kamera, Ped und Lesbarkeit während tatsächlicher Spielbewegung zusätzlich im FiveM-Client prüfen.
