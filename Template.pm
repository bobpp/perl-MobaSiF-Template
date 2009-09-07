package MobaSiF::Template;

use 5.008;
use strict;
use warnings;

use File::stat;
use MobaSiF::Template::Compiler;

require Exporter;

our @ISA = qw(Exporter);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = '0.01';

require XSLoader;
XSLoader::load('MobaSiF::Template', $VERSION);

our $DEVELOP = 0;
sub render {
	my ($template, $compiled_template, $param, $param2, $param3) = @_;
	if ($DEVELOP) {
		my $template_stat = stat($template);
		my $compiled_stat = stat($compiled_template);

		if ($template_stat->mtime > $compiled_stat->mtime) {
			MobaSiF::Template::Compiler::compile($template, $compiled_template);
		}
	}
	return MobaSiF::Template::insert($compiled_template, $param, $param2, $param3);
}

1;

__END__

=head1 NAME

MobaSiF::Template - 高速なテンプレートライブラリ

=head1 SYNOPSIS

use MobaSiF::Template;
$html = MobaSiF::Template::insert($compiled_template_file, $refParamHash);

=head1 ABSTRACT

事前コンパイルされたテンプレートバイナリを用いて高速なテンプレート処理を行います。ループ・条件分岐・置換（URL ENCODE, HTMLSPECIALCHARS(+NL2BR) が可能）に対応しており、基本的なHTMLテンプレートの処理に対応できます。

=head1 DESCRIPTION

=head1 SEE ALSO

MobaSiF::Template::Compiler

=cut
