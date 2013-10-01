package Lexer;
use strict;

my $pat_space = " \t\n";
my $pat_special = ",;'\"{}()";
my $pat_variable_first = 'A-Za-z_';
my $pat_variable = "${pat_variable_first}0-9";
my $pat_kw = join '|', qw(
    print printf shift undef
    if else elsif while for foreach
    next last
);

my $pat_comparisons = join '|', qw(<= >= == != < >);

my $pat_operators = join '|', qw(\+ - \*\* / % \* x \.); # TODO add logicals

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

  { 'type' => 'range',      're' => '\.\.' },

  { 'type' => 'comparison', 're' => $pat_comparisons },
  { 'type' => 'assignment', 're' => qr(($pat_operators)=) },
  { 'type' => 'assignment', 're' => '=' },

  { 'type' => 'number',     're' => qr(-?([1-9][0-9]*|0)\b) },
  { 'type' => 'operator',   're' => '\+\+|--|' . $pat_operators },
  { 'type' => 'scalar',     're' => "\\\$[$pat_variable_first][$pat_variable]*" },

  { 'type' => 'string-rel', 're' => qr(\b(le|lt|ge|gt)\b) },
  { 'type' => 'string-eq',  're' => qr(\b(eq|ne)\b) },

  { 'type' => 'not',        're' => qr(!) },
  { 'type' => 'and',        're' => qr(\&\&) },
  { 'type' => 'or',         're' => qr(\|\|) },

  { 'type' => 'lp-not',     're' => qr(\bnot\b) },
  { 'type' => 'lp-and',     're' => qr(\band\b) },
  { 'type' => 'lp-or',      're' => qr(\bor\b) },
  { 'type' => 'lp-xor',     're' => qr(\bxor\b) },

  { 'type' => 'filedes',    're' => qr(\bSTDIN\b) },

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
