# Different types of for loops, just because.

my @list = (1, 2, 3, 4);

foreach my $item (@list) {
  print "$item\n";
}

for ($i = 0; $i <= $#list; $i += 1) {
  printf "%d: %d\n", $i, $list[$i];
}

print "Even with post-increments!\n";
for ($i = 0; $i <= $#list; $i++) {
  printf "%d: %d\n", $i, $list[$i];
}

print "And empty conditionals!\n";
$i = 0;
for (;;) {
  print $list[$i], "\n";

  if ($i == $#list) {
    last;
  }

  $i++;
}
