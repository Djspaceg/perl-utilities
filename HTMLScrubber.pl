#!/usr/bin/perl
use CGI qw(:standard *table *Tr *td);
use CGI::Pretty;
use HTML::Entities;
#use Encode;
#use CGI::Carp qw(warningsToBrowser fatalsToBrowser); #
use strict;
use LWP::Simple;
use DBI;

use UCFcommon;

# my $path = '\\\\UCFXP650\\CGI-LIB\\XMLtemplates\\';

my %OPTIONS = (
	case		=> 'Change all tags and attributes to lowercase',
	blockquotes	=> 'Convert <BLOCKQUOTE> to <div class="ThinBlock">',
	bolds		=> 'Convert <b> to <storng>',
	italics		=> 'Convert <i> to <em>',
	spaces		=> 'Strip &nbsp; Smartly',
	fonts		=> 'Strip Fonts',
	styles		=> 'Strip style="" attributes',
	empty		=> 'Strip Empty Tags',
);

my %OPT = ();
for (param('options')) {
	$OPT{$_} = 1;
}

if (param('uploaded_file')) {
	&Scrubber( &UploadFile() );
}
elsif (param('File')) {
	&Scrubber( param('File') );
}
else {
	&InputFileForm();
	
}

# A sample edit
####

sub InputFileForm {
	# opendir(TEMPLATES,$path) || &dienice('Couldn\'t open the blasted folder',$path);
	# rewinddir TEMPLATES;
	# my @Templates = grep { !/^\./ && /\.xml$/i } readdir(TEMPLATES);
	# closedir TEMPLATES;
    
	print header, start_html(-title=>'HTML Scrubber Form',-style=>{-src=>"/Web/standard.css"}),
		UCFInclude('MainHeaderSmall'),
		# style('form th { font-size: 12px; background-color: black; color: gold; } form td { background-color: #fec; color: black; }'),
		h1('HTML Code Scrubber'),
		start_multipart_form(-name=>'formUpload'),
			table({-align=>'center',-style=>'width: 80%; text-align: center;',-border=>0,-cellspacing=>0,-cellpadding=>3,-class=>'FormTable'},
				Tr([
					th('Choose a local HTML file or paste in one'),
					td('Browse for a file on your hard drive:',
						filefield(-name=>'uploaded_file',
								-default=>'File Path Here',
								-size=>50
							),
					),
					td(span({-class=>'ImportantNote'},'OR'),'Paste HTML code into here:',br,
						textarea(-name=>'File',
								-default=>'',
								-columns=>100,
								-rows=>18,
								-style=>'width: 100%; font-family: ProFontWindows, "Courier New", monospace; font-size: 12px;',
							),
					),
					th(
						'Options:',
					),
					td({-style=>'text-align: left;'},
						checkbox_group(-name=>'options',
								-values=>[sort {$OPTIONS{$a} cmp $OPTIONS{$b}} keys %OPTIONS],
								-default=>[sort keys %OPTIONS],
								-columns=>2,
								-labels=>\%OPTIONS,
							),
					),
					td(
						'Output XML to:',
						radio_group(-name=>'output',
								-values=>['File','Screen'],
								-default=>'Screen'
							),
					),
					td(
						'Convert Into Format:',
						radio_group(-name=>'format',
								-values=>['HTML','CGI'],
								-default=>'HTML'
							),
					),
					td(
						submit(	-name=>'go',
								-value=>'Start Scrubbing'
							),
					)
				])
			),
		end_multipart_form(),
		<DATA>,
		UCFInclude('MainFooter'),
		end_html();
}

sub LoadTabedData {
	my $rawdata = shift;
	my ($header,$repeater,$footer) = &TemplateProcess(param('templatetype') eq 'Uploaded' ? &UserTemplate() : &SystemTemplate() );
	my $xmlData = $header;
	### Standardize Line breaks
	$rawdata =~ s/\r\n/\n/g;
	$rawdata =~ s/\r/\n/g;
	#$rawdata =~ s/\n\n/\n/g;
	my @Records = split(/\n/,$rawdata);
	my $lineCount = -1;
	foreach my $r (@Records) {
		$lineCount++;
		next if ($lineCount == 0);
		my $insert = $repeater;
		my @Cols = split(/\t/,$r);
		#if ( $Cols[0] =~ /\d+/ ) {
			for (@Cols) {
				encode_entities($_);
			}
			$insert =~ s/\[(\d+)\]/$Cols[$1]/ig;								# Convert Template field refs to form variables
			$xmlData.= $insert;
		#}
	}
	$xmlData.= $footer;
	return $xmlData;
}

sub UploadFile {
	#my $filename = &getfilename(param('uploaded_file'));
	my $filedata = '';
	#my ($mime) = &SetMIME($filename);
	
	while ( read( param('uploaded_file'), my $i, 1024 ) ) {
		$filedata.= $i;
	}
	# my $size = length($filedata);

	#my $xml = &LoadTabedData($filedata);
	
	return $filedata;
}

sub Scrubber {
	my $filedata = shift;
	my $sizeOriginal = length($filedata);
	# print header, start_html(),
	if (param('format') eq 'HTML') {
		$filedata =~ s/<(\/)?i>/<$1em>/ig							if ( $OPT{'italics'} );		# Match all simple <i> and </i> tags
		$filedata =~ s/<i[^>\w](.*?)>/<em$1>/ig						if ( $OPT{'italics'} );		# Match all <i> tags with attributes, but not things like <img>
		$filedata =~ s/<(\/)?b>/<$1strong>/ig						if ( $OPT{'bolds'} );
		$filedata =~ s/<b[^>\w](.*?)>/<strong$1>/ig					if ( $OPT{'bolds'} );
		$filedata =~ s/\&nbsp;/ /ig									if ( $OPT{'spaces'} );
		$filedata =~ s/(<p>)\s*(<\/p>)/<p>&nbsp;<\/p>/ig			if ( $OPT{'spaces'} );
		$filedata =~ s/<blockquote>/<div class="ThinBlock">/ig		if ( $OPT{'blockquotes'} );
		$filedata =~ s/<\/blockquote>/<\/div>/ig					if ( $OPT{'blockquotes'} );
		$filedata =~ s/<\/?font.*?>//ig								if ( $OPT{'fonts'} );
		# $filedata =~ s/<(\/?)(\w+)(.*?)>/'<'.$1.lc($2).&CaseCorrection($3).'>'/eig	if ( $OPT{'case'} );
		$filedata =~ s/<([^>]*?)style=".*?"(.*?>)/<$1$2/ig			if ( $OPT{'styles'} );
		$filedata =~ s/<([^(textarea)]+)(\s+[^>]*?)?>(\s*)<\/\1>/$3/igs		if ( $OPT{'empty'} );	# Strip Empty Tags
		# $filedata =~ s/<(\/?)(\w+)(.*?)>/'<'.$1.lc($2).$3.'>'/eig	if ( $OPT{'case'} );
		
		$filedata =~ s/<body.*?>/<body>/ig							if ( 1 );	# Always strip body attrs.
		$filedata =~ s/(<strong>)(\s*)(<a.*?>)(.*?)(<\/a>)(\s*)(<\/strong>)/$2$3$1$4$7$5$6/ig			if ( 1 );	# Correct the order ofstrong and a tags
		$filedata =~ s/(<b>)(\s*)(<a.*?>)(.*?)(<\/a>)(\s*)(<\/b>)/$2$3$1$4$7$5$6/ig						if ( !$OPT{'bolds'} );	# Correct the order ofstrong and a tags
		$filedata =~ s/\s+>/>/ig									if ( 1 );	# Correct the order ofstrong and a tags
	}
	elsif (param('format') eq 'CGI') {
		$filedata =~ s/<\/.*?>/\),/g;
		$filedata =~ s/<(\w+)\s+(.*?)>/$1\({$2}, /g;
		$filedata =~ s/<(\w+?)>/$1(/g;
		$filedata =~ s/{}, //g;
		$filedata =~ s/(\w+)="(.*?)"/-$1=>'$2', /g;
		$filedata =~ s/, \}/}/g;
		$filedata =~ s/\),\)/))/g;
		
		### Adjust tags to CGI equiv
		$filedata =~ s/form\(/start_form\(/g;
		$filedata =~ s/tr\(/Tr\(/g;
	}
	my $sizeNew = length($filedata);
	my $sizeSaved = $sizeOriginal - $sizeNew;
	if (param('output') eq 'File') {
		#$xml =~ s/^\n//g;
		print header(-type=>'text/xml',-attachment=>'NewHTML.htm'),$filedata;
	}
	else {
		print header, start_html(-title=>'HTML Scrubber Output'),
			UCFInclude('MainHeaderSmall'),
			h1('File Clensed Sucessfully'),
			p('Processed with the following options:',span({-class=>'ImportantNote'},join(', ', sort keys %OPT))),
			p('Original File was',$sizeOriginal,'bytes. The Clensed File is',$sizeNew,'bytes, saving ',$sizeSaved,'bytes'),
			start_form(),
				textarea(-name=>'newfile',
						-default=>$filedata,
						-rows=>20,
						-columns=>100,
						-style=>'width: 99%;',
					);
			end_form(),
			UCFInclude('MainFooter'),
			end_html();
	}
}

sub CaseCorrection {
	my $str = shift;
	my $outstr = '';
	my %ATTRS = ();
	### Isolate Attributes
	my @AttrPairs = ();
	while ($str =~ s/\s*([\w\-]+)\s*=\s*('|")(.*?)\2//) {
		push(@AttrPairs, $1 . '="'.$3.'"');
	}
	#   Attribute Selector
	#    ([\w-])+=\s*(['"])(.*?)\2
	while ($str =~ s/\s*([\w\-]+)\s*=\s*('|")(.*?)("|')//) {
		my ($attr, $value) = (lc($1), $3);
		$value =~ s/^("|')//;
		$value =~ s/("|')$//;
		if ($attr eq 'class' or $attr eq 'id' or $attr eq 'href' or $attr eq 'src' or $attr eq 'name' or $attr eq 'action' or $attr eq 'content' or $attr eq 'equiv' or $attr eq 'value' or $attr =~ /^on/) {
			$ATTRS{$attr} = $value;
		}
		else {
			$ATTRS{$attr} = lc($value);
		}
		# print pre($1 .' = '. $2 .br);
		$outstr.= ' ' . $attr . '="' . $ATTRS{$attr} . '"';
	}
	return $outstr;
	# my @Attrs = split(/\s*=\s*/, $str);
	
}

# sub TemplateProcess {
	# my $tmpl = shift;
	
	# my ($header,$body) = split(/<!--\#ENDHEADER\s*?-->/,$tmpl);
	# my ($repeater,$footer) = split(/<!--\#STARTFOOTER\s*?-->/,$body);
	
	# return ($header,$repeater,$footer);
# }

# sub SystemTemplate {
	# my $filename = param('builtintemplate');
	# $filename =~ s/[\\\/]//g;
	# my $URI = $path . $filename;
	# my $tmpl;
	# open(FILE,'<',$URI) or &prettydienice("Template","Could not open $URI");
	# while (<FILE>) { $tmpl .= $_; }
	# close(FILE);
	# return $tmpl;
# }

# sub UserTemplate {
	# my $filedata;
	# while ( read( param('usertemplate'), my $i, 1024 ) ) {
		# $filedata.= $i;
	# }
	# return $filedata;
# }

__END__
<!--
		<style>
.tag {
	color: #00c;
	font-weight: bold;
}
.column {
	color: #060;
}
.comment {
	color: #c00;
}
pre {
	background-color: #eee;
	border: 1px #ccc solid;
	padding: 10px;
	margin: 10px;
}
		</style>
		<p>Below is a sample template. Each template consists of a header section, a repeated item section and a footer section. Each section is divided by a
<span class="comment">&lt;!--#--&gt;</span>
		element.</p><p>The repeated item section contains <span class="column">[#]</span> which relates to the columns of the source data file. The columns start numbering at 0, not 1. This script will replace any occurrence of <span class="column">[2]</span> with the data in the 3rd column of your 
		file, <span class="column">[3]</span> with 4th, <span class="column">[4]</span> with 5th etc. All other formatting is user settable; tabs newlines, tag contents, etc. The template does not even need to output XML, but could be used for any organized text based output.</p>
		<pre><span class="tag">&lt;?xml version=&quot;1.0&quot;?&gt;
&lt;?spreadsheet harrison price reports?&gt;
&lt;ead&gt;</span>
<span class="comment">&lt;!--#ENDHEADER --&gt;</span>
<span class="tag">   &lt;c03 level=&quot;file&quot;&gt;
      &lt;did&gt;
         &lt;container type=&quot;Box&quot;&gt;&lt;/container&gt;
         &lt;container type=&quot;Folder&quot;&gt;</span></span><span class="column">[0]</span><span class="tag">&lt;/container&gt;
         &lt;unittitle&gt;
            &lt;corpname&gt;</span><span class="column">[1]</span><span class="tag">&lt;/corpname&gt; 
            &lt;title&gt;</span><span class="column">[2]</span><span class="tag">&lt;/title&gt;
            &lt;corpname&gt;</span><span class="column">[3]</span><span class="tag">&lt;/corpname&gt;
            &lt;subject&gt;</span>Project Class: <span class="column">[4]</span><span class="tag">&lt;/subject&gt;
         &lt;/unittitle&gt;
         &lt;unitdate type=&quot;inclusive&quot;&gt;</span><span class="column">[5]</span><span class="tag">&lt;/unitdate&gt;
      &lt;/did&gt;
      &lt;accessrestrict&gt; 
      &lt;p&gt;</span><span class="column">[6]</span><span class="tag">&lt;/p&gt;
      &lt;/accessrestrict&gt;
   &lt;/c03&gt;</span>
<span class="comment">&lt;!--#STARTFOOTER --&gt;</span>
<span class="tag">&lt;/ead&gt;</span></pre>
-->
