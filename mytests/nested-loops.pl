$a = 0;
$b = 0;

while (($a += 2) < 10) {
  while ($b++ < $a) {
    print "$a $b\n";
  }
}
