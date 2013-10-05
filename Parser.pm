package Parser;

use strict;
use Data::Dumper;
use TryTiny;
use feature qw(switch);

our (@all_tokens, %tok, @current_statement);

sub display {
  local $Data::Dumper::Terse = 1;
  $_ = Dumper(@_);
  print;
}

sub peek {
  die "Out of tokens" if !@all_tokens;
  return $all_tokens[0];
}

sub parser_skip_to_next_statement {
  my ($exp, $type) = @_;

  my $comment = "# Parser error: expeted $exp got $type: " .
      join ' ', (map { $_->{match} } @current_statement);
  return {
    'type' => 'comment',
    'value' => $comment,
  };
}

sub expect {
  my $exp = shift;
  my $actual = shift @all_tokens;
  my $type = defined($actual) ? $actual->{type} : 'eof';

  if ($exp ne $type) {
    die parser_skip_to_next_statement($exp, $type);
  }

  %tok = %{peek()};
  return $actual;
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
  my @ops = qw(+ - .);
  return $tok{type} eq 'operator' && $tok{match} ~~ @ops;
}

sub is_multiplicative {
  my @ops = qw(* / % x);
  return $tok{type} eq 'operator' && $tok{match} ~~ @ops;
}

sub is_named_unary {
  return $tok{type} eq 'named_unary';
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

sub is_low_prec_logical_ors {
  my @ops = qw(lp-xor lp-or);
  return $tok{type} ~~ @ops;
}

sub p_leaf {
  return {
    'type' => shift,
    'value' => ${shift @_}{match},
  };
}

sub p_leafget {
  my $type = shift;
  return p_leaf($type, expect($type));
}

sub p_node {
  my ($type, @cld) = @_;
  return {
    'type' => $type,
    'cld' => \@cld,
  };
}

sub p_node_with_value {
  my ($type, $value) = @_;
  return {
    'type' => $type,
    'cld' => [],
    'value' => $value,
  };
}

# Does not operate on the global %tok.
sub interpolate_string {
  my @cld = ();
  my $node = {
    'type' => 'comma_sep_string_concat',
    'cld' => \@cld,
  };

  my $tok = shift;
  my $quoted_string = $tok->{match};
  my $string = substr $quoted_string, 1, -1;

  # Empty string?
  if (!$string) {
    return p_node_with_value('string', '');
  }

  my $is_raw = ($quoted_string =~ /^'/);
  if ($is_raw) {
    my %raw_node = %{p_node_with_value('string', $string)};
    $raw_node{raw_string} = 1;

    push @cld, \%raw_node;

    return $node;
  }

  # At this point, we know we have to do it :(
  actually_interpolate($string);
}

sub actually_interpolate {
  my ($string, $force_raw) = @_;

  my @cld = ();
  my $node = {
    'type' => 'comma_sep_string_concat',
    'cld' => \@cld,
  };

  my $id_regex = qr((((\$|@)\w+)({[^]]+}|\[[A-Za-z0-9_]+\])?)); # Capture group makes split return seps too
  my @fragments = split $id_regex, $string;
  my $last_text_fragment = undef;

  # Every second and fourth capgroup are garbage: ignore them
  my @temp = ();
  while (@fragments) {
    push @temp, shift @fragments;
    shift @fragments;
    push @temp, shift @fragments;
    shift @fragments;
    push @temp, shift @fragments;
  }
  @fragments = @temp;

  # Combine fragments if they end with a backslash (that must escape the sigil)
  @temp = ();
  while (@fragments) {
    my $str = shift @fragments;
    my $var = shift @fragments;
    my $acs = shift @fragments;

    if (substr($str, -1) eq '\\') {
      unshift @fragments, ($str . $var . ($acs || '') . (shift @fragments));
    } else {
      push @temp, $str, $var, $acs;
    }
  }
  @fragments = @temp;

  while (@fragments) {
    my $text = shift @fragments;
    my $var  = shift @fragments;
    my $accessors = shift @fragments;

    push @cld, p_node_with_value('string', $text) if $text;
    if ($text && $force_raw) { $cld[-1]->{'raw_string'} = 1; }
    push @cld, p_stringify(p_variable_from_string($var, $accessors)) if defined($var);

    $last_text_fragment = defined($var) ? undef : $text;
  }

  if ($#cld == 0) {  # Bloody perl
    return $cld[0];
  }

  return $node;
}

sub p_string {
  my $tok = expect('string');
  return interpolate_string($tok);
}

sub p_literal_number {
  return p_leafget('number');
}

sub p_regexp {
  my $match = expect('regexp')->{match};
  if ($match !~ m#^m#) {
    $match = "m$match";
  }
  $match = substr $match, 2, -1;  # Strip the m/ and /

  return p_node('regexp', actually_interpolate($match, 1));
}

sub p_subtitution {
  return p_leafget('substitute');
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

sub p_func_call {
  my $func = $tok{match};
  consume();

  # This is not a func per se
  if ($func eq 'return') {
    my $node = p_node('call', p_expression_funcargs());
    $node->{func} = 'return';
    return $node;
  }

  return p_emit_cheat($func, p_expression_funcargs());
}

sub p_variable_from_string {
  my $var = shift;
  my $accessors = shift;
  my $prefix = substr $var, 0, 1;
  my $name = substr $var, 1;
  my @cld = ();

  while ($accessors) {
    given (substr $accessors, 0, 1) {
      when ('[') {
        my $acs = $accessors;
        $acs =~ s/^\[([^]]*)\].*/$1/;
        push @cld, { 'type' => 'number', 'value' => $acs};
        $accessors = substr($accessors, (length $acs)+2);
      }

      when ('{') {
        my $acs = $accessors;
        $acs =~ s/^{([^}]*)}.*/$1/;
        push @cld, { 'type' => 'string', 'value' => $acs};
        $accessors = substr($accessors, (length $acs)+2);
      }

      default {
        push @cld, { 'type' => 'string', 'value' => 'wat'};
      }
    }
  }

  my $node = p_node('variable');
  $node->{value} = $name;
  $node->{context} = $prefix;
  $node->{cld} = \@cld;
  return $node;
}

sub p_variable {
  my ($prefix, $name) = split '', expect('variable')->{match}, 2;
  my @accessors = ();

  # Special case: $#list
  if ($prefix eq '$' && substr($name, 0, 1) eq '#') {
    return p_node_with_value('last_item_index', substr($name, 1));
  }

  while ($tok{type} ~~ [ 'blockbegin', 'arraybegin' ]) {
    my $type = $tok{type};
    expect($type);

    if ($tok{type} eq 'word') {
      # Using $hash{bareword} form of the hash
      my @list = ();
      push @list, consume()->{match} until $tok{type} eq 'blockend';

      push @accessors, p_node_with_value('string', join ' ', @list);
    } else {
      push @accessors, p_expression_start();
    }

    $type =~ s/begin/end/;
    expect($type);
  }

  my $node = p_node('variable', @accessors);
  $node->{value} = $name;
  $node->{context} = $prefix;
  return $node;
}

sub p_function_call {
  my $func = substr $tok{match}, 1;
  expect('function');

  my $empty = { 'type' => 'empty', 'cld' => [] };

  my $args = peek()->{type} eq 'semicolon' ? $empty : p_expression_funcargs();

  return {
    'type' => 'call',
    'func' => $func,
    'cld' => [ $args ]
  };
}

sub p_simple_value {
  given ($tok{type}) {
    when ('comment')    { return p_comment();       }
    when ('variable')   { return p_variable();       }
    when ('string')     { return p_string();         }
    when ('number')     { return p_literal_number(); }
    when ('function')   { return p_function_call();  }
    when ('regexp')     { return p_regexp(); }
    when ('substitute') { return p_subtitution(); }
    when ('parenbegin') { return p_expression_start(); }
    when ('arraybegin') { return p_expression_start(); }
    when ('blockbegin') { return p_expression_start(); }
    when ('list_op')    { return p_func_call(); }

    when ('parenend')   { return { 'type' => 'empty', 'cld' => [] }; }

    default           {
      die parser_skip_to_next_statement('simple value', $tok{type});
    }
  }
}

# I don't care about cases like ++$x++ for two reasons:
# 1) The behaviour is undefined by Perl anyway
# 2) It makes my life hard
#
# Thus we translate ++$x into ($x += 1), and $x++ is handled by the
# postprocessor. If both appear, ++$x overrides the postfix version.
sub p_expression_incdec {
  if (is_incdec) {
    my $op = expect('operator')->{match};
    my $node_ref = p_simple_value();

    return {
      'type' => 'foldl',
      'cld' => [
        $node_ref,
        { 'type' => 'operator', 'value' => substr($op, 0, 1) },
        { 'type' => 'number', 'value' => '1' },
      ],
    };
  }

  my $node_ref = p_simple_value();

  if (is_incdec) {
    my $opref = {
      'type' => 'incdec',
      'operator' => $tok{match},
      'cld' => [ $node_ref ],
    };

    expect('operator');
    return $opref;
  }

  return $node_ref;
}

sub p_expression_power {
  my $left_ref = p_expression_incdec();
  return $left_ref unless ($tok{type} eq 'operator' && $tok{match} eq '**');

  expect('operator');

  my $node = p_node('power', $left_ref, p_expression_power());
  $node->{operator} = '**';

  return $node;
}

sub p_expression_high_precedence_unary {
  return p_expression_power() unless is_high_precedence_unary;

  my $unary = p_literal_op();
  return {
    'type' => 'unary',
    'operator' => $unary,
    'cld' => [ p_expression_high_precedence_unary() ],
  };
}

sub p_expression_regexp_comparison {
  my $left = p_expression_high_precedence_unary();

  while ($tok{type} eq 'regexp_comparison') {
    $left = {
      'type' => 'regex_match',
      'operator' => p_literal_op()->{operator},
      'cld' => [ $left, p_expression_high_precedence_unary() ],
    };
  }

  return $left;
}

sub p_mul_expression {
  my @cld = ( p_expression_regexp_comparison() );

  while (is_multiplicative) {
    push @cld, p_literal_op();
    push @cld, p_expression_regexp_comparison();
  }

  if ($#cld) {
    return p_node('foldl', @cld);
  } else {
    return $cld[0];
  }
}

sub p_add_expression {
  my @cld = ( p_mul_expression() );

  while (is_additive) {
    push @cld, p_literal_op();
    push @cld, p_mul_expression();
  }

  if ($#cld) {
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

  if ($#cld) {
    return p_node('foldl', @cld);
  } else {
    return $cld[0];
  }
}

sub p_expression_named_unary {
  return p_expression_bitwise_shift unless is_named_unary;

  my $func = $tok{match};
  expect('named_unary');
  my $arg = p_expression_bitwise_shift();

  if ($func eq 'chomp') {
    return p_node('assignment', $arg, p_emit_cheat($func, $arg));
  }

  return p_emit_cheat($func, $arg);
}

sub p_expression_io {
  expect('comparison');

  # Check for null filehandle
  if ($tok{type} eq 'comparison' && $tok{match} eq '>') {
    expect('comparison');
    return p_emit_cheat('io_null');
  }

  # Check for bareword filehandle
  if ($tok{type} eq 'word') {
    my $ref = p_node_with_value('io', consume()->{match});
    expect('comparison');
    return $ref;
  }

  # Okay, assume variable/scalar.
  my $fd = p_expression_named_unary();
  expect('comparison');

  return p_node('io', $fd);
}

sub p_expression_relational {
  # Try I/O.
  return p_expression_io() if ($tok{type} eq 'comparison' && $tok{match} eq '<');

  my $left_ref = p_expression_named_unary();
  return $left_ref unless is_relational;

  my $op = consume()->{match};
  my $right_ref = p_expression_named_unary();

  return {
    'type' => 'comparison',
    'operator' => $op,
    'cld' => [
      $left_ref,
      $right_ref,
    ]
  };
}

sub p_expression_equality {
  my $left_ref = p_expression_relational();
  return $left_ref unless is_equality;

  my $op = consume()->{match};
  my $right_ref = p_expression_named_unary();

  return {
    'type' => 'comparison',
    'operator' => $op,
    'cld' => [
      $left_ref,
      $right_ref,
    ],
  };
}

sub p_expression_bitwise_and {
  my @cld = ( p_expression_equality() );

  while (is_bitwise_and) {
    push @cld, p_literal_op();
    push @cld, p_expression_equality();
  }

  if ($#cld) {
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

  if ($#cld) {
    return p_node('foldl', @cld);
  } else {
    return $cld[0];
  }
}

sub p_expression_logical_and {
  my $left_ref = p_expression_bitwise_ors();
  return $left_ref unless $tok{type} eq 'and';

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
  return $left_ref unless $tok{type} eq 'or';

  expect('or');
  my $right_ref = p_expression_logical_or();

  return {
    'type' => 'logical',
    'operator' => 'or',
    'cld' => [ $left_ref, $right_ref ],
  };
}

sub p_expression_range {
  my $left_ref = p_expression_logical_or();
  return $left_ref unless $tok{type} eq 'range';

  expect('range');
  my $right_ref = p_expression_logical_or();

  return {
    'type' => 'range',
    'cld' => [ $left_ref, $right_ref ],
  };
}

# Ternaries go here

sub p_expression_assignment {
  my $left_ref = p_expression_range();
  return $left_ref unless $tok{type} eq 'assignment';

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

sub p_expression_loopcontrol {
  if ($tok{match} ~~ ['next', 'last']) {
    return p_loopcontrol_expression();
  } else {
    return p_expression_assignment();
  }
}

sub p_expression_comma {
  my @cld = ( p_expression_loopcontrol() );

  while ($tok{type} eq 'comma') {
    expect('comma');
    push @cld, p_node('comma');
    push @cld, p_expression_loopcontrol();
  }

  if ($#cld) {
    return p_node('comma', @cld);
  } else {
    return $cld[0];
  }
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
    }
  }

  # Default case
  return p_expression_comma();
}

sub p_expression_low_precedence_logical_not {
  return p_expression_rightward_list_op() unless $tok{type} eq 'lp-not';

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
  return $left_ref unless $tok{type} eq 'lp-and';

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
  return $left_ref unless is_low_prec_logical_ors;

  return {
    'type' => 'logical',
    'operator' => substr(${consume()}{type}, 3),  # drop the "lp-"
    'cld' => [
      $left_ref,
      p_expression_low_precedence_logical_ors(),
    ],
  };
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

sub p_expression_postfix_conditionals {
  my $body_ref = p_expression_low_precedence_logical_ors();
  return $body_ref
      if ($tok{type} ne 'keyword' || $body_ref->{type} eq 'comment');

  given ($tok{match}) {
    when (['if', 'unless']) {
      my $negate = $tok{match} eq 'unless';
      expect('keyword');

      my $condition = p_expression_start();
      if ($negate) {
        $condition = {
          'type' => 'unary',
          'operator' => { 'value' => '!' },
          'cld' => [ $condition ],
        };
      }

      $body_ref = {
        'type' => 'body',
        'cld' => [ $body_ref ],
      };

      return {
        'type' => 'if_expr',
        'cld' => [
          $condition,
          $body_ref,
        ],
      };
    }

    default {
      return $body_ref;
    }
  }
}

sub p_expression_start {
  my $type = $tok{type};
  my $gobble = $type ~~ ['parenbegin', 'arraybegin', 'blockbegin'];

  # Safeguard against empty expressions (i.e. ;;;;)
  if ($tok{type} eq 'semicolon') {
    return { 'type' => 'empty', 'cld' => [] };
  }

  expect($type) if $gobble;

  my $expression_ref = p_expression_postfix_conditionals();

  $type =~ s/begin/end/;
  expect($type) if $gobble;

  if ($gobble) {
    $expression_ref = p_parenthesise($expression_ref);
    $expression_ref->{type} = 'array_initialise' if $type eq 'arrayend';
    $expression_ref->{type} = 'hash_initialise' if $type eq 'blockend';
  }

  return $expression_ref;
}

sub p_expression_function {
  expect('keyword');

  my $name = expect('word')->{match};

  if ($tok{type} eq 'parenbegin') {
    consume() until $tok{type} eq 'blockbegin';
  }

  my $body = p_body_expression();

  return {
    'type' => 'function',
    'name' => $name,
    'cld' => [ $body ],
  };
}

sub p_expression_controlstructure {
  if ($tok{type} eq 'keyword') {
    given ($tok{match}) {
      when (['if', 'unless']) {
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

      when ('sub') {
        return p_expression_function();
      }
    }
  }

  # Default case
  return p_expression_start();
}

sub p_body_expression {
  my $node = {
    'type' => 'body',
    'cld' => [],
  };

  expect('blockbegin');

  while ($tok{type} ne 'blockend') {
    push @{$node->{cld}}, p_statement();
  }

  expect('blockend');

  return $node;
}

sub p_if_expression {
  my $negate = $tok{match} eq 'unless';
  expect('keyword');
  return p_if_expression_internal($negate);
}

sub p_if_expression_internal {
  my $negate = shift;
  my $condition_ref = p_expression_start();
  my $if_true = p_body_expression();
  my $if_false = undef;

  if ($negate) {
    $condition_ref = {
      'type' => 'unary',
      'operator' => { 'value' => '!' },
      'cld' => [ $condition_ref ],
    };
  }

  if ($tok{type} eq 'keyword' && $tok{match} eq 'else') {
    expect('keyword');
    $if_false = p_body_expression();
  } elsif ($tok{type} eq 'keyword' && $tok{match} eq 'elsif') {
    expect('keyword');

    $if_false = {
      'type' => 'body',
      'cld' => [ p_if_expression_internal() ],
    };
  }

  return p_node('if_expr', $condition_ref, $if_true, $if_false);
}

sub p_while_expression {
  expect('keyword');

  my $condition_ref = p_expression_start();
  my $body_ref = p_body_expression();

  return p_node('while_expr', $condition_ref, $body_ref);
}

sub p_for_expression {
  expect('keyword');
  expect('parenbegin');

  my $initialis = p_expression_start(); expect('semicolon');
  my $condition = p_expression_start(); expect('semicolon');
  my $post_op = p_expression_start();

  if ($condition->{type} eq 'empty') {
    $condition = p_node_with_value('number', '1');
  }

  my @cld = ($initialis, $condition);

  expect('parenend');

  my $body_ref = p_body_expression();
  push @{$body_ref->{cld}}, $post_op;

  return p_node('for_expr', @cld, $body_ref);
}

sub p_foreach_expression {
  expect('keyword');

  my $iterator_ref = p_variable();
  return p_node('foreach_expr',
      $iterator_ref,
      p_expression_start(),
      p_body_expression());
}

sub p_statement {
  @current_statement = ();
  foreach my $ref (@all_tokens) {
    push @current_statement, $ref;
    if (!exists($ref->{type}) || $ref->{type} ~~ ['blockbegin', 'blockend', 'semicolon', 'eof']) {
      last;
    }
  }

  my $result_ref;
  try {
    $result_ref = p_expression_controlstructure();
  } catch {
    my $error = $_;

    try {
      my %node = %{$error};
      $result_ref = \%node;

      consume() while
          !($tok{type} ~~ ['blockbegin', 'blockend', 'semicolon', 'eof']);
    } catch {
      print "Internal error:\n";
      die $error;
    }
  };

  consume() if $tok{type} eq 'semicolon';

  return $result_ref if defined $result_ref;
  die "statement: got undef as result of parsing; tokens: ", Dumper(\%tok);
}

sub p_program {
  my $node = {
    'type' => 'program',
    'cld' => [],
  };

  while ($tok{type} ne 'eof') {
    push @{$node->{cld}}, p_statement();
  }

  return $node;
}


sub parse {
  @all_tokens = @{shift @_};
  @current_statement = ();
  %tok = %{peek()};

  # display(\@all_tokens);

  my $tree = p_program();
  # display($tree);
  print "## Parsed!\n";

  return $tree;
}

1;
