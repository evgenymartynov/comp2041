# This demonstrates a bunch of list ops with optional parentheses.
# Further, split() works differently in Python than in Perl.
# split on '' works for Perl only; number of splits to make is off by 1 in Perl.
# We account for both in our p2p Python stub.

$str = "this is a string lel\n";
chomp $str;
print "$str\n";
print split(" ", "hi there perl you are horrible", 3), "\n";
print split(" ", "just words here"), "\n";
print join(", ", split " ", "apple banana orange pineapple"), "\n";
print join "\n", split '', "what\n";
