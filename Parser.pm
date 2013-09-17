package Parser;

use strict;
use Data::Dumper;
use Switch;

use feature qw(switch);

our (@all_tokens, %tok, %strop_to_cmpop);

%strop_to_cmpop = (
  'eq' => '==',
  'ne' => '!=',
  'lt' => '<',
  'le' => '<=',
  'gt' => '>',
  'ge' => '>=',
);

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

sub p_parenthesise {
  return p_node('parenthesise', @_);
}

sub pinternal_printfmt {
  my $fmt_ref = shift;
  my $variadic_ref = shift;

  my @modulo_args = ($fmt_ref, p_parenthesise($variadic_ref));

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

sub is_relational {
  my @ops = qw(< > <= >= le lt ge gt);
  return $tok{match} ~~ @ops;
}

sub is_equality {
  my @ops = qw(== != eq ne);
  return $tok{match} ~~ @ops;
}

sub is_additive {
  my @additives = qw(+ -);
  return $tok{type} eq 'operator' && $tok{match} ~~ @additives;
}

sub is_multiplicative {
  my @muliplicatives = qw(* / ** %);
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
  my $last_text_fragment = undef;

  while (@fragments) {
    my $text = shift @fragments;
    my $var  = shift @fragments;

    push @cld, p_node_with_value('string', $text) if $text;
    push @cld, p_stringify(p_node_with_value('scalar', $var)) if defined($var);

    $last_text_fragment = defined($var) ? undef : $text;
  }

  # Does this string have EOL?
  if ($last_text_fragment =~ /\\n$/) {  # TODO: breaks if \\\\\\n.
    ${$cld[$#cld]}{eol} = 1;
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

sub p_file_descriptor_caps {
  return p_leafget('filedes');
}

sub p_file_descriptor {
  return $tok{type} eq 'scalar' ? p_scalar() : p_file_descriptor_caps();
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

sub p_literal_comparison {
  return p_leafget('comparison');
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
  my $left_ref = p_simple_value();

  if (!is_multiplicative) {
    return $left_ref;
  }

  my %op = %{p_literal_op()};
  my $right_ref = p_mul_expression();

  my %node = %{p_node('mul_expr', $left_ref, $right_ref)};
  $node{operator} = ${op}{value};

  return \%node;
}

sub p_add_expression {
  my $left_ref = p_mul_expression();

  if (!is_additive) {
    return $left_ref;
  }

  my %op = %{p_literal_op()};
  my $right_ref = p_add_expression();

  my %node = %{p_node('add_expr', $left_ref, $right_ref)};
  $node{operator} = ${op}{value};

  return \%node;
}

sub p_comparison_expression {
  my $left_ref = p_add_expression();

  if ($tok{type} ne 'comparison') {
    return $left_ref;
  }

  my %op = %{p_literal_comparison()};
  my $right_ref = p_mul_expression();

  my %node = %{p_node('comparison', $left_ref, $right_ref)};
  $node{operator} = ${op}{value};

  return \%node;
}

sub p_range_expression {
  my $left_ref = p_comparison_expression();

  if ($tok{type} ne 'range') {
    return $left_ref;
  }

  expect('range');
  my $right_incl_ref = p_comparison_expression();

  # Fix up incl/excl ranges
  my $right_excl_ref = p_node('add_expr', $right_incl_ref, p_node_with_value('number', '1'));
  ${$right_excl_ref}{operator} = '+';

  return p_node('range', $left_ref, $right_excl_ref);
}

sub p_expression_todo {
  if ($tok{type} eq 'string') {
    return p_string();
  }

  return p_range_expression();
}

sub p_expression_relational {
  my $left_ref = p_expression_todo();
  if (!is_relational) {
    return $left_ref;
  }

  my $op = ${consume()}{match};
  $op = $strop_to_cmpop{$op} // $op;

  return {
    'type' => 'comparison',
    'operator' => $op,
    'cld' => [
      $left_ref,
      p_expression_todo(),
    ]
  };
}

sub p_expression_equality {
  my $left_ref = p_expression_relational();
  if (!is_equality) {
    return $left_ref;
  }

  my $op = ${consume()}{match};
  $op = $strop_to_cmpop{$op} // $op;

  return {
    'type' => 'comparison',
    'operator' => $op,
    'cld' => [
      $left_ref,
      p_expression_relational(),
    ]
  };
}

sub p_expression {
  my @cld = ();
  my %node = (
    'type' => 'expression',
    'cld' => \@cld,
  );

  given ($tok{type}) {
    when (['string', 'number', 'scalar']) {
      push @cld, p_expression_equality();
    }

    when ('parenbegin') {
      expect('parenbegin');
      my $expression_ref = p_expression();
      expect('parenend');

      push @cld, $expression_ref;
    }

    when ('comparison' && $tok{match} eq '<') {
      return p_file_read();
    }

    default {
      display(\%tok);
      display(\@all_tokens);
      die ${node}{type} . ": not sure what to do with this: ", Dumper(\%tok);
    }
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
    } elsif ($tok{type} eq 'semicolon' || $tok{type} eq 'blockend') {
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

  if (is_assignment) {
    my $assignment_ref = p_literal_assignment();
    my $rvalue_ref = p_assignment();

    return p_node('assign', $lvalue_ref, $rvalue_ref);
  } else {
    return $lvalue_ref;
  }
}

sub p_body_expression {
  my @cld = ();
  my %node = (
    'type' => 'body',
    'cld' => \@cld,
  );

  expect('blockbegin');

  while ($tok{type} ne 'blockend') {
    my $node_ref = p_statement();
    push @cld, $node_ref;
  }

  expect('blockend');

  return \%node;
}

sub p_if_expression {
  expect('if');
  return p_if_expression_internal();
}

sub p_if_expression_internal {
  my $condition_ref = p_expression();
  my $if_true = p_body_expression();
  my $if_false = undef;

  if ($tok{type} eq 'else') {
    expect('else');
    $if_false = p_body_expression();
  } elsif ($tok{type} eq 'elsif') {
    expect('elsif');

    my $nested = p_if_expression_internal();

    my @ffs = ($nested);

    my %elsif = (
      'type' => 'body',
      'cld' => \@ffs,
    );

    $if_false = \%elsif;
  }

  return p_node('if_expr', $condition_ref, $if_true, $if_false);
}

sub p_while_expression {
  expect('while');

  my $condition_ref = p_expression();
  my $body_ref = p_body_expression();

  return p_node('while_expr', $condition_ref, $body_ref);
}

sub p_foreach_expression {
  expect('foreach');

  my $iterator_ref = p_scalar();
  my $range_ref = p_expression();
  my $body_ref = p_body_expression();

  return p_node('foreach_expr', $iterator_ref, $range_ref, $body_ref);
}

sub p_file_read {
  my @cld = ();
  my %node = (
    'type' => 'file_read',
    'cld' => \@cld,
  );

  if ($tok{match} ne '<') {
      display(\%tok);
      display(\@all_tokens);
      die "p_file_read: not sure what to do with this: ", Dumper(\%tok);
  }
  expect('comparison');

  if ($tok{type} ne 'comparison') {
    push @cld, p_file_descriptor();
  }

  if ($tok{match} ne '>') {
      display(\%tok);
      display(\@all_tokens);
      die "p_file_read: not sure what to do with this: ", Dumper(\%tok);
  }
  expect('comparison');

  return \%node;
}

sub p_statement {
  my $result_ref = undef;

  given ($tok{type}) {
    when ('comment') {
      return p_comment();
    }

    when ('keyword') {
      given ($tok{match}) {
        when ('print')    {
          $result_ref = p_print_statement();
        }

        when ('printf')   {
          $result_ref = p_printfmt_statement();
        }

        default         {
          die "Forgot to catch a keyword :(";
        }
      }
    }

    when ('if') {
      return p_if_expression();
    }

    when ('while') {
      return p_while_expression();
    }

    when ('foreach') {
      return p_foreach_expression();
    }

    when ('blockend') {
      return;
    }

    default             {
      $result_ref = p_assignment();
    }
  }

  given ($tok{type}) {
    when ('semicolon') {
      expect('semicolon');
    }

    when ('blockend') {
      break;
    }

    default {
      die 'Expected semicolon or block end, got this instead: ', display(\%tok);;
    }
  }

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
