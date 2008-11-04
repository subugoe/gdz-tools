@echo off
SET PERL_BIN=perl
SET SORT_SCRIPT=C:\Dokumente und Einstellungen\cmahnke\Desktop\Scripts\GDZ-Tools\sort.pl
SET SORT_DIR=C:\Dokumente und Einstellungen\cmahnke\Desktop\Scripts\GDZ-Tools
"%PERL_BIN%" -I"%SORT_DIR%" "%SORT_SCRIPT%" "%1"
pause