#/usr/bin/perl -w

use warnings;

use File::Copy;
use File::Spec;
use File::Path;
use Cwd;
use File::Basename;


#########################################
# Konfiguration
#########################################
my $src_ap = "_tif";
my $grey_ap = "_grau";
my $tiff_ap = "_tif";
my $color_ap = "_col";
my $dummy_tiff = "./data/dummy.tif";


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

sub lsDir {
	my $workdir = shift;
	if (!File::Spec->file_name_is_absolute($workdir)) {
		my $base_dir = Cwd::cwd();
		$workdir = "$base_dir/$workdir";
		return 1 if (!-d $workdir);
	}
	eval {
		opendir(TIFFDIR, $workdir);
	};
	if ($@) {
		print "Verzeichnis: " . $workdir . " nicht gefunden\n";
	}
	@files = readdir(TIFFDIR);
	closedir(TIFFDIR);
	return @files;
}


die "Keine Eingabeordner" if (!$ARGV[0]);
my $arg_dir = $ARGV[0];
if (!$arg_dir && -d $arg_dir) {
	print "Keine Eingabeordner";
	exit 1;
}

sub getWorkingDir {
	my $arg_dir = shift;
	my ($volume, $directories, $workdir) = File::Spec->splitpath($arg_dir);
	if (!File::Spec->file_name_is_absolute($directories)) {
		my $base_dir = Cwd::cwd();
		$directories =  File::Spec->catdir($base_dir, $directories);
	}
	# Überprüfung auf Unterverzeichnis

	if ($workdir =~ /(\w*_PPN\d{9}(_\d{4})?(_\d{2})?)($grey_ap|$tiff_ap|$color_ap)/ || 
				$workdir =~ /(\w*_\d{6}_\d{2})($grey_ap|$tiff_ap|$color_ap)/) {
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

my ($path, $workdir) = getWorkingDir($arg_dir);


@files = lsDir(File::Spec->catdir($path, $workdir . $src_ap));