#!/usr/bin/perl

$i = 0;
while ($i < 5) {
  print $i, "\n";
  $i++;
}

foreach $i (0..4) {
  print $i, "\n";
}

for ($i = 0; $i < 5; $i++) {
  print $i, "\n";
}

while ($i < 10) {
  $i++;

  if ($i == 5) {
    next;
  }

  if ($i == 8) {
    last;
  }

  print $i, "\n";
}
