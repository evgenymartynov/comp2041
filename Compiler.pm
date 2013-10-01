package Compiler;

use strict;
use Data::Dumper;
use feature qw(switch);

our (%cs, %emitter_state, %emitter_stack);

sub display {
  local $Data::Dumper::Terse = 1;
  $_ = Dumper(@_);
  print;
}

#
# Emitters
#

sub emit_internal_string {
  my $string = shift;
  die "Trying to emit undefined string :(" unless defined($string);

# if (!$emitter_state{suppress_space_once} || $emitter_state{suppress_space_override}) {
    $string = "$string ";
# }

  $emitter_state{suppress_space_once} = 0;
  $emitter_state{suppress_space_override} = 0;

  print $string;
}

sub emit_statement_begin {
  $emitter_state{suppress_space_once} = 1;
  $emitter_state{suppress_space_override} = 0;

  print "\n" . ('  ' x $cs{depth});
}

sub emit_constant {
  emit_internal_string(shift);
}

sub emit_identifier {
  emit_internal_string(shift);
}

sub emit_token {
  my $token = shift;

  my $no_space_before = '():,';
  my $no_space_after =  '(:';
  my $always_space_after = '-+*/%';

  $emitter_state{suppress_space_once} = 1     if ($token =~ qr([$no_space_before]));
  emit_internal_string($token);
  $emitter_state{suppress_space_once} = 1     if ($token =~ qr([$no_space_after]));
  $emitter_state{suppress_space_override} = 1 if ($token =~ qr([$always_space_after]));
}

sub emit_keyword {
  emit_internal_string(shift);

  $emitter_state{suppress_space_override} = 1;
}

sub emit_node_value {
  my %node = %{shift @_};

  die("Expecting value inside node ", display(\%node)) unless defined($node{value});
  emit_internal_string($node{value});
}

#
# Compiler
#

sub lookup_variable {
  my $var = shift;
  $var =~ s/^\$//;
  return $var;
}

sub compile_comment {
  emit_node_value(shift @_);
}

sub compile_number {
  emit_node_value(shift @_);
}

sub compile_comma_sep_expr_onlist {
  my @cld = @_;

  my $first = 1;
  for my $node_ref (@cld) {
    emit_token(",") unless $first;
    $first = 0;

    compile_node($node_ref);
  }
}

sub compile_function_call {
  my $funcname = shift @_;
  my @args = @_;

  emit_identifier($funcname);
  emit_token("(");
  compile_comma_sep_expr_onlist(@args);
  emit_token(")");
}

sub compile_range {
  my %node = %{shift @_};

  my $from_ref = shift @{$node{cld}};
  my $to_ref = shift @{$node{cld}};

  compile_function_call('xrange', $from_ref, $to_ref);
}

sub compile_comma {
  my $node = shift;
  my @cld = @{$node->{cld}};
  # my $brackets = $#cld > 1;

  # emit_token('[') if $brackets;

  foreach my $child (@cld) {
    given ($child->{type}) {
      when ('comma') {
        emit_token(',');
      }

      default {
        compile_node($child);
      }
    }
  }

  # emit_token(']') if $brackets;
}

sub compile_incdec {
  my $node = shift;
  push $cs{postfix_incdec}, [ $cs{node_depth}, $node ];
}

sub compile_stringify {
  my %node = %{shift @_};

  compile_function_call('str', ${$node{cld}}[0]);
}

sub massage_string_concat_under_print_context {
  my $current_node_ref = shift;   # Need the ref to strip newlines
  my %current_node = %{$current_node_ref};
  my $cld_ref = $current_node{cld};

  my $eol_please = 0;
  my $kill_me_please = 0;

  given ($current_node{type}) {
    when ('comma_sep_string_concat') {
      my $rightmost_ref = ${$cld_ref}[$#{$cld_ref}];
      ($eol_please, $kill_me_please) =
          massage_string_concat_under_print_context($rightmost_ref);

      # Don't want empty strings hanging around.
      if ($kill_me_please) {
        pop ${$current_node_ref}{cld};

        # Or empty concats
        $kill_me_please = 0 unless $#{$cld_ref};
      }
    }

    when ('string') {
      if ($current_node{eol}) {
        ${$current_node_ref}{value} =~ s/\\n$//;
        if (${$current_node_ref}{value} eq '') {
          $kill_me_please = 1;
        }

        $eol_please = 1;
      }
    }
  }

  return ($eol_please, $kill_me_please);
}

sub compile_string {
  my %node = %{shift @_};

  my $prefix = ($node{raw_string} ? 'r' : '');
  my $escaped = $node{value};
  $escaped =~ s/'/\\'/g;

  emit_identifier("$prefix'$escaped'");
}

sub compile_scalar {
  my %node = %{shift @_};

  emit_identifier(lookup_variable($node{value}));
}

sub compile_call {
  my %node = %{shift @_};

  my $func = $node{func};
  emit_identifier($func);
  emit_token("(");
  compile_comma($node{cld}->[0]);
  emit_token(")");
}

sub compile_comma_sep_expr {
  my %node = %{shift @_};

  compile_comma_sep_expr_onlist(@{$node{cld}});
}

sub compile_comma_sep_string_concat {
  my %node = %{shift @_};

  # Listception. Hashception. Everythingception.
  # ...contraception?
  my @cld = @{$node{cld}};
  my $first = 1;

  foreach my $child (@cld) {
    emit_token("+") unless $first;
    $first = 0;

    compile_node($child);
  }
}

sub compile_assignment {
  my %node = %{shift @_};

  my $lvalue_node_ref = ${$node{cld}}[0];
  my $rvalue_node_ref = ${$node{cld}}[1];

  compile_node($lvalue_node_ref);

  emit_token(
    (defined $node{operator}
        ? $node{operator}
        : '')
    . '='
  );

  compile_node($rvalue_node_ref);
}

sub compile_parenthesise {
  my %node = %{shift @_};

  emit_token('(');
  for my $node_ref (@{$node{cld}}) {
    compile_node($node_ref);
  }
  emit_token(')');
}

sub compile_foldl {
  my $node = shift @_;
  my @cld = @{$node->{cld}};

  while (@cld) {
    my $item = shift @cld;
    given ($item->{type}) {
      when ('operator') {
        emit_token($item->{operator});
      }

      default {
        compile_node($item);
      }
    }
  }
}

sub compile_unary {
  my $node = shift @_;
  my $ref = $node->{cld}->[0];

  emit_token($node->{operator}->{value});
  emit_token('(');
  compile_node($ref);
  emit_token(')');
}

sub compile_binary_op_expr {
  my %node = %{shift @_};

  my $lop_ref = shift @{$node{cld}};
  my $rop_ref = shift @{$node{cld}};

  emit_token('(');
  compile_node($lop_ref);

  while (defined($rop_ref)) {
    emit_token($node{operator});
    compile_node($rop_ref);

    $rop_ref = shift @{$node{cld}};
  }

  emit_token(')');
}

sub compile_if {
  my %node = %{shift @_};

  my $cond_ref = shift @{$node{cld}};
  my $true_ref = shift @{$node{cld}};
  my $false_ref = shift @{$node{cld}};

  emit_keyword('if');
  compile_node($cond_ref);
  compile_node($true_ref);
  emit_keyword('else') if defined($false_ref);
  compile_node($false_ref) if defined($false_ref);
}

sub compile_while {
  my %node = %{shift @_};

  my $cond_ref = shift @{$node{cld}};
  my $body_ref = shift @{$node{cld}};

  emit_keyword('while');
  compile_node($cond_ref);
  compile_node($body_ref);
}

sub compile_for {
  my %node = %{shift @_};

  my ($init_ref, $cond_ref, $post_ref, $body_ref) = @{$node{cld}};
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
  my %node = %{shift @_};

  my $iterator_ref = shift @{$node{cld}};
  my $range_ref = shift @{$node{cld}};
  my $body_ref = shift @{$node{cld}};

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

sub compile_fileread {
  my %node = %{shift @_};

  compile_function_call('__p2p_readline');
  warn 'todo filedes';
}

sub compile_body {
  my %node = %{shift @_};

  $cs{depth}++;

  emit_token(':');

  for my $node_ref (@{$node{cld}}) {
    emit_statement_begin();
    compile_node($node_ref);
  }

  $cs{depth}--;
  emit_statement_begin();
}

sub compile_program {
  my %node = %{shift @_};

  # Small hack to get our preamble set up
  open F, '<preamble.py';
  my $preamble = do { local $/ = undef; <F> };
  close F;
  emit_internal_string($preamble);
  emit_statement_begin();

  my @cld = @{$node{cld}};

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
  my %node = %{shift @_};

  $cs{node_depth}++;

  given ($node{type}) {
    when ('program')          { compile_program         (\%node); }
    when ('body')             { compile_body            (\%node); }

    when ('comment')          { compile_comment         (\%node); }
    when ('number')           { compile_number          (\%node); }
    when ('string')           { compile_string          (\%node); }
    when ('scalar')           { compile_scalar          (\%node); }
    when ('range')            { compile_range           (\%node); }

    when ('incdec')           { compile_incdec          (\%node) }

    when ('comma')            { compile_comma           (\%node); }

    when ('foldl')            { compile_foldl           (\%node); }
    when ('unary')            { compile_unary           (\%node); }

    when ('assignment')       { compile_assignment      (\%node); }
    when ('add_expr')         { compile_binary_op_expr  (\%node); }
    when ('mul_expr')         { compile_binary_op_expr  (\%node); }
    when ('logical')          { compile_binary_op_expr  (\%node); }
    when ('power')            { compile_binary_op_expr  (\%node); }
    when ('comparison')       { compile_binary_op_expr  (\%node); }
    when ('comma_sep_expr')   { compile_comma_sep_expr  (\%node); }

    when ('call')             { compile_call            (\%node); }

    when ('if_expr')          { compile_if              (\%node); }
    when ('while_expr')       { compile_while           (\%node); }
    when ('for_expr')         { compile_for             (\%node); }
    when ('foreach_expr')     { compile_foreach         (\%node); }

    when ('loop_control')     { compile_loopcontrol     (\%node); }

    when ('parenthesise')     { compile_parenthesise    (\%node); }

    when ('file_read')        { compile_fileread        (\%node); }

    # I hate perl at times. More so than the other times when I want to kill it.
    when ('comma_sep_string_concat') { compile_comma_sep_string_concat(\%node); }
    when ('stringify')        { compile_stringify       (\%node); }

    default           {
      print "What are you doing? Got this: ";
      display(\%node);
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
  %cs = (
    'depth' => 0,
    'node_depth' => 0,
    'postfix_incdec' => [],
  );

  %emitter_state = (
    'suppress_space_once' => 1,
  );

  %emitter_stack = ();

  compile_node($ast_ref);
  print "## Compiled!\n";
}

1;
