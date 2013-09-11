package Compiler;

use strict;
use Data::Dumper;
use Switch;

sub display {
  local $Data::Dumper::Terse = 1;
  $_ = Dumper(@_);
  print;
}

sub emit_string {
  print shift @_, "\n";
}

sub emit {
  print shift @_, " ";
}

sub emit_newline {
  my %cs = %{shift @_};

  print "\n" . ('  ' x $cs{depth});
}

sub lookup_variable {
  my $var = shift;
  $var =~ s/^\$//;
  return $var;
}

sub compile_comment {
  my %cs = %{shift @_};
  my %node = %{shift @_};

  emit_string($node{value});
}

sub compile_number {
  my %cs = %{shift @_};
  my %node = %{shift @_};

  emit($node{value});
}

sub compile_comma_sep_expr_onlist {
  my %cs = %{shift @_};
  my @cld = @_;

  my $first = 1;
  for my $node_ref (@cld) {
    emit(",") unless $first;
    $first = 0;

    compile_node(\%cs, $node_ref);
  }
}

sub compile_function_call {
  my %cs = %{shift @_};
  my $funcname = shift @_;
  my @args = @_;

  emit($funcname);
  emit("(");
  compile_comma_sep_expr_onlist(\%cs, @args);
  emit(")");
}

sub compile_range {
  my %cs = %{shift @_};
  my %node = %{shift @_};

  my $from_ref = shift @{$node{cld}};
  my $to_ref = shift @{$node{cld}};

  compile_function_call(\%cs, 'xrange', $from_ref, $to_ref);
}

sub compile_stringify {
  my %cs = %{shift @_};
  my %node = %{shift @_};

  emit("str(");
  compile_node(\%cs, ${$node{cld}}[0]);
  emit(")");
}

sub compile_string {
  my %cs = %{shift @_};
  my %node = %{shift @_};

  my $prefix = ($node{raw_string} ? 'r' : '');
  my $escaped = $node{value};
  $escaped =~ s/'/\\'/g;

  emit("$prefix'$escaped'");
}

sub compile_scalar {
  my %cs = %{shift @_};
  my %node = %{shift @_};

  emit(lookup_variable($node{value}));
}

sub compile_print {
  my %cs = %{shift @_};
  my %node = %{shift @_};

  emit('sys.stdout.write(');
  compile_node(\%cs, @{$node{cld}}[0]);
  emit(')');
}

sub compile_comma_sep_expr {
  my %cs = %{shift @_};
  my %node = %{shift @_};

  compile_comma_sep_expr_onlist(\%cs, @{$node{cld}});
}

sub compile_comma_sep_string_concat {
  my %cs = %{shift @_};
  my %node = %{shift @_};

  # Listception. Hashception. Everythingception.
  # ...contraception?
  my @cld = @{$node{cld}};
  my $first = 1;

  foreach my $child (@cld) {
    emit("+") unless $first;
    $first = 0;

    compile_node(\%cs, $child);
  }
}

sub compile_assign {
  my %cs = %{shift @_};
  my %node = %{shift @_};

  my $lvalue_node_ref = ${$node{cld}}[0];
  my $rvalue_node_ref = ${$node{cld}}[1];

  compile_node(\%cs, $lvalue_node_ref);
  emit('=');
  compile_node(\%cs, $rvalue_node_ref);
}

sub compile_parenthesise {
  my %cs = %{shift @_};
  my %node = %{shift @_};

  emit('(');
  for my $node_ref (@{$node{cld}}) {
    compile_node(\%cs, $node_ref);
  }
  emit(')');
}

sub compile_binary_op_expr {
  my %cs = %{shift @_};
  my %node = %{shift @_};

  my $lop_ref = shift @{$node{cld}};
  my $rop_ref = shift @{$node{cld}};

  compile_node(\%cs, $lop_ref);

  while (defined($rop_ref)) {
    emit($node{operator});
    compile_node(\%cs, $rop_ref);

    $rop_ref = shift @{$node{cld}};
  }
}

sub compile_if {
  my %cs = %{shift @_};
  my %node = %{shift @_};

  my $cond_ref = shift @{$node{cld}};
  my $true_ref = shift @{$node{cld}};
  my $false_ref = shift @{$node{cld}};

  emit('if');
  compile_node(\%cs, $cond_ref);
  compile_node(\%cs, $true_ref);
  compile_node(\%cs, $false_ref) if defined($false_ref);
}

sub compile_while {
  my %cs = %{shift @_};
  my %node = %{shift @_};

  my $cond_ref = shift @{$node{cld}};
  my $body_ref = shift @{$node{cld}};

  emit('while');
  compile_node(\%cs, $cond_ref);
  compile_node(\%cs, $body_ref);
}

sub compile_foreach {
  my %cs = %{shift @_};
  my %node = %{shift @_};

  my $iterator_ref = shift @{$node{cld}};
  my $range_ref = shift @{$node{cld}};
  my $body_ref = shift @{$node{cld}};

  emit('for');
  compile_node(\%cs, $iterator_ref);
  emit('in');
  compile_node(\%cs, $range_ref);
  compile_node(\%cs, $body_ref);
}

sub compile_body {
  my %cs = %{shift @_};
  my %node = %{shift @_};

  $cs{depth}++;

  emit(':');
  emit_newline(\%cs);

  for my $node_ref (@{$node{cld}}) {
    compile_node(\%cs, $node_ref);
    emit_newline(\%cs);
  }

  $cs{depth}--;
}

sub compile_program {
  my %cs = %{shift @_};
  my %node = %{shift @_};

  emit_string("#!/usr/bin/python2 -u");
  emit_string("import sys");
  emit_newline(\%cs);

  my @cld = @{$node{cld}};

  # Get rid of shebang
  if (@cld && ${$cld[0]}{type} eq 'comment' && ${$cld[0]}{value} =~ /^#!/) {
    shift @cld;
  }

  for my $node_ref (@cld) {
    compile_node(\%cs, $node_ref);
    emit_newline(\%cs);
  }
}

sub compile_node {
  my %cs = %{shift @_};
  my %node = %{shift @_};

  switch ($node{type}) {
    case 'program'          { compile_program         (\%cs, \%node); }
    case 'body'             { compile_body            (\%cs, \%node); }

    case 'comment'          { compile_comment         (\%cs, \%node); }
    case 'number'           { compile_number          (\%cs, \%node); }
    case 'string'           { compile_string          (\%cs, \%node); }
    case 'scalar'           { compile_scalar          (\%cs, \%node); }
    case 'range'            { compile_range           (\%cs, \%node); }

    case 'assign'           { compile_assign          (\%cs, \%node); }
    case 'add_expr'         { compile_binary_op_expr  (\%cs, \%node); }
    case 'mul_expr'         { compile_binary_op_expr  (\%cs, \%node); }
    case 'comparison'       { compile_binary_op_expr  (\%cs, \%node); }
    case 'comma_sep_expr'   { compile_comma_sep_expr  (\%cs, \%node); }

    case 'print_expr'       { compile_print           (\%cs, \%node); }

    case 'if_expr'          { compile_if              (\%cs, \%node); }
    case 'while_expr'       { compile_while           (\%cs, \%node); }
    case 'foreach_expr'     { compile_foreach         (\%cs, \%node); }

    case 'parenthesise'     { compile_parenthesise    (\%cs, \%node); }

    # I hate perl at times. More so than the other times when I want to kill it.
    case 'comma_sep_string_concat' { compile_comma_sep_string_concat(\%cs, \%node); }
    case 'stringify'        { compile_stringify       (\%cs, \%node); }

    default           {
      print "What are you doing? Got this: ";
      display(\%node);
      die;
    }
  }
}

sub compile {
  my $ast_ref = shift;
  my %compile_state = (
    'depth' => 0,
  );

  compile_node(\%compile_state, $ast_ref);
  print "## Compiled!\n";
}

1;
