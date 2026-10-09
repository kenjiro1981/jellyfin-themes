@echo off
rem ===========================================================================
rem  Profil-Reset.cmd  -  Abmeldeskript (GPO: Benutzerkonfiguration > Richtlinien
rem                       > Windows-Einstellungen > Skripts > Abmelden)
rem
rem  Setzt das Profil des gerade abmeldenden Benutzers zurueck, OHNE das Profil
rem  zu loeschen. Erhalten bleiben dadurch:
rem    - Standard-Apps / Dateizuordnungen (Browser, PDF, Mail, ...)
rem    - Startmenue, Store-Apps, Anwendungseinstellungen
rem
rem  Geloescht bzw. geleert werden:
rem    - Desktop, Dokumente, Downloads, Bilder, Musik, Videos, Favoriten,
rem      Links, Kontakte, Gespeicherte Spiele, Suchvorgaenge, 3D-Objekte
rem      (auch umgeleitete Ordner, z.B. OneDrive / Ordnerumleitung)
rem    - Google Chrome, Microsoft Edge, Mozilla Firefox, Brave, Opera, Vivaldi
rem    - Papierkorb des Benutzers
rem    - Zuletzt verwendet, Sprunglisten, Temp, Caches
rem    - MRU-Listen (Ausfuehren, Explorer, Office, Adobe, Remotedesktop)
rem    - optional: Anmeldedaten, Taskleisten-Pins, Netzlaufwerke
rem    - optional: Hintergrundbild setzen
rem
rem  Testlauf (zeigt nur an, loescht nichts):  Profil-Reset.cmd /TEST
rem ===========================================================================
setlocal EnableExtensions DisableDelayedExpansion

rem ============================ KONFIGURATION ================================
rem Hintergrundbild (leer = nicht aendern). Wird bei der naechsten Anmeldung
rem angezeigt. Der Pfad muss fuer den Benutzer lesbar sein.
set "WALLPAPER=\\intern.afz-rostock.de\NETLOGON\Hintergrund\AFZ-Wallpaper.png"

rem 1 = an, 0 = aus
rem Gespeicherte Windows-Anmeldedaten (Anmeldeinformationsverwaltung) loeschen
set "RESET_CREDENTIALS=1"
rem An die Taskleiste angeheftete Programme zuruecksetzen
set "RESET_TASKBAR=0"
rem Verbundene Netzlaufwerke des Benutzers entfernen
set "RESET_NETDRIVES=0"
rem ===========================================================================

set "DRY=0"
if /i "%~1"=="/TEST" set "DRY=1"

rem Nur im Kontext eines normalen Benutzers laufen (nicht als SYSTEM o.ae.)
if not defined USERPROFILE goto end
if not exist "%USERPROFILE%\NTUSER.DAT" goto end
if /i not "%USERPROFILE:\Windows\=%"=="%USERPROFILE%" goto end

pushd "%SystemRoot%"

set "P=%USERPROFILE%"
set "RO=%USERPROFILE%\AppData\Roaming"
set "LO=%USERPROFILE%\AppData\Local"
set "LL=%USERPROFILE%\AppData\LocalLow"
set "EXP=HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer"

if "%DRY%"=="1" echo TESTLAUF fuer %P% - es wird nichts geloescht.

rem --- Browser beenden, falls noch offen -------------------------------------
if "%DRY%"=="0" (
  for %%E in (chrome.exe msedge.exe firefox.exe brave.exe opera.exe vivaldi.exe iexplore.exe) do (
    taskkill /f /t /im %%E /fi "USERNAME eq %USERNAME%" >nul 2>&1
  )
  ping -n 3 127.0.0.1 >nul
)

rem --- Benutzerordner ---------------------------------------------------------
for %%F in (Desktop Documents Downloads Pictures Music Videos Favorites Links Contacts "Saved Games" Searches "3D Objects") do (
  call :EmptyDir "%P%\%%~F"
)
rem Umgeleitete Ordner (OneDrive, Ordnerumleitung per GPO)
for %%V in (Desktop Personal "My Pictures" "My Music" "My Video" Favorites "{374DE290-123F-4565-9164-39C4925E467B}") do (
  call :ShellFolder "%%~V"
)

rem --- Browser ----------------------------------------------------------------
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
call :EmptyDir "%LO%\Microsoft\Windows\INetCache"
call :EmptyDir "%LO%\Microsoft\Windows\INetCookies"
call :EmptyDir "%LO%\Microsoft\Windows\History"
call :EmptyDir "%LO%\Microsoft\Windows\WebCache"
call :RegDel "HKCU\Software\Microsoft\Internet Explorer\TypedURLs"
call :RegDel "HKCU\Software\Microsoft\Internet Explorer\TypedURLsTime"

rem --- Papierkorb -------------------------------------------------------------
set "SID="
for /f "tokens=2 delims=," %%S in ('whoami /user /fo csv /nh 2^>nul') do set "SID=%%~S"
if defined SID (
  for %%D in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if exist "%%D:\$Recycle.Bin\%SID%\" call :RemoveItem "%%D:\$Recycle.Bin\%SID%"
  )
)

rem --- Zuletzt verwendet, Sprunglisten, Caches, Temp --------------------------
call :EmptyDir "%RO%\Microsoft\Windows\Recent"
call :EmptyDir "%RO%\Microsoft\Office\Recent"
call :EmptyDir "%LO%\Temp"
call :EmptyDir "%LO%\CrashDumps"
call :EmptyDir "%LO%\ConnectedDevicesPlatform"
call :EmptyDir "%LO%\Microsoft\Windows\Clipboard"
call :EmptyDir "%LL%\Temp"
call :RemoveItem "%LO%\Microsoft\Windows\Explorer\thumbcache_*.db"
call :RemoveItem "%LO%\Microsoft\Windows\Explorer\iconcache_*.db"

rem --- MRU-Listen in der Registry ---------------------------------------------
for %%K in (RecentDocs RunMRU TypedPaths WordWheelQuery "ComDlg32\OpenSavePidlMRU" "ComDlg32\LastVisitedPidlMRU" "ComDlg32\CIDSizeMRU" "ComDlg32\OpenSaveMRU" "ComDlg32\LastVisitedMRU") do (
  call :RegDel "%EXP%\%%~K"
)
for %%A in (Word Excel PowerPoint Access Publisher Visio OneNote) do (
  for %%M in ("User MRU" "File MRU" "Place MRU") do call :RegDel "HKCU\Software\Microsoft\Office\16.0\%%A\%%~M"
)
for %%V in ("Acrobat Reader\DC" "Adobe Acrobat\DC") do (
  for %%M in (cRecentFiles cRecentFolders) do call :RegDel "HKCU\Software\Adobe\%%~V\AVGeneral\%%M"
)
call :RegDel "HKCU\Software\Microsoft\Terminal Server Client\Default"
call :RegDel "HKCU\Software\Microsoft\Terminal Server Client\Servers"

rem --- Optionale Bereiche -----------------------------------------------------
if "%RESET_CREDENTIALS%"=="1" (
  call :EmptyDir "%RO%\Microsoft\Credentials"
  call :EmptyDir "%LO%\Microsoft\Credentials"
)
if "%RESET_TASKBAR%"=="1" (
  call :EmptyDir "%RO%\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"
  call :RegDel "%EXP%\Taskband"
)
if "%RESET_NETDRIVES%"=="1" (
  call :RegDel "HKCU\Network"
  call :RegDel "%EXP%\Map Network Drive MRU"
)

rem --- Hintergrundbild --------------------------------------------------------
if not defined WALLPAPER goto wallpaper_done
call :RegAdd "HKCU\Control Panel\Desktop" Wallpaper REG_SZ "%WALLPAPER%"
call :RegAdd "HKCU\Control Panel\Desktop" WallpaperStyle REG_SZ 10
call :RegAdd "HKCU\Control Panel\Desktop" TileWallpaper REG_SZ 0
call :RegAdd "%EXP%\Wallpapers" BackgroundType REG_DWORD 0
call :RemoveItem "%RO%\Microsoft\Windows\Themes\TranscodedWallpaper"
call :RemoveItem "%RO%\Microsoft\Windows\Themes\CachedFiles"
:wallpaper_done

if "%DRY%"=="1" pause
popd
goto end

rem ===========================================================================
rem  Hilfsroutinen
rem ===========================================================================

rem Inhalt eines Ordners loeschen, Ordner selbst und desktop.ini behalten
rem (desktop.ini sorgt fuer die deutschen Ordnernamen im Explorer).
rem Verknuepfungspunkte (Junctions wie "Eigene Bilder") werden uebersprungen.
:EmptyDir
if not exist "%~1\" goto :eof
if "%DRY%"=="1" echo leeren  : %~1& goto :eof
for /f "delims=" %%F in ('dir /b /a-d "%~1" 2^>nul') do (
  if /i not "%%F"=="desktop.ini" del /f /q /a "%~1\%%F" >nul 2>&1
)
for /f "delims=" %%D in ('dir /b /ad-l "%~1" 2^>nul') do rd /s /q "%~1\%%D" >nul 2>&1
goto :eof

rem Datei, Ordner oder Platzhalter (z.B. *.db) komplett loeschen
:RemoveItem
if not exist "%~1" goto :eof
if "%DRY%"=="1" echo loeschen: %~1& goto :eof
if exist "%~1\" (
  rd /s /q "%~1" >nul 2>&1
) else (
  del /f /q /a "%~1" >nul 2>&1
)
goto :eof

:RegDel
reg query "%~1" >nul 2>&1 || goto :eof
if "%DRY%"=="1" echo reg del : %~1& goto :eof
reg delete "%~1" /f >nul 2>&1
goto :eof

rem :RegAdd <Schluessel> <Wertname> <Typ> <Daten>
:RegAdd
if "%DRY%"=="1" echo reg add : %~1 [%~2 = %~4]& goto :eof
reg add "%~1" /v "%~2" /t %~3 /d "%~4" /f >nul 2>&1
goto :eof

rem Tatsaechlichen Pfad eines (evtl. umgeleiteten) Benutzerordners lesen und leeren
:ShellFolder
set "SF="
for /f "delims=" %%L in ('reg query "%EXP%\User Shell Folders" /v "%~1" 2^>nul ^| find "_SZ"') do set "SF=%%L"
if not defined SF goto :eof
set "SF=%SF:*_SZ    =%"
call set "SF=%SF%"
if "%SF:~-1%"=="\" set "SF=%SF:~0,-1%"
rem Sicherheitspruefungen: nur absolute Pfade, nie das Profil selbst
if not "%SF:~1,1%"==":" if not "%SF:~0,2%"=="\\" goto :eof
if "%SF:~3%"=="" goto :eof
if /i "%SF%"=="%USERPROFILE%" goto :eof
call :EmptyDir "%SF%"
goto :eof

:end
endlocal
exit /b 0
