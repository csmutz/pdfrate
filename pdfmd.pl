#!/usr/bin/perl

#pdfmd--pdf metadata/structure extraction tool with focus on simplicity
#Copyright Charles Smutz, csmutz@gmu.edu, 2011

use strict;
use Digest::MD5 qw(md5_hex);

my $filename;
my $contents;

my $pos;
my $name;
my $value;
my $value2;
my $value3;
my $value4;
my $out_value;
my $raw_match;

my $last_pdfid0 = "";

my $width;
my $height;
my $desc;

my $medium_output = 0;
my $extended_output = 0;
my $hash_output = 0;
my $hex_output = 0;

my $max_value_length = 200;
my $max_value_length_hex = $max_value_length * 2;

foreach $filename (@ARGV)
{
    #print("$filename:\n");
    
    if ($filename eq "-m")
    {
        $medium_output = 1;
        next;
    }

    if ($filename eq "-x")
    {
	$extended_output = 1;
	next;
    }
    
    if ($filename eq "-y")
    {
	$hash_output = 1;
	next;
    }
    
    if ($filename eq "-z")
    {
	$hex_output = 1;
	next;
    }
    
    open (FILE, $filename) or die "Can't open $filename: $!\n";
    $contents = do { local $/;  <FILE> };
    close (FILE);
    
    #print filename for multiple files
    $pos = sprintf("%08X", 0);
    $name = "Filename";
    $value = $filename;
    #filter unprintables
    $value =~ s/[^[:print:]]/\./g;
    $value =~ s/[\r\n\t]/ /g;
    output($pos,$name,$value);
    
    $pos = sprintf("%08X", 0);
    $name = "Size";
    $value = -s $filename;
    output($pos,$name,$value);
    
    
    
    #extract the PDF header(s)
    while ($contents =~ m/(%PDF-\S+|%\!PS-Adobe-\S+)/sg )
    {
	$pos = sprintf("%08X", $-[0]);
	$raw_match = substr($contents,$-[0],($+[0] - $-[0]));
        $name = "Header";
        $value = $1;
	$value =~ s/[^[:print:]]/\./g;
        $value =~ s/[\r\n\t]/ /g;
        output($pos,$name,$value,$raw_match);
	
    }
    
   
    #classic /Metadata
    while ($contents =~ m/\/(F|ModDate|CreationDate|Title|Creator|Author|Producer|Company|Subject|Keywords|URL|URI|Lang)\s?\(((?:[^\)]|(?:(?<=\\))\)){0,$max_value_length})\)/sg )
    {
        $pos = sprintf("%08X", $-[0]);
        $raw_match = substr($contents,$-[0],($+[0] - $-[0]));
        $name = $1;
        $value = $2;
        #deal with escaped parens
        $value =~ s/\\\(/\(/g;
        $value =~ s/\\\)/\)/g;
        $value =~ s/\\\\/\\/g;
        #filter unprintables
        $value =~ s/[^[:print:]]/\./g;
        $value =~ s/[\r\n\t]/ /g;
        
	if ($name eq "F")
	{
		$name = "File";
	}

	#print($pos." ".sprintf("%16s",$name).": ".$value."\n");
        output($pos,$name,$value,$raw_match);
    }
    
    #hex /Metadata
    while ($contents =~ m/\/(ModDate|CreationDate|Title|Creator|Author|Producer|Company|Subject|Keywords|URL|URI|Lang)\s?\<(?:FEFF)?([^\>]{0,$max_value_length_hex})\>/sg )
    {
        $pos = sprintf("%08X", $-[0]);
        $raw_match = substr($contents,$-[0],($+[0] - $-[0]));
        $name = $1;
        $value = pack("H*",$2);
        #deal with escaped parens
        $value =~ s/\\\(/\(/g;
        $value =~ s/\\\)/\)/g;
        $value =~ s/\\\\/\\/g;
        #filter unprintables
        $value =~ s/[^[:print:]]/\./g;
        $value =~ s/[\r\n\t]/ /g;
        #print($pos." ".sprintf("%16s",$name).": ".$value."\n");
        output($pos,$name,$value,$raw_match);
    }
    
    #xml <pdf:Metadata>
    while ($contents =~ m/\<(?:pdf|xmp|xap|pdfx|xapMM|xmpMM):(ModifyDate|CreateDate|MetadataDate|Title|CreatorTool|Author|Producer|Company|Subject|Keywords|URL|URI|DocumentID|InstanceID|Lang)\>(.{0,$max_value_length})\<\/(?:pdf|xmp|xap|pdfx|xapMM|xmpMM):\1\>/sg )
    {
        $pos = sprintf("%08X", $-[0]);
        $raw_match = substr($contents,$-[0],($+[0] - $-[0]));
        $name = $1;
        $value = $2;
        #TODO: normalize date?
        #comment this if you don't want it.
        if ( $name =~ m/[Dd]ate$/ )
        {
           #this 2009-12-22T11:36:33+08:00 needs to become D:20090708105346+08'00'
           #intentionally don't touch the punctuation around the timezone because this is done nilly willy all over
           $value =~ s/^([0-9]{4})-([0-9]{2})-([0-9]{2})T([0-9]{2}):([0-9]{2}):([0-9]{2})/D:\1\2\3\4\5\6/; 
        }
        #filter unprintables
        $value =~ s/[^[:print:]]/\./g;
        $value =~ s/[\r\n\t]/ /g;
	#filer uuid:
	$value =~ s/^uuid://g;
	$value =~ s/^xmp\.[di]id://g;
        #print($pos." ".sprintf("%16s",$name).": ".$value."\n");
        output($pos,$name,$value,$raw_match);
    }
    
    
    #metadata as objects in PDF
    
    #00000e70  6e 64 6f 62 6a 0a 31 32  20 30 20 6f 62 6a 0a 28  |ndobj.12 0 obj.(|
    #00000e80  55 70 64 61 74 65 73 2d  58 58 58 29 0a 65 6e 64  |hello world).end|
    #...
    #00000f20  6a 0a 3c 3c 20 2f 54 69  74 6c 65 20 31 32 20 30  |j.<< /Title 12 0|
    #00000f30  20 52 20 2f 50 72 6f 64  75 63 65 72 20 31 33 20  | R /Producer 13 |
    
    while ($contents =~ m/\/(F|ModDate|CreationDate|Title|Creator|Author|Producer|Company|Subject|Keywords|URL|URI|Lang)[ \n]([0-9]+[ \n][0-9]+)[ \n]R/sg )
    {
        $name = $1;
        $pos = $2;
        #print("-$1 $2\n");
        
        #if ( $contents =~ m/$pos obj\.\((.{0,$max_value_length})\)\.endobj/ 
        if ( $contents =~ m/$pos[ \n]obj[ \n]\(((?:[^\)]|(?:(?<=\\))\)){0,$max_value_length})\)[ \n]endobj/s )
        {
            $value = $1;
            #print("$name: $value\n");
            $pos = sprintf("%08X", $-[0]);
            $raw_match = substr($contents,$-[0],($+[0] - $-[0]));
            
            #deal with escaped parens
            $value =~ s/\\\(/\(/g;
            $value =~ s/\\\)/\)/g;
            $value =~ s/\\\\/\\/g;
            #filter unprintables
            $value =~ s/[^[:print:]]/\./g;
            $value =~ s/[\r\n\t]/ /g;
            #print($pos." ".sprintf("%16s",$name).": ".$value."\n");    
            output($pos,$name,$value,$raw_match);
        }
    }
 
    #/ID [<fa8644b832d814b038ea1c585dcdcb96><fa
    while ($contents =~ m/\/(ID)\s?\[\s?\<([0-9A-Fa-f]{1,60})\>.?\<([0-9A-Fa-f]{1,60})\>\s?\]/sg )
    {
        $pos = sprintf("%08X", $-[0]);
        $raw_match = substr($contents,$-[0],($+[0] - $-[0]));
        $name = $1;
        $value = $2;
        $value2 = $3;
        #print($pos." ".sprintf("%16s","PdfID0").": ".$value."\n");
        #print($pos." ".sprintf("%16s","PdfID1").": ".$value2."\n");
        output($pos,"PdfID0",$value,$raw_match);
        output($pos,"PdfID1",$value2,$raw_match);
    
    }
    
    
    if ($extended_output || $hash_output || $medium_output)
    {
	

    #FONT Names
    #/BaseFont\s?/[^\s/]+
    while ($contents =~ m/\/BaseFont\s?\/([^\s\/]{0,$max_value_length})/sg )
    {
        $pos = sprintf("%08X", $-[1]);
        $raw_match = substr($contents,$-[1] - 1,($+[1] - ($-[1] - 1)));
        $name = "BaseFont";
        $value = $1;
        #filter unprintables
        $value =~ s/[^[:print:]]/\./g;
        $value =~ s/[\r\n\t]/ /g;
        #print($pos." ".sprintf("%16s",$name).": ".$value."\n");
        output($pos,$name,$value,$raw_match);
    }

    
    #/Mediabox [ 0 0 1 1 ] --- For page sizes
    #while ($contents =~ m/\/(MediaBox) ?\[ ?([0-9\.]{0,12}) ([0-9\.]{0,12}) ([0-9\.]{0,12}) ([0-9\.]{0,12}) ?\]/g )
    while ($contents =~ m/\[ ?([0-9\.-]{0,12}) ([0-9\.-]{0,12}) ([0-9\.-]{0,12}) ([0-9\.-]{0,12}) ?\]/g )
    {
        $pos = sprintf("%08X", $-[0]);
        $raw_match = substr($contents,$-[0],($+[0] - $-[0]));
        $name = "Box";
        $value = $1;
        $value2 = $2;
        $value3 = $3;
        $value4 = $4;
        
        #normalize the size, then label size according to one of the popular labels
        if ($value3 > $value)
	{
		$width = int($value3 - $value +.5);
	} else 
	{
		$width = int($value - $value3 +.5);
	}

	if ($value4 > $value2)
	{
		$height = int($value4 - $value2 +.5);
	} else
	{
		$height = int($value2 - $value4 +.5);
	}
	
	#$width = int($value3 - $value +.5);
        #$height = int($value4 - $value2 +.5);
        $desc = "other";
        if (($width > 602 && $width < 622 ) && ($height > 782 && $height <  802 ) ) { $desc = "letter"; }
        if (($width > 782 && $width < 802 ) && ($height > 602 && $height < 622) ) { $desc = "letter-landscape"; }
        #if ($width == 595 && $height == 842) { $desc = "A4"; }
        if (($width > 585 && $width < 605 ) && ($height > 832 && $height <  852 ) ) { $desc = "A4"; }
	if (($width > 832 && $width < 852 ) && ($height > 585 && $height > 605 ) ) { $desc = "A4-landscape"; }
	#if ($width == 595 && $height == 792) { $desc = "letter-A4-overlap"; }
        if (($width > 585 && $width < 602 ) && ($height > 782 && $height < 832 ) ) { $desc = "letter-A4-overlap"; }
	#if ($width == 612 && $height == 1008) { $desc = "legal"; }
	if (($width > 602 && $width < 622 ) && ($height > 998 && $height <  1018 ) ) { $desc = "legal"; }
        
        #print($pos." ".sprintf("%16s",$name).": ${width}x$height ($desc)\n");
        $value = "${width}x$height ($desc)";
        output($pos,$name,$value,$raw_match);
    }
    
    #images
    #00000010  0a 3c 3c 2f 54 79 70 65  20 2f 58 4f 62 6a 65 63  |.<</Type /XObjec|
    #00000020  74 0a 2f 53 75 62 74 79  70 65 20 2f 49 6d 61 67  |t./Subtype /Imag|
    #00000030  65 0a 2f 4e 61 6d 65 20  2f 4a 49 31 61 0a 2f 57  |e./Name /xxxx./W|
    #00000040  69 64 74 68 20 31 37 30  30 0a 2f 48 65 69 67 68  |idth 1700./Heigh|
    #00000050  74 20 32 32 30 30 0a 2f  42 69 74 73 50 65 72 43  |t 2200./BitsPerC|
    #00000060  6f 6d 70 6f 6e 65 6e 74  20 38 0a 2f 43 6f 6c 6f  |omponent 8./Colo|
    #00000070  72 53 70 61 63 65 20 2f  44 65 76 69 63 65 52 47  |rSpace /DeviceRG|
    #00000080  42 0a 2f 46 69 6c 74 65  72 20 2f 44 43 54 44 65  |B./Filter /DCTDe|
    #00000090  63 6f 64 65 0a 2f 4c 65  6e 67 74 68 20 32 20 30  |code./Length 2 0|
    #000000a0  20 52 0a 3e 3e 0a 73 74  72 65 61 6d 0d 0a ff d8  | R.>>.stream....|


    #00000600  72 2f 4a 42 49 47 32 44  65 63 6f 64 65 2f 48 65  |r/JBIG2Decode/He|
    #00000610  69 67 68 74 20 36 30 30  2f 4c 65 6e 67 74 68 20  |ight 600/Length |
    #00000620  33 37 33 39 2f 4e 61 6d  65 2f 58 2f 53 75 62 74  |3739/Name/X/Subt|
    #00000630  79 70 65 2f 49 6d 61 67  65 2f 54 79 70 65 2f 58  |ype/Image/Type/X|
    #00000640  4f 62 6a 65 63 74 2f 57  69 64 74 68 20 38 30 30  |Object/Width 800|


    #while ($contents =~ m/\/(Width|Height)\s+([0-9]+)[^0-9].{0,$max_value_length}?\/(Width|Height)\s+([0-9]+)[^0-9]/sg )
    while ($contents =~ m/\/(Width|Height)\s+([0-9]+).{0,$max_value_length}?\/(Width|Height)\s+([0-9]+)[^0-9]/sg )
    {
                
        $pos = sprintf("%08X", $-[0]);
        $raw_match = substr($contents,$-[0],($+[0] - $-[0]));
        $name = "Image";
        $value = $1;
        $value2 = $2;
        $value3 = $3;
        $value4 = $4;
        #report width x height
        if ($value eq "Width")
        {
            #print($pos." ".sprintf("%16s",$name).": ${value2}x${value4}\n");
            $out_value = "${value2}x${value4}";
        } else
        {
            #print($pos." ".sprintf("%16s",$name).": ${value4}x${value2}\n");
            $out_value = "${value4}x${value2}";
        }
        output($pos,$name,$out_value,$raw_match);
    }
    
    } #end medium output 
    
    if ($extended_output || $hash_output)
    {
	#for filters......
	#filter abbreviations
	#    ASCIIHexDecode -> AHx
	#    ASCII85Decode -> A85
	# LZWDecode -> LZW
	#FlateDecode -> Fl
	#RunLengthDecode -> RL
	#CCITTFaxDecode -> CCF
	#DCTDecode -> DCT

	#pcregrep -o -h "\/(?:F|#46)(?:i|#69)(?:l|#6c)(?:t|#74)(?:e|#65)(?:r|#72)\s{0,4}\\[(\s{0,4}\/[a-zA-Z0-9#]+)+\s{0,4}\]"
	
	while ($contents =~ m/\/((?:F|#46)(?:i|#69)(?:l|#6c)(?:t|#74)(?:e|#65)(?:r|#72))\s{0,4}(\[(?:\s{0,4}\/[a-zA-Z0-9#]{2,$max_value_length})+\s{0,4}\]|\/[a-zA-Z0-9#]{2,$max_value_length})/sg )
	{	
	    $pos = sprintf("%08X", $-[0]);
	    $raw_match = substr($contents,$-[0],($+[0] - $-[0]));
	    #print "$raw_match\n";
	    $name = "Filter";
	    $value = $2;
	    
	    if ($raw_match =~ m/#/)
	    {
	        $value2 = " (obfuscated)";
	    } else
	    {
	        $value2 ="";
	    }
	    $value =~ s/#([A-Fa-f0-9]{2})/chr(hex($1))/ges;
	    $value =~ s/[^[:print:]]/\ /g;
            $value =~ s/[\r\n\t]/ /g;
	    
	    $value =~ s/[\[\]]//g;
	    $value =~ s/\s+\//\//g;
	    #$value =~ s/^\s//g;
	    
	    $out_value = "$value$value2";
	
	    output($pos,$name,$out_value,$raw_match);
	}
	



    #PDFID style structure markers (don't extract any values, just location)
    #$ echo -n "|\/"; echo -n Encrypt | while read -n 1 c; do hex=`echo -n $c | xxd -p`; echo -n "(?:$c|#$hex)"; done; echo "";
    #|\/(?:E|#45)(?:n|#6e)(?:c|#63)(?:r|#72)(?:y|#79)(?:p|#70)(?:t|#74)

    #TODO: Add object numbers, references (need to fix pdf_cluster_features)
    #[0-9]+\s[0-9]\sobj
    

    while ($contents =~ m/([0-9]+\s[0-9]\sR|obj|endobj|stream|endstream|xref|trailer|startxref|%EOF|\/(?:J|#4A)(?:S|#53)|\/(?:P|#50)(?:a|#61)(?:g|#67)(?:e|#65)|\/(?:E|#45)(?:n|#6e)(?:c|#63)(?:r|#72)(?:y|#79)(?:p|#70)(?:t|#74)|\/(?:O|#4f)(?:b|#62)(?:j|#6a)(?:S|#53)(?:t|#74)(?:m|#6d)|\/(?:J|#4a)(?:a|#61)(?:v|#76)(?:a|#61)(?:S|#53)(?:c|#63)(?:r|#72)(?:i|#69)(?:p|#70)(?:t|#74)|\/(?:A|#41)(?:A|#41)|\/(?:O|#4f)(?:p|#70)(?:e|#65)(?:n|#6e)(?:A|#41)(?:c|#63)(?:t|#74)(?:i|#69)(?:o|#6f)(?:n|#6e)|\/(?:A|#41)(?:c|#63)(?:r|#72)(?:o|#6f)(?:F|#46)(?:o|#6f)(?:r|#72)(?:m|#6d)|\/(?:R|#52)(?:i|#69)(?:c|#63)(?:h|#68)(?:M|#4d)(?:e|#65)(?:d|#64)(?:i|#69)(?:a|#61)|\/(?:L|#4c)(?:a|#61)(?:u|#75)(?:n|#6e)(?:c|#63)(?:h|#68)|\/(?:C|#43)(?:o|#6f)(?:l|#6c)(?:o|#6f)(?:r|#72)(?:s|#73)|\/(?:F|#46)(?:o|#6f)(?:n|#6e)(?:t|#74))[^A-Za-z#]/sg )
    {
	$pos = sprintf("%08X", $-[0]);
        $raw_match = substr($contents,$-[0],($+[0] - 1 - $-[0]));
        $name = "Structure";
	$value = $1;
	
	
	
	if ($value =~ m/#/)
	{
	    $value2 = " (obfuscated)";
	} else
	{
	    $value2 ="";
	}
	$value =~ s/#([A-Fa-f0-9]{2})/chr(hex($1))/ges;
	#print($pos." ".sprintf("%16s",$name).": $value$value2\n");
	$out_value = "$value$value2";
        output($pos,$name,$out_value,$raw_match);
    }

	#if ($contents =~ m/%EOF$/s)
	#{
	#	$pos = sprintf("%08X", $-[0]);
	#	print($pos." ".sprintf("%16s","Structure").": %EOF\n");
	#}
	
	if ( substr($contents, -4) eq  "%EOF" )
	{
		$pos = sprintf("%08X", length($contents) - 4);
                #print($pos." ".sprintf("%16s","Structure").": %EOF\n");
                output($pos,$name,"%EOF","%EOF");
	}	

    }#end extended_output if


    
    
}

#function to output the stuff, allows output to be modified easily
#pos, name, value
sub output()
{
    my $pos, $name, $value;
    my $rawbytes;
    my $hexdump;
    
    ($pos, $name, $value, $rawbytes) = @_;
    
    if ($hash_output)
    {
        if (($name ne 'Structure') && ($name ne 'Filename') && ($name ne 'Filter') && ($name ne 'Size'))
        {
            print(md5_hex($name.": ".$value)." ".$name.": $value\n");
        }
    } elsif ($hex_output)
    {
        #quite a hack to deal with PdfID0 and PdfID1 being lumped together--yes we're using a global here :(
        if ($name eq 'PdfID0')
        {
            $last_pdfid0 = $name.": ".$value;
        }
        if (($name ne 'PdfID0') && ($name ne 'Filename') && ($name ne 'Size') && ($value !~ m/[0-9]+\s[0-9]\sR/ ))
        {
            $hexdump = unpack( 'H*', $rawbytes );
            $hexdump =~ s/(..)/$1 /g;
            print("\t".'$pdfmd_'.(($name eq "PdfID1") ? "ID" : $name)."_".md5_hex($name.": ".$value).'_'.substr(md5_hex($hexdump),0,8).' = { '.$hexdump.'} // '.(($name eq "PdfID1") ? "$last_pdfid0 " : "").$name.": ".$value."\n");
        }
    } else
    {
        print(lc($pos)." ".sprintf("%16s",$name).": $value\n");
    }
    
    
    
}



