#!/usr/bin/perl
$|=1;
use CGI qw(:standard *table *Tr *td);
use CGI::Pretty;
use HTML::Entities qw(encode_entities_numeric);
#use Encode;
#use CGI::Carp qw(warningsToBrowser fatalsToBrowser); #
use strict;
use LWP::Simple;
use DBI;
use Data::Dumper;

use UCFcommon;

my $path = &Path('support').'XMLtemplates\\';

my $CSS =<<END_CSS;

form td {
	white-space: nowrap;
}
#ResultsContainer {
	margin: 0 5% 2em 5%;
	padding: 1em;
	overflow: auto;
	background-color: #f8f8f8;
	border: 1px solid #eee;
	white-space: pre;
	height: 30em;
	width: 90%;
}

END_CSS

my $cgi = CGI->new();

if ($cgi->param('Upload')) {
	my $filename = $cgi->param('uploaded_file');
	# my $type = $cgi->uploadInfo($filename);
	my $filename = &getfilename($filename);
	my $filedata = '';
	my ($mime) = &SetMIME($filename);
	
	# while ( read( param('uploaded_file'), my $i, 1024 ) ) {
		# $filedata.= $i;
	# }
	my $fh = $cgi->upload('uploaded_file');
	while ( <$fh> ) {
		$filedata.= $_;
	}
	$filedata =~ s/\s+$//s;
	my $size = length($filedata);

	my $xml = &LoadTabedData($filedata);
	
	if (param('output') eq 'File') {
		#$xml =~ s/^\n//g;
		print header(-type=>'text/xml',-attachment=>'metadata.xml'),$xml;
	}
	else {
		# $xml =~ s/&/&amp;/g;
		# $xml =~ s/</&lt;/g;
		# $xml =~ s/>/&gt;/g;
		
		print header, start_html(-title=>'File Processing Complete',-style=>{-src=>'/Web/advanced.asp?section=services',-code=>$CSS}),
			UCFInclude('MainHeaderSmall'),
			h1('File Uploaded and Converted Sucessfully'), p('sent',$filename,'-',$size,'bytes',br,'resulting file -',length($xml),'bytes'),
			# div({-id=>'ResultsContainer'},$xml),
			div({-id=>'Loading',-style=>'text-align: center;'},
				img({-alt=>'Loading, please wait...',-src=>'img/LoadingArrowsWhiteOnGray.gif',-align=>'absmiddle'}),
				strong('Loading, please wait...'),
			),
			# &Dumper($type),
			start_form(),
				textarea(-name=>'xml',
					-id=>'ResultsContainer',
					-default=>$xml,
					-rows=>20,
					-columns=>100
				),
			end_form(),
			UCFInclude('MainFooter'),
			style('#Loading { display: none; }'),
			end_html();
	}
}
elsif ($cgi->param('view') eq 'View XML Template') {
	# $cgi->param('view') eq 'xmltemplate',-attachment=>'template.xml'
	print header(-type=>'text/xml'), &SystemTemplate();
}
else {
	opendir(TEMPLATES,$path) || &dienice('Couldn\'t open the blasted folder',$path);
	rewinddir TEMPLATES;
	my @Templates = grep { !/^\./ && /\.xml$/i } readdir(TEMPLATES);
	closedir TEMPLATES;
    
	print header, start_html(-title=>'Text To XML Converter',-style=>{-src=>'/Web/advanced.asp?section=services',-code=>$CSS}),
	&UCFInclude('MainHeaderSmall'),
	h1('Upload a file to convert to XML.'),
	div({-align=>'center'},
	start_multipart_form(-name=>'formUpload'),
		table({-border=>0,-cellspacing=>0,-cellpadding=>3,-class=>'DataTable'},
			Tr(
				th({-colspan=>2},'Choose a local tab delimited file and upload it here.'),
			),
			Tr(
				td({-colspan=>2},
					filefield(	-name=>'uploaded_file',
								-default=>'File Path Here',
								-size=>50),
					br,'Output XML to:',
					radio_group(-name=>'output',
								-values=>['File','Screen'],
								-default=>'Screen'),
					div(
						checkbox(-name=>'firstline',-value=>'ignore',-label=>'First line of data file is Column Names'),
					),
				),
			),
			Tr(
				td({-style=>'text-align: left;'},
					radio_group(-name=>'templatetype',
								-values=>['Uploaded','Built-In'],
								-default=>'Built-In',
								-linebreak=>1),
				),
				td({-style=>'text-align: left;'},'->',
					filefield(	-name=>'usertemplate',
								-default=>'File Path Here',
								-size=>45),
					br,'->',
					'Choose a built-in template:', popup_menu(-name=>'builtintemplate',-values=>\@Templates)
				)
			),
			Tr(
				td({-colspan=>2},
					submit(	-name=>'Upload',-value=>'Upload'),
					submit(	-name=>'view',-value=>'View XML Template'),
				),
			),
		),
	end_multipart_form(),
	),
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
		next if ($lineCount == 0 and $cgi->param('firstline') eq 'ignore');
		my $insert = $repeater;
		my @Cols = split(/\t/,$r);
		#if ( $Cols[0] =~ /\d+/ ) {
			for (@Cols) {
				s/(^"|"$)//g;
				encode_entities_numeric($_);
			}
			$insert =~ s/\[(\d+)\]/$Cols[$1]/ig;								# Convert Template field refs to form variables
			$xmlData.= $insert;
		#}
	}
	$xmlData.= $footer;
	return $xmlData;
}

sub TemplateProcess {
	my $tmpl = shift;
	
	my ($header,$body) = split(/<!--\#ENDHEADER\s*?-->/,$tmpl);
	my ($repeater,$footer) = split(/<!--\#STARTFOOTER\s*?-->/,$body);
	
	return ($header,$repeater,$footer);
}

sub SystemTemplate {
	my $filename = $cgi->param('builtintemplate');
	$filename =~ s/[\\\/]//g;
	my $URI = $path . $filename;
	my $tmpl;
	open(FILE,'<',$URI) or &prettydienice('Template','Could not open '.$URI);
	while (<FILE>) { $tmpl .= $_; }
	close(FILE);
	return $tmpl;
}

sub UserTemplate {
	my $filedata;
	my $fh = $cgi->upload('usertemplate');
	while ( <$fh> ) {
		$filedata.= $_;
	}
	return $filedata;
}



__END__

		<style>
code.html .column {
	color: #060;
}
.HeaderSection {
	background-color: #aac;
}
.RepeatedSection {
	background-color: #aca;
}
.FooterSection {
	background-color: #cca;
}
code .HeaderSection, code .RepeatedSection, code .FooterSection {
	display: block;
}
.comment {
	color: #c00;
}
/*
.tag {
	color: #00c;
	font-weight: bold;
}
pre {
	background-color: #eee;
	border: 1px #ccc solid;
	padding: 10px;
	margin: 10px;
}
*/
		</style>
		<h3>Creating a Template</h3>
		<p>Below is a sample template. Each template consists of a <span class="HeaderSection">header section</span>, a <span class="RepeatedSection">repeated item section</span> and a <span class="FooterSection">footer section</span>. Each section is divided by a <code><span class="comment">&lt;!--#--&gt;</span></code> directive element.</p>
		<p>The repeated item section contains <span class="column">[#]</span> which relates to the columns of the source data file. The columns start numbering at 0, not 1. This script will replace any occurrence of <span class="column">[2]</span> with the data in the 3rd column of your 
		file, <span class="column">[3]</span> with 4th, <span class="column">[4]</span> with 5th etc. All other formatting is user settable; tabs newlines, tag contents, etc. The template does not even need to output XML, but could be used for any organized text based output.</p>
		<pre title="Example Template: Harrison Price Reports"><code class="html"><span class="HeaderSection"><span class="tag">&lt;<span class="keyword">?xml</span> <span class="attribute">version=<span class="value">&quot;1.0&quot;</span>?</span>&gt;</span>
<span class="tag">&lt;<span class="keyword">ead</span>&gt;</span></span><span class="comment">&lt;!--#ENDHEADER --&gt;</span><span class="RepeatedSection">   <span class="tag">&lt;<span class="keyword">c03</span> <span class="attribute">level=<span class="value">&quot;file&quot;</span></span>&gt;</span>
      <span class="tag">&lt;<span class="keyword">did</span>&gt;</span>
         <span class="tag">&lt;<span class="keyword">container</span> <span class="attribute">type=<span class="value">&quot;Box&quot;</span></span>&gt;</span><span class="tag">&lt;/<span class="keyword">container</span>&gt;</span>
         <span class="tag">&lt;<span class="keyword">container</span> <span class="attribute">type=<span class="value">&quot;Folder&quot;</span></span>&gt;</span><span class="column">[0]</span><span class="tag">&lt;/<span class="keyword">container</span>&gt;</span>
         <span class="tag">&lt;<span class="keyword">unittitle</span>&gt;</span>
            <span class="tag">&lt;<span class="keyword">corpname</span>&gt;</span><span class="column">[1]</span><span class="tag">&lt;/<span class="keyword">corpname</span>&gt;</span>
            <span class="tag">&lt;<span class="keyword">title</span>&gt;</span><span class="column">[2]</span><span class="tag">&lt;/<span class="keyword">title</span>&gt;</span>
            <span class="tag">&lt;<span class="keyword">corpname</span>&gt;</span><span class="column">[3]</span><span class="tag">&lt;/<span class="keyword">corpname</span>&gt;</span>
            <span class="tag">&lt;<span class="keyword">subject</span>&gt;</span>Project Class: <span class="column">[4]</span><span class="tag">&lt;/<span class="keyword">subject</span>&gt;</span>
         <span class="tag">&lt;/<span class="keyword">unittitle</span>&gt;</span>
         <span class="tag">&lt;<span class="keyword">unitdate</span> <span class="attribute">type=<span class="value">&quot;inclusive&quot;</span></span>&gt;</span><span class="column">[5]</span><span class="tag">&lt;/<span class="keyword">unitdate</span>&gt;</span>
      <span class="tag">&lt;/<span class="keyword">did</span>&gt;</span>
      <span class="tag">&lt;<span class="keyword">accessrestrict</span>&gt;</span>
         <span class="tag">&lt;<span class="keyword">p</span>&gt;</span><span class="column">[6]</span><span class="tag">&lt;/<span class="keyword">p</span>&gt;</span>
      <span class="tag">&lt;/<span class="keyword">accessrestrict</span>&gt;</span>
   <span class="tag">&lt;/<span class="keyword">c03</span>&gt;</span></span><span class="comment">&lt;!--#STARTFOOTER --&gt;</span><span class="FooterSection"><span class="tag">&lt;/<span class="keyword">ead</span>&gt;</span></span></code></pre>
