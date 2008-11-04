#/usr/bin/perl -w

use warnings;

use File::Copy;
use File::Spec;
use File::Path;
use Cwd 'abs_path';
use File::Basename;

use GDZ::lib;

#########################################
# Konfiguration
#########################################
my $tiff_scan_ap = "_tif";
my $grey_scan_ap = "_grau";
my $src_ap = "__\\[\\d{1,5}\\]";

#########################################
# History
#########################################
# 1.0 
# - Erste Version
#

my $w = "[\\wÄÖÜäöüß]";

#functions
#Pfade initialisieren
sub getWorkingDir {
	my $arg_dir = shift;
	my ($volume, $directories, $workdir) = File::Spec->splitpath($arg_dir);
	if (!File::Spec->file_name_is_absolute($directories)) {
		my $base_dir = Cwd::cwd();
		$directories =  File::Spec->catdir($base_dir, $directories);
	}
	# Überprüfung auf Unterverzeichnis
	
	if ($workdir =~ /^($w*_PPN(\d{9}|\d{8}\w)(_\d{4})?(_\d{2,4})?)($grey_scan_ap|$tiff_scan_ap)$/ || 
				$workdir =~ /^($w*_\d{6}_\d{2})($grey_scan_ap|$tiff_scan_ap)$/) {
		($volume, $directories, $workdir) = File::Spec->splitpath(File::Spec->catdir($volume, $directories, $workdir, ".."));
	}
	my $path = $volume . $directories . $workdir;
	return $path, $workdir;
}

sub get_basename {
	my $name = shift;
	if ($name =~ /^($w*_PPN(\d{9}|\d{8}\w)(_\d{4})?(_\d{2,4})?)($src_ap)$/ || 
				$name =~ /^($w*_\d{6}_\d{2})($src_ap)$/) {
		return  $1;
	} else {
		return 0;
	}
}

#main
die "Keine Eingabeordner" if (!$ARGV[0]);
my $arg_dir = $ARGV[0];
if (!$arg_dir && -d $arg_dir) {
	print "Keine Eingabeordner";
	exit 1;
}

my ($path, $workdir) = getWorkingDir($arg_dir);
my $name = get_basename($workdir);


# Prüfen ob Verzeichnisse da sind.
if (!-d File::Spec->catdir($path, $name . $tiff_scan_ap) || !-d File::Spec->catdir($path, $name . $grey_scan_ap)) {
	die "Scanverzeichnisse \"$name\" nicht gefunden.\n";
}

#Dateien einlesen
my @greyfiles;
my @tiffiles;
my $filecount = 0;
my $greycount = 0;
foreach $greyfile (filterFileList("\\d{8}\\.tif{1,2}", lsDir(File::Spec->catdir($path, $name . $grey_scan_ap)))){
	$greyfile =~ /(\d{8})\.tif{1,2}/;
	my $filename = int $1;
	$greyfiles[$filename] = $greyfile;
	$greycount++;
	#print "Nr: ". $filename . " -> " .$greyfile ."\n";
}
#my $filename;
my $maxcount = 0;
#foreach $tiffile (filterFileList("\\d{8}\\.tif{1,2}", lsDir($path))){
foreach $tiffile (filterFileList("\\d{8}\\.tif{1,2}", lsDir(File::Spec->catdir($path, $name . $tiff_scan_ap)))){
	$tiffile =~ /(\d{8})\.tif{1,2}/;
	my $filename = int $1;
	$tiffiles[$filename] = $tiffile;
	$filecount++;
	#print "Nr: ". $filename . " -> " .$tiffile ."\n";
	$maxcount = $filename if ($filename > $maxcount);
}

#Vergleiche Anzahl der Grau mit der der SW Dateien.
if (($maxcount - $filecount) < $greycount) {
#	print "Pfad: " . $path . "\n";
#	print "Anzahl SW Bilder: " . scalar(@tiffiles) . " -> " .$maxcount. " -> ". $filecount . "\n";
#	print "Anzahl Grau Bilder: " . scalar(@greyfiles) . " -> " .$greycount."\n";
	die "Zu wenige Grauscans!\n";
} elsif (($maxcount - $filecount) > $greycount) {
	print "Achtung! Die Zahl der Lücken stimmt nicht mit der der Zahl der Grauscans überein, überzählige Dateien werden am Ende angefügt.\n";
	die;
}

#Prüfung auf vornummerierte Graubilder
my $ordered = 0;
if (scalar(@greyfiles) - 1 > $greycount) {
	print "Grösse der Liste der Graudateien: ".scalar(@greyfiles)."\n";
	print "Anzahl Graudateien: ".$greycount."\n";
	print "Graudateien sind vorsortiert.\n";
	$ordered = 1;
}


#Dateien ins übergeordnete Verzeichnis verschieben
my $src = File::Spec->catdir($path, $name . $tiff_scan_ap); 
opendir(DIR, $src) or return 0;
my @files = readdir(DIR);
closedir(DIR);
foreach $file (@files) {
	next if ($file eq "." || $file eq "..");
	my $newSrc = File::Spec->catdir($src, $file);
	my $newDestFile = File::Spec->catdir($path, $file);
	if (-d $file) {
		mkpath($newDestFile) or die "Verzeichnis konnte nicht angelegt werden $newDest: $!" if (!-d $newDest);
		recursiveMove($newSrc, $newDestFile);
		rmtree($newSrc);
	} else {
		move($newSrc, $newDestFile) or die "Datei konnte nicht verschoben werden: $!";
	}
}
@files = undef;
$file = undef;
rmtree(File::Spec->catdir($path, $name . $tiff_scan_ap)) if (-r File::Spec->catdir($path, $name . $tiff_scan_ap));

my $greycounter = 0;
for ($i = 1; $i <= $maxcount; $i++) {
	if (!$tiffiles[$i]) {
		my $targetFile = File::Spec->catdir($path, fill($i, 8, "0") .".tif");
		my $srcFile;
		if ($ordered == 0) {
			$srcFile = File::Spec->catdir($path, $name . $grey_scan_ap, $greyfiles[$greycounter + 1]);
		} else {
			$srcFile = File::Spec->catdir($path, $name . $grey_scan_ap, $greyfiles[$i]);
		}
		print $targetFile . " <- " . $srcFile . "\n";
		move($srcFile, $targetFile);
		$greycounter++;
	}
}

#print "maxcount".$maxcount."\n";
#print "scalar(greyfiles)" . scalar(@greyfiles)."\n";
#print "greycount".$greycount."\n";


# Restliche Dateien am Ende anfügen.
if ($greycounter != $greycount) {
	print "Restliche Dateien werden am Ende anfügt.\n";
	for ($i = $maxcount; $i <= $maxcount + scalar(@greyfiles) - $greycounter; $i++) {
		print "i: ".$i."\n";
		my $targetFile = File::Spec->catdir($path, fill($i, 8, "0") .".tif");
		my $srcFile = File::Spec->catdir($path, $name . $grey_scan_ap, $greyfiles[$greycounter]);
		print $targetFile . " <- " . $srcFile . "\n";
		move($srcFile, $targetFile);
		$greycounter++;
	}
}

$file = undef;
@files = undef;
#Unerwünschte Dateien löschen
rmtree(File::Spec->catdir($path, $name . $grey_scan_ap, "thumb")) if (-r File::Spec->catdir($path, $name . $grey_scan_ap, "thumb"));
rmtree(File::Spec->catdir($path, $name . $grey_scan_ap, "undo")) if (-r File::Spec->catdir($path, $name . $grey_scan_ap, "undo"));
#Restliche Dateien ins übergeordnete Verzeichnis verschieben
$src = File::Spec->catdir($path, $name . $grey_scan_ap); 
opendir(DIR, $src) or die "Verzeichnis $src konnte nicht geöffnet werden: " . $!;
@files = readdir(DIR);
closedir(DIR);
foreach $file (@files) {
	next if ($file eq "." || $file eq "..");
	my $newSrc = File::Spec->catdir($src, $file);
	my $newDestFile = File::Spec->catdir($path, $file);
	if (-d $file) {
		mkpath($newDestFile) or die "Verzeichnis konnte nicht angelegt werden $newDest: $!" if (!-d $newDest);
		recursiveMove($newSrc, $newDestFile);
		rmtree($newSrc);
	} else {
		move($newSrc, $newDestFile) or die "Datei \"$newSrc\" konnte nicht verschoben werden: $!";
	}
}
@files = undef;
$file = undef;
rmtree(File::Spec->catdir($path, $name . $grey_scan_ap)) if (-r File::Spec->catdir($path, $name . $grey_scan_ap));

#Unterordner anlegen
#print "Pfad: ". $path . $name . $tiff_scan_ap ."\n";

mkpath(File::Spec->catdir($path, $name . $tiff_scan_ap)) or die "Verzeichnis konnte nicht angelegt werden $newDest: $!" if (!-d File::Spec->catdir($path, $name . $tiff_scan_ap));
$src = File::Spec->catdir($path); 
opendir(DIR, $src) or die "Verzeichnis $src konnte nicht geöffnet werden: " . $!;
@files = readdir(DIR);
closedir(DIR);
foreach $file (@files) {
	next if ($file eq "." || $file eq "..");
	next if ($file eq $name . $tiff_scan_ap);
	my $newSrc = File::Spec->catdir($src, $file);
	#print "Path: " . $path ."\n";
	#print "Name: " . $name ."\n";
	#print "Tif_scan_ap: " . $tiff_scan_ap . "\n";
	my $newDestFile = File::Spec->catdir($path, $name . $tiff_scan_ap, $file);
	if (-d $file) {
		mkpath($newDestFile) or die "Verzeichnis konnte nicht angelegt werden $newDest: $!" if (!-d $newDest);
		recursiveMove($newSrc, $newDestFile);
		rmtree($newSrc);
	} else {
		move($newSrc, $newDestFile) or die "Datei \"$newSrc\" konnte nicht verschoben werden: $!";
	}
}
@files = undef;


