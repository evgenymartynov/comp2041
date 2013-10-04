sub fib {
  my $x = @_[0];
  if ($x <= 1) {
    return 1;
  }

  return &fib($x - 1) + &fib($x - 2);
}

my $n = 20;
print $n, "th fibonacci number is ", &fib($n), "\n";
