@echo off
CALL C:\Programme\GDZ-Tools\config.bat
"%PERL_BIN%" -I"%GDZTOOLS_PATH%" "%GDZTOOLS_PATH%\sort.pl" "%1"
pause