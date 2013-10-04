# Type safety demo!

my $s = "123";
my $num = 42;

print "This is their sum: ", $s + $num, "\n";
print "And this is their concat: ", $s . $num, "\n";

print "We may also compare them:\n";
if ($s < $num) {
  print "This should not get printed\n";
} else {
  print "test passed\n";
}
if ($s > $num) {
  print "test passed\n";
} else {
  print "This should not get printed\n";
}
print "One of these would normally fail in Python "  .
      "if you don't cast like I did!\n";

print "Similarly for strings, these need to be cast:\n";
if ($s lt $num)     { print "test passed\n"; }
if (!($s gt $num))  { print "test passed\n"; }
print "Did you pass both tests here, too?\n"
