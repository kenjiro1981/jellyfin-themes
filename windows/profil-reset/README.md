# Profil-Reset.cmd

Abmeldeskript, das das Profil des gerade abmeldenden Benutzers zurücksetzt, **ohne das Profil zu löschen**. Deshalb bleiben die Standard-Apps und Dateizuordnungen erhalten (Browser, PDF, Mail usw.), außerdem Startmenü, Store-Apps und Anwendungseinstellungen.

## Einrichtung (GPO)

Benutzerkonfiguration → Richtlinien → Windows-Einstellungen → Skripts → **Abmelden** → `Profil-Reset.cmd` hinzufügen (z.B. aus `\\intern.afz-rostock.de\NETLOGON\`).

Testlauf, bei dem nur angezeigt und nichts gelöscht wird: `Profil-Reset.cmd /TEST`

## Was gelöscht wird

| Bereich | Details |
|---|---|
| Benutzerordner | Desktop, Dokumente, Downloads, Bilder, Musik, Videos, Favoriten, Links, Kontakte, Gespeicherte Spiele, Suchvorgänge, 3D-Objekte. Umgeleitete Ordner (OneDrive, GPO-Ordnerumleitung) werden mit geleert. Die Ordner selbst und `desktop.ini` bleiben erhalten, damit die deutschen Namen bleiben. |
| Browser | Chrome, Edge, Firefox, Brave, Opera, Vivaldi (Verlauf, Cookies, Passwörter, Erweiterungen, Cache), IE/WinINet-Cache |
| Papierkorb | `X:\$Recycle.Bin\<SID>` auf allen Laufwerken |
| Spuren | Zuletzt verwendet, Sprunglisten/Schnellzugriff, Temp, Thumbnail-Cache, Aktivitätsverlauf, Zwischenablage |
| Registry-MRUs | Ausführen, Explorer-Adressleiste/Suche, Öffnen/Speichern-Dialoge, Office 2016+/365, Adobe Reader/Acrobat, Remotedesktop |
| optional (1 = an, 0 = aus) | `RESET_CREDENTIALS` Windows-Anmeldedaten (an), `RESET_TASKBAR` Taskleisten-Pins (aus), `RESET_NETDRIVES` Netzlaufwerke (aus) |

## Hintergrund / Sperrbildschirm

* **Hintergrund:** `WALLPAPER` oben im Skript (aktuell `\\intern.afz-rostock.de\NETLOGON\Hintergrund\AFZ-Wallpaper.png`). Leer lassen = nicht ändern. Das Bild ist ab der nächsten Anmeldung zu sehen.
* **Sperrbildschirm:** Das kann ein Abmeldeskript nicht setzen, weil dafür Adminrechte (HKLM) nötig sind. Lösung per GPO:
  * Enterprise/Education: Computerkonfiguration → Administrative Vorlagen → Systemsteuerung → Anpassung → *Bestimmtes Standardbild für den Sperrbildschirm und die Anmeldung erzwingen*
  * Pro: Computerkonfiguration → Einstellungen → Windows-Einstellungen → **Registrierung**, Schlüssel `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP`:
    `LockScreenImagePath` und `LockScreenImageUrl` (REG_SZ, Bildpfad), `LockScreenImageStatus` (REG_DWORD 1).
    Das Bild am besten vorher per GPO-Einstellung *Dateien* lokal kopieren (z.B. nach `C:\Windows\Web\Screen\`).

## Hinweise

* Das Löschen ist **endgültig**. Bei OneDrive-umgeleiteten Ordnern werden die Dateien auch in der Cloud gelöscht (dort landen sie im OneDrive-Papierkorb).
* Das Skript tut nichts, wenn es nicht im Kontext eines normalen Benutzers läuft (z.B. als SYSTEM).
