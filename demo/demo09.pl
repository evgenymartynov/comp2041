# Just a simple demo of a function with multiple arguments
# and multiple return values.

sub cp_add {
  # Unfortunately the (a, b) = @list syntax doesn't work.
  # Neither does shifting @_ because Python passes it as tuple.
  $x1 = @_[0];
  $y1 = @_[1];
  $x2 = @_[2];
  $y2 = @_[3];

  return ($x1 + $x2, $y1 + $y2);
}

@sum = &cp_add(1, 2, 3, 4);
print "(1,2) + (3,4) = ($sum[0], $sum[1])\n";
