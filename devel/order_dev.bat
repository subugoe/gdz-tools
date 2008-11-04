@echo off
SET PERL_BIN=perl
SET ORDER_SCRIPT=C:\Dokumente und Einstellungen\cmahnke\Desktop\tiffwriter-dist\GDZ-Tools\order.pl
SET ORDER_DIR=C:\Dokumente und Einstellungen\cmahnke\Desktop\tiffwriter-dist\GDZ-Tools
"%PERL_BIN%" -I"%ORDER_DIR%" "%ORDER_SCRIPT%" "%1"
pause