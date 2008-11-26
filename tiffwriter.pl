#!/usr/bin/perl

#
# Aufruf: tiffwriter.pl /thispath/
#

use strict;
use Fcntl;
use IO::File;

use File::Basename;
use File::Path; 
use Config;
use Term::ReadLine;

use GDZ::TIFFFile;
use GDZ::TIFFTag;
use GDZ::lib;


my $dirSep = '/';  # assume Unix
if ($Config{'osname'} =~/MSWin32/i ) {
	$dirSep='\\';
}
if ($Config{'osname'}=~/^macos/i ) {
	$dirSep=':';
}

my $VERSION = "0.35";

my $tiffheaderwriter="";
my @entries=();             # files
my @tifffiles=();		    # only tiff files
my $singleentry=undef;
my $number=0;
my $key=undef;
my $updateartist=undef;
my $updatedocname=undef;
my $updateimgdesc=undef;
my $updateresolutionx=undef;
my $updateresolutiony=undef;
my $checkfornames=undef;

my @pagearray=();
my $pagenumber=0;

my $basedir=$ARGV[0];
my $silent = $ARGV[1];

if (substr($basedir,length($basedir)-1,1) eq $dirSep) {  # delete last char, if diretory seperator
	$basedir=substr($basedir,0,length($basedir)-1);
}

print "\n\n\n";
print "______________________________________________________\n";
print "|                                                    |\n";
print "|          Updating TIFF-Header information          |\n";
print "|                                                    |\n";
print "|            version 0.35, November 2008             |\n";
print "|                                                    |\n";
print "| (C) GDZ / Goettingen State and University Library  |\n";
print "|           Original author: Markus Enders           |\n";
print "|   Info/bugreports: mahnke\@sub.uni-goettingen.de    |\n";
print "|                                                    |\n";
print "______________________________________________________\n";
print "OS:".$Config{'osname'}."\n";
print "\nUpdating: PageName (285)\n";

($updateartist,$updatedocname,$updateimgdesc,$updateresolutionx,$updateresolutiony,$checkfornames)=ReadTiffWriterConf($basedir);

if ((defined $updateartist)&&($updateartist ne "")) {
	print "          Artist (315)\n         \" ".$updateartist."\"\n";
}
if ((defined $updatedocname)&&($updatedocname ne "")) {
	print "          Documentname (269)\n          \"".$updatedocname."\"\n";
}
if ((defined $updateimgdesc)&&($updateimgdesc ne "")) {
	print "          Image Description (270)\n          \"".$updateimgdesc."\"\n";
}
if ((defined $updateresolutionx)&&($updateresolutionx ne "")) {
	print "          Resolution - x (282)\n          \"".$updateresolutionx."\"\n";
	if ($updateresolutionx eq "!!FEHLER!!") {
		print "\n* FEHLER: Falscher Wert fuer X-Aufloesung; vermutl. kein Zahlenwert\n";
		if ($silent eq "") {
			my $term = new Term::ReadLine 'exit';
			my $prompt = "\nZeilenschalter (Return) zum beenden druecken... ";
			$term->readline($prompt);
		}
		exit 1;
	}
}
if ((defined $updateresolutiony)&&($updateresolutiony ne "")) {
	print "          Resolution - y (283)\n          \"".$updateresolutiony."\"\n";
	if ($updateresolutiony eq "!!FEHLER!!") {
		print "\n* FEHLER: Falscher Wert fuer Y-Aufloesung; vermutl. kein Zahlenwert\n";
		if ($silent eq "") {
			my $term = new Term::ReadLine 'exit';
			my $prompt = "\nZeilenschalter (Return) zum beenden druecken... ";
			$term->readline($prompt);
		}
		exit 2;
	}
}

print "\n";

if (!defined $basedir) {
	print "Kein Verzeichnis angegeben :-(\n";
	
	if ($silent eq "") {
		my $term = new Term::ReadLine 'exit';
		my $prompt = "\nZeilenschalter (Return) zum beenden druecken... ";
		$term->readline($prompt);
	}

	exit -2;
}else {
	print " Bearbeite TIFFs in ".$basedir."\n";
}
#
# read directory
#

eval {
	opendir(DIR,$basedir)||die "dir not found\n";
};
if ($@) {
	# directory not available
	print "Verzeichnis: ".$basedir." nicht gefunden\n";
	if ($silent eq "") {
		my $term = new Term::ReadLine 'exit';
		my $prompt = "\nZeilenschalter (Return) zum beenden druecken... ";
		$term->readline($prompt);
	}

	exit -1;
}

	@entries=readdir(DIR); # get all entries
closedir(DIR);


foreach $singleentry (@entries) {

	my $filetype=substr($singleentry,length($singleentry)-3,3);
	if (($filetype eq "TIF")||($filetype eq "tif")) {
		$singleentry=~s/TIF/tif/g;
		push(@tifffiles,$singleentry);
		$number++;
	}

}

print $number." TIFF-Dateien gefunden    \n\n";

if (($checkfornames eq "yes")||($checkfornames eq "true")) {
	
print "Vorbereiten...\n";
#
# checking document name
#
my $counter=0;
sort @tifffiles;

($updateartist,$updatedocname,$updateimgdesc,$updateresolutionx,$updateresolutiony,$checkfornames)=ReadTiffWriterConf($basedir);
foreach my $tifffile (@tifffiles) {
	my $pagenumber=0;
	my $pagenumber_str=undef;
	my $fulldir=undef;
	my $documentname=undef;
	my $olddocumentname=undef;
	my $artist=undef;
	my $oldartist=undef;
	my $oldimagedesc=undef;
	my $imagedesc=undef;
	my $myfile=undef;    # TIFFFIle object

	$fulldir=$basedir.$dirSep.$tifffile;
	$pagenumber=substr($tifffile,0,length($tifffile)-4);
	
	$myfile=GDZ::TIFFFile->new($fulldir);    # open TIFF file, get object
	if (!defined $myfile) {
		print ("no tiff image, continue with next one...");
		next;
	}

	if (substr($pagenumber,0,1) ne "0") {
		print "Unzulaessiger Imagename:".$tifffile."\n";
		next;
	}

	while(substr($pagenumber,0,1) eq "0"){
		$pagenumber=substr($pagenumber,1,length($pagenumber)-1); # delete the first zero
	} 
	
	$counter++;

	$pagearray[$pagenumber]=$pagenumber;

	#TODO: This is evil
	if ($pagenumber<10) {$pagenumber_str="|0000".$pagenumber."||";}
	elsif ($pagenumber<100) {$pagenumber_str="|000".$pagenumber."||";}
	elsif ($pagenumber<1000) {$pagenumber_str="|00".$pagenumber."||";}
	elsif ($pagenumber<10000) {$pagenumber_str="|".$pagenumber."||";}

	$documentname=GetDocumentName($myfile);

	if ((defined $documentname)&&((!defined $updatedocname)||($updatedocname eq ""))) {
		if ((defined $olddocumentname)&&($olddocumentname ne $documentname)) {
			print "\n * Document-Name abweichend/falsch in Image:".$tifffile."\n";
		}else {
			$olddocumentname=$documentname;
		}
	}else {
		if ((!defined $updatedocname)||($updatedocname eq "")) {
			print "\n * Document-Name nicht vorhanden in Image:".$tifffile."\n";
		}
	}

	$artist=GetArtist($myfile);
	if ((defined $artist)&&((!defined $updateartist)||($updateartist eq ""))) {
		if ((defined $oldartist)&&($oldartist ne $artist)) {
			print "\n * Artist  abweichend/falsch in Image:".$tifffile."\n";
		}else {
			$oldartist=$artist;
		}
	}else {
		if ((!defined $updateartist)||($updateartist eq "")) {
			print "\n * Artist nicht vorhanden in Image:".$tifffile."\n";
		}
	}

	$imagedesc=GetImageDesc($myfile);
	if ((defined $imagedesc)&&((!defined $updateimgdesc)||($updateimgdesc eq ""))) {
		if ((defined $oldimagedesc)&&($oldimagedesc ne $imagedesc)) {
			print "\n * Image Description  abweichend/falsch in Image:".$tifffile."\n";
		}else {
			$oldimagedesc=$imagedesc;
		}
	}else {
		if ((!defined $updateimgdesc)||($updateimgdesc eq "")) {
			print "\n * Image Description nicht vorhanden in Image:".$tifffile."\n";
		}
	}

	$myfile->delete();   # delete object and close file
}

# for (my $i=1;$i<$counter;$i++) {
foreach my $i (1..$counter-1) {
	if (!defined $pagearray[$i]){
		print "\n * Image ".$i." koennte fehlen \n";
	}
}

} else { # endif  check for names
	print "Dateinamen werde nicht geprueft";
}
print "\n\nund los geht's   -   ";
print "Fortschritt: \n";
($updateartist,$updatedocname,$updateimgdesc,$updateresolutionx,$updateresolutiony,$checkfornames)=ReadTiffWriterConf($basedir);
foreach my $tifffile (@tifffiles) {
	my $pagenumber=0;
	my $pagenumber_str=undef;
	my $fulldir=undef;
	my @tags=();
	my @tagvalues=();
	$fulldir=$basedir.$dirSep.$tifffile;
	
	
	if (($checkfornames eq "yes")||($checkfornames eq "true")) {
		$pagenumber=substr($tifffile,0,length($tifffile)-4);
	
		if (substr($pagenumber,0,1) ne "0") {
			next;
		}
	
		while(substr($pagenumber,0,1) eq "0"){
			$pagenumber=substr($pagenumber,1,length($pagenumber)-1); # delete the first zero
		} 
	#TODO: make this a helper function
		if ($pagenumber<10) {$pagenumber_str="|0000".$pagenumber."||";}
		elsif ($pagenumber<100) {$pagenumber_str="|000".$pagenumber."||";}
		elsif ($pagenumber<1000) {$pagenumber_str="|00".$pagenumber."||";}
		elsif ($pagenumber<10000) {$pagenumber_str="|".$pagenumber."||";}
	} elsif ($checkfornames eq "filename") {
		$pagenumber_str = $tifffile;
	} else {
		$pagenumber_str="";
	}

	print ".";

	# write tiff tags

	push(@tags,"271");
	push(@tagvalues,"Göttinger Digitalisierungszentrum (GDZ) ");
	push(@tags,"305");
	push(@tagvalues,"tiffwriter, Version 0.33, (c) GDZ/SUB 2002-2006, Markus Enders ");

	if ((defined $updateartist)&&($updateartist ne "")) {
		push(@tags,"315");
		push(@tagvalues,$updateartist);
	}
	if ((defined $updatedocname)&&($updatedocname ne "")) {
		push(@tags,"269");
		push(@tagvalues,$updatedocname);
	}
	if ((defined $updateimgdesc)&&($updateimgdesc ne "")) {
		push(@tags,"270");
		push(@tagvalues,$updateimgdesc);
	}
	if ((defined $updateresolutionx)&&($updateresolutionx ne "")) {
		push(@tags,"282");
		push(@tagvalues,$updateresolutionx);
	}
	if ((defined $updateresolutiony)&&($updateresolutiony ne "")) {
		push(@tags,"283");
		push(@tagvalues,$updateresolutiony);
	}

	WriteTags($fulldir,\@tags,\@tagvalues);

	ChangeTIFFHeader($fulldir,$pagenumber_str);			  # write page number
}


print "Geschafft!";

if ($silent eq "") {
	my $term = new Term::ReadLine 'exit';
	my $prompt = "\nZeilenschalter (Return) zum beenden druecken... ";
	$term->readline($prompt);
}

exit 0;

sub WriteTag{
	my ($myfile,$tag,$value)=@_;

	if (!defined $myfile) {
		print "Fehlendes TIFF-Object.....\n";
		return 0;
	}

	# write pagenumber (pagename)
	my $myTag=$myfile->GetTag($tag);
	if (!defined $myTag) {
		$myTag=$myfile->newTag();    # only if tag cannot be found add it.
		$myTag->ChangeType("2");
		$myTag->ChangeName($tag);
	}
	$myTag->ChangeValue($value);
	if ($myTag->Write()!=1){    # Fehler beim schreiben
		return 0;
	}
	return 1;
}

sub WriteTags{
	my ($fulldir,$tagsref,$tagvaluestef)=@_;
	my $myfile=GDZ::TIFFFile->new($fulldir);
	my $singletag=undef;
	my $value=undef;
	my $i=0;

	my @tags=@$tagsref;
	my @tagvalues=@$tagvaluestef;

	if (!defined $myfile) {
		print "Tiff-Datei konnte nicht geoeffnet werden: ".$fulldir."\n";
		return 0;
	}

	foreach $singletag(@tags) {
		my $myTag=$myfile->GetTag($singletag);
		if (!defined $myTag) {
			$myTag=$myfile->newTag();    # only if tag cannot be found add it.
			$myTag->ChangeType("2");
			$myTag->ChangeName($singletag);
		}
		$value=$tagvalues[$i];
		$myTag->ChangeValue($value);
		if ($myTag->Write()!=1){    # Fehler beim schreiben
			$myfile->delete(); #closes tiff file; deletes object 
			next;
		}
		$i++;
	}
	$myfile->delete(); #closes tiff file; deletes object
	return 1;
}

sub ChangeTIFFHeader{
	my ($fulldir,$pagenumber)=@_;

	my $myfile=GDZ::TIFFFile->new($fulldir);

	if (!defined $myfile) {
		print "Tiff-Datei konnte nicht geoeffnet werden: ".$fulldir."\n";
		return 0;
	}

	# write pagenumber (pagename)
	if ($pagenumber ne "") {
		my $myTag=$myfile->GetTag("285");
		if (!defined $myTag) {
			$myTag=$myfile->newTag();    # only if tag cannot be found add it.
			$myTag->ChangeType("2");
			$myTag->ChangeName("285");
		}
		$myTag->ChangeValue($pagenumber);
		if ($myTag->Write()!=1){    # Fehler beim schreiben
			$myfile->delete(); #closes tiff file; deletes object 
			return 0;
		}
	}

	$myfile->delete(); #closes tiff file; deletes object

    return 1;
}

sub ReadTiffWriterConf{
	my ($dir)=@_;
	my $replaceArtist="";
	my $replaceDocname="";
	my $replaceImageDesc="";
	my $replaceResolutionX="";
	my $replaceResolutionY="";
	my $checkfornames="";
	my @in=();


	if (substr($dir,length($dir),1) ne $dirSep) {
		$dir=$dir.$dirSep;
	}

	eval{
		open (CONF,"<".$dir."tiffwriter.conf")||die "No conf file";
	};
	if (@$) {
		print "No conf file found...\n";
		return undef;
	}
	@in=<CONF>;
	close CONF;

	foreach my $line (@in) {
		if (substr($line,0,1) eq "#") {
			next;  # next line, 
		}
		if (substr($line,0,7) eq "Artist=") {
			$replaceArtist=substr($line,7,length($line)-7);
		}
		if (substr($line,0,13) eq "Documentname=") {
			$replaceDocname=substr($line,13,length($line)-13);
		}
		if (substr($line,0,17) eq "ImageDescription=") {
			$replaceImageDesc=substr($line,17,length($line)-17);
		}
		if (substr($line,0,12) eq "ResolutionX=") {
			$replaceResolutionX=substr($line,12,length($line)-12);
		}
		if (substr($line,0,12) eq "ResolutionY=") {
			$replaceResolutionY=substr($line,12,length($line)-12);
		}
		if (substr($line,0,11) eq "CheckNames=") {
			$checkfornames=substr($line,11,length($line)-11);
		}
	}
	
	chomp ($replaceArtist);
	chomp ($replaceDocname);
	chomp ($replaceImageDesc);
	chomp ($replaceResolutionX);
	chomp ($replaceResolutionY);
	chomp ($checkfornames);

	if ($checkfornames eq "") {
		$checkfornames="yes";
	}
	if (($checkfornames ne "yes")&&($checkfornames ne "true")&&($checkfornames ne "filename")&&
	   ($checkfornames ne "no")&&($checkfornames ne "false")){
		print "Falscher Wert in tiffwriter.conf: CheckNames muss \"yes\" , \"no\" oder \"filename\"";
		print "sein.\n";
		print "Wird auf Default-Werk = \"yes\" zurueckgesetzt\n";
		$checkfornames="yes";
	}

	if ($replaceResolutionX ne "") {
		if ($replaceResolutionX =~ /^\d+$/) {
		} else {
			$replaceResolutionX="!!FEHLER!!";
		}
	}
	if ($replaceResolutionY ne "") {
		if ($replaceResolutionY =~ /^\d+$/) {
		} else {
			$replaceResolutionY="!!FEHLER!!";
		}
	}

	return ($replaceArtist,$replaceDocname,$replaceImageDesc,$replaceResolutionX,$replaceResolutionY,$checkfornames);
}
