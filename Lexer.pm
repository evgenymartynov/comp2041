package Lexer;
use strict;

my $pat_space = " \t\n";
my $pat_special = ",;'\"{}()";
my $pat_variable_first = 'A-Za-z_';
my $pat_variable = "${pat_variable_first}0-9";
my $pat_kw = join '|', qw(print printf shift undef);
my $pat_comparisons = join '|', qw(<= >= == != < >);

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

  { 'type' => 'keyword',    're' => qr(\b($pat_kw)\b) },
  { 'type' => 'if',         're' => qr(\bif\b) },
  { 'type' => 'else',       're' => qr(\belse\b) },
  { 'type' => 'elsif',      're' => qr(\belsif\b) },
  { 'type' => 'while',      're' => qr(\bwhile\b) },
  { 'type' => 'foreach',    're' => qr(\bforeach\b) },

  { 'type' => 'range',      're' => '\.\.' },

  { 'type' => 'number',     're' => qr(-?([1-9][0-9]*|0)\b) },
  { 'type' => 'operator',   're' => '\*\*|[+-/*%]' },
  { 'type' => 'scalar',     're' => "\\\$[$pat_variable_first][$pat_variable]*" },

  { 'type' => 'comparison', 're' => $pat_comparisons },
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

sub lex {
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

1;
