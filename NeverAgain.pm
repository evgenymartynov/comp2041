package NeverAgain;

use strict;
use Data::Dumper;
use feature qw(switch);

sub display {
  local $Data::Dumper::Terse = 1;
  $_ = Dumper(@_);
  print;
}

sub node_with_value {
  return {
    'type' => shift,
    'value' => shift,
  };
}

sub node_with_children {
  return {
    'type' => shift,
    'cld' => \@_,
  };
}

sub node_true {
  return node_with_value('number', '1');
}

sub node_not {
  return {
    'type' => 'unary',
    'operator' => node_with_value('operator', '!'),
    'cld' => [ shift ],
  };
}

sub node_if {
  return node_with_children('if_expr', @_);
}

sub prepend_statements_to_block {
  my ($node, @statements) = @_;
  unshift @{$node->{cld}}, @statements;
}


sub find_assignments {
  my $node = shift;
  my @assignments = ();

  if ($node->{type} eq 'assignment') {
    my %copy = %{$node};
    push @assignments, \%copy;

    %{$node} = %{$node->{cld}->[0]};
  } else {
    foreach my $child(@{$node->{cld}}) {
      push @assignments, find_assignments($child);
    }
  }

  return @assignments;
}

# Pulls out assignments in conditions, e.g. if (($a = <>) != "\n") {}
sub pull_assignments {
  my $node = shift;

  given ($node->{type}) {
    when ('while_expr') {
      my ($cond, $body) = @{$node->{cld}};

      if (my @assignments = find_assignments($cond)) {
        # Rewrite:
        # while (cond with assts) { ... }
        # to
        # while (1) { assts; if (!cond) { break; } ... }

        my @preamble = (
          @assignments,
          node_if(
            node_not($cond),
            node_with_children('body',
                node_with_value('loop_control', 'last'),
            ),
          ),
        );

        $node->{cld}->[0] = node_true();
        prepend_statements_to_block($node->{cld}->[1], @preamble);
      }
    }
  }

  foreach my $child (@{$node->{cld}}) {
    pull_assignments($child);
  }
}

sub am_i_going_to_write_a_perl_compiler {
  my $node = shift;

  pull_assignments($node);

  return $node;
}

1;
