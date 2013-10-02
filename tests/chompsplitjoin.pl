#!/usr/bin/perl

$str = "this is a string lel\n";
chomp $str;
print $str, "\n";
print split(" ", "hi there perl you are horrible", 3), "\n";
print split(" ", "just words here"), "\n";
print join(", ", split(" ", "apple banana orange pineapple")), "\n";
