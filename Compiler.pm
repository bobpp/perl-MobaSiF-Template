package MobaSiF::Template::Compiler;

use 5.008;
use strict;
use FileHandle;
use constant {
	
	# ������ID
	
	TYPE_PLAIN   => 1,
	TYPE_REPLACE => 2,
	TYPE_LOOP    => 3,
	TYPE_IF      => 4,
	TYPE_ELSE    => 5,
	TYPE_QSA     => 6,
	TYPE_LB      => 253,
	TYPE_RB      => 254,
	TYPE_END     => 255,
	
	# ���ץ������
	
	O_ENCODE => 1, # url encode
	O_HSCHRS => 2, # htmlspecialchars
	O_NL2BR  => 4, # nl2br
	O_SUBSTR => 8, # substr
	
	# �ǥ�ߥ�
	
	DELIM_OR  => '\\|+',
	DELIM_AND => '\\&+',
	
	# ��勵����
	
	COND_EQ => 0,
	COND_NE => 1,
	COND_GT => 2,
	COND_GE => 3,
	COND_LT => 4,
	COND_LE => 5,
	
	# ����¾
	
	TRUE  => 1,
	FALSE => 0,
};

our $VERSION = '0.03';

#---------------------------------------------------------------------

sub loadTemplate {
	my ($in) = @_;
	
	my $tpl;
	if (ref($in)) {
		# �ե�����̾�ǤϤʤ���ʸ���󻲾Ȥ�������������
		$tpl = ${$in};
	} else {
		my $fh = new FileHandle;
		open($fh, $in) || die "Can't find template $in\n";
		$tpl = join('', <$fh>);
		close($fh);
	}
	return _parseTemplate(\$tpl);
}

sub _parseTemplate {
	my ($rTpl) = @_;
	my $i;
	
	my @parts;
	my $pos = 0;
	
	# Vodafone ��ʸ��(SJIS)���ƥ�ץ�����äƤ����
	# ���ƶ���Ϳ����ΤǤ��ä��󥨥�������
	
	my $voda_esc1  = chr(0x1B).chr(0x24);
	my $voda_esc2  = chr(0x0F);
	my $voda_esc_q = quotemeta($voda_esc1). '(.*?)'. quotemeta($voda_esc2);
	
	${$rTpl} =~ s($voda_esc_q) {
		my $in = $1;
		$in =~ s/./unpack('H2',$&)/eg;
		('%%ESC%%'. $in. '%%/ESC%%');
	}eg;
	
	${$rTpl} =~ s(\t*\$(\s*([\=\{\}]|if|loop|/?qsa|.)[^\$]*)\$\t*|[^\$]+) {
		if (!(my $cmd = $1)) {
			
			#-----------------
			# PLAIN
			
			my $text = $&;
			$text =~ s(\%\%ESC\%\%(.*?)\%\%/ESC\%\%) {
				my $in = $1;
				$in =~ s/[a-f\d]{2}/pack("C", hex($&))/egi;
				($voda_esc1. $in. $voda_esc2);
			}eg;
			push(@parts, { type => TYPE_PLAIN, text => $text }); $pos++;
			
		} else {
			
			my $cmd_orig = $cmd;
			$cmd =~ s/\s+//g;
			
			#-----------------
			# REPLACE
			
			if ($cmd =~ /^\=((b|e|h|hn)\:)?/i) {
				my ($l, $o, $key) = ('', "$2", "$'");
				
				die "no replace type '$cmd_orig'\n" if ($o eq '');
				
				my $opt = 0;
				$opt = O_ENCODE            if ($o eq 'e');
				$opt = O_HSCHRS            if ($o eq 'h');
				$opt = O_HSCHRS | O_NL2BR  if ($o eq 'hn');
				
				push(@parts, { type => TYPE_REPLACE,
					key => $key, opt => $opt }); $pos++;
			}
			
			#-----------------
			# LOOP
			
			elsif ($cmd =~ /^loop\(([^\)]+)\)\{$/i) {
				my $key = $1;
				push(@parts, { type => TYPE_LOOP,
					key => $key, loopend => $pos + 1 }); $pos++;
				push(@parts, { type => TYPE_LB }); $pos++;
			}
			
			#-----------------
			# [ELS]IF -> [RB + ELSE +] IF + LB
			
			elsif ($cmd =~ /^(\}els)?if\(([^\)]+)\)\{$/i) {
				my $else = $1;
				my $cond = $2;
				my $delim = ($cond =~ /\|/) ? DELIM_OR : DELIM_AND;
				my @p = split($delim, $cond);
				my $ofs_next = scalar(@p);
				
				if ($else) {
					$ofs_next++;
					push(@parts, { type => TYPE_RB }); $pos++;
					push(@parts, { type => TYPE_ELSE,
						ontrue => $pos + 1, onfalse => $pos + $ofs_next });
					$pos++; $ofs_next--;
				}
				for my $p (@p) {
					if ($delim eq DELIM_AND) {
						push(@parts, { type => TYPE_IF,
							ontrue => $pos + 1, onfalse => $pos + $ofs_next,
							cond => $p });
					} else {
						push(@parts, { type => TYPE_IF,
							ontrue => $pos + $ofs_next, onfalse => $pos + 1,
							cond => $p });
					}
					$pos++; $ofs_next--;
				}
				push(@parts, { type => TYPE_LB }); $pos++;
			}
			
			#-----------------
			# ELSE -> RB + ELSE + LB
			
			elsif ($cmd =~ /^\}else\{$/i) {
				push(@parts, { type => TYPE_RB }); $pos++;
				push(@parts, { type => TYPE_ELSE,
					ontrue => $pos + 1, onfalse => $pos + 1 }); $pos++;
				push(@parts, { type => TYPE_LB }); $pos++;
			}
			
			#-----------------
			# RB
			
			elsif ($cmd =~ /^\}$/i) {
				push(@parts, { type => TYPE_RB }); $pos++;
			}
			
			#-----------------
			# QSA
			
			elsif ($cmd =~ /^(\/)?qsa$/i) {
				push(@parts, { type => TYPE_QSA, inout => $1 ? 1 : 0 }); $pos++;
			}
			
			#-----------------
			# ERROR
			
			else {
				die "Unknown command \$$cmd_orig\$\n";
			}
		}
	}egisx;
	push(@parts, { type => TYPE_END });
	
	if (${$rTpl} =~ /\$/) {
		die "unmatched '\$' found\n";
	}
	
	# ��̤��б��ط�������
	
	$i = 0;
	my @stack;
	for my $raPart (@parts) {
		if ($raPart->{type} == TYPE_LB) {
			push(@stack, $i);
		}
		elsif ($raPart->{type} == TYPE_RB) {
			$parts[pop(@stack)]->{rbpos} = $i;
		}
		$i++;
	}
	
	# �ƾ�����������������������
	
	for my $raPart (@parts) {
		if ($raPart->{type} == TYPE_IF ||
		    $raPart->{type} == TYPE_ELSE) {
			if ($parts[$raPart->{onfalse}]->{type} == TYPE_LB) {
				$raPart->{onfalse} =
					$parts[$raPart->{onfalse}]->{rbpos};
			}
		} elsif ($raPart->{type} == TYPE_LOOP) {
			$raPart->{loopend} =
				$parts[$raPart->{loopend}]->{rbpos};
			$parts[$raPart->{loopend}]->{type} = TYPE_END;
		}
	}
	
	# ��̤��б��ط�������å�
	
	{
		my $lv = 1;
		for my $raPart (@parts) {
			if ($raPart->{type} == TYPE_LB) {
				$lv++;
			} elsif
				($raPart->{type} == TYPE_RB ||
			     $raPart->{type} == TYPE_END ) {
				$lv--;
				if ($lv < 0) {
					die "unmatched {}\n";
				}
			}
		}
		if ($lv != 0) {
			die "unmatched {}\n";
		}
	}
	
	# �����������
	
	for my $raPart (@parts) {
		if ($raPart->{type} == TYPE_IF) {
			my $cond_str = $raPart->{cond};
			if      ($cond_str =~ />(\=)?/) {
				my $val = int($');
				$raPart->{condkey} = $`;
				$raPart->{condval} = $val;
				$raPart->{condtyp} = $1 ? COND_GE : COND_GT;
			} elsif ($cond_str =~ /<(\=)?/) {
				my $val = int($');
				$raPart->{condkey} = $`;
				$raPart->{condval} = $val;
				$raPart->{condtyp} = $1 ? COND_LE : COND_LT;
			} elsif ($cond_str =~ /^\!/) {
				$raPart->{condkey} = $';
				$raPart->{condval} = '';
				$raPart->{condtyp} = COND_EQ;
			} elsif ($cond_str =~ /(\!)?==?/) {
				$raPart->{condkey} = $`;
				$raPart->{condval} = $';
				$raPart->{condtyp} = $1 ? COND_NE : COND_EQ;
			} else {
				$raPart->{condkey} = $cond_str;
				$raPart->{condval} = '';
				$raPart->{condtyp} = COND_NE;
			}
		}
	}
	
	return(\@parts);
}

#=====================================================================
#                       �Х��ʥ�ƥ�ץ졼������
#=====================================================================

sub compile {
	my ($in, $out_file) = @_;
	
	my $raParts = loadTemplate($in);
	
	# �ԥ��ե��åȤη׻�
	
	{
		my $ofs = 0;
		for my $raPart (@{$raParts}) {
			$raPart->{ofs} = $ofs;
			
			my $type = $raPart->{type};
			if    ( $type == TYPE_PLAIN   ) { $ofs += 8;  }
			elsif ( $type == TYPE_REPLACE ) { $ofs += 12; }
			elsif ( $type == TYPE_IF      ) { $ofs += 24; }
			elsif ( $type == TYPE_ELSE    ) { $ofs += 12; }
			elsif ( $type == TYPE_LOOP    ) { $ofs += 12; }
			elsif ( $type == TYPE_QSA     ) { $ofs += 8;  }
			elsif ( $type == TYPE_LB      ) { $ofs += 4;  }
			elsif ( $type == TYPE_RB      ) { $ofs += 4;  }
			elsif ( $type == TYPE_END     ) { $ofs += 4;  }
		}
	}
	
	# �������軲�Ȱ��֤ν���
	
	{
		for my $raPart (@{$raParts}) {
			my $type = $raPart->{type};
			if ($type == TYPE_LOOP) {
				$raPart->{loopend} = $raParts->[ $raPart->{loopend} ]->{ofs};
			}
			elsif ($type == TYPE_IF) {
				$raPart->{ontrue}  = $raParts->[ $raPart->{ontrue}  ]->{ofs};
				$raPart->{onfalse} = $raParts->[ $raPart->{onfalse} ]->{ofs};
			}
			elsif ($type == TYPE_ELSE) {
				$raPart->{ontrue}  = $raParts->[ $raPart->{ontrue}  ]->{ofs};
				$raPart->{onfalse} = $raParts->[ $raPart->{onfalse} ]->{ofs};
			}
		}
	}
	
	# ʸ���󻲾ȥХåե����֤�����
	
	my $strBuf = "";
	my %strPos = ();
	for my $raPart (@{$raParts}) {
		my $type = $raPart->{type};
		if ($type == TYPE_PLAIN) {
			$raPart->{text} =
				useStringPos(\$strBuf, \%strPos, $raPart->{text});
		}
		elsif ($type == TYPE_REPLACE) {
			$raPart->{key} =
				useStringPos(\$strBuf, \%strPos, $raPart->{key});
		}
		elsif ($type == TYPE_IF) {
			$raPart->{condkey} =
				useStringPos(\$strBuf, \%strPos, $raPart->{condkey});
			if ($raPart->{condtyp} == COND_EQ ||
				$raPart->{condtyp} == COND_NE) {
				$raPart->{condval} =
					useStringPos(\$strBuf, \%strPos, $raPart->{condval});
			}
		}
		elsif ($type == TYPE_LOOP) {
			$raPart->{key} =
				useStringPos(\$strBuf, \%strPos, $raPart->{key});
		}
	}
	
	# ����
	
	if ($out_file) {
		my $fh = new FileHandle;
		my $bin = makeBinTemplate($raParts, \$strBuf);
		open($fh, ">$out_file") || die "Can't open $out_file";
		print $fh $bin;
		close($fh);
	} else {
		debugBinTemplate($raParts, \$strBuf);
	}
}

sub useStringPos {
	my ($rStrBuf, $rhStrPos, $str) = @_;
	
	if (exists($rhStrPos->{$str})) {
		return($rhStrPos->{$str});
	}
	my $newPos = length(${$rStrBuf});
	$rhStrPos->{$str} = $newPos;
	${$rStrBuf} .= ($str. chr(0));
	return($newPos);
}

#-------------------------
# �Х��ʥ경

sub makeBinTemplate {
	my ($raParts, $rStrBuf) = @_;
	my $bin = '';
	
	for my $raPart (@{$raParts}) {
		my $type = $raPart->{type};
		
		if ($type == TYPE_PLAIN) {
			$bin .= pack('LL', $type,
				$raPart->{text});
		}
		elsif ($type == TYPE_REPLACE) {
			$bin .= pack('LLL', $type,
				$raPart->{key},
				$raPart->{opt});
		}
		elsif ($type == TYPE_LOOP) {
			$bin .= pack('LLL', $type,
				$raPart->{key},
				$raPart->{loopend});
		}
		elsif ($type == TYPE_IF) {
			$bin .= pack('LLLLLL', $type,
				$raPart->{ontrue},
				$raPart->{onfalse},
				$raPart->{condkey},
				$raPart->{condval},
				$raPart->{condtyp});
		}
		elsif ($type == TYPE_ELSE) {
			$bin .= pack('LLL', $type,
				$raPart->{ontrue},
				$raPart->{onfalse});
		}
		elsif ($type == TYPE_QSA) {
			$bin .= pack('LL', $type, $raPart->{inout});
		}
		elsif ($type == TYPE_LB) {
			$bin .= pack('L', $type);
		}
		elsif ($type == TYPE_RB) {
			$bin .= pack('L', $type);
		}
		elsif ($type == TYPE_END) {
			$bin .= pack('L', $type);
		}
		else {
			die "unknown type ($type)\n";
		}
	}
	return(pack('L', length($bin)). $bin. ${$rStrBuf});
}

#-------------------------
# �ƥ�ץ졼�Ȥβ��Ϸ�̤ΥǥХå�����

sub debugBinTemplate {
	my ($raParts, $rStrBuf) = @_;
	
	print "     :{\n";
	for my $raPart (@{$raParts}) {
		my $type = $raPart->{type};
		
		printf("%5d:", $raPart->{ofs});
		
		if ($type == TYPE_PLAIN) {
			my $s = _debug_getString($rStrBuf, $raPart->{text});
			$s =~ s/\s+/ /g;
			print qq|"$s"|;
		}
		elsif ($type == TYPE_REPLACE) {
			my @opt;
			push(@opt, "e") if ($raPart->{opt} & O_ENCODE);
			push(@opt, "h") if ($raPart->{opt} & O_HSCHRS);
			push(@opt, "n") if ($raPart->{opt} & O_NL2BR);
			my $opt = scalar(@opt) ? join ('', @opt) : '';
			my $s = _debug_getString($rStrBuf, $raPart->{key});
			print qq|=$opt:$s|;
		}
		elsif ($type == TYPE_LOOP) {
			my $s = _debug_getString($rStrBuf, $raPart->{key});
			print qq|loop (\@$s) loopend L$raPart->{loopend}|;
		}
		elsif ($type == TYPE_IF) {
			my $cmp = '';
			$cmp = '==' if ($raPart->{condtyp} == COND_EQ);
			$cmp = '!=' if ($raPart->{condtyp} == COND_NE);
			$cmp = '>'  if ($raPart->{condtyp} == COND_GT);
			$cmp = '<'  if ($raPart->{condtyp} == COND_LT);
			$cmp = '>=' if ($raPart->{condtyp} == COND_GE);
			$cmp = '<=' if ($raPart->{condtyp} == COND_LE);
			my $s1 = _debug_getString($rStrBuf, $raPart->{condkey});
			my $s2 = $raPart->{condval};
			my $s2 =
				($raPart->{condtyp} == COND_EQ ||
				 $raPart->{condtyp} == COND_NE) ?
				 "'". _debug_getString($rStrBuf, $raPart->{condval}). "'" :
				 $raPart->{condval};
			print qq|if ( $s1 $cmp $s2 ) L$raPart->{ontrue} else L$raPart->{onfalse}|;
		}
		elsif ($type == TYPE_ELSE) {
			print qq|if ( PREV_COND_IS_FALSE ) L$raPart->{ontrue} else L$raPart->{onfalse}|;
		}
		elsif ($type == TYPE_LB) {
			print qq|{|;
		}
		elsif ($type == TYPE_RB) {
			print qq|}|;
		}
		elsif ($type == TYPE_END) {
			print qq|} END|;
		}
		print "\n";
	}
}
sub _debug_getString {
	my ($rStrBuf, $pos) = @_;
	my $str = substr(${$rStrBuf}, $pos);
	my $delim = chr(0);
	$str = $` if ($str =~ /$delim/);
	return($str);
}

#=====================================================================

1;

__END__

=encoding euc-jp

=head1 NAME

MobaSiF::Template::Compiler - Template compiler for MobaSiF::Template

=head1 SYNOPSIS

  use MobaSiF::Template::Compiler;
  MobaSiF::Template::Compiler::compile($in, $out_file);
  
=head1 DESCRIPTION

  MobaSiF::Template::Compiler::compile($in_file, $out_file);
  
    $in �򥳥�ѥ��뤷�� $out_file �˥Х��ʥ�ƥ�ץ졼�Ȥ���Ϥ��ޤ���
    $out_file ����ꤷ�ʤ��ȡ��ǥХå����Ϥ�ɽ������ޤ���
    $in �ˤϡ��ե�����̾��ʸ����ؤλ��Ȥ��Ϥ����Ȥ��Ǥ��ޤ���
  
=head1 �ƥ�ץ졼�Ȥν�

�� �ִ����ޥ��

$={b|e|h|hn}:NAME$
  
  NAME ���ؤ��ѥ�᡼���ͤ��ִ����ޤ���
  �ʲ��Τ����줫���Ѵ���ˡ����ꤷ�ޤ���
  
  b:    ̵�Ѵ�
  e:    url encode
  h:    htmlspecialchars
  hn:   htmlspecialchars + nl2br

�� �롼�ץ��ޥ��

$ loop (NAME) { $ �� $ } $

  ������ʬ�򷫤��֤��ޤ���
  NAME �ϥϥå���򻲾Ȥ�������ؤλ��Ȥ�ؤ��ޤ���

�� ��拾�ޥ��

$ if (�����) { $
$ } elsif (�����) { $
$ } else { $
$ } $
  
  ���ʬ����Ԥ��ޤ����ͥ��Ȥ��ǽ�Ǥ���
  ������ˤĤ��Ƥξܺ٤ϲ����򻲾ȡ�

=head2 ������ν�

  NAME        : NAME �� "",0,NULL �ʳ��ξ��˿��Ȥʤ�ޤ���
 !NAME        : NAME �� "",0,NULL     �ξ��˿��Ȥʤ�ޤ���
  NAME==VALUE : NAME==VALUE �ξ��˿��Ȥʤ�ޤ���
  NAME!=VALUE : NAME!=VALUE �ξ��˿��Ȥʤ�ޤ���
  COND1 && COND2 && ... and : and ��郎�Ĥʤ����ޤ���
  COND1 || COND2 || ... or  : or  ��郎�Ĥʤ����ޤ���
  
  ���¡�and, or �򺮺ߤ��뤳�ȤϤǤ��ޤ���

=head1 SEE ALSO

MobaSiF::Template

=cut
