package Compiler;

use strict;
use Data::Dumper;
use feature qw(switch);

our %cs;

sub display {
  local $Data::Dumper::Terse = 1;
  $_ = Dumper(@_);
  print;
}

#
# Emitters
#
# These were meant to assist with cleaning up spaces everywhere, but that turned
# out to be rather hard and brittle. I have left these in here since the code
# reads better with them -- it is much clearer what is being done.
#

sub emit_internal_string {
  my $string = shift;
  die "Trying to emit undefined string :(" unless defined($string);

  $string = "$string ";  # We play it safe and insert spaces everywhere.

  print $string;
}

sub emit_statement_begin {
  print "\n" . ('  ' x $cs{depth});
}

sub emit_constant   { emit_internal_string(shift); }
sub emit_identifier { emit_internal_string(shift); }
sub emit_token      { emit_internal_string(shift); }
sub emit_keyword    { emit_internal_string(shift); }

sub emit_node_value {
  my %node = %{shift @_};

  die("Expecting value inside node ", display(\%node)) unless defined($node{value});
  emit_internal_string($node{value});
}


#
# Type coercers... because perl sucks and you know it.
#

sub get_coercer {
  my $op = shift;
  my @numeric = qw(+ - * / % ** == != < > <= >=);
  my @strings = qw(. x eq ne lt gt le ge);

  if ($op ~~ @numeric) {
    return \&coercer_int;
  } elsif ($op ~~ @strings) {
    return \&coercer_str;
  } else {
    return \&coercer_id;
  }
}

sub coercer_id {
  return @_;
}

sub coercer_int {
  my $ref = shift;
  return ($ref->{type} eq 'number' ? $ref : {
    'type' => 'integrify',
    'cld' => [ $ref ],
  });
}

sub coercer_str {
  my $ref = shift;
  return ($ref->{type} eq 'string' ? $ref : {
    'type' => 'stringify',
    'cld' => [ $ref ],
  });
}


#
# Compiler
#

sub lookup_variable {
  my $var = shift;

  for my $scope (@{$cs{locals}}) {
    return $scope->{$var} if exists $scope->{$var};
  }

  # We didn't find one. Save it in current scope.
  $cs{locals}->[-1]->{$var} = $var;

  return $var;
}

sub lookup_operator {
  my %translations = (
    '!' => 'not',
  );

  my $op = shift;
  return $translations{$op} || $op;
}

sub mk_variable {
  return {
    'type' => 'variable',
    'context' => shift,
    'value' => shift,
  };
}

sub convert_op {
  my $op = shift;
  my %ops = qw(. + x * eq == ne != lt < gt > le <= ge >=);
  return $ops{$op} || $op;
}

sub foldl_nodeopnum {
  my ($node, $op, $num) = @_;

  return {
    'type' => 'foldl',
    'cld' => [
      $node,
      { 'type' => 'operator', 'operator' => $op },
      { 'type' => 'number', 'value' => $num },
    ],
  };
}

sub compile_comment {
  emit_node_value(shift);
}

sub compile_number {
  emit_node_value(shift);
}

sub compile_comma_sep_expr_onlist {
  my $first = 1;
  for my $node_ref (@_) {
    emit_token(",") unless $first;
    $first = 0;

    compile_node($node_ref);
  }
}

sub compile_function_call {
  my ($funcname, @args) = @_;

  emit_identifier($funcname);
  emit_token("(");
  compile_comma_sep_expr_onlist(@args);
  emit_token(")");
}

sub compile_range {
  my $node = shift;
  my ($from_ref, $to_ref) = @{$node->{cld}};

  # In case of ranges, we compile x..$#list to a more natural form of
  #   xrange(x, len(list))
  if ($to_ref->{type} eq 'last_item_index') {
    $to_ref = {
      'type' => 'call',
      'func' => '__len',
      'cld' => [ mk_variable('@', $to_ref->{value}) ],
    };
  } else {
    # Otherwise we have to add one to account for xrange()
    # being inclusive/exclusive.
    $to_ref = foldl_nodeopnum($to_ref, '+', '1');
  }

  compile_function_call('xrange', $from_ref, $to_ref);
}

sub compile_last_item_index {
  my $node = shift;
  my $listname = $node->{value};

  # There comes a moment when you really can't be bothered to make an AST

  compile_node({
    'type' => 'parenthesise',
    'cld' => [ foldl_nodeopnum(
        {
          'type' => 'call',
          'func' => '__len',
          'cld' => [ mk_variable('@', $listname) ],
        },
        '-', 1
    )],
  });
}

sub compile_comma {
  my $node = shift;

  foreach my $child (@{$node->{cld}}) {
    given ($child->{type}) {
      when ('comma') {
        emit_token(',');
      }

      default {
        compile_node($child);
      }
    }
  }
}

sub compile_incdec {
  my $node = shift;
  push $cs{postfix_incdec}, [ $cs{node_depth}, $node ];
}

sub compile_stringify {
  my $node = shift;
  compile_function_call('__str', $node->{cld}->[0]);
}

sub compile_integrify {
  my $node = shift;
  compile_function_call('__int', $node->{cld}->[0]);
}

sub compile_string {
  my $node = shift;

  my $prefix = ($node->{raw_string} ? 'r' : '');
  my $escaped = $node->{value};
  $escaped =~ s/'/\\'/g;

  emit_identifier("$prefix'$escaped'");
}

sub compile_variable {
  my $node = shift;
  emit_identifier(lookup_variable($node->{value}));

  for my $child (@{$node->{cld}}) {
    emit_token('[');
    compile_node($child);
    emit_token(']');
  }
}

sub compile_call {
  my $node = shift;

  my $func = $node->{func};
  emit_identifier($func);
  emit_token("(");
  compile_node($node->{cld}->[0]) if defined $node->{cld}->[0];
  emit_token(")");
}

sub compile_io {
  my $node = shift;

  if (exists $node->{value}) {
    emit_identifier('__p2p_io');
    emit_token("(");
    emit_identifier(lookup_variable($node->{value}));
    emit_token(")");
  } elsif (length @{$node->{cld}}) {
    die 'TODO scalar fd';
  }
}

sub compile_comma_sep_expr {
  my $node = shift;
  compile_comma_sep_expr_onlist(@{$node->{cld}});
}

sub compile_comma_sep_string_concat {
  my $node = shift;

  my $first = 1;
  foreach my $child (@{$node->{cld}}) {
    emit_token("+") unless $first;
    $first = 0;

    compile_node($child);
  }
}

sub compile_assignment {
  my $node = shift;
  my ($lvalue_ref, $rvalue_ref) = @{$node->{cld}};

  compile_node($lvalue_ref);
  emit_token(($node->{operator} || '') . '=');
  compile_node($rvalue_ref);
}

sub compile_parenthesise {
  my $node = shift;

  emit_token('(');
  for my $child (@{$node->{cld}}) {
    compile_node($child);
  }
  emit_token(')');
}

sub compile_foldl {
  my $node = shift @_;
  my @cld = @{$node->{cld}};

  my $coercer = ($#cld ? get_coercer($cld[1]->{operator}) : &coercer_id);

  foreach my $item (@cld) {
    given ($item->{type}) {
      when ('operator') {
        emit_token($item->{operator});
      }

      default {
        compile_node($coercer->($item));
      }
    }
  }
}

sub compile_unary {
  my $node = shift;
  my $ref = $node->{cld}->[0];

  emit_token(lookup_operator($node->{operator}->{value}));
  emit_token('(');
  compile_node($ref);
  emit_token(')');
}

sub compile_binary_op_expr {
  my $node = shift;
  my $lop_ref = shift $node->{cld};
  my $rop_ref = shift $node->{cld};
  my $coercer = get_coercer($node->{operator});

  emit_token('(');
  compile_node($coercer->($lop_ref));

  while (defined($rop_ref)) {
    emit_token(convert_op($node->{operator}));
    compile_node($coercer->($rop_ref));

    $rop_ref = shift $node->{cld};
  }

  emit_token(')');
}

sub compile_if {
  my $node = shift;
  my ($cond_ref, $true_ref, $false_ref) = @{$node->{cld}};

  emit_keyword('if');
  compile_node($cond_ref);
  compile_node($true_ref);
  ( emit_keyword('else'), compile_node($false_ref) ) if defined($false_ref);
}

sub fuck_with_while_conditions {
  my $node = shift;
  if ($node->{type} eq 'assignment') {
    my %copy = %{$node};
    %{$node} = %{$copy{cld}->[0]};

    return \%copy;
  }

  my @ass = ();
  for my $child (@{$node->{cld}}) {
    push @ass, fuck_with_while_conditions($child);
  }

  return @ass;
}

sub compile_while {
  my $node = shift;
  my ($cond_ref, $body_ref) = @{$node->{cld}};

  emit_keyword('while');

  my @assignments = fuck_with_while_conditions($cond_ref);
  if (@assignments) {
    # Turn this into while(1)
    compile_node({'type' => 'number', 'value' => '1'});

    # Now add: if (!(condition)): break
    my $exit_block = {
      'type' => 'if_expr',
      'cld' => [
        {
          'type' => 'unary',
          'operator' => {
            'type' => 'operator',
            'value' => '!',
            'operator' => '!',
          },
          'cld' => [
            $cond_ref,
          ],
        },
        {
          'type' => 'body',
          'cld' => [
            {
              'type' => 'loop_control',
              'value' => 'last',
            },
          ],
        },
      ],
    };

    unshift @{$body_ref->{cld}}, @assignments, $exit_block;
    compile_node($body_ref);
  } else {
    # Just compile normally
    compile_node($cond_ref);
    compile_node($body_ref);
  }
}

sub compile_for {
  my $node = shift;

  my ($init_ref, $cond_ref, $post_ref, $body_ref) = @{$node->{cld}};
  # TODO: run $post_ref on "continue"

  compile_node($init_ref);
  emit_statement_begin();

  emit_keyword('while');
  compile_node($cond_ref);

  # TODO: make continue work
  push $body_ref->{cld}, $post_ref;

  compile_node($body_ref);
}

sub compile_foreach {
  my $node = shift;
  my ($iterator_ref, $range_ref, $body_ref) = @{$node->{cld}};

  emit_keyword('for');
  compile_node($iterator_ref);
  emit_keyword('in');
  compile_node($range_ref);
  compile_node($body_ref);
}

sub compile_loopcontrol {
  my $node = shift;

  given ($node->{value}) {
    when ('next') {
      emit_keyword('continue');
    }

    when ('last') {
      emit_keyword('break');
    }
  }
}

sub compile_body {
  my $node = shift;

  $cs{depth}++;
  unshift $cs{locals}, {};

  emit_token(':');

  for my $child (@{$node->{cld}}) {
    emit_statement_begin();
    compile_node($child);
  }

  $cs{depth}--;
  shift $cs{locals};

  emit_statement_begin();
}

sub compile_program {
  my $node = shift;

  # Small hack to get our preamble set up
  emit_internal_string("from p2p_preamble import *\nimport sys\n");
  emit_statement_begin();

  my @cld = @{$node->{cld}};  # Useless but simplifies next few lines

  # Get rid of shebang
  if (@cld && ${$cld[0]}{type} eq 'comment' && ${$cld[0]}{value} =~ /^#!/) {
    shift @cld;
  }

  for my $node_ref (@cld) {
    compile_node($node_ref);
    emit_statement_begin();
  }
}

sub compile_node {
  my $node = shift;

  $cs{node_depth}++;

  given ($node->{type}) {
    when ('program')          { compile_program         ($node); }
    when ('body')             { compile_body            ($node); }

    when ('comment')          { compile_comment         ($node); }
    when ('number')           { compile_number          ($node); }
    when ('string')           { compile_string          ($node); }
    when ('variable')         { compile_variable        ($node); }
    when ('range')            { compile_range           ($node); }
    when ('last_item_index')  { compile_last_item_index ($node); }

    when ('incdec')           { compile_incdec          ($node) }

    when ('comma')            { compile_comma           ($node); }

    when ('foldl')            { compile_foldl           ($node); }
    when ('unary')            { compile_unary           ($node); }

    when ('assignment')       { compile_assignment      ($node); }
    when ('logical')          { compile_binary_op_expr  ($node); }
    when ('power')            { compile_binary_op_expr  ($node); }
    when ('comparison')       { compile_binary_op_expr  ($node); }
    when ('comma_sep_expr')   { compile_comma_sep_expr  ($node); }

    when ('call')             { compile_call            ($node); }
    when ('io')               { compile_io              ($node); }

    when ('if_expr')          { compile_if              ($node); }
    when ('while_expr')       { compile_while           ($node); }
    when ('for_expr')         { compile_for             ($node); }
    when ('foreach_expr')     { compile_foreach         ($node); }

    when ('loop_control')     { compile_loopcontrol     ($node); }

    when ('parenthesise')     { compile_parenthesise    ($node); }

    when ('comma_sep_string_concat') { compile_comma_sep_string_concat($node); }
    when ('stringify')        { compile_stringify       ($node); }
    when ('integrify')        { compile_integrify       ($node); }

    default           {
      print "What are you doing? Got this: ";
      display($node);
      die;
    }
  }

  my $replacement = [];
  foreach my $ref (@{$cs{postfix_incdec}}) {
    if ($ref->[0] == $cs{node_depth}) {
      compile_node($ref->[1]->{cld}->[0]);

      my $op = substr $ref->[1]->{operator}, 0, 1;
      emit_token($op . '=');
      emit_constant('1');
    } else {
      push $replacement, $ref;
    }
  }
  $cs{postfix_incdec} = $replacement;

  $cs{node_depth}--;
}

sub compile {
  my $ast_ref = shift;
  my $bootstrap_locals = {
    'ARGV' => '__p2p_argv',
    'STDIN' => 'sys.stdin',
    'STDOUT' => 'sys.stdout',
    'STDERR' => 'sys.stderr',
  };

  %cs = (
    'depth' => 0,
    'node_depth' => 0,
    'postfix_incdec' => [],
    'locals' => [ $bootstrap_locals ],
  );

  compile_node($ast_ref);
  print "## Compiled!\n";
}

1;
