#/usr/bin/perl -w

sub GetBitsPerSample {
	my ($myfile)=@_;

	my $myTag=$myfile->GetTag("258");
	if (defined $myTag) {
		return $myTag->GetValue();
	}
	return undef;
}

sub GetSamplesPerPixel {
	my ($myfile)=@_;

	my $myTag=$myfile->GetTag("277");
	if (defined $myTag) {
		return $myTag->GetValue();
	}
	return undef;
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

sub filterFileList {
	my $filter = shift;
	my @files = @_;
	my @filteredFiles;
	for $file (@files) {
		if ($file =~ /$filter/) {
			push @filteredFiles, $file;
		}
	}
	return @filteredFiles;
}


sub recursiveMove {
	my ($src, $dest) = @_;
	return 0 if (!File::Spec->file_name_is_absolute($src) && !File::Spec->file_name_is_absolute($dest));
	if (-d $src) {
		opendir(DIR, $src) or return 0;
		@files = readdir(DIR);
		closedir(DIR);
		my($volume, $directories, $newDest) = File::Spec->splitpath($src);
		$newDest = File::Spec->catdir($dest, $newDest);
		mkpath($newDest) or die "Verzeichnis konnte nicht angelegt werden $newDest: $!" if (!-d $newDest);
		foreach $file (@files) {
			next if ($file eq "." || $file eq "..");
			my $newSrc = File::Spec->catdir($src, $file);
			my $newDestFile = File::Spec->catdir($newDest, $file);
			if (-d $file) {
				mkpath($newDestFile) or die "Verzeichnis konnte nicht angelegt werden $newDest: $!" if (!-d $newDest);
				recursiveMove($newSrc, $newDestFile);
				rmtree($newSrc);
			} else {
				move($newSrc, $newDestFile) or die "Datei konnte nicht verschoben werden: $!";
			}
		}
		rmtree($src);
		return 1;
	} else {
		move($src, $dest) or die "Datei konnte nicht verschoben werden: $!";
		return 1;
	}
}

sub fill {
	my ($str, $len, $char) = @_;
	my $return = $str;
	for (my $i = 1; $i <= ($len - length($str)); $i++) {
		$return = $char . $return;
	}
	return $return;
}

return 1;