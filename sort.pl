#/usr/bin/perl -w

use warnings;

use File::Copy;
use File::Spec;
use File::Path;
use Cwd;
use File::Basename;

use GDZ::TIFFFile;
use GDZ::TIFFTag;
use GDZ::lib;

#########################################
# Konfiguration
#########################################
my $src_ap = "_tif";
my $grey_ap = "_grau";
my $tiff_ap = "_tif";
my $color_ap = "_col";
my $dummy_tiff = "./data/dummy.tif";
my $tiff_scan_ap = "_tifscan";
my $grey_scan_ap = "_grauscan";


#########################################
# History
#########################################
# 1.0.3
# - Gemeinsame Funktionen ausgegliedert
# 
# 1.0.2
# - PPN Formatierung angepasst
# 
# 1.0.1
# - 4 Bit Modus hinzugefügt
#
# 1.0 
# - Erste Version
#


sub mkDirs {
	my ($path, $dirname) = @_;
	my $dir;
	eval { 
		$dir = File::Spec->catdir($path, $dirname . $grey_ap);
		mkpath($dir);
		$dir = File::Spec->catdir($path, $dirname . $tiff_ap);
		mkpath($dir);
	};
  if ($@) {
    print "Verzeichnis konnte nicht angelegt werden $dir: $@";
    return 0;
  }
  return 1;
}

sub cleanDir {
	my $workdir = shift;
	@files = lsDir($workdir);
	foreach $file (@files) {
		if (!$file =~ /\d*\.tif{1,2}/i) {
			my $infile = File::Spec->catdir($workdir, $file);
			my ($volume, $directories, $workdir) = File::Spec->splitpath($workdir);
			my $outdir = File::Spec->catdir($volume, $directories, $file);
		}
	}
}

#Pfade initialisieren
sub getWorkingDir {
	my $arg_dir = shift;
	my ($volume, $directories, $workdir) = File::Spec->splitpath($arg_dir);
	if (!File::Spec->file_name_is_absolute($directories)) {
		my $base_dir = Cwd::cwd();
		$directories =  File::Spec->catdir($base_dir, $directories);
	}
	# Überprüfung auf Unterverzeichnis

	if ($workdir =~ /^(\w*_PPN(\d{9}|\d{8}\w)(_\d{4})?(_\d{2,4})?)($grey_ap|$tiff_ap|$color_ap)$/ || 
				$workdir =~ /^(\w*_\d{6}_\d{2})($grey_ap|$tiff_ap|$color_ap)$/) {
		my $newname = $1;
		my $src = File::Spec->catdir($volume, $directories, $workdir);
		($volume, $directories, $workdir) = File::Spec->splitpath(File::Spec->catdir($volume, $directories));
		if ($workdir ne $newname) {
			my $newdir = File::Spec->catdir($volume, $directories, $workdir, $newname);
			if (!-d $newdir) {
				mkpath($newdir) or die "Verzeichnis konnte nicht angelegt werden $newdir: $!";
			}
			print "Das Verzeichnis wird verschoben, dies kann einige Zeit dauern... \n";
			recursiveMove($src, $newdir) or die "Verzeichnis konnte nicht verschoben werden: $!";
			cleanDir($newdir);
			($volume, $directories, $workdir) = File::Spec->splitpath($newdir);
		}
	}
	my $path = $volume . $directories . $workdir;
	return $path, $workdir;
}

# Initialisierung Dummy Bild
$scriptname = $0;
$dummy_tiff = File::Spec->catfile(dirname($scriptname),  $dummy_tiff);

die "Keine Eingabeordner" if (!$ARGV[0]);
my $arg_dir = $ARGV[0];
if (!$arg_dir && -d $arg_dir) {
	print "Keine Eingabeordner";
	exit 1;
}



my ($path, $workdir) = getWorkingDir($arg_dir);

if (length($path) > 2) {
# Verzeichnisse anlegen
	mkDirs($path, $workdir);
}

#Dateien einlesen
@files = lsDir(File::Spec->catdir($path, $workdir . $src_ap));

my ($grey_file, $tiff_file);

foreach $file (@files) {
	if ($file =~ /\d*\.tif{1,2}/i) {
		my $srcFile = File::Spec->catfile($path, $workdir . $src_ap, $file);
		my $myfile = GDZ::TIFFFile->new($srcFile); 
		if (GetBitsPerSample($myfile) == 8 || GetBitsPerSample($myfile) == 4) {
			$myfile->delete();
			$grey_file = File::Spec->catfile($path, $workdir . $grey_ap, $file);
			move($srcFile, $grey_file) or die "Error: $!";
			print "Datei verschoben: " . $srcFile . " -> " . $grey_file . "\n";
			$tiff_file = File::Spec->catfile($path, $workdir . $tiff_ap, $file);
			copy($dummy_tiff, $tiff_file) or die "Error: $!";
			print "Dummy angelegt: " . $dummy_tiff . " -> " . $grey_file . "\n";
		} elsif (GetBitsPerSample($myfile) == 1) {
			$myfile->delete();
			$tiff_file = File::Spec->catfile($path, $workdir . $tiff_ap, $file);
			if ($srcFile ne $tiff_file) {
				print "Datei verschoben: " . $srcFile . " -> " . $tiff_file . "\n";
				move($srcFile, $tiff_file) or die "Error: $!";
			} else {
				print $file . " beibehalten.\n";
			}
		} else {
			print "Modus \"$color_ap\" noch nicht implementiert!";
			$myfile->delete();
		}
	}
}
