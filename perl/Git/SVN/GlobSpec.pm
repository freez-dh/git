package Git::SVN::GlobSpec;
use strict;
use warnings;

sub new {
	my ($class, $glob, $pattern_ok) = @_;
	my $re = $glob;
	$re =~ s!/+$!!g; # no need for trailing slashes
	my (@left, @right, @patterns);
	my $state = "left";
	my $die_msg = "Only one set of wildcard directories " .
				"(e.g. '*' or '*/*/*') is supported: '$glob'\n";
	for my $part (split(m|/|, $glob)) {
		if ($part =~ /\*/ && $part ne "*") {
			die "Invalid pattern in '$glob': $part\n";
		} elsif ($pattern_ok && $part =~ /[{}]/ &&
			 $part !~ /^\{[^{}]+\}/) {
			die "Invalid pattern in '$glob': $part\n";
		}
		if ($part eq "*") {
			die $die_msg if $state eq "right";
			$state = "pattern";
			push(@patterns, "[^/]*");
		} elsif ($pattern_ok && $part =~ /^\{(.*)\}$/) {
			die $die_msg if $state eq "right";
			$state = "pattern";
			my $p = quotemeta($1);
			$p =~ s/\\,/|/g;
			push(@patterns, "(?:$p)");
		} else {
			if ($state eq "left") {
				push(@left, $part);
			} else {
				push(@right, $part);
				$state = "right";
			}
		}
	}
	my $depth = @patterns;
	if ($depth == 0) {
		die "One '*' is needed in glob: '$glob'\n";
	}
	my $left = join('/', @left);
	my $right = join('/', @right);
	$re = join('/', @patterns);
	$re = join('\/',
		   grep(length, quotemeta($left), "($re)", quotemeta($right)));
	my $left_re = qr/^\/\Q$left\E(\/|$)/;
	bless { left => $left, right => $right, left_regex => $left_re,
	        regex => qr/$re/, glob => $glob, depth => $depth }, $class;
}

sub full_path {
	my ($self, $path) = @_;
	return (length $self->{left} ? "$self->{left}/" : '') .
	       $path . (length $self->{right} ? "/$self->{right}" : '');
}

1;