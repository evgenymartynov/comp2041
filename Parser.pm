package Parser;

use strict;
use Data::Dumper;
use Switch;

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

sub pinternal_parenthesise {
  return p_node('parenthesise', @_);
}

sub pinternal_printfmt {
  my $fmt_ref = shift;
  my $variadic_ref = shift;

  my @modulo_args = ($fmt_ref, pinternal_parenthesise($variadic_ref));

  my %modulo = (
    'operator' => '%',
    'type'     => 'mul_expr',
    'cld'      => \@modulo_args,
  );

  my @perl_sucks = ( \%modulo );

  my %print_invocation = (
    'type' => 'print_expr',
    'cld'  => \@perl_sucks,
  );

  return \%print_invocation;
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

sub is_string_type {
  my $type = shift;
  my @string_types = qw(comma_sep_string_concat string);
  return $type ~~ @string_types;
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


sub p_node {
  my $type = shift;
  my @cld = @_;
  my %node = (
    'type' => $type,
    'cld' => \@cld,
  );

  return \%node;
}

sub p_node_with_value {
  my $type = shift;
  my $value = shift;
  my @cld = ();

  my %node = (
    'type' => $type,
    'cld' => \@cld,
    'value' => $value,
  );

  return \%node;
}

# Does not operate on the global %tok.
sub interpolate_string {
  my @cld = ();
  my %node = (
    'type' => 'comma_sep_string_concat',  # Kind of cheating, but eh.
    'cld' => \@cld,
  );

  my %tok = %{shift @_};
  my $quoted_string = $tok{match};
  my $string = substr $quoted_string, 1, -1;

  my $is_raw = ($quoted_string =~ /^'/);
  if ($is_raw) {
    my %raw_node = %{p_node_with_value('string', $string)};
    $raw_node{raw_string} = 1;

    push @cld, \%raw_node;

    return \%node;
  }

  # At this point, we know we have to do it :(

  # Pull out things like /$(?!\d)\w+/
  my $id_regex = qr((\$(?!\d)\w+)); # Capture group makes split return seps too
  my @fragments = split $id_regex, $string;

  while (@fragments) {
    my $text = shift @fragments;
    my $var  = shift @fragments;

    push @cld, p_node_with_value('string', $text) if $text;
    push @cld, p_stringify(p_node_with_value('scalar', $var)) if defined($var);
  }

  return \%node;
}

sub p_string {
  my %tok = %{expect('string')};
  return interpolate_string(\%tok);
}

sub p_scalar {
  return p_leafget('scalar');
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

sub p_simple_value {
  switch ($tok{type}) {
    case 'number'     { return p_literal_number(); }
    case 'scalar'     { return p_scalar();         }

    default           {
      display(\%tok);
      display(\@all_tokens);
      die "simple_value: not sure what to do with this: ", Dumper(\%tok);
    }
  }
}

sub p_mul_expression {
  my @cld = ();
  my %node = (
    'type' => 'mul_expr',
    'operator' => '*',
    'cld' => \@cld,
  );

  my $left_ref = p_simple_value();
  push @cld, $left_ref;

  if (is_multiplicative) {
    my %op = %{p_literal_op()};
    $node{operator} = ${op}{value};
    push @cld, p_mul_expression();
  }

  return \%node;
}

sub p_add_expression {
  my @cld = ();
  my %node = (
    'type' => 'add_expr',
    'operator' => '+',
    'cld' => \@cld,
  );

  my $left_ref = p_mul_expression();
  push @cld, $left_ref;

  if (is_additive) {
    my %op = %{p_literal_op()};
    $node{operator} = ${op}{value};
    push @cld, p_add_expression();
  }

  return \%node;
}

sub p_expression {
  my @cld = ();
  my %node = (
    'type' => 'expression',
    'cld' => \@cld,
  );

  if ($tok{type} eq 'string') {
    push @cld, p_string();
  } elsif ($tok{type} eq 'number' || $tok{type} eq 'scalar') {
    push @cld, p_add_expression();
  } else {
    display(\%tok);
    display(\@all_tokens);
    die ${node}{type} . ": not sure what to do with this: ", Dumper(\%tok);
  }

  return $cld[0];
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

sub p_stringify {
  return p_node('stringify', shift);
}

sub p_comma_separated_string_concatenation {
  my @cld = ();
  my %node = (
    'type' => 'comma_sep_string_concat',
    'cld' => \@cld,
  );

  my $statements = ${p_comma_sep_expressions()}{cld};

  while (my $node_ref = shift @{$statements}) {
    my $type = ${$node_ref}{type};

    if (!is_string_type($type)) {
      push @cld, p_stringify($node_ref);
    } elsif ($type eq 'string') {
      push @cld, interpolate_string($node_ref);
    } else {
      die 'u wot mate' unless is_string_type($type);
      push @cld, $node_ref;
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
  push @cld, p_comma_separated_string_concatenation();

  return \%node;
}

sub p_printfmt_statement {
  expect('keyword');
  my $fmt_ref = p_expression();
  expect('comma');
  my $variadic_ref = p_comma_sep_expressions();

  return pinternal_printfmt($fmt_ref, $variadic_ref);
}

sub p_value {
  if ($tok{type} eq 'scalar') {
    return p_leafget('scalar');
  } else {
    return p_expression();
  }
}

sub p_assignment {
  my $lvalue_ref = p_expression();
  if (!is_assignment) {
    return $lvalue_ref;
  }

  my $assignment_ref = p_literal_assignment();
  my $rvalue_ref = p_assignment();

  return p_node('assign', $lvalue_ref, $rvalue_ref);
}

sub p_statement {
  my $result_ref = undef;

  if ($tok{type} eq 'comment') {
    # No need to do anything else here
    return p_comment();
  }

  if ($tok{type} eq 'keyword') {
    switch ($tok{match}) {
      case 'print'    {
        $result_ref = p_print_statement();
      }

      case 'printf'   {
        $result_ref = p_printfmt_statement();
      }

      default         {
        die "Forgot to catch a keyword :(";
      }
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
  # display(\%tree);
  print "## Parsed!\n";

  return \%tree;
}

1;
