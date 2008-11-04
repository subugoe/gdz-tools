@echo off
SET PERL_BIN=perl
SET FINDER_SCRIPT=C:\Dokumente und Einstellungen\cmahnke\Desktop\tiffwriter-dist\GDZ-Tools\finder.pl
SET FINDER_DIR=C:\Dokumente und Einstellungen\cmahnke\Desktop\tiffwriter-dist\GDZ-Tools
"%PERL_BIN%" -I"%FINDER_DIR%" "%FINDER_SCRIPT%" "%1"
pause