@echo off
rem ===========================================================================
rem  Profil-Reset.cmd
rem
rem  Setzt ein Windows-Benutzerprofil auf einen "sauberen" Stand zurueck,
rem  OHNE das Profil selbst zu loeschen. Dadurch bleiben erhalten:
rem    - Standard-Apps / Dateizuordnungen (Browser, PDF, Mail, ...)
rem      (HKCU\...\FileExts, UrlAssociations, UserChoice, NTUSER.DAT, UsrClass.dat)
rem    - Startmenue, installierte Store-Apps, Anwendungseinstellungen
rem    - DPAPI-Schluessel (AppData\Roaming\Microsoft\Protect)
rem
rem  Geloescht bzw. geleert werden:
rem    - Desktop, Dokumente, Downloads, Bilder, Musik, Videos, Favoriten,
rem      Links, Kontakte, Gespeicherte Spiele, Suchvorgaenge, 3D-Objekte
rem      (auch umgeleitete Ordner, z.B. OneDrive / Ordnerumleitung)
rem    - Google Chrome, Microsoft Edge, Mozilla Firefox, Brave, Opera, Vivaldi
rem      (Verlauf, Cookies, Passwoerter, Erweiterungen, Cache)
rem    - Papierkorb des Benutzers (alle Laufwerke)
rem    - Zuletzt verwendet, Sprunglisten, Schnellzugriff, Temp, Caches,
rem      Thumbnail-Cache, Aktivitaetsverlauf
rem    - MRU-Listen: Ausfuehren, Explorer-Adressleiste/Suche, Oeffnen/Speichern-
rem      Dialoge, Office, Adobe Reader/Acrobat, Remotedesktop
rem    - optional: gespeicherte Windows-Anmeldedaten, Taskleisten-Pins,
rem      Netzlaufwerke
rem    - optional: Hintergrundbild und Sperrbildschirm setzen
rem
rem  Aufruf:
rem    Profil-Reset.cmd                     aktuellen Benutzer zuruecksetzen
rem    Profil-Reset.cmd max.muster          Profil C:\Users\max.muster (Admin!)
rem    Profil-Reset.cmd D:\Users\max        Profil ueber vollen Pfad (Admin!)
rem  Optionen:
rem    /Y      ohne Rueckfrage ausfuehren (fuer Anmelde-/Startskripte)
rem    /TEST   Testlauf: zeigt nur an, was geloescht wuerde
rem
rem  Fremde Profile koennen nur zurueckgesetzt werden, wenn der Benutzer
rem  abgemeldet ist und das Skript mit Administratorrechten (oder als SYSTEM)
rem  laeuft.
rem ===========================================================================
setlocal EnableExtensions DisableDelayedExpansion
set "ORIGARGS=%*"

rem ============================ KONFIGURATION ================================
rem Hintergrundbild (leer = nicht aendern). Der Pfad muss fuer den Benutzer
rem lesbar sein (lokaler Pfad oder UNC-Pfad).
set "WALLPAPER=\\intern.afz-rostock.de\NETLOGON\Hintergrund\AFZ-Wallpaper.png"

rem Sperrbildschirm (leer = nicht aendern). Benoetigt Adminrechte und gilt fuer
rem ALLE Benutzer des Rechners (PersonalizationCSP, funktioniert auch mit Pro).
rem Das Bild wird nach %SystemRoot%\Web\Screen kopiert, da der Sperrbildschirm
rem auch ohne angemeldeten Benutzer / Netzwerk verfuegbar sein muss.
set "LOCKSCREEN=\\intern.afz-rostock.de\NETLOGON\Hintergrund\AFZ-Sperrbildschirm.png"

rem Gespeicherte Windows-Anmeldedaten (Anmeldeinformationsverwaltung) loeschen
set "RESET_CREDENTIALS=1"

rem An die Taskleiste angeheftete Programme zuruecksetzen
set "RESET_TASKBAR=0"

rem Verbundene Netzlaufwerke des Benutzers entfernen (HKCU\Network)
set "RESET_NETDRIVES=0"

rem Nach dem Zuruecksetzen abmelden (nur wenn der eigene Benutzer bearbeitet wird)
set "LOGOFF_AFTER=0"
rem ===========================================================================

set "TARGET="
set "ASSUME_YES=0"
set "DRY=0"
set "SELF=0"
set "IS_ADMIN=0"
set "HIVE_LOADED=0"
set "SID="
set "HIVE_NAME=PROFILE_RESET_TMP"
set "PL=HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList"

:parse_args
if "%~1"=="" goto args_done
if "%~1"=="/?" goto usage
if /i "%~1"=="/H" goto usage
if /i "%~1"=="/Y" (
  set "ASSUME_YES=1"
) else if /i "%~1"=="/TEST" (
  set "DRY=1"
) else (
  set "TARGET=%~1"
)
shift
goto parse_args
:args_done

pushd "%SystemRoot%"
fltmc >nul 2>&1 && set "IS_ADMIN=1"

rem --- Zielprofil ermitteln --------------------------------------------------
set "PROFILES_ROOT=%SystemDrive%\Users"
for /f "tokens=2,*" %%A in ('reg query "%PL%" /v ProfilesDirectory 2^>nul ^| find /i "ProfilesDirectory"') do call set "PROFILES_ROOT=%%B"

set "PROFILE_DIR=%USERPROFILE%"
if not defined TARGET goto target_set
set "PROFILE_DIR=%TARGET%"
if "%TARGET:\=%"=="%TARGET%" set "PROFILE_DIR=%PROFILES_ROOT%\%TARGET%"
:target_set
if "%PROFILE_DIR:~-1%"=="\" set "PROFILE_DIR=%PROFILE_DIR:~0,-1%"
for %%I in ("%PROFILE_DIR%") do set "PROFILE_NAME=%%~nxI"
if /i "%PROFILE_DIR%"=="%USERPROFILE%" set "SELF=1"

rem --- Sicherheitspruefungen -------------------------------------------------
if not exist "%PROFILE_DIR%\NTUSER.DAT" (
  echo FEHLER: "%PROFILE_DIR%" ist kein Benutzerprofil ^(NTUSER.DAT fehlt^).
  goto fail
)
call set "REST=%%PROFILE_DIR:%PROFILES_ROOT%\=%%"
if /i "%REST%"=="%PROFILE_DIR%" (
  echo FEHLER: "%PROFILE_DIR%" liegt nicht unter "%PROFILES_ROOT%".
  goto fail
)
if not "%REST:\=%"=="%REST%" (
  echo FEHLER: "%PROFILE_DIR%" ist kein Profilordner direkt unter "%PROFILES_ROOT%".
  goto fail
)
for %%N in (Default "Default User" Public "All Users" defaultuser0) do (
  if /i "%PROFILE_NAME%"=="%%~N" (
    echo FEHLER: Das Systemprofil "%PROFILE_NAME%" darf nicht zurueckgesetzt werden.
    goto fail
  )
)
if "%SELF%"=="0" if "%IS_ADMIN%"=="0" (
  echo FEHLER: Fuer fremde Profile werden Administratorrechte benoetigt.
  goto fail
)

rem --- Skript liegt im Zielprofil? Dann Kopie ausserhalb starten, da es sich
rem     sonst ggf. selbst loescht (z.B. vom Desktop oder aus Downloads gestartet).
set "SCRIPT_DIR=%~dp0"
call set "REST=%%SCRIPT_DIR:%PROFILE_DIR%\=%%"
set "COPY=%PUBLIC%\Profil-Reset.cmd"
if /i not "%REST%"=="%SCRIPT_DIR%" if /i not "%~f0"=="%COPY%" (
  copy /y "%~f0" "%COPY%" >nul || goto fail
  popd
  "%COPY%" %ORIGARGS%
)

rem --- SID ermitteln (fuer Papierkorb und Anmeldepruefung) -------------------
for /f "delims=" %%K in ('reg query "%PL%" 2^>nul ^| find "\S-1-"') do call :CheckSid "%%K"
if not defined SID if "%SELF%"=="1" (
  for /f "tokens=2 delims=," %%S in ('whoami /user /fo csv /nh 2^>nul') do set "SID=%%~S"
)

if "%SELF%"=="0" if defined SID (
  reg query "HKU\%SID%" >nul 2>&1 && (
    echo FEHLER: Der Benutzer "%PROFILE_NAME%" ist angemeldet. Bitte zuerst abmelden.
    goto fail
  )
)

rem --- Rueckfrage -------------------------------------------------------------
echo.
echo  ==================== PROFIL ZURUECKSETZEN ====================
echo   Profil : %PROFILE_DIR%
echo   SID    : %SID%
if "%SELF%"=="1" (echo   Modus  : aktuell angemeldeter Benutzer) else (echo   Modus  : fremdes Profil, Benutzer abgemeldet)
if "%DRY%"=="1"  echo   TESTLAUF - es wird nichts geloescht.
echo.
echo   Desktop, Dokumente, Downloads, Bilder, Musik, Videos, Browserdaten
echo   und Papierkorb dieses Benutzers werden UNWIDERRUFLICH geloescht.
echo  ==============================================================
echo.
if "%ASSUME_YES%"=="1" goto confirmed
if "%DRY%"=="1" goto confirmed
set "ANSWER="
set /p "ANSWER=Zum Fortfahren JA eingeben: "
if /i not "%ANSWER%"=="JA" (
  echo Abgebrochen.
  goto end
)
:confirmed

call :Log "===== Profil-Reset fuer %PROFILE_DIR% (SID %SID%, Testlauf=%DRY%) ====="

rem --- Registry des Benutzers bereitstellen ----------------------------------
if "%SELF%"=="1" (
  set "HK=HKCU"
  goto hive_ready
)
set "HK=HKU\%HIVE_NAME%"
if "%DRY%"=="1" goto hive_ready
reg unload "HKU\%HIVE_NAME%" >nul 2>&1
reg load "HKU\%HIVE_NAME%" "%PROFILE_DIR%\NTUSER.DAT" >nul 2>&1
if errorlevel 1 (
  call :Log "FEHLER: NTUSER.DAT konnte nicht geladen werden - ist der Benutzer noch angemeldet?"
  goto fail
)
set "HIVE_LOADED=1"
:hive_ready

set "P=%PROFILE_DIR%"
set "RO=%PROFILE_DIR%\AppData\Roaming"
set "LO=%PROFILE_DIR%\AppData\Local"
set "LL=%PROFILE_DIR%\AppData\LocalLow"
set "EXP=%HK%\Software\Microsoft\Windows\CurrentVersion\Explorer"

rem --- Laufende Browser des eigenen Benutzers beenden -----------------------
if "%SELF%"=="0" goto browsers_closed
if "%DRY%"=="1" goto browsers_closed
call :Log "Beende Browser ..."
for %%E in (chrome.exe msedge.exe firefox.exe brave.exe opera.exe vivaldi.exe iexplore.exe) do (
  taskkill /f /t /im %%E /fi "USERNAME eq %USERNAME%" >nul 2>&1
)
ping -n 3 127.0.0.1 >nul
:browsers_closed

rem ===========================================================================
call :Log "--- Benutzerordner"
for %%F in (Desktop Documents Downloads Pictures Music Videos Favorites Links Contacts "Saved Games" Searches "3D Objects") do (
  call :EmptyDir "%P%\%%~F"
)
rem Umgeleitete Ordner (OneDrive, Ordnerumleitung per GPO, anderes Laufwerk)
for %%V in (Desktop Personal "My Pictures" "My Music" "My Video" Favorites "{374DE290-123F-4565-9164-39C4925E467B}") do (
  call :ShellFolder "%%~V"
)

rem ===========================================================================
call :Log "--- Browser"
call :RemoveItem "%LO%\Google\Chrome\User Data"
call :RemoveItem "%LO%\Microsoft\Edge\User Data"
call :RemoveItem "%LO%\BraveSoftware\Brave-Browser\User Data"
call :RemoveItem "%LO%\Vivaldi\User Data"
call :RemoveItem "%RO%\Opera Software"
call :RemoveItem "%LO%\Opera Software"
call :RemoveItem "%RO%\Mozilla\Firefox\Profiles"
call :RemoveItem "%RO%\Mozilla\Firefox\profiles.ini"
call :RemoveItem "%RO%\Mozilla\Firefox\installs.ini"
call :RemoveItem "%LO%\Mozilla\Firefox\Profiles"
rem Internet Explorer / WinINet (wird auch von vielen Programmen genutzt)
call :EmptyDir "%LO%\Microsoft\Windows\INetCache"
call :EmptyDir "%LO%\Microsoft\Windows\INetCookies"
call :EmptyDir "%LO%\Microsoft\Windows\History"
call :EmptyDir "%LO%\Microsoft\Windows\WebCache"
call :RegDel "%HK%\Software\Microsoft\Internet Explorer\TypedURLs"
call :RegDel "%HK%\Software\Microsoft\Internet Explorer\TypedURLsTime"

rem ===========================================================================
call :Log "--- Papierkorb"
if not defined SID (
  call :Log "  WARNUNG: SID unbekannt - Papierkorb wird uebersprungen."
  goto recycle_done
)
for %%D in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
  if exist "%%D:\$Recycle.Bin\%SID%\" call :RemoveItem "%%D:\$Recycle.Bin\%SID%"
)
if "%SELF%"=="1" if "%DRY%"=="0" (
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Clear-RecycleBin -Force -ErrorAction SilentlyContinue" >nul 2>&1
)
:recycle_done

rem ===========================================================================
call :Log "--- Zuletzt verwendet, Sprunglisten, Caches, Temp"
call :EmptyDir "%RO%\Microsoft\Windows\Recent"
call :EmptyDir "%RO%\Microsoft\Office\Recent"
call :EmptyDir "%LO%\Temp"
call :EmptyDir "%LO%\CrashDumps"
call :EmptyDir "%LO%\ConnectedDevicesPlatform"
call :EmptyDir "%LO%\Microsoft\Windows\Clipboard"
call :EmptyDir "%LL%\Temp"
call :RemoveItem "%LO%\Microsoft\Windows\Explorer\thumbcache_*.db"
call :RemoveItem "%LO%\Microsoft\Windows\Explorer\iconcache_*.db"

rem ===========================================================================
call :Log "--- MRU-Listen in der Registry"
for %%K in (RecentDocs RunMRU TypedPaths WordWheelQuery "ComDlg32\OpenSavePidlMRU" "ComDlg32\LastVisitedPidlMRU" "ComDlg32\CIDSizeMRU" "ComDlg32\OpenSaveMRU" "ComDlg32\LastVisitedMRU") do (
  call :RegDel "%EXP%\%%~K"
)
for %%A in (Word Excel PowerPoint Access Publisher Visio OneNote) do (
  for %%M in ("User MRU" "File MRU" "Place MRU") do call :RegDel "%HK%\Software\Microsoft\Office\16.0\%%A\%%~M"
)
for %%V in ("Acrobat Reader\DC" "Adobe Acrobat\DC") do (
  for %%M in (cRecentFiles cRecentFolders) do call :RegDel "%HK%\Software\Adobe\%%~V\AVGeneral\%%M"
)
call :RegDel "%HK%\Software\Microsoft\Terminal Server Client\Default"
call :RegDel "%HK%\Software\Microsoft\Terminal Server Client\Servers"

rem ===========================================================================
if not "%RESET_CREDENTIALS%"=="1" goto creds_done
call :Log "--- Gespeicherte Windows-Anmeldedaten"
call :EmptyDir "%RO%\Microsoft\Credentials"
call :EmptyDir "%LO%\Microsoft\Credentials"
:creds_done

if not "%RESET_TASKBAR%"=="1" goto taskbar_done
call :Log "--- Taskleisten-Pins"
call :EmptyDir "%RO%\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"
call :RegDel "%EXP%\Taskband"
:taskbar_done

if not "%RESET_NETDRIVES%"=="1" goto netdrives_done
call :Log "--- Netzlaufwerke"
call :RegDel "%HK%\Network"
call :RegDel "%EXP%\Map Network Drive MRU"
:netdrives_done

rem ===========================================================================
if not defined WALLPAPER goto wallpaper_done
call :Log "--- Hintergrundbild: %WALLPAPER%"
if not exist "%WALLPAPER%" call :Log "  WARNUNG: Bilddatei nicht gefunden."
call :RegAdd "%HK%\Control Panel\Desktop" Wallpaper REG_SZ "%WALLPAPER%"
call :RegAdd "%HK%\Control Panel\Desktop" WallpaperStyle REG_SZ 10
call :RegAdd "%HK%\Control Panel\Desktop" TileWallpaper REG_SZ 0
call :RegAdd "%EXP%\Wallpapers" BackgroundType REG_DWORD 0
call :RemoveItem "%RO%\Microsoft\Windows\Themes\TranscodedWallpaper"
call :RemoveItem "%RO%\Microsoft\Windows\Themes\CachedFiles"
if "%SELF%"=="1" if "%DRY%"=="0" RUNDLL32.EXE user32.dll,UpdatePerUserSystemParameters 1, True
:wallpaper_done

if not defined LOCKSCREEN goto lockscreen_done
call :Log "--- Sperrbildschirm: %LOCKSCREEN%"
if "%IS_ADMIN%"=="0" (
  call :Log "  WARNUNG: Keine Adminrechte - Sperrbildschirm wird nicht gesetzt."
  goto lockscreen_done
)
if not exist "%LOCKSCREEN%" (
  call :Log "  WARNUNG: Bilddatei nicht gefunden - Sperrbildschirm wird nicht gesetzt."
  goto lockscreen_done
)
rem lokale Kopie anlegen und diese verwenden
for %%I in ("%LOCKSCREEN%") do set "LOCK_LOCAL=%SystemRoot%\Web\Screen\%%~nxI"
call :Log "  kopieren: %LOCKSCREEN% nach %LOCK_LOCAL%"
if "%DRY%"=="1" goto lock_copied
copy /y "%LOCKSCREEN%" "%LOCK_LOCAL%" >nul 2>&1
if errorlevel 1 (
  call :Log "    WARNUNG: Kopieren fehlgeschlagen - verwende Netzwerkpfad."
  set "LOCK_LOCAL=%LOCKSCREEN%"
)
:lock_copied
set "CSP=HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP"
call :RegAdd "%CSP%" LockScreenImagePath REG_SZ "%LOCK_LOCAL%"
call :RegAdd "%CSP%" LockScreenImageUrl REG_SZ "%LOCK_LOCAL%"
call :RegAdd "%CSP%" LockScreenImageStatus REG_DWORD 1
rem Windows-Blickpunkt (Spotlight) auf dem Sperrbildschirm abschalten
set "CDM=%HK%\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
call :RegAdd "%CDM%" RotatingLockScreenEnabled REG_DWORD 0
call :RegAdd "%CDM%" RotatingLockScreenOverlayEnabled REG_DWORD 0
:lockscreen_done

rem ===========================================================================
call :Log "===== Profil-Reset abgeschlossen ====="
call :UnloadHive
echo.
echo Fertig.
if "%SELF%"=="1" if "%LOGOFF_AFTER%"=="1" if "%DRY%"=="0" (
  echo Abmeldung in 5 Sekunden ...
  ping -n 6 127.0.0.1 >nul
  shutdown /l
)
goto end

rem ===========================================================================
rem  Hilfsroutinen
rem ===========================================================================

:Log
echo %~1
goto :eof

rem Inhalt eines Ordners loeschen, Ordner selbst und desktop.ini behalten
rem (desktop.ini sorgt fuer die deutschen Ordnernamen im Explorer).
rem Verknuepfungspunkte (Junctions wie "Eigene Bilder") werden uebersprungen.
:EmptyDir
if not exist "%~1\" goto :eof
call :Log "  leeren : %~1"
if "%DRY%"=="1" goto :eof
for /f "delims=" %%F in ('dir /b /a-d "%~1" 2^>nul') do (
  if /i not "%%F"=="desktop.ini" del /f /q /a "%~1\%%F" >nul 2>&1
)
for /f "delims=" %%D in ('dir /b /ad-l "%~1" 2^>nul') do rd /s /q "%~1\%%D" >nul 2>&1
goto :eof

rem Datei, Ordner oder Platzhalter (z.B. *.db) komplett loeschen
:RemoveItem
if not exist "%~1" goto :eof
call :Log "  loeschen: %~1"
if "%DRY%"=="1" goto :eof
if exist "%~1\" (
  rd /s /q "%~1" >nul 2>&1
) else (
  del /f /q /a "%~1" >nul 2>&1
)
if exist "%~1" call :Log "    WARNUNG: nicht vollstaendig geloescht (Datei in Benutzung?)"
goto :eof

:RegDel
reg query "%~1" >nul 2>&1 || goto :eof
call :Log "  reg del: %~1"
if "%DRY%"=="1" goto :eof
reg delete "%~1" /f >nul 2>&1
goto :eof

rem :RegAdd <Schluessel> <Wertname> <Typ> <Daten>
:RegAdd
call :Log "  reg add: %~1 [%~2 = %~4]"
if "%DRY%"=="1" goto :eof
reg add "%~1" /v "%~2" /t %~3 /d "%~4" /f >nul 2>&1 || call :Log "    WARNUNG: konnte nicht gesetzt werden"
goto :eof

rem SID zu einem ProfileList-Eintrag pruefen
:CheckSid
set "IMG="
for /f "tokens=2,*" %%A in ('reg query "%~1" /v ProfileImagePath 2^>nul ^| find /i "ProfileImagePath"') do call set "IMG=%%B"
if not defined IMG goto :eof
if /i not "%IMG%"=="%PROFILE_DIR%" goto :eof
for %%S in ("%~1") do set "CAND=%%~nxS"
if /i "%CAND:~-4%"==".bak" goto :eof
set "SID=%CAND%"
goto :eof

rem Tatsaechlichen Pfad eines (evtl. umgeleiteten) Benutzerordners lesen und leeren
:ShellFolder
if "%DRY%"=="1" if "%SELF%"=="0" goto :eof
set "SF="
for /f "delims=" %%L in ('reg query "%EXP%\User Shell Folders" /v "%~1" 2^>nul ^| find "_SZ"') do set "SF=%%L"
if not defined SF goto :eof
set "SF=%SF:*_SZ    =%"
rem %USERPROFILE% im Wert auf das Zielprofil abbilden, danach Variablen aufloesen
setlocal EnableDelayedExpansion
set "SF=!SF:%%USERPROFILE%%=%PROFILE_DIR%!"
for /f "delims=" %%X in ("!SF!") do endlocal & set "SF=%%X"
call set "SF=%SF%"
echo "%SF%" | find "%%" >nul && goto :eof
if "%SF:~-1%"=="\" set "SF=%SF:~0,-1%"
if /i "%SF%"=="%PROFILE_DIR%" goto :eof
if /i "%SF%"=="%PROFILES_ROOT%" goto :eof
if "%SF:~3%"=="" goto :eof
rem nur absolute Pfade (Laufwerk oder UNC) zulassen
if not "%SF:~1,1%"==":" if not "%SF:~0,2%"=="\\" goto :eof
call :EmptyDir "%SF%"
goto :eof

:UnloadHive
if not "%HIVE_LOADED%"=="1" goto :eof
for /l %%N in (1,1,5) do (
  reg unload "HKU\%HIVE_NAME%" >nul 2>&1 && (
    set "HIVE_LOADED=0"
    goto :eof
  )
  ping -n 3 127.0.0.1 >nul
)
call :Log "WARNUNG: Registry des Benutzers konnte nicht entladen werden (HKU\%HIVE_NAME%)."
goto :eof

:usage
echo.
echo Profil-Reset.cmd [Profilordner ^| Profilpfad] [/Y] [/TEST]
echo.
echo   ohne Profil   setzt den aktuell angemeldeten Benutzer zurueck
echo   Profilordner  z.B. max.muster  (unterhalb von C:\Users, Admin noetig)
echo   /Y            ohne Rueckfrage
echo   /TEST         Testlauf, es wird nichts geloescht
echo.
goto end

:fail
call :UnloadHive
popd
endlocal
if /i "%~f0"=="%PUBLIC%\Profil-Reset.cmd" (goto) 2>nul & del /f /q "%~f0" & exit /b 1
exit /b 1

:end
popd
endlocal
rem temporaere Kopie (siehe oben) wieder entfernen
if /i "%~f0"=="%PUBLIC%\Profil-Reset.cmd" (goto) 2>nul & del /f /q "%~f0" & exit /b 0
exit /b 0
