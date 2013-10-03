package Lexer;
use strict;

my $pat_space = " \t\n";
my $pat_special = ",;'\"{}()";
my $pat_variable = '0-9A-Za-z_';
my $pat_kw = join '|', qw(
    print printf
    if unless else elsif while for foreach
    next last
);

my $pat_var_type = '\$|@|%';

my $pat_named_unaries = join '|', qw(chomp pop shift);
my $pat_list_operators = join '|', qw(split join push unshift sort reverse keys);

my $pat_regexp_comparison = '=~|!~';
my $pat_regexp_body = '/(\\\.|[^/\\\])*/';

my $pat_comparisons = join '|', qw(<= >= == != < >);
my $pat_operators = join '|', qw(\+ - \*\* / % \* x \.);

my @patterns = (
  { 'type' => 'comment',    're' => qr(#.*\n), 'chomp' => 1 },

  { 'type' => 'string',     're' => '"(\\\.|[^"\\\])*"' },
  { 'type' => 'string',     're' => '\'(\\\.|[^\'\\\])*\'' },

  { 'type' => 'comma',      're' => qr(,|=>) },
  { 'type' => 'semicolon',  're' => qr(;) },
  { 'type' => 'blockbegin', 're' => qr({) },
  { 'type' => 'blockend',   're' => qr(}) },
  { 'type' => 'parenbegin', 're' => '\(' },
  { 'type' => 'parenend',   're' => '\)' },
  { 'type' => 'arraybegin', 're' => '\[' },
  { 'type' => 'arrayend',   're' => '\]' },

  { 'type' => 'keyword',    're' => qr(\b($pat_kw)\b) },
  { 'type' => 'named_unary','re' => qr(\b($pat_named_unaries)\b) },
  { 'type' => 'list_op',    're' => qr(\b($pat_list_operators)\b) },

  { 'type' => 'range',      're' => '\.\.' },

  { 'type' => 'bw-shift',   're' => qr(<<|>>) },

  { 'type' => 'regexp_comparison', 're' => $pat_regexp_comparison },
  { 'type' => 'regexp',     're' => 'm?' . $pat_regexp_body },

  { 'type' => 'comparison', 're' => $pat_comparisons },
  { 'type' => 'assignment', 're' => qr(($pat_operators)=) },
  { 'type' => 'assignment', 're' => '=' },

  { 'type' => 'number',     're' => qr(-?([1-9][0-9]*|0)\b) },
  { 'type' => 'variable',   're' => "($pat_var_type)#?[$pat_variable]+" },
  { 'type' => 'operator',   're' => '\+\+|--|' . $pat_operators },

  { 'type' => 'string-rel', 're' => qr(\b(le|lt|ge|gt)\b) },
  { 'type' => 'string-eq',  're' => qr(\b(eq|ne)\b) },

  { 'type' => 'operator',   're' => qr(!) },
  { 'type' => 'and',        're' => qr(\&\&) },
  { 'type' => 'or',         're' => qr(\|\|) },

  { 'type' => 'operator',   're' => qr(~) },
  { 'type' => 'bw-and',     're' => qr(&) },
  { 'type' => 'bw-or',      're' => qr(\|) },
  { 'type' => 'bw-xor',     're' => qr(\^) },

  { 'type' => 'lp-not',     're' => qr(\bnot\b) },
  { 'type' => 'lp-and',     're' => qr(\band\b) },
  { 'type' => 'lp-or',      're' => qr(\bor\b) },
  { 'type' => 'lp-xor',     're' => qr(\bxor\b) },

  { 'type' => 'whitespace', 're' => qr([$pat_space]+) , 'ignore' => 1 },
  { 'type' => 'word',       're' => qr(\b[^$pat_space$pat_special]+\b) },
);

sub get_next_token {
  my ($data, $match, $tok_type, $ignore, $chomp) = (shift, undef, undef, 0, 0);

  foreach my $pattern (@patterns) {
    my $re = qr(^($pattern->{re}));  # Only match tokens at start of the line

    if ($data =~ $re) {
      $match = $1;
      $tok_type = $pattern->{type};
      $ignore = $pattern->{ignore};
      $chomp = $pattern->{chomp};

      last;
    }
  }

  if (!defined($match)) {
    print "Can't match >>>\n$data\n<<<\n";
    die 'Fix your grammar';
  }

  $data = substr($data, length $match);  # Skip over the token just matched

  chomp $match if $chomp;
  return ($match, $tok_type, $data, $ignore);
}

sub lex {
  my $data = shift;
  my @tokens = ();

  while ($data) {
    my ($match, $tok_type, $ignore);
    ($match, $tok_type, $data, $ignore) = get_next_token($data);

    push @tokens, {
        'match' => $match,
        'type'  => $tok_type,
    } unless $ignore;
  }

  push @tokens, { 'type' => 'eof' };

  return \@tokens;
}

1;
