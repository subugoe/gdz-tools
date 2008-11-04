@echo off

IF NOT %1 GOTO CHECKCONFIG
SET GDZTOOLS_PATH=%1
GOTO COPYFILES
CHECKCONFIG:
IF EXIST config.bat GOTO LOADCONFIG
SET GDZTOOLS_PATH=C:\Programme\GDZ-Tools
GOTO COPYFILES
:LOADCONFIG
CALL config.bat
:COPYFILES
ECHO Installations Pfad: %GDZTOOLS_PATH%
IF NOT EXIST %GDZTOOLS_PATH% MKDIR %GDZTOOLS_PATH%
XCOPY /E /R /Y *.* %GDZTOOLS_PATH%
ECHO Instalation abgeschlossen
COPY sort.bat "C:\Dokumente und Einstellungen\ All Users\Desktop"
COPY multiply.bat "C:\Dokumente und Einstellungen\ All Users\Desktop"
COPY tiffwriter.bat "C:\Dokumente und Einstellungen\ All Users\Desktop"
ECHO Verknüpfungen kopiert
PAUSE
