# Profil-Reset.cmd

Setzt ein Windows-Benutzerprofil zurück, **ohne das Profil zu löschen**. Deshalb bleiben die Standard-Apps und Dateizuordnungen erhalten (Browser, PDF, Mail usw., also `UserChoice` in `NTUSER.DAT` / `UsrClass.dat`), außerdem Startmenü, Store-Apps und Anwendungseinstellungen.

## Was gelöscht wird

| Bereich | Details |
|---|---|
| Benutzerordner | Desktop, Dokumente, Downloads, Bilder, Musik, Videos, Favoriten, Links, Kontakte, Gespeicherte Spiele, Suchvorgänge, 3D-Objekte. Umgeleitete Ordner (OneDrive, GPO-Ordnerumleitung) werden mit geleert. Die Ordner selbst und `desktop.ini` bleiben erhalten, damit die deutschen Namen bleiben. |
| Browser | Chrome, Edge, Firefox, Brave, Opera, Vivaldi (Verlauf, Cookies, Passwörter, Erweiterungen, Cache), IE/WinINet-Cache |
| Papierkorb | `X:\$Recycle.Bin\<SID>` auf allen Laufwerken |
| Spuren | Zuletzt verwendet, Sprunglisten/Schnellzugriff, Temp, Thumbnail-Cache, Aktivitätsverlauf, Zwischenablage |
| Registry-MRUs | Ausführen, Explorer-Adressleiste/Suche, Öffnen/Speichern-Dialoge, Office 2016+/365, Adobe Reader/Acrobat, Remotedesktop |
| optional | Windows-Anmeldedaten (Standard: an), Taskleisten-Pins (aus), Netzlaufwerke (aus) |

## Verwendung

```bat
Profil-Reset.cmd                    :: aktuellen Benutzer zurücksetzen (fragt nach)
Profil-Reset.cmd max.muster         :: Profil C:\Users\max.muster (als Admin, Benutzer abgemeldet)
Profil-Reset.cmd max.muster /Y      :: ohne Rückfrage
Profil-Reset.cmd max.muster /TEST   :: Testlauf, zeigt nur an
```

**Empfohlen:** Zuerst mit `/TEST` laufen lassen.

## Einsatzmöglichkeiten

* **Abmeldeskript (GPO)**: Benutzerkonfiguration → Windows-Einstellungen → Skripts → Abmelden: `Profil-Reset.cmd /Y`
* **Anmeldeskript**: ebenfalls `Profil-Reset.cmd /Y` (läuft vor dem Desktop, Browser sind noch zu)
* **Als Admin/SYSTEM** (z.B. Startskript oder geplante Aufgabe beim Start): `Profil-Reset.cmd <Profilordner> /Y`. Der Benutzer muss abgemeldet sein. Diese Variante ist die gründlichste, weil keine Dateien in Benutzung sind.

## Hintergrund / Sperrbildschirm

Oben im Skript `WALLPAPER` bzw. `LOCKSCREEN` setzen (das Bild z.B. nach `C:\Windows\Web\Wallpaper\Firma\` legen, damit alle Benutzer es lesen können).
Der Sperrbildschirm wird über `PersonalizationCSP` (HKLM) gesetzt. Das braucht Adminrechte, gilt für alle Benutzer und funktioniert auch mit Windows Pro.
Zuverlässiger ist die GPO (*Desktophintergrund* bzw. *Bestimmtes Standardbild für den Sperrbildschirm erzwingen*, letzteres nur für Enterprise/Education).

## Hinweise

* Das Löschen ist **endgültig**. Bei OneDrive-umgeleiteten Ordnern werden die Dateien auch in der Cloud gelöscht (dort landen sie im OneDrive-Papierkorb).
* Wird das Skript vom Desktop oder aus Downloads des Zielprofils gestartet, kopiert es sich nach `%PUBLIC%` (C:\Users\Public) und startet sich von dort neu; die Kopie wird am Ende wieder entfernt.
* Gesperrte Dateien (z.B. in `Temp`) werden übersprungen, wenn der Benutzer angemeldet ist.
