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

sub compile_stringify {
  my %cs = %{shift @_};
  my %node = %{shift @_};

  emit("str(");
  compile_node(\%cs, ${$node{cld}}[0]);
  emit(")");
}

sub interpolate_string {
  my %cs = %{shift @_};
  my $pattern = shift @_;

  return $pattern;
}

sub compile_string {
  my %cs = %{shift @_};
  my %node = %{shift @_};

  my $result = interpolate_string(\%cs, $node{value});
  emit($result);
}

sub compile_scalar {
  my %cs = %{shift @_};
  my %node = %{shift @_};

  emit(lookup_variable($node{value}));
}

sub compile_print {
  my %cs = %{shift @_};
  my %node = %{shift @_};

  emit('print');
  compile_node(\%cs, @{$node{cld}}[0]);
}

sub compile_comma_sep_expr {
  my %cs = %{shift @_};
  my %node = %{shift @_};

  my $first = 1;
  for my $node_ref (@{$node{cld}}) {
    emit(",") unless $first;
    $first = 0;

    compile_node(\%cs, $node_ref);
  }
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

  my %lvalue_node = %{${$node{cld}}[0]};
  my $rvalue_node_ref = ${$node{cld}}[1];

  my $lvalue = lookup_variable($lvalue_node{value});
  emit($lvalue);
  emit('=');
  compile_node(\%cs, $rvalue_node_ref);
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

sub compile_program {
  my %cs = %{shift @_};
  my %node = %{shift @_};

  emit_string("#!/usr/bin/python2 -u");

  my @cld = @{$node{cld}};

  # Get rid of shebang
  if (@cld && ${$cld[0]}{type} eq 'comment' && ${$cld[0]}{value} =~ /^#!/) {
    shift @cld;
  }

  for my $node_ref (@cld) {
    compile_node(\%cs, $node_ref);
    emit_string("");
  }
}

# sub compile_children {
#   my %cs = %{shift @_};
#   my %node = %{shift @_};
# 
#   for my $node_ref (@{$node{cld}}) {
#     compile_node(\%cs, $node_ref);
#   }
# }

sub compile_node {
  my %cs = %{shift @_};
  my %node = %{shift @_};

  switch ($node{type}) {
    case 'program'          { compile_program         (\%cs, \%node); }
    case 'comment'          { compile_comment         (\%cs, \%node); }
    case 'number'           { compile_number          (\%cs, \%node); }
    case 'string'           { compile_string          (\%cs, \%node); }
    case 'scalar'           { compile_scalar          (\%cs, \%node); }

    case 'assign'           { compile_assign          (\%cs, \%node); }
    case 'add_expr'         { compile_binary_op_expr  (\%cs, \%node); }
    case 'mul_expr'         { compile_binary_op_expr  (\%cs, \%node); }
    case 'comma_sep_expr'   { compile_comma_sep_expr  (\%cs, \%node); }

    case 'print_expr'       { compile_print           (\%cs, \%node); }

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
  my %compile_state = ();

  compile_node(\%compile_state, $ast_ref);
  print "## Compiled!\n";
}

1;
