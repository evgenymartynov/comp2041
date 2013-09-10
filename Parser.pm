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

  die("expected $exp but got $actual instead;\n ", Dumper(\%actual), "\n", Dumper(\@all_tokens))
      unless $exp eq $actual;

  %tok = %{peek()};
  return \%actual;
}

sub consume {
  my $popped = shift @all_tokens;
  %tok = %{peek()};
  return $popped;
}


sub p_template {
  my @cld = ();
  my %node = (
    'name' => 'templ',
    'cld' => \@cld,
  );


  return \%node;
}


sub p_string {
  my @cld = ();
  my %node = (
    'name' => 'string',
    'cld' => \@cld,
  );

  push @cld, expect('string');

  return \%node;
}

sub p_literal_number {
  my @cld = ();
  my %node = (
    'name' => 'literal_number',
    'cld' => \@cld,
  );

  push @cld, expect('number');

  return \%node;
}

sub p_literal_op {
  my @cld = ();
  my %node = (
    'name' => 'literal_op',
    'cld' => \@cld,
  );

  push @cld, expect('operator');

  return \%node;
}

sub p_arithmetic_expression {
  my @cld = ();
  my %node = (
    'name' => 'arithmetic_expr',
    'cld' => \@cld,
  );

  push @cld, expect('number');

  my $tok_stop = sub {
    my @stops = qw(comma semicolon);
    return $tok{name} ~~ @stops;
  };

  while ( !$tok_stop->() ) {
    if ($tok{name} eq 'number') {
      push @cld, p_literal_number();
    } elsif ($tok{name} eq 'operator') {
      push @cld, p_literal_op();
    } else {
      display(\%tok);
      display(\@all_tokens);
      die "p_arithmetic_expression: not sure what to do with this: ", Dumper(\%tok);
    }
  }

  return \%node;
}

sub p_expression {
  my @cld = ();
  my %node = (
    'name' => 'expression',
    'cld' => \@cld,
  );

  my $tok_stop = sub {
    my @stops = qw(comma semicolon);
    return $tok{name} ~~ @stops;
  };

  while ( !$tok_stop->() ) {
    if ($tok{name} eq 'string') {
      push @cld, p_string();
    } elsif ($tok{name} eq 'number') {
      push @cld, p_arithmetic_expression();
    } else {
      display(\%tok);
      display(\@all_tokens);
      die "p_expression: not sure what to do with this: ", Dumper(\%tok);
    }
  }

  return \%node;
}

sub p_comma_sep_expressions {
  my @cld = ();
  my %node = (
    'name' => 'comma_sep_expr',
    'cld' => \@cld,
  );

  while (1) {
    push @cld, p_expression();

    if ($tok{name} eq 'comma') {
      expect('comma');
    } else {
      last;
    }
  }

  return \%node;
}

sub p_print_statement {
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

  push @cld, expect('comment');

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
      return p_print_statement();
    }
  } elsif ($tok{name} eq 'comment') {
    return p_comment();
  }

  die "p_statement: not sure what to do with this: ", Dumper(\%tok);
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
  print "## Success!\n";
}

1;
