#
# package GDZ::TIFFTag
# version 0.31, May. 2004
# (C) GDZ / Goettingen State and University Library
# Info/bugreports: enders\@mail.sub.uni-goettingen.de
#
#

package GDZ::TIFFTag;

use IO::File;

sub new{	# konstruktor
	my ($class,$filehandle,$byteorder)=@_;
	my $self={};

		$self->{'name'}=undef;    # just the code, not the real name
		$self->{'type'}=undef;	   # tagtype
		$self->{'count'}=undef;
		$self->{'offset'}=undef;
		$self->{'value'}=undef;     # pointer to an array
		$self->{'IFDentry'}=undef;	# store position of pointer
		$self->{'IFD'}=undef;
		$self->{'TIFFILE'}=undef;   # reference of (pointer to) TIFF file object
		$self->{'filehandle'}=$filehandle;
		$self->{'byteorder'}=$byteorder;

	bless($self,$class);
	return $self;
}

#
# GetValue
# returns the first value from the array as a string
#
sub GetValue{
	my ($self)=@_;
	my @allValues=();
	#$self->PrintInfo();
	if (defined $self->{'value'}) {
		@allValues=@{$self->{'value'}};
		return $allValues[0];
	}

}

#
# Sets a new value of the Tag
#
# string is the only parameter

sub SetValue{
	my ($self,$newValue)=@_;
	my @allValues=();

#print "DEBUG: SetValue:  value:".$newValue."\n";
	push(@allValues,$newValue);
	$self->{'value'}=\@allValues;
	return;
}

sub PrintInfo{
	my ($self)=@_;
	my $myvalue=undef;

	print "Tagname:".$self->{'name'}."\n";
	print "Typ:    ".$self->{'type'}."\n";
	print "Count:  ".$self->{'count'}."\n";
	print "Offset: ".$self->{'offset'}."\n";	
	print "IFDEnt: ".$self->{'IFDentry'}."\n";
	
	foreach $myvalue (@{$self->{'value'}}) {
		print "Value:  ".$myvalue."<\n";
	}
	
}

sub ChangeValue{
	my ($self,$newvalue)=@_;
	$self->{'updated'}=1;
	$self->SetValue($newvalue);

	return 1;
}

sub ChangeType{
	my ($self,$newtype)=@_;

	$self->{'updated'}=1;
	$self->{'type'}=$newtype;

	return 1;
}

sub ChangeName{
	my ($self,$newname)=@_;

	$self->{'updated'}=1;
	$self->{'name'}=$newname;

	return 1;
}

sub ReadValue{
	my ($self)=@_;
	my $bytelength=0;  # stores information how many bytes one value needs
	my $bytes_to_read=0;
	my $bytesread=0;
	my @value=();
	my $value_from_offset=0;
	my $value_read=undef;
	my $packstring=undef;  # string containing information how to unpack binary value

	# check, if value would fit into the offset field or if offset is really an offset

	if ($self->{'type'}==1) {$bytelength=1;}
	if ($self->{'type'}==2) {$bytelength=1;}
	if ($self->{'type'}==3) {$bytelength=2;}    # SHORT 2 BYTE
	if ($self->{'type'}==4) {$bytelength=4;}    # LONG 4 BYTE
	if ($self->{'type'}==5) {$bytelength=8;}    # RATIONAL; 2 LONG values
	if ($self->{'type'}==6) {$bytelength=1;}
	if ($self->{'type'}==7) {$bytelength=1;}
	if ($self->{'type'}==8) {$bytelength=2;}
	if ($self->{'type'}==9) {$bytelength=4;}
	if ($self->{'type'}==10) {$bytelength=8;}
	if ($self->{'type'}==11) {$bytelength=4;}
	if ($self->{'type'}==12) {$bytelength=8;}

	if (($bytelength*$self->{'count'})<=4) {
		# value fits into offset; so the value is offset
		$value_read=$self->{'offset'};
		if ($self->{'byteorder'}eq "m") {        # pack value again, cause we'll unpack it later
			$value_read=pack('N',$value_read);
		} else {
			$value_read=pack('V',$value_read);
		}
		$value_from_offset=1;
		#print "DEBUG: value is stored in offset...\n";

	} else {

		if (sysseek($self->{'filehandle'},$self->{'offset'},0)==-1) {
			# could to sysseek filepointer :-(
			print "DEBUG: Can't sysseek... (getting tag: ".$self->{'name'}.") - offset:".$self->{'offset'}."\n";
			return 0;
		}

		$bytes_to_read=$self->{'count'}*$bytelength;
		
        if ($self->{'type'}==2) {$bytes_to_read=$bytes_to_read-1;}	# count contains number of chars including NUL

		$bytesread=sysread($self->{'filehandle'},$value_read,$bytes_to_read); # read 8 bytes
		if ($bytesread!=$bytes_to_read) {
				print "DEBUG (830): Nothing read...\n";
				return 0;
		}  # less than 4 bytes have been read :-(
	}

	if (($self->{'type'}==2)||($self->{'type'}==1)) {
		@value=$value_read;
	}

	if (($self->{'type'}==3)&&($self->{'byteorder'} eq "i")) {   # ungeprueft
		$packstring='v'.$self->{'count'};
		if ($value_from_offset==1) {
			$value_read=substr($value_read,0,(2*$self->{'count'}));   # if it's from offset just read the left two bytes
		}
		@value=unpack($packstring,$value_read);
	}

	if (($self->{'type'}==3)&&($self->{'byteorder'} eq "m")) {   # ungeprueft
		$packstring='n'.$self->{'count'};
		if ($value_from_offset==1) {
			$value_read=substr($value_read,0,(2*$self->{'count'}));   # if it's from offset just read the left two bytes
		}
		@value=unpack($packstring,$value_read);
	}

    # handle LONG values
	if (($self->{'type'}==4)&&($self->{'byteorder'} eq "i")) {   # ungeprueft
		$packstring='V'.$self->{'count'};
		@value=unpack($packstring,$value_read);
	}


	if (($self->{'type'}==4)&&($self->{'byteorder'} eq "m")) {   # ungeprueft
		$packstring='N'.$self->{'count'};
		@value=unpack($packstring,$value_read);
	}

    # handle RATIONAL values
	if (($self->{'type'}==5)&&($self->{'byteorder'} eq "i")) {
	    # first long is numerator
		# second long is denumerator
		$packstring="V".($self->{'count'}*2);
		@value=unpack($packstring,$value_read);
	}

	if (($self->{'type'}==5)&&($self->{'byteorder'} eq "m")) {
		$packstring='N'.($self->{'count'}*2);
		@value=unpack($packstring,$value_read);
	}
	
	$self->{'value'}=\@value;
	#print "DEBUG: ReadValue:  value:".$value[0]."\n";
}


#
# WriteValue: String must still be packed; e.g. if writing a SHORT, it already
# must be packed with "n" or "v" depending if it's a motorola or intel byte order.
#
# Only ASCII (type 2) is modified, when the value does not have a NULLbyte at the end.
#

sub Write{
	my ($self)=@_;
	my $bytelength=undef;
	my $newoffset=-1;
	my $newcount=0;
	my $byteswritten=undef;

	my $nextifdoffset=undef;
	my $numofentries=undef;
	my $ifdentry=undef;
	my $newoffset_toIFD=undef;

	my $firstpointer=0;			# pointer to the first IFD
	my $lastpointerposition=0;	# pointer to the offset field in the last IFD

	my $newvalue;
	my @writestrings=@{$self->{'value'}};
	my $writestring=$writestrings[0];

	if ($self->{'updated'}!=1) {  # nothing changed, so write nothing
		return;
	}

	if ($self->{'type'}==1) {$bytelength=1;}
	if ($self->{'type'}==2) {$bytelength=1;}
	if ($self->{'type'}==3) {$bytelength=2;}
	if ($self->{'type'}==4) {$bytelength=4;}  # LONG
	if ($self->{'type'}==5) {$bytelength=8;}  # RATIONAL
	if ($self->{'type'}==6) {$bytelength=1;}
	if ($self->{'type'}==7) {$bytelength=1;}
	if ($self->{'type'}==8) {$bytelength=2;}
	if ($self->{'type'}==9) {$bytelength=4;}
	if ($self->{'type'}==10) {$bytelength=8;}
	if ($self->{'type'}==11) {$bytelength=4;}
	if ($self->{'type'}==12) {$bytelength=8;}

	if ($self->{'type'}==2) {		
		if (substr($writestring,length($writestring),1) ne "\0" ) {
			$writestring=$writestring."\0";   # add null byte if it's not avaliable
		}
		$newvalue=$writestring;
	}

	if ($self->{'type'}==5) {
		
		if ($writestring =~ /^\d+$/) {
			# print "Zahl" ;
		} else {
			print "keine Zahl" ;
			return 0;
		}

		my $numberoflongs=length($writestring)/2;
		$numberoflongs=int($numberoflongs + .5);

		#if ((length($writestring)%2)>0) {     # ungerade zahl; add one
		#	$numberoflongs++;
		#}

		if ($self->{'byteorder'} eq "i") {

			# first long value is the numerator
			# the second on is the denumerator (MUST NOT BE ZERO)
			# this is valid for both Intel and Motorola byte order

			$newvalue=pack("V".($numberoflongs*2),$writestring,1);
		} else {
			$newvalue=pack("N".($numberoflongs*2),$writestring,1);	
		}
	}

	if ($self->{'type'}==4) {
		if ($self->{'byteorder'} eq "i") {
			$newvalue=pack("V",$writestring);
		} else {
			$newvalue=pack("N",$writestring);	
		}
	}

	if ($self->{'type'}==3) {
		if ($self->{'byteorder'} eq "i") {
			$newvalue=pack("v",$writestring);
		} else {
			$newvalue=pack("n",$writestring);	
		}
	}

	# check, if tag is already available

	if (defined $self->{'IFDentry'}) { 		# tag is already available; must be overwritten
		$newcount=$self->CalculateCount();
		if ($newcount>$self->{'count'}) {   # is longer then old value; text can't be overwritten
			#print "DEBUG: Entry can't be overwritten....(".$self->{'name'}."\n";
			$newoffset=sysseek($self->{'filehandle'}, 1, 2);   # jump to end of file (plus one)

			if ($newoffset==-1) {
				# could to sysseek filepointer :-(
				print "DEBUG: Can't sysseek... (getting tag: ".$self->{'name'}.") - offset:".$self->{'offset'}."\n";
				return 0;
			}
			#print "DEBUG: write value at:".$newoffset."\n";

			syswrite($self->{'filehandle'},$newvalue); # write to the end
			# update pointer in IFD
			$self->{'offset'}=$newoffset;
			$self->{'count'}=$newcount;
			
			#$self->WriteIFDEntry();			# update offset inIFD entry

		}else {	# overwrite old value, cause new value is shorter than old value
			
			$newcount=$self->CalculateCount();
			#print "DEBUG: Overwrite old entry at: ".$self->{'offset'}."      (".$self->{'name'}.")\n";
			#print "new value:".$newvalue."<\n";
			#print "old count:".$self->{'count'}."\n";
			#print "new count:".$newcount."\n";
			if (sysseek($self->{'filehandle'},$self->{'offset'},0)==-1) {
				# could to sysseek filepointer :-(
				print "DEBUG: Can't sysseek... (getting tag: ".$self->{'name'}.") - offset:".$self->{'offset'}."\n";
				return 0;
			}
			
			#$byteswritten=syswrite($self->{'filehandle'},$newvalue,$newcount);   # write to disk
			my $writebytes=$newcount*$bytelength;   # calculate the number of bytes to be written...
			$byteswritten=syswrite($self->{'filehandle'},$newvalue,$writebytes);   # write to disk

			if (!defined $byteswritten) {
				print "DEBUG: Error occured; can't write :-(\n";
			}
			$self->{'value'}=$newvalue;
			$self->{'count'}=$newcount;
			#$self->WriteIFDEntry();			# update offset inIFD entry
		}
		

	} else {
		#
		
		# print "DEBUG: Tag isn't available... new IFD entry....  (".$self->{'name'}.")\n";
		# tag is not available
		#
		# add tag; write new IFD and change pointer from last IFD to this IFD
		#

		# check if contents must be written separatly or if contents is small enough, though it can be written in the offset field of the IFDEntry

		if (length($newvalue)>4) {

			# write contents to end of file, but only if it's longer than four bytes
			$newoffset=sysseek($self->{'filehandle'}, 1, 2);   # jump to end of file
			if ($newoffset==-1) {
					# could to sysseek filepointer :-(
					print "DEBUG: Can't sysseek... (getting tag: ".$self->{'name'}.") - offset:".$self->{'offset'}."\n";
					return 0;
			}
			syswrite($self->{'filehandle'},$newvalue); # write to the end
		} else {
			# contents can be written as offset (less then 4 bytes)
			$newoffset=$newvalue;
		}

		$self->{'offset'}=$newoffset;  # pointer to tag value
		$self->{'count'}=$self->CalculateCount();
	}

	my $tiffile=${$self->{'TIFFILE'}};
	$tiffile->{'updated'}=1;         # update tifffile when closing, cause tags has changed

	return 1;
}

sub WriteIFDEntry{
	my ($self)=@_;
	my $entry=undef;

	if ((!defined $self->{'IFDentry'})||($self->{'IFDentry'}==0)) {
		print "DEBUG: No value for IFDentry set :-(\n";
		return 0;
	}

	if (sysseek($self->{'filehandle'},$self->{'IFDentry'},0)==-1) {
		# could to sysseek filepointer :-(
		print "DEBUG: Can't sysseek... (getting tag: ".$self->{'name'}.") - offset:".$self->{'offset'}."\n";
		return 0;
	}

	#print "DEBUG: WriteIFDEntry: update IFDEntry at:".$self->{'IFDentry'}."\n";
	#print "       contents:   name:  ".$self->{'name'}."\n";
	#print "       contents:   type:  ".$self->{'type'}."\n";
	#print "       contents:   count: ".$self->{'count'}."\n";
	#print "       contents:   offset:".$self->{'offset'}."\n";

	# build entry
	if ($self->{'byteorder'} eq "i") {
		$entry=pack('vvVV',($self->{'name'},$self->{'type'},$self->{'count'},$self->{'offset'}));
	}
	if ($self->{'byteorder'} eq "m") {
		$entry=pack('nnNN',($self->{'name'},$self->{'type'},$self->{'count'},$self->{'offset'}));
	}
	#print "DEBUG: WriteIFDEntry entry: ".unpack('vvVV',$entry)." >".$entry."<\n";
	syswrite($self->{'filehandle'},$entry,12); # write to the end

	return 1;
}


sub CalculateCount{
	my ($self)=@_;
	my $newcount=0;
	my $bytelength=0;
	my $mod=0;
	my $maxvalue_foroneentity=0;
	my $rest_writestring=0;

	if ($self->{'type'}==1) {$bytelength=1;}
	if ($self->{'type'}==2) {$bytelength=1;}
	if ($self->{'type'}==3) {$bytelength=2;}
	if ($self->{'type'}==4) {$bytelength=4;} # LONG
	if ($self->{'type'}==5) {$bytelength=8;} # RATIONAL
	if ($self->{'type'}==6) {$bytelength=1;}
	if ($self->{'type'}==7) {$bytelength=1;}
	if ($self->{'type'}==8) {$bytelength=2;}
	if ($self->{'type'}==9) {$bytelength=4;}
	if ($self->{'type'}==10) {$bytelength=8;}
	if ($self->{'type'}==11) {$bytelength=4;}
	if ($self->{'type'}==12) {$bytelength=8;}

	#print "DEBUG: bytelength:".$bytelength." - type:".$self->{'type'}."\n";
	my @writestrings=@{$self->{'value'}};
	my $writestring=$writestrings[0];
    
	# get length
	if ($self->{'type'}==2) {   # ascii
		$mod=length($writestring)%$bytelength;
		$newcount=(length($writestring)+$mod)/$bytelength;
	} else {        # for all numbers (short, long, rational etc...
		$maxvalue_foroneentity=(2**8)**$bytelength;   # enthält den maximalen Zahlenwert, der mit einem Count dargestellt werden kann
		$rest_writestring=$writestring;
		$newcount=1;                    # at least one count is available
		while($rest_writestring>$maxvalue_foroneentity){
			$newcount++;
			$rest_writestring=$rest_writestring-$maxvalue_foroneentity;
		}
	}
	
	#print "DEBUG: \n       Writestring:".$writestring."<\n       Calcualted new count:".$newcount." - length:".length($writestring)." - mod:".$mod."\n";

	return $newcount;
}


return 1;