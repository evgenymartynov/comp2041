package StringInterpolator;

use strict;
use Data::Dumper;
use feature qw(switch);

sub display {
  local $Data::Dumper::Terse = 1;
  $_ = Dumper(@_);
  print;
}

our $pat_sigil = '\$@';
our $pat_identifier = 'A-Za-z0-9_';

our @rules = (
  [ 'identifier' => qr{\G
        [$pat_sigil]
        \#?              # This lets us do e.g. "$#list"
        [$pat_identifier]+
      }x
  ],

  [ 'open'    => qr/\G({|\[)/ ],
  [ 'close'   => qr/\G(}|])/ ],

  [ 'integer' => qr{\G[0-9]+}x ],

  # Basically everything else, incl. newlines
  [ 'string'  => qr{\G(
        \\.                 # Backslashes should escape
        |                   # ...or not
        [^$pat_sigil\]\}]   # if not, stop at sigils or closing brackets
        |
        \$$                 # Or a dollar at the end
      )+}xs
  ],
);

sub lex {
  my $input = shift;
  my @tokens = ();
  my $matched = 1;

  while ($matched) {
    $matched = 0;

    foreach my $rule (@rules) {
      my ($type, $re) = @{$rule};

      next if ($input !~ /$re/gc);
      push @tokens, { 'type' => $type, 'match' => $& };
      $matched = 1;
    }
  }

  return @tokens;
}

sub mknode {
  return {
    'type' => shift,
    'value' => shift,
  };
}

sub wrap_ref {
  my ($type, $node) = @_;
  my %copy = %{$node};

  %{$node} = (
    'type' => $type,
    'cld' => [ \%copy ],
  );
}

# NOTE: mutual recursion w/parse()
sub parse_accessors {
  my $tokens = shift;
  my @cld = ();

  while ($tokens->[0]->{type} eq 'open') {
    # Perl does not allow using raw [ inside {} and v.v. as a string
    my $bracket = shift @{$tokens};

    push @cld, parse($tokens, 1);
    # parse() consumes the closing brace so don't shift here

    # Check if we are inside {} -- then force str()
    if ($bracket->{match} eq '{' && $cld[-1]->{type} eq 'number') {
      $cld[-1]->{type} = 'string';
    }
  }

  return \@cld;
}

# NOTE: Takes in a reference which is consumed with recursion
sub parse {
  my ($tokens, $not_toplevel) = @_;
  my @cld = ();

OUTER:
  while (my $tok = shift @{$tokens}) {
    given ($tok->{type}) {
      when ('identifier') {
        push @cld, {
            'type' => 'variable',
            'value' => substr($tok->{match}, 1),
            'context' => substr($tok->{match}, 0, 1),
            'cld' => parse_accessors($tokens),
        };
      }

      when ('close') {
        last OUTER if $not_toplevel;
        push @cld, mknode('string', $tok->{match});
      }

      when ('integer') {
        push @cld, mknode('number', $tok->{match});
      }

      # We include more types here as at this point they are not part of the
      # interpolated string. However, close might be.
      when (['string', 'integer', 'open']) {
        my $value = $tok->{match};
        $value =~ s/\\([$pat_sigil])/$1/g;
        push @cld, mknode('string', $value);
      }
    }
  }

  if (!$not_toplevel) {
    foreach my $child (@cld) {
      if ($child->{type} ne 'string') {
        wrap_ref('stringify', $child);
      }
    }

    return {
      'type' => 'comma_sep_string_concat',
      'cld' => \@cld,
    };
  }

  return @cld;
}

sub interpolate_string {
  my ($input, $mark_as_raw) = @_;
  my @tokens = lex($input);
  my $node = parse(\@tokens);

  if ($mark_as_raw) {
    foreach my $child (@{$node->{cld}}) {
      $child->{raw_string} = 1 if $child->{type} eq 'string';
    }
  }

  if (!$#{$node->{cld}}) {
    return $node->{cld}->[0];
  }

  return $node;
}

1;
