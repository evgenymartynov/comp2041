# Reverse lines, written by evgenym, idea stolen off assignment spec
# Operates with <>, not <STDIN>.
# Does it in three ways:
## push and reverse-iteration,
## unshift
## reverse

@lines = ();
@other = ();

while ($line = <>) {
  push @lines, $line;
  unshift @other, $line;
}

print "=== Iteration ===\n";
for ($i = $#lines; $i >= 0; $i -= 1) {
  print $lines[$i];
}

print "=== Unshift ===\n";
foreach $line (@other) {
  print $line;
}

print "=== Reverse ===\n";
foreach $line (reverse @lines) {
  print $line;
}
