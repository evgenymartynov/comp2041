#!/usr/bin/perl -w

use strict;
use Data::Dumper;

require Parser;

my $pat_space = " \t\n";
my $pat_special = ",;'\"{}()";
my $pat_variable_first = 'A-Za-z_';
my $pat_variable = "${pat_variable_first}0-9";
my $pat_kw = join '|', qw(print shift undef);

my @patterns = (
  { 'type' => 'comment',    're' => qr(#.*\n), 'chomp' => 1 },

  { 'type' => 'string',     're' => '"(\\\.|[^"\\\])*"' },
  { 'type' => 'string',     're' => '\'(\\\.|[^\'\\\])*\'' },

  { 'type' => 'comma',      're' => qr(,) },
  { 'type' => 'semicolon',  're' => qr(;) },
  { 'type' => 'blockbegin', 're' => qr({) },
  { 'type' => 'blockend',   're' => qr(}) },
  { 'type' => 'parenbegin', 're' => '\(' },
  { 'type' => 'parenend',   're' => '\)' },

  { 'type' => 'keyword',    're' => $pat_kw },

  { 'type' => 'number',     're' => '-?[1-9][0-9]*' },
  { 'type' => 'operator',   're' => '[+-/*]' },
  { 'type' => 'scalar',     're' => "\\\$[$pat_variable_first][$pat_variable]*" },

  { 'type' => 'assignment', 're' => '=' },

  { 'type' => 'whitespace', 're' => qr([$pat_space]+) , 'ignore' => 1 },
  { 'type' => 'word',       're' => qr([^$pat_space$pat_special]+) },
);

sub is_terminal_token_type {
  my $type = shift;
  my @terminals = qw(semicolon comment);

  return ($type ~~ @terminals);
}

sub get_next_token {
  my $data = shift;
  my $match = undef;
  my $tok_type = undef;
  my $ignore = 0;
  my $chomp = 0;

  foreach my $pattern__ (@patterns) {
    my %pattern = %$pattern__;

    my $repat = $pattern{re};
    $repat = "^($repat)";
    my $re = qr($repat);

    if ($data =~ $re) {
      $match = $1;
      $tok_type = $pattern{type};
      $ignore = $pattern{ignore};
      $chomp = $pattern{chomp};

      last;
    }
  }

  if (!defined($match)) {
    print "Can't match >>>\n$data\n<<<\n";
    die 'Fix your grammar';
  }

  $data = substr($data, length $match);

  if ($chomp) {
    chomp $match;
  }

  return ($match, $tok_type, $data, $ignore);
}

sub tokenise {
  my $data = shift;
  my @tokens = ();

  while ($data) {
    my ($match, $tok_type, $ignore);
    ($match, $tok_type, $data, $ignore) = get_next_token($data);

    if ($ignore) {
      next;
    }

    push @tokens, {
        'match' => $match,
        'type'  => $tok_type,
    };

    # printf("%12s: %s\n", $tok_type, $match);
  }

  my %eof = ( 'type' => 'eof' );
  push @tokens, \%eof;

  return \@tokens;
}

sub gogo {
  my $tokens__ = shift;
  my @tokens = @$tokens__;
  my @results = ();

  for my $token__ (@tokens) {
    my %token = %$token__;

    if ($token{type} eq 'comment') {
      push @results, $token{match} unless $token{match} =~ '#!/usr/bin/perl';
    } elsif ($token{type} eq 'keyword') {
      push @results, $token{match};
    } elsif ($token{type} eq 'string') {
      push @results, $token{match};
    } elsif ($token{type} eq 'whitespace') {
      my $newlines = $token{match};
      $newlines =~ s/ \t//g;
      push @results, $newlines;
    }
  }

  print (join '', @results);
}

sub translate {
  my $all_tokens__ = shift;
  my @all_tokens = @$all_tokens__;

  print "#!/usr/bin/python2.7 -u\n";

  while (@all_tokens) {
    my @tokens = ();

    while (@all_tokens) {
      my $tok__ = shift @all_tokens;
      my %tok = %$tok__;

      push @tokens, \%tok;

      if (is_terminal_token_type($tok{type})) {
        last;
      }
    }

    gogo(\@tokens);
  }
}

sub parse {
  Parser::parse(@_);
}

my @data = <>;
my $data = join '', @data;

my $tokens__ = tokenise($data);
my @tokens = @$tokens__;
parse(\@tokens);
