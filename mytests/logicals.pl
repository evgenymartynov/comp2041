#!/usr/bin/perl

if (1 < 3 && 1 < 5) {
  print "1 < 3 && 1 < 5\n";
}

if (1 < 3 || 1 < 5) {
  print "1 < 3 || 1 < 5\n";
}

if (1 < 3 && 1 > 5) {
  print "1 < 3 && 1 > 5\n";
}

if (1 < 3 || 1 > 5) {
  print "1 < 3 || 1 > 5\n";
}

if (1 < 2 && 2 < 3 && 3 < 4) {
  print "Testing associativity\n";
}
