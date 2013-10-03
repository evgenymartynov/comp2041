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

sub node_empty {
  return node_with_children('empty');
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

sub pull_postfix_incdec {
  my ($node, $suppress_if_silly) = @_;

  if ($node->{type} eq 'program' || $node->{type} eq 'body') {
    my @ops = ();

    foreach my $child (@{$node->{cld}}) {
      my @temp = pull_postfix_incdec($child, 1);
      push @ops, $child;
      push @ops, @temp;
    }

    $node->{cld} = \@ops;
    return ();
  } elsif ($node->{type} eq 'incdec') {
    my %thingy = %{$node->{cld}->[0]};
    my $op = substr $node->{operator}, 0, 1;

    if ($suppress_if_silly) {
      %{$node} = %{node_empty()};
    } else {
      %{$node} = %thingy;
    }

    return {
      'type' => 'foldl',
      'cld' => [
        \%thingy,
        { 'type' => 'operator', 'operator' => substr($op, 0, 1) . '=' },
        { 'type' => 'number', 'value' => '1' },
      ],
    };
  } else {
    my @pulled = ();
    foreach my $child (@{$node->{cld}}) {
      if (defined($child)) {
        push @pulled, pull_postfix_incdec($child);
      }
    }

    return @pulled;
  }
}

sub rewrite_substitutions {
  my $node = shift;

  # Shallow walk here because this is ridiculous
  if ($node->{type} eq 'regex_match' && $node->{cld}->[1]->{type} eq 'substitute') {
    my ($left_ref, $next_ref) = @{$node->{cld}};
    %{$node} = (
      'type' => 'assignment',
      'cld' => [
        $left_ref,
        {
          'type' => 'call',
          'func' => '__p2p_re_subs',
          'cld' => [
            { 'type' => 'string', 'value' => $node->{operator} },
            $left_ref,
            $next_ref,
          ],
        },
      ],
    );
  } else {
    foreach my $child (@{$node->{cld}}) {
      if (defined($child)) {
        rewrite_substitutions($child);
      }
    }
  }
}

sub am_i_going_to_write_a_perl_compiler {
  my $node = shift;

  rewrite_substitutions($node);
  pull_assignments($node);
  pull_postfix_incdec($node);

  return $node;
}

1;
