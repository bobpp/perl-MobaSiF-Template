package MobaSiF::Template;

use 5.008;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = '0.01';

require XSLoader;
XSLoader::load('MobaSiF::Template', $VERSION);

1;

__END__

=head1 NAME

MobaSiF::Template - ��®�ʥƥ�ץ졼�ȥ饤�֥��

=head1 SYNOPSIS

use MobaSiF::Template;
$html = MobaSiF::Template::insert($compiled_template_file, $refParamHash);

=head1 ABSTRACT

��������ѥ��뤵�줿�ƥ�ץ졼�ȥХ��ʥ���Ѥ��ƹ�®�ʥƥ�ץ졼�Ƚ�����Ԥ��ޤ����롼�ס����ʬ�����ִ���URL ENCODE, HTMLSPECIALCHARS(+NL2BR) ����ǽ�ˤ��б����Ƥ��ꡢ����Ū��HTML�ƥ�ץ졼�Ȥν������б��Ǥ��ޤ���

=head1 DESCRIPTION

=head1 SEE ALSO

MobaSiF::Template::Compiler

=cut