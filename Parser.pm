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
  my $actual = %actual ? $actual{type} : 'eof';

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
  return $tok{type} ~~ @expression_terminators;
}

sub is_additive {
  my @additives = qw(+ -);
  return $tok{type} eq 'operator' && $tok{match} ~~ @additives;
}

sub is_multiplicative {
  my @muliplicatives = qw(* /);
  return $tok{type} eq 'operator' && $tok{match} ~~ @muliplicatives;
}

sub is_assignment {
  my @assignments = qw(=);
  return $tok{type} eq 'assignment' && $tok{match} ~~ @assignments;
}


sub p_leaf {
  my %node = (
    'type' => shift,
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
    'type' => 'templ',
    'cld' => \@cld,
  );


  return \%node;
}


sub p_apply_operator {
  my @cld = ();
  my %node = (
    'type' => 'apply_operator',
    'cld' => \@cld,
  );

  push @cld, shift;
  push @cld, shift;
  push @cld, shift;

  return \%node;
}

sub p_string {
  return p_leafget('string');
}

sub p_literal_number {
  return p_leafget('number');
}

sub p_literal_assignment {
  return p_leafget('assignment');
}

sub p_literal_op {
  return p_leafget('operator');
}

sub p_comment {
  return p_leafget('comment');
}

sub p_mul_expression {
  my @cld = ();
  my %node = (
    'type' => 'mul_expr',
    'cld' => \@cld,
  );

  my $left_ref = p_literal_number();

  while (is_multiplicative) {
    my $op_ref = p_literal_op();
    my $right_ref = p_literal_number();

    push @cld, p_apply_operator($op_ref, $left_ref, $right_ref);
  }

  if (!@cld) {
    push @cld, $left_ref;
  }

  return \%node;
}

sub p_add_expression {
  my @cld = ();
  my %node = (
    'type' => 'add_expr',
    'cld' => \@cld,
  );

  my $left_ref = p_mul_expression();

  while (is_additive) {
    my $op_ref = p_literal_op();
    my $right_ref = p_mul_expression();

    push @cld, p_apply_operator($op_ref, $left_ref, $right_ref);
  }

  if (!@cld) {
    push @cld, $left_ref;
  }

  return \%node;
}

sub p_arithmetic_expression {
  my @cld = ();
  my %node = (
    'type' => 'arithmetic_expr',
    'cld' => \@cld,
  );

  do {
    if ($tok{type} eq 'number') {
      push @cld, p_add_expression();
    } else {
      display(\%tok);
      display(\@all_tokens);
      die ${node}{type} . ": not sure what to do with this: ", Dumper(\%tok);
    }
  } while (!is_expression_end);

  return \%node;
}

sub p_expression {
  my @cld = ();
  my %node = (
    'type' => 'expression',
    'cld' => \@cld,
  );

  while (!is_expression_end) {
    if ($tok{type} eq 'string') {
      push @cld, p_string();
    } elsif ($tok{type} eq 'number') {
      push @cld, p_arithmetic_expression();
    } else {
      display(\%tok);
      display(\@all_tokens);
      die ${node}{type} . ": not sure what to do with this: ", Dumper(\%tok);
    }
  }

  return \%node;
}

sub p_comma_sep_expressions {
  my @cld = ();
  my %node = (
    'type' => 'comma_sep_expr',
    'cld' => \@cld,
  );

  while (1) {
    push @cld, p_expression();

    if ($tok{type} eq 'comma') {
      expect('comma');
    } elsif ($tok{type} eq 'semicolon') {
      last;
    }
  }

  return \%node;
}

sub p_print_statement {
  my @cld = ();
  my %node = (
    'type' => 'print_expr',
    'cld' => \@cld,
  );

  expect('keyword');
  push @cld, p_comma_sep_expressions();

  return \%node;
}

sub p_value {
  if ($tok{type} eq 'scalar') {
    return p_leafget('scalar');
  } else {
    return p_expression();
  }
}

sub p_assignment {
  my $lvalue_ref = p_value();
  if (!is_assignment) {
    return $lvalue_ref;
  }

  my $assignment_ref = p_literal_assignment();
  my $rvalue_ref = p_assignment();

  return p_apply_operator($assignment_ref, $lvalue_ref, $rvalue_ref);
}

sub p_statement {
  my $result_ref = undef;

  if ($tok{type} eq 'comment') {
    # No need to do anything else here
    return p_comment();
  }

  if ($tok{type} eq 'keyword') {
    if ($tok{match} eq 'print') {
      $result_ref = p_print_statement();
    }
  } else {
    $result_ref = p_assignment();
  }

  expect('semicolon');

  if (defined($result_ref)) {
    return $result_ref;
  }

  die "statement: not sure what to do with this: ", Dumper(\%tok);
}

sub p_program {
  my @cld = ();
  my %node = (
    'type' => 'program',
    'cld' => \@cld,
  );

  while ($tok{type} ne 'eof') {
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

  return \%tree;
}

1;
