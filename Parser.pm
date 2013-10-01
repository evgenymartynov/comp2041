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

sub p_stringify {
  return p_node('stringify', shift);
}

sub p_emit_cheat {
  my ($p2p_builtin, @args) = @_;
  my $ref = p_node('call', @args);
  $ref->{func} = '__p2p_' . $p2p_builtin;
  return $ref;
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
  my @muliplicatives = qw(* / % x);
  return $tok{type} eq 'operator' && $tok{match} ~~ @muliplicatives;
}

sub is_bitwise_shift {
  my @ops = qw(<< >>);
  return $tok{type} eq 'bw-shift' && $tok{match} ~~ @ops;
}

sub is_bitwise_and {
  my @ops = qw(&);
  return $tok{type} eq 'bw-and' && $tok{match} ~~ @ops;
}

sub is_bitwise_ors {
  my @ops = qw(^ |);
  return substr($tok{type}, 0, 3) eq 'bw-' && $tok{match} ~~ @ops;
}

sub is_incdec {
  my @ops = qw(++ --);
  return $tok{type} eq 'operator' && $tok{match} ~~ @ops;
}

sub is_high_precedence_unary {
  my @ops = qw(! ~ \\ + -);
  return $tok{type} eq 'operator' && $tok{match} ~~ @ops;
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
  my $tok = expect('string');
  return interpolate_string($tok);
}

sub p_scalar {
  return p_leafget('scalar');
}

sub p_literal_number {
  return p_leafget('number');
}

sub p_literal_op {
  my $op = $tok{match};
  my $ref = p_leaf('operator', consume());
  $ref->{operator} = $op;
  return $ref;
}

sub p_comment {
  return p_leafget('comment');
}

sub p_simple_value {
  switch ($tok{type}) {
    case 'string'     { return p_string();         }
    case 'number'     { return p_literal_number(); }
    case 'scalar'     { return p_scalar();         }
    case 'parenbegin' { return p_expression_start(); }

    default           {
      display(\@all_tokens);
      die "simple_value: not sure what to do with this: ", Dumper(\%tok);
    }
  }
}

sub p_expression_incdec {
  my $opref;

  if (is_incdec) {
    $opref = {
      'type' => 'operator',
      'operator' => $tok{match},
      'cld' => [],
      'prefix' => 1,
    };
    expect('operator');
  }

  my $node_ref = p_simple_value();

  if (is_incdec) {
    if (defined $opref) {
      die 'Bad prefix/postfix operation: doing both at once';
    }

    $opref = {
      'type' => 'incdec',
      'operator' => $tok{match},
      'cld' => [],
      'postfix' => 1,
    };
    expect('operator');
  }

  if (defined $opref) {
    push $opref->{cld}, $node_ref;
    return $opref;
  }

  return $node_ref;
}

sub p_expression_power {
  my $left_ref = p_expression_incdec();

  if ($tok{type} ne 'operator' || $tok{match} ne '**') {
    return $left_ref;
  }

  expect('operator');

  my %node = %{p_node('power', $left_ref, p_expression_power())};
  $node{operator} = '**';

  return \%node;
}

sub p_expression_high_precedence_unary {
  if (!is_high_precedence_unary) {
    return p_expression_power();
  }

  my $unary = p_literal_op();
  return {
    'type' => 'unary',
    'operator' => $unary,
    'cld' => [ p_expression_high_precedence_unary() ],
  };
}

sub p_mul_expression {
  my $left_ref = p_expression_high_precedence_unary();

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
  my @cld = ( p_mul_expression() );

  while (is_additive) {
    push @cld, p_literal_op();
    push @cld, p_mul_expression();
  }

  if ($#cld > 1) {
    return p_node('foldl', @cld);
  } else {
    return $cld[0];
  }
}

sub p_expression_bitwise_shift {
  my @cld = ( p_add_expression() );

  while (is_bitwise_shift) {
    push @cld, p_literal_op();
    push @cld, p_add_expression();
  }

  if ($#cld > 1) {
    return p_node('foldl', @cld);
  } else {
    return $cld[0];
  }
}

# TODO named unary operators

sub p_expression_relational {
  my $left_ref = p_expression_bitwise_shift();
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
      p_expression_bitwise_shift(),
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
    ],
  };
}

sub p_expression_bitwise_and {
  my @cld = ( p_expression_equality() );

  while (is_bitwise_and) {
    push @cld, p_literal_op();
    push @cld, p_expression_equality();
  }

  if ($#cld > 1) {
    return p_node('foldl', @cld);
  } else {
    return $cld[0];
  }
}

sub p_expression_bitwise_ors {
  my @cld = ( p_expression_bitwise_and() );

  while (is_bitwise_ors) {
    push @cld, p_literal_op();
    push @cld, p_expression_bitwise_and();
  }

  if ($#cld > 1) {
    return p_node('foldl', @cld);
  } else {
    return $cld[0];
  }
}

sub p_expression_logical_and {
  my $left_ref = p_expression_bitwise_ors();
  if ($tok{type} ne 'and') {
    return $left_ref;
  }

  expect('and');
  my $right_ref = p_expression_logical_and();

  return {
    'type' => 'logical',
    'operator' => 'and',
    'cld' => [ $left_ref, $right_ref ],
  };
}

sub p_expression_logical_or {
  my $left_ref = p_expression_logical_and();
  if ($tok{type} ne 'or') {
    return $left_ref;
  }

  expect('or');
  my $right_ref = p_expression_logical_or();

  return {
    'type' => 'logical',
    'operator' => 'or',
    'cld' => [ $left_ref, $right_ref ],
  };
}

# Ternary, ranges , ..., go here.

sub p_expression_assignment {
  my $left_ref = p_expression_logical_or();
  if ($tok{type} ne 'assignment') {
    return $left_ref;
  }

  # Extract the operator from *=, +=, etc.
  my $op = (length($tok{match}) == 2) ? substr($tok{match}, 0, 1) : undef;
  expect('assignment');

  return {
    'type' => 'assignment',
    'operator' => $op,
    'cld' => [
        $left_ref,
        p_expression_assignment(),
    ],
  };
}

sub p_expression_comma {
  my @cld = ( p_expression_assignment() );

  while ($tok{type} eq 'comma') {
    expect('comma');
    push @cld, p_node('comma');
    push @cld, p_expression_assignment();
  }

  return p_node('comma', @cld);
}

sub p_loopcontrol_expression {
  return p_leaf('loop_control', expect('keyword'));
}

sub p_expression_rightward_list_op {
  if ($tok{type} eq 'keyword') {
    given ($tok{match}) {
      when (['print', 'printf']) {
        return p_print_statement();
      }

      when ('if') {
        return p_if_expression();
      }

      when ('while') {
        return p_while_expression();
      }

      when ('for') {
        return p_for_expression();
      }

      when ('foreach') {
        return p_foreach_expression();
      }

      when (['next', 'last']) {   # TODO these need to be moved to the proper spot
        return p_loopcontrol_expression();
      }
    }

    default {
      die 'unknown keyword when parsing rightward list ops ', Dumper(\%tok);
    }
  } else {
    return p_expression_comma();
  }
}

sub p_expression_low_precedence_logical_not {
  if ($tok{type} ne 'not') {
    return p_expression_rightward_list_op();
  }

  expect('lp-not');

  return {
    'type' => 'logical',
    'operator' => 'not',
    'cld' => [
        p_expression_low_precedence_logical_not(),
    ],
  };
}

sub p_expression_low_precedence_logical_and {
  my $left_ref = p_expression_low_precedence_logical_not();
  if ($tok{type} ne 'lp-and') {
    return $left_ref;
  }

  expect('lp-and');

  return {
    'type' => 'logical',
    'operator' => 'and',
    'cld' => [
        $left_ref,
        p_expression_low_precedence_logical_and(),
    ],
  };
}

sub p_expression_low_precedence_logical_ors {
  my $left_ref = p_expression_low_precedence_logical_and();
  my @ops = qw(lp-or lp-xor);

  if (!($tok{type} ~~ @ops)) {
    return $left_ref;
  }

  my $op = substr ${consume()}{type}, 3;  # drop the "lp-"

  my @cld = (
    $left_ref,
    p_expression_low_precedence_logical_ors(),
  );

  return {
    'type' => 'logical',
    'operator' => $op,
    'cld' => \@cld,
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
      push @cld, p_expression_low_precedence_logical_ors();
    }

    when ('parenbegin') {
      expect('parenbegin');
      my $expression_ref = p_expression();
      expect('parenend');

      push @cld, $expression_ref;
    }

    default {
      display(\%tok);
      display(\@all_tokens);
      die ${node}{type} . ": not sure what to do with this: ", Dumper(\%tok);
    }
  }

  return $cld[0];
}

sub p_expression_funcargs_inner {
  return p_expression_comma();
}

sub p_expression_funcargs {
  my $gobble = $tok{type} eq 'parenbegin';

  expect('parenbegin') if $gobble;
  my $ref = p_expression_funcargs_inner();
  expect('parenend') if $gobble;

  return $ref;
}

sub p_print_statement {
  my $func = $tok{match};
  expect('keyword');

  my $args = p_expression_funcargs();
  return p_emit_cheat($func, $args);
}

sub p_expression_start {
  my $gobble = $tok{type} eq 'parenbegin';

  expect('parenbegin') if $gobble;
  my $expression_ref = p_expression_low_precedence_logical_ors();
  expect('parenend') if $gobble;

  $expression_ref = p_parenthesise($expression_ref) if $gobble;

  return $expression_ref;
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
  expect('keyword');
  return p_if_expression_internal();
}

sub p_if_expression_internal {
  my $condition_ref = p_expression();
  my $if_true = p_body_expression();
  my $if_false = undef;

  if ($tok{type} eq 'keyword' && $tok{match} eq 'else') {
    expect('keyword');
    $if_false = p_body_expression();
  } elsif ($tok{type} eq 'keyword' && $tok{match} eq 'elsif') {
    expect('keyword');

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
  expect('keyword');

  my $condition_ref = p_expression();
  my $body_ref = p_body_expression();

  return p_node('while_expr', $condition_ref, $body_ref);
}

sub p_for_expression {
  expect('keyword');
  expect('parenbegin');

  my @cld = ();
  push @cld, p_expression_start(); expect('semicolon');
  push @cld, p_expression_start(); expect('semicolon');
  push @cld, p_expression_start();

  expect('parenend');

  my $body_ref = p_body_expression();
  return p_node('for_expr', @cld, $body_ref);
}

sub p_foreach_expression {
  expect('keyword');

  my $iterator_ref = p_scalar();
  my $range_ref = p_expression();
  my $body_ref = p_body_expression();

  return p_node('foreach_expr', $iterator_ref, $range_ref, $body_ref);
}

sub p_statement {
  my $result_ref = p_expression_start();

  if ($tok{type} eq 'semicolon') {
    expect('semicolon');
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
    if ($tok{type} eq 'comment') {
      push @cld, p_comment();
    } else {
      push @cld, p_statement();
    }
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
