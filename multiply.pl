#/usr/bin/perl -w

use Term::ReadLine;
use File::Copy;
use File::Spec; 
use Cwd;

use GDZ::lib;

my $count;
my $file = $ARGV[0];
my ($volume, $directories, $orig_file) = File::Spec->splitpath($file);
if (!File::Spec->file_name_is_absolute($directories)) {
	my $base_dir = Cwd::cwd();
	$directories = "$base_dir/$directories";
}
my $path = $volume . $directories;
my $term = new Term::ReadLine("");
if ($ARGV[0] && $path) {
	$count = $term->readline("Anzahl der Dateien?");
	undef $term;
} else {
	print "Keine Eingabedatei";
}

if ($count > 1) {
	$orig_file =~ /(\d*)(\.\w{3})/;
	my ($start, $suffix, $len) = (($1 + 1), $2, length($1));
	print "\n";
	for (my $i = $start; $i <= ($count + $start - 1); $i++) {
		$target = $path . fill($i, $len, "0") . $suffix;
		copy($file, $target);
		print "$target kopiert\n";
	}
}
