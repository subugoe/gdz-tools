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

#functions
sub createDirList  {
	my $dir = shift;
	my @dirList;
	my $file;
	opendir(DIR, $dir) or return 0;
	@files = readdir(DIR);
	closedir(DIR);
	foreach $file (@files) {
		#print $file . "\n";
		next if ($file eq "." || $file eq "..");
		next if ($file =~ /_col$/ || $file =~ /_grau$/ || !-d File::Spec->catdir($dir, $file));
		if (-d File::Spec->catdir($dir, $file)) {
			push (@dirList, File::Spec->catdir($dir, $file));
			createDirList(File::Spec->catdir($dir, $file));
			#push (@dirList, createDirList(File::Spec->catdir($dir, $file)));
			print $file . "\n";
		}
		
	}
	return @dirList
}


#main
die "Keine Eingabeordner" if (!$ARGV[0]);
my $arg_dir = $ARGV[0];
if (!$arg_dir && -d $arg_dir) {
	print "Keine Eingabeordner";
	exit 1;
}

my $dir;
print "Verzeichnisliste wird aufgebaut.\n";
foreach $dir (createDirList($arg_dir)) {
	#print "Verzeichnisliste aufgebaut.\n";
	#print $dir . "\n";
	my @dirContent = filterFileList("\\d{8}\\.tif{1,2}", lsDir($dir));
	my $maxcount = 0;
	my @tiffiles;
	my $filecount;
	if (scalar(@dirContent) > 0) {
		print "Verzeichnis: $dir - " . scalar(@dirContent)." Dateien\n";
		my @tiffiles;
		foreach $file (@dirContent){
			$file =~ /(\d{8})\.tif{1,2}/;
			my $filename = int $1;
			$tiffiles[$filename] = $file;
			$filecount++;
			$maxcount = $filename if ($filename > $maxcount);
		}
		for ($i = 1; $i <= $maxcount; $i++) {
			if (!$tiffiles[$i]) {
				print "Verzeichnis: $dir" . " Datei ". fill($i, 8, "0") .".tif" ." fehlt\n";
			}
		}
	}
}
