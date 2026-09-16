# Security-Checkliste

Vor dem Merge jedes Features prüfen:

- Stammt die Spieleridentität ausschließlich aus `source`?
- Werden Typ, Länge, Wertebereich und erlaubte Enum-Werte geprüft?
- Prüft der Server Job, Rang, Gruppenrechte und aktuellen Charakterzustand?
- Prüft der Server Besitz, Inventar und Geld selbst?
- Werden Preise und Belohnungen serverseitig aus Konfiguration oder Datenbank ermittelt?
- Wird räumliche Nähe serverseitig geprüft, wenn sie für die Aktion relevant ist?
- Gibt es Schutz gegen Spam oder parallele Doppel-Ausführung?
- Sind Datenbankabfragen parameterisiert und Transaktionen bei mehrteiligen Änderungen eingesetzt?
- Werden nur benötigte Daten an den Client gesendet?
- Gibt es Cleanup bei Disconnect und Resource-Restart?
- Antwortet jeder NUI-Callback auch bei Fehlern?
- Enthalten Logs keine Secrets oder unnötigen personenbezogenen Identifikatoren?

Ein Client-Event bedeutet nur: „Der Client bittet um Aktion X.“ Der Server entscheidet vollständig, ob X erlaubt ist und welche Folgen X hat.
