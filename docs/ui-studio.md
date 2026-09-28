# UI Studio im Browser

## Start

```powershell
# Im Repository-Root; einmalig bei frischem Checkout:
npm ci

# Vorschau starten und Browser automatisch öffnen:
npm run ui:preview
```

Adresse: **http://127.0.0.1:5173/**. Der Befehl bindet nur localhost, verwendet Port 5173 und wechselt bei einem belegten Port nicht unbemerkt auf einen anderen. Läuft dort schon `npm run ui:dev`, öffne dessen Adresse direkt. `Strg+C` beendet den Vorschau-Server. Es werden weder FiveM noch FXServer, Docker oder eine Datenbank benötigt.

## Bedienung

- **Geldautomaten**: Fleeca (`/?preview=banking`), Maze Bank (`/?preview=atm-maze`) und Liberty (`/?preview=atm-liberty`) zeigen die drei Gerätevarianten. Ein-/Auszahlen, Empfängerprüfung, Überweisen, Bestätigung und Verlauf funktionieren mit lokalen Demodaten. Maus, Tab/Enter, Pfeile und Escape. [Details](../server-data/resources/%5Bcustom%5D/rp_banking/README.md).

- **HUD** (`/?preview=hud`) zeigt Bargeld, Onlinezahl, Server-ID, Mikrofonstatus und Reichweite oben rechts. Mit **GTA · Straßenszene** lässt sich die Lesbarkeit vor der Spielkulisse beurteilen. Die Vorschau verwendet Demodaten; im Spiel kommen die Werte aus ESX/FiveM. Details: [HUD](hud.md).

- **Interaktionshinweis** (`/?preview=interaction`) zeigt die kompakte Taste/Aktion-Anzeige im unteren Bildschirmviertel. Mit dem GTA-Hintergrund lassen sich Position und Kontrast direkt pr?fen. Dateien: `components/InteractionPrompt.tsx`, `interaction.css`.

- **NativeUI** zeigt die wiederverwendbare Interaktionsmenü-Demo (`/?preview=nativeui` oder `/?view=nativeui`). Nach Auswahl liegt der Tastaturfokus im Menü: Pfeile navigieren, Enter bestätigt, Backspace/Esc geht zurück. Die Maus bedient nur die äußere Studio-Seitenleiste. Nach einem Klick in die Seitenleiste bei Bedarf die Vorschau einmal fokussieren; ein Klick wählt keine Menüzeile aus. Schließen der obersten Ebene blendet die Vorschau aus.

- Die linke Liste enthält Charakterauswahl, Charaktererstellung, Mein Charakter, Inventar, Shop, Werkbank, Organisationen, Einstellungen, Ladezustand, Fehlerzustand und allgemeinen Dialog. Die Suche filtert Namen und Beschreibungen.
- Ein Klick zeigt die UI, ein weiterer auf denselben Eintrag blendet sie aus. Die zentralen Vollbildmenüs werden einzeln angezeigt. „UI ausblenden“ leert die Vorschau ebenfalls. Schließt du die UI über ihren eigenen Schließen-Knopf, aktualisiert sich die Liste mit.
- Unter „Auflösung“ stehen Fenstergröße, Full HD, QHD, 4K (3840×2160), Ultrawide (3440×1440), 1366×768, 1280×720 und 740×900 zur Verfügung. Das eingebettete Fenster hat tatsächlich die gewählte CSS-Auflösung; die äußere Darstellung wird passend verkleinert. Die linken Studio-Bedienelemente bleiben immer außerhalb der Spieloberfläche und ihrer modalen Dialoge.
- Unter **Hintergrund → GTA · Straßenszene** steht das bereitgestellte GTA-Bild zur Auswahl. Es liegt unter `src/dev/assets/gta-street.jpg`, wird zentriert und ohne Verzerrung bildfüllend dargestellt; bei abweichendem Seitenverhältnis werden die Ränder beschnitten. Im Charaktereditor ersetzt es auch die künstliche Browserkulisse. Weitere Optionen: dunkle Szene, Transparenzraster und hell. Die Auswahl verändert weder den Demozustand noch die Spieloberfläche in FiveM.
- Der Pfeilknopf „Demozustand zurücksetzen“ lädt die aktive Vorschau frisch. Für Einstellungen entfernt er zusätzlich deren Browser-Demobelegung. FiveM-KVP und Spielerdaten werden nicht berührt.
- „Einzeln öffnen“ öffnet die aktuelle UI ohne Studio in einem neuen Tab.
- URLs lassen sich direkt auf eine Ansicht setzen, etwa `/?preview=settings` für das Studio oder `/?view=settings` für die einzelne UI. `/?preview=none` startet mit leerer Vorschau.

## Bearbeiten

Für jede Ansicht gilt der [verbindliche UI-Standard](ui-design.md). Gemeinsame Farben, Flächen, Auswahlzustände und Rundungen stehen in `src/design.css`, allgemeine SVG-Icons in `src/components/UiIcon.tsx`. Das Studio verwendet dieselbe Gestaltungsrichtung. Reguläre Spielmenüs lassen ihre Umgebung transparent; mit dem hellen Hintergrund lässt sich ihre Lesbarkeit gezielt prüfen.

Das Inventar ist unter `/?preview=inventory` oder direkt `/?view=inventory` erreichbar. Es zeigt nur zwei Bestandskästen. Rechtsklick am Item öffnet Menge, Benutzen, Ablegen und Geben direkt am Mauszeiger. Zum Teilen vor Drag & Drop „Menge fürs Ziehen übernehmen“ wählen. Geben hat zwei lokale Demo-Empfänger mit eigenen Beständen. Externe Items lassen sich über Aufnehmen oder Drag & Drop übernehmen; ein angelegter Rucksack ist über das kleine Symbol im linken Kasten erreichbar. Änderungen liegen in `views/Inventory.tsx`, `inventory.css`, `lib/inventory.ts` und `lib/inventoryPreview.ts`. Waffenrad, Bodenmarker, echte Übergaben und Animationen benötigen FiveM; Browseraktionen ändern keine Spielerdaten.

Der Creator zeigt die neue kompakte GTA-orientierte Ansicht mit Icon-Navigation. Die Kamera-Piktogramme haben Tooltips; „Freie Vorschau“ blendet den Editor aus und erhält Formulareingaben. Die helle Browserkulisse bleibt ein Platzhalter: Die neue Vinewood-Terrasse und ihre Tageslicht-/Füllbeleuchtung werden nur im FiveM-Client dargestellt.

Die Dateien liegen unter `server-data/resources/[custom]/rp_ui/web/src/`. Links unten zeigt „Hier bearbeiten“ die Komponente und die passende CSS-Datei der aktiven UI. React und CSS wie gewohnt im Editor ändern und speichern; Vite aktualisiert die Vorschau automatisch. Das Studio ist eine Entwicklungs- und Testansicht, kein visueller Drag-and-drop-Editor.

Es werden dieselben Komponenten wie im Spiel verwendet. Identitätsformulare, Creator-Tabs, Modellwechsel mit getrennten Auswahlkatalogen, Tastenbelegung, Konflikte und Warnungen können mit Demodaten bedient werden. Im Creator zeigt eine kleine Statuszeile die mit Maus/Presets veränderten Kamerawerte. Freemode-Ped, echte Kamerafahrt, Kleidung am 3D-Modell, Spawn und Servervalidierung benötigen weiterhin FiveM. Browser-Demodaten stehen in `lib/preview.ts`, `lib/appearance-preview.json`, `lib/menuPreview.ts` und `lib/input-preview.json`. Der Appearance-Katalog wird mit `python tools/export-appearance-preview.py` aus den gemeinsamen Lua-Definitionen erzeugt (benötigt `lupa`); die modellabhängigen Native-Grenzen sind im Browser repräsentative Beispielwerte.

Spieloberflächen skalieren Schrift, Abstände und Bedienelemente gemeinsam über `rem`: Full HD 1×, QHD ca. 1,33×, 4K 2×. Breite und Höhe begrenzen den Faktor gemeinsam, damit Ultrawide keine übergroßen Panels erzeugt. Kleine Viewports nutzen eigene Umbrüche und scrollbare Editorbereiche. Das Studio selbst behält seine unabhängige Bedienleiste. Creator-Anpassungen liegen in `creator.css`, gemeinsame Größen in `styles.css`, Spielmenüs in `menus.css`.

## Technische Grenze und Erweiterung

Shop und Werkbank sind unter `/?view=shop` und `/?view=crafting` interaktiv testbar: Bargeld/Karte, Mengen, Suche, Rezeptzutaten, Fortschritt und Abbruch. Jede geladene Vorschau startet mit eigenen Demobeständen; es findet keine ESX-Buchung statt. Dateien: `views/Commerce.tsx`, `commerce.css`, `lib/commerce.ts`, `lib/commercePreview.ts`. E für Shop/Werkbank ist ebenfalls in der Browser-Tastenbelegung enthalten.

`main.tsx` lädt `dev/BrowserStudio.tsx` nur im normalen Browser ohne `view`-Parameter. Wenn `GetParentResourceName` vorhanden ist, bleibt der reguläre NUI-Einstieg aktiv. Im Spiel wird keine Studio-Seitenleiste geladen. Es gibt keine neue Lua-Resource, Datenbankänderung oder Änderung der Startreihenfolge.

Das Studio zeigt die App in einem gleichnamigen, lokalen iframe, damit feste CSS-Positionierung, Auflösungen und modale Dialoge unverändert funktionieren. Der einzige zusätzliche Frame-Nachrichtentyp ist `studio:visibility`; der Empfänger prüft Origin, Frame-Fenster und Payload. Spielnachrichten bleiben beim validierten NUI-Vertrag aus `lib/nui.ts`.

Für eine neue Oberfläche:

1. Die tatsächliche React-Ansicht und ihren validierten NUI-Payload ergänzen.
2. Einen Browser-Demozustand in `App.tsx` unter `browserScreen()` vorsehen.
3. Einen Eintrag in `dev/catalog.ts` mit ID, Titel, Gruppe, Beschreibung sowie Quell-/CSS-Datei ergänzen. Die ID entspricht dem `view`-Parameter der Vorschau.

## Prüfen

```text
npm run check
npm run ui:build
```

Optional mit Python, Playwright und installiertem Chrome sowie laufendem UI-Devserver:

```text
python tests/studio-ui.py
python tests/ui-smoke.py
python tests/menus-ui.py
python tests/creator-ui.py
python tests/organizations-ui.py
python tests/inventory-ui.py
python tests/nativeui-ui.py
python tests/hud-ui.py
python tests/menu-toggle-ui.py
```

Der Studio-Test prüft alle vierzehn Ansichten, Ein-/Ausblenden, Schließen aus dem iframe, feste Auflösungen, Hintergrundwahl, interaktive Tastenbelegung samt Reset, Suche, Links, Bildschirmgrößen und den Ausschluss im simulierten FiveM-Kontext. Der NativeUI-Test prüft zusätzlich Tastatursteuerung, Untermenüs, dynamische Einträge, gesperrte Aktionen, Größen bis 4K, NUI-Antworten und Textauswahl. Der HUD-Test prüft Geld-/Sprachstatus, ungültige Payloads, Safe-Zone, Auflösungen und das Zusammenspiel mit anderen Anzeigen.

Die Organisationsvorschau simuliert Mitglieder, Ränge, Finanzen und Anlage neuer Berufe/Fraktionen. Beispieldaten: `lib/organizationPreview.ts`; Ansicht: `views/Organizations.tsx`; Layout: `organizations.css`. Im Spiel werden Berechtigungen und Daten ausschließlich vom Server geliefert.

## Server-Ladebildschirm

Der **Server-Ladebildschirm** ist ebenfalls unter Einreise auswählbar. `/?preview=loadscreen` öffnet ihn im Studio; `npm run ui:loading` öffnet seine eigenständige Vorschau mit simuliertem Fortschritt. Technischer Einstieg: `loading.html`, Layout und Texte unter `src/loading/`. [Konfiguration und Lebenszyklus](loading-screen.md).

## Kleidungsladen

`/?preview=clothing` bzw. links **Kleidungsladen**: Kategorien, Produktillustrationen, Suche, Kauf-Demo und gemeinsame Creator-Kamera. Inventar-Demo enthält ein getragenes Shirt und eine Brille zum An-/Ausziehen und Transfer-Test. Exakte GTA-Kleidung und Animationen benötigen FiveM. [Details](clothing.md).
