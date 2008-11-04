@echo off
CALL C:\Programme\GDZ-Tools\config.bat
"%PERL_BIN%" "%GDZTOOLS_PATH%\multiply.pl" "%1"
pause