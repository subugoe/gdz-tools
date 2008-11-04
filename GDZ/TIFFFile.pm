#
# package GDZ::TIFFFile
# version 0.34, May. 2007
# (C) GDZ / Goettingen State and University Library
# Info/bugreports: enders@mail.sub.uni-goettingen.de
# Some Portions by Bernd Fallert
#


package GDZ::TIFFFile;


STDOUT->autoflush(1);
use IO::File;

sub new{	# konstruktor
	my ($class,$filename)=@_;
	my $self={};
	my $retval=undef;
	my $file=undef;

	eval{
		open ($file,"+<".$filename)||die "Can't open file ".$filename;
	};

	#print "\n\nDEBUG: new: open tiff file\n";

	binmode $file;
	$self->{'filehandle'}=$file;
	$self->{'filename'}=$filename;
	$self->{'ifh'}=undef;
	$self->{'byteorder'}=undef;   # byteorder of file: i for intel or m for motorola
	$self->{'allMyTagsPointer'}=undef;
	$self->{'updated'}=0;

	bless($self,$class);
	$retval=$self->ReadImageFileHeader();
	if ($retval==0) {
		print "DEBUG: No TIFF file (".$filename.") ...\n";
		return undef;
	}
	return $self;
}

sub delete{
	my ($self)=@_;

	if ($self->{'updated'}==1) {
		$self->WriteIFD();        # update IFD
	}

	#print "DEBUG: delete: close tiff file\n";

	$self->{'filehandle'}->close();
}

sub DESTROY{
	my ($self)=@_;

	if ($self->{'updated'}==1) {
		$self->WriteIFD();        # update IFD
	}

	#print "DEBUG: delete: close tiff file\n";

	$self->{'filehandle'}->close();
}



sub ReadImageFileHeader{
	my ($self)=@_;
	my $ifh=undef;
	my $bytesread=0;
	my $unpackediffsetifd=undef;

	# set file pointer to file begin
	if (sysseek($self->{'filehandle'},0,0)==-1) {
		# could to sysseek filepointer :-(
		print "DEBUG: Can't sysseek...\n";
		return 0;
	}

	$bytesread=sysread($self->{'filehandle'},$ifh,8); # read 8 bytes
	if ($bytesread!=8) {
		print "DEBUG: (492) Nothing read...(less than 8 bytes for ifh had been read\n";
		return 0;
	}  # less than 8 bytes have been read :-(
	
	# parse ifh
	if (substr($ifh,0,2) eq "II") {
		$self->{'byteorder'}="i";
		#print "DEBUG: IntelByteOrder...\n";
	} elsif (substr($ifh,0,2) eq "MM") {
		$self->{'byteorder'}="m";
		#print "DEBUG: MotByteorder...\n";
	} else {
		print "DEBUG: Unknown Byte order...\n";
		return 0;		# unknown byteorder - probably not a TIFF file
	}

	my ($packedbyteorder1,$packedbyteorder2)=unpack('cc',substr($ifh,2,2));
	#print "DEBUG: pborder:".$packedbyteorder1."<>".$packedbyteorder1."<\n";
	if (($self->{'byteorder'} eq "m" )&&($packedbyteorder2 ne "42")) {return 0;} # not a TIFF file
	if (($self->{'byteorder'} eq "i" )&&($packedbyteorder1 ne "42")) {return 0;} # not a TIFF file

	my $offsetifd=substr($ifh,4,4);

	if ($self->{'byteorder'} eq "m" ) {
		$offsetifd=unpack('N',$offsetifd);
		#$offsetifd=substr($ifh,7,1).substr($ifh,6,1).substr($ifh,5,1).substr($ifh,4,1);
	} else {
		$offsetifd=unpack('V',$offsetifd);
	}

	#my $unpackediffsetifd=unpack('L',$offsetifd); # just works for intel - what happens with motorola?
	my $unpackediffsetifd=$offsetifd;

	#print "DEBUG: offset to first ifd:".$offsetifd." - ".$unpackediffsetifd."<\n";

	$self->ReadIFD($unpackediffsetifd);

	return 1;
}

sub ReadIFD{
	my ($self,$ifd_offset)=@_;
	my $numberofentries=0;
	my $bytesread=0;
	my $nextifd_offset="";
	my $nextifd_offset_unpack=undef;
	my $myTag=undef;   # TIFFTag object representing a single Tag
	my $tagname=undef;
	my $tagoffset=undef;
	my $tagcount=undef;
	my $tagtype=undef;
	my @allMyTags=();
	
	my ($tagnameM,$tagtypeM,$tagcountM,$tagoffsetM)=();
	my ($tagnameI,$tagtypeI,$tagcountI,$tagoffsetI)=();

	if (defined $self->{'allMyTagsPointer'}) {
		@allMyTags=@{$self->{'allMyTagsPointer'}};
	}

	if (sysseek($self->{'filehandle'},$ifd_offset,0)==-1) {
		# could to sysseek filepointer :-(
		print "DEBUG: Can't sysseek...\n";
		return 0;
	}
   
	$bytesread=sysread($self->{'filehandle'},$numberofentries,2); # read 8 bytes
	
	if ($bytesread!=2) {
		print "DEBUG: (559) Nothing read...(number of entries) \n";
		return 0;
	}  # less than 2 bytes have been read :-(
	
	if ($self->{'byteorder'} eq "m") {
		$numberofentries=unpack('n',$numberofentries);
    }else {
		$numberofentries=unpack('v',$numberofentries);
	}

	#print "DEBUG:ReadIFD: number of entries:".$numberofentries."\n";

  my %TagsSchonGelesen = ();


	#
	# read all entries
	#
	# for (my $i=0;$i<$numberofentries;$i++) {
	foreach my $i (0..$numberofentries-1) {
		my $IFDentry=undef;
		if (sysseek($self->{'filehandle'},($ifd_offset+2)+($i*12),0)==-1) {
			# could to sysseek filepointer :-(
			print "DEBUG: Can't sysseek... - ".$i." entry in IFD\n";
			return 0;
		}
		$bytesread=sysread($self->{'filehandle'},$IFDentry,12); # read 8 bytes
		if ($bytesread!=12) {
			print "DEBUG: (583) Nothing read...\n";
			return 0;
		}  # less than 12 bytes have been read :-(

		# parse IFD entry;
		if ($self->{'byteorder'} eq 'i') {
			($tagname,$tagtype,$tagcount,$tagoffset)=unpack('vvVV',$IFDentry);
		} else {
			($tagname,$tagtype,$tagcount,$tagoffset)=unpack('nnNN',$IFDentry);
		}

		($tagnameM,$tagtypeM,$tagcountM,$tagoffsetM)=unpack('nnNN',$IFDentry);
		($tagnameI,$tagtypeI,$tagcountI,$tagoffsetI)=unpack('vvVV',$IFDentry);


        # Anpassung wg. doppelt vergebenen Feldern!
        # Alle $tagname werden gezählt, es darf keiner mehr als 1 Mal vorkommen
        # Wenn er mehr als einmal vorkommt wird er nicht uebernommen
        # Bernd Fallert
        $TagsSchonGelesen{ $tagname }++;

        if ($TagsSchonGelesen{ $tagname } > 1) 
        {
            # Nur fuer Test einschalten
            #print "$tagname ist schon gelesen worden\n";
        };


		$myTag=GDZ::TIFFTag->new($self->{'filehandle'},$self->{'byteorder'});
		$myTag->{'name'}=$tagname;    # just the code, not the real name
		$myTag->{'type'}=$tagtype;	  # tagtype
		$myTag->{'count'}=$tagcount;
		$myTag->{'offset'}=$tagoffset;
		$myTag->{'value'}=undef;
		$myTag->{'IFDentry'}=($ifd_offset+2)+($i*12);	# store position of pointer
		$myTag->{'IFD'}=$ifd_offset;		# store position of IDF itself
		$myTag->{'TIFFILE'}=\$self;			# store pointer to this object in Tag object

		$myTag->ReadValue();
		#$myTag->PrintInfo();


    # wg. doppelt vergebenen tagname nur die nur einmal vorkommenden Tagnamen uebernehmen
    # Bernd Fallert
    if ($TagsSchonGelesen{ $tagname } > 1) 
    {
        # Nicht uebernehmen ist doppelt vorhanden
    }
    else
    {
        # Alles in Ordnung, das war das normale Verhalten



			push(@allMyTags,$myTag);		# add tag to all tags
	
			$self->{'allMyTagsPointer'}=\@allMyTags;
	
		};

	}
	
	#print "DEBUG: number of entries read:".$#allMyTags."\n";

	# get next IFD
	if (sysseek($self->{'filehandle'},($ifd_offset+2)+($numberofentries*12),0)==-1) {
		# could to sysseek filepointer :-(
		print "DEBUG: Can't sysseek...\n";
		return 0;
	}
	$bytesread=sysread($self->{'filehandle'},$nextifd_offset,4); # read 8 bytes
	if ($bytesread!=4) {
			print "DEBUG: (625) Nothing read...\n";
			return 0;
	}  # less than 4 bytes have been read :-(

	if ($self->{'byteorder'} eq "m" ) {
		$nextifd_offset_unpack=unpack('N',$nextifd_offset);
	}else {
		$nextifd_offset_unpack=unpack('V',$nextifd_offset);
	}

	#print "DEBUG: Next IFD at:".$nextifd_offset_unpack."<\n";
	if (($nextifd_offset_unpack eq "0")||(!defined $nextifd_offset_unpack)) {
		#print "DEBUG: No next IFD...\n";
	} else {
		$self->ReadIFD($nextifd_offset_unpack);
	}
}



#
# Writes Image File directory
#

sub WriteIFD{
	my ($self,$ifd_offset)=@_;
	my @entries=@{$self->{'allMyTagsPointer'}};
	my %entryhash=undef;
	my @sortedentries=undef;
	my @allsorted=();
	my $numberofentries=$#entries+1;
	my $numberofentries_towrite=0;

	my $newifdoffset=0;
	my $oldifdoffset=0;
	my $byteswritten=0;
	my $firstifdoffset=0;
	my $nextifdoffset=0;
	my $i=0;
	my $allsortedref=undef;

	# write number of entries
	#
	$newifdoffset=sysseek($self->{'filehandle'}, 0, 2);   # to end of file

	#print "DEBUG: WriteIFD: Number of entries: ".$numberofentries."\n";

	if ($self->{'byteorder'} eq "m") {
		$numberofentries_towrite=pack('n',$numberofentries);
   }else {
		$numberofentries_towrite=pack('v',$numberofentries);
	}

	$byteswritten=syswrite($self->{'filehandle'},$numberofentries_towrite,2); # write 2 bytes
	
	if ($byteswritten!=2) {
		print "DEBUG: (673) Nothing read...(number of entries) \n";
		return 0;
	}  # less than 2 bytes have been written :-(

	# sort entries (lowest tag number first
	$allsortedref=$self->sortTags(\@entries);
	@allsorted=@$allsortedref;

	# write entries (in foreach loop)
	#
	$i=0;
	foreach $singleentry (@allsorted) {	
		my $IFDentry=undef;
		$singleentry->{'IFDentry'}=($newifdoffset+2)+($i*12);
		#$singleentry->PrintInfo();
		$singleentry->WriteIFDEntry();
		$i++;
	}

	# write pointer to next entry (set to zero)
	if(sysseek($self->{'filehandle'}, ($newifdoffset+2)+($numberofentries*12), 0)==-1){   # to end of file
		# could not to sysseek filepointer :-(
		print "DEBUG: Can't sysseek... \n";
		return 0;
	}
	$nextifdoffset=0;
	if ($self->{'byteorder'} eq 'i') {   # write offset to next ifd (there is no next IFD)
		$nextifdoffset=pack('V',$nextifdoffset);
	} else {
		$nextifdoffset=pack('N',$nextifdoffset);
	}
	syswrite($self->{'filehandle'},$nextifdoffset,4);

	# write offset to first IFD
	if(sysseek($self->{'filehandle'}, 4, 0)==-1){   # to 4th byte in file
		print "DEBUG: Can't sysseek... \n";
		return 0;
	}
	
	if ($self->{'byteorder'} eq 'i') {   # write offset to first ifd
		$firstifdoffset=pack('V',$newifdoffset);
	} else {
		$firstifdoffset=pack('N',$newifdoffset);
	}
	syswrite($self->{'filehandle'},$firstifdoffset,4);


	# delete information about old IFD
	$self->{'updated'} = 0;
}

sub sortTags{
	my ($self,$taglistref)=@_;
	my @tags=@$taglistref;
	my @sortedlist=();
	my $inserted;
	my $newtag=undef;

	foreach my $singletag (@tags) {
		my $i=0;
		my $inserted=0;
		foreach $newtag (@sortedlist) {
		    #print "    DEBUG: checking with:".$newtag->{'name'}."\n";
			if ($singletag->{'name'}<$newtag->{'name'}) { # insert it here
				my $x=$#sortedlist;
				#for($x=$#sortedlist;$x+1>$i;$x--){
				my @temp=splice(@sortedlist,$i,$#sortedlist-$i+1);    # get array with elements, which has to be moved
				splice(@sortedlist,$i,1,$singletag);	
				splice(@sortedlist,$#sortedlist+1,0,@temp);

				$inserted=1;
				last;  # out of foreach loop, check next tag
			}
			$i++;
		}
		if ($inserted==0) {
			splice(@sortedlist,$#sortedlist+1,1,$singletag);  # add tag to end of sorted list
		}
	}

	return \@sortedlist;
}

sub GetAllTags{
	my ($self)=@_;
	return $self->{'allMyTagsPointer'};
}

sub GetTag{
	my ($self,$tagname)=@_;
    if (!defined $self->{'allMyTagsPointer'} ) {
		return undef;
    }
	my @allmytags=@{$self->{'allMyTagsPointer'}};
	my $tag=undef;

	foreach $tag (@allmytags) {
	   if ($tag->{'name'} eq $tagname) {
	   return $tag;
	   }
	}
	return undef;
}

sub newTag{
	my ($self)=@_;	
	my $newTag=GDZ::TIFFTag->new($self->{'filehandle'},$self->{'byteorder'});
	my @allmytags=();
	
	$newTag->{'TIFFILE'}=\$self;
	if (defined $self->{'allMyTagsPointer'}) {
		@allmytags=@{$self->{'allMyTagsPointer'}};
	}
	
	push(@allmytags,$newTag);
	$self->{'allMyTagsPointer'}=\@allmytags;
	$self->{'updated'}=1;			# tiff file was updated
	return $newTag;
}


return 1;