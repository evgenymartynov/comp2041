package Parser;

use strict;
use Data::Dumper;

our (@all_tokens, %tok);

sub display {
  local $Data::Dumper::Terse = 1;
  $_ = Dumper(@_);
  print;
}

sub peek {
  return $all_tokens[0];
}

sub expect {
  my $exp = shift;
  my %actual = %{shift @all_tokens};
  my $actual = %actual ? $actual{name} : 'eof';

  die("expected $exp but got $actual instead;\n ", Dumper(\%actual))
      unless $exp eq $actual;

  %tok = %{peek()};
  1;
}

sub consume {
  my $popped = shift @all_tokens;
  %tok = %{peek()};
  return $popped;
}

sub p_expression {
  my @cld = ();
  my %node = (
    'name' => 'expression',
    'cld' => \@cld,
  );

  my $tok_stop = sub {
    my %tok = %{shift @_};
    my @stops = qw(comma semicolon);
    return $tok{name} ~~ @stops;
  };

  while (!$tok_stop->(\%tok)) {
    push @cld, consume();
  }

  return \%node;
}

sub p_comma_sep_expressions {
  my @cld = ();
  my %node = (
    'name' => 'comma_sep_expr',
    'cld' => \@cld,
  );

  my $tok_stop = sub {
    my %tok = %{shift @_};
    my @stops = qw(semicolon);
    return $tok{name} ~~ @stops;
  };

  while (!$tok_stop->(\%tok)) {
    push @cld, p_expression();
  }

  return \%node;
}

sub p_print_expression {
  my @cld = ();
  my %node = (
    'name' => 'print_expr',
    'cld' => \@cld,
  );

  expect('keyword');
  push @cld, p_comma_sep_expressions();
  expect('semicolon');

  return \%node;
}

sub p_comment {
  my @cld = ();
  my %node = (
    'name' => 'comment',
    'cld' => \@cld,
  );

  push @cld, consume();

  return \%node;
}

sub p_statement {
  my @cld = ();
  my %node = (
    'name' => 'statement',
    'cld' => \@cld,
  );

  if ($tok{name} eq 'keyword') {
    if ($tok{match} eq 'print') {
      return p_print_expression();
    }
  } elsif ($tok{name} eq 'comment') {
    return p_comment();
  }

  die "Not sure what to do with this: ", Dumper(\%tok);
}

sub p_program {
  my @cld = ();
  my %node = (
    'name' => 'program',
    'cld' => \@cld,
  );

  while ($tok{name} ne 'eof') {
    my $node_ref = p_statement();
    push @cld, $node_ref;
  }

  return \%node;
}


sub parse {
  @all_tokens = @{shift @_};
  %tok = %{peek()};

  # display(\@all_tokens);

  my %tree = %{p_program()};
  display(\%tree);
}

1;
