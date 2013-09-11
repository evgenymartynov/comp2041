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


sub is_expression_end {
  my @expression_terminators = qw(comma semicolon);
  return $tok{name} ~~ @expression_terminators;
}


sub p_leaf {
  my %node = (
    'name' => shift,
    'value' => ${shift @_}{match},
  );

  return \%node;
}

sub p_leafget {
  my $type = shift;
  return p_leaf($type, expect($type));
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
  return p_leafget('string');
}

sub p_literal_number {
  return p_leafget('number');
}

sub p_literal_op {
  return p_leafget('operator');
}

sub p_arithmetic_expression {
  my @cld = ();
  my %node = (
    'name' => 'arithmetic_expr',
    'cld' => \@cld,
  );

  push @cld, expect('number');

  while (!is_expression_end) {
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

  while (!is_expression_end) {
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
  return p_leafget('comment');
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
