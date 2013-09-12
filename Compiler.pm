package Compiler;

use strict;
use Data::Dumper;
use Switch;

our %cs;

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
  print $string . " ";
}

sub emit_statement_begin {
  print "\n" . ('  ' x $cs{depth});
}

sub emit_constant {
  emit_internal_string(shift);
}

sub emit_identifier {
  emit_internal_string(shift);
}

sub emit_token {
  emit_internal_string(shift);
}

sub emit_keyword {
  emit_internal_string(shift);
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

sub compile_stringify {
  my %node = %{shift @_};

  compile_function_call('str', ${$node{cld}}[0]);
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

sub compile_print {
  my %node = %{shift @_};

  compile_function_call('sys.stdout.write', @{$node{cld}}[0]);
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

sub compile_assign {
  my %node = %{shift @_};

  my $lvalue_node_ref = ${$node{cld}}[0];
  my $rvalue_node_ref = ${$node{cld}}[1];

  compile_node($lvalue_node_ref);
  emit_token('=');
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

sub compile_binary_op_expr {
  my %node = %{shift @_};

  my $lop_ref = shift @{$node{cld}};
  my $rop_ref = shift @{$node{cld}};

  compile_node($lop_ref);

  while (defined($rop_ref)) {
    emit_token($node{operator});
    compile_node($rop_ref);

    $rop_ref = shift @{$node{cld}};
  }
}

sub compile_if {
  my %node = %{shift @_};

  my $cond_ref = shift @{$node{cld}};
  my $true_ref = shift @{$node{cld}};
  my $false_ref = shift @{$node{cld}};

  emit_keyword('if');
  compile_node($cond_ref);
  compile_node($true_ref);
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

sub compile_body {
  my %node = %{shift @_};

  $cs{depth}++;

  emit_token(':');
  emit_statement_begin();

  for my $node_ref (@{$node{cld}}) {
    compile_node($node_ref);
    emit_statement_begin();
  }

  $cs{depth}--;
}

sub compile_program {
  my %node = %{shift @_};

  # Small hack to get our preamble set up
  emit_node_value({'value' => "#!/usr/bin/python2 -u"});
  emit_statement_begin();
  emit_node_value({'value' => "import sys"});
  emit_statement_begin();
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

  switch ($node{type}) {
    case 'program'          { compile_program         (\%node); }
    case 'body'             { compile_body            (\%node); }

    case 'comment'          { compile_comment         (\%node); }
    case 'number'           { compile_number          (\%node); }
    case 'string'           { compile_string          (\%node); }
    case 'scalar'           { compile_scalar          (\%node); }
    case 'range'            { compile_range           (\%node); }

    case 'assign'           { compile_assign          (\%node); }
    case 'add_expr'         { compile_binary_op_expr  (\%node); }
    case 'mul_expr'         { compile_binary_op_expr  (\%node); }
    case 'comparison'       { compile_binary_op_expr  (\%node); }
    case 'comma_sep_expr'   { compile_comma_sep_expr  (\%node); }

    case 'print_expr'       { compile_print           (\%node); }

    case 'if_expr'          { compile_if              (\%node); }
    case 'while_expr'       { compile_while           (\%node); }
    case 'foreach_expr'     { compile_foreach         (\%node); }

    case 'parenthesise'     { compile_parenthesise    (\%node); }

    # I hate perl at times. More so than the other times when I want to kill it.
    case 'comma_sep_string_concat' { compile_comma_sep_string_concat(\%node); }
    case 'stringify'        { compile_stringify       (\%node); }

    default           {
      print "What are you doing? Got this: ";
      display(\%node);
      die;
    }
  }
}

sub compile {
  my $ast_ref = shift;
  %cs = (
    'depth' => 0,
  );

  compile_node($ast_ref);
  print "## Compiled!\n";
}

1;
