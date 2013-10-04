sub guess_what {
  print "what?\n";
  return 42;
}

sub functions_work {
  print "whoa\n";
  return 13;
}

sub they_can_even_recurse {
  print "u w0t m8\n";
  &guess_what;
  print "parens are optional\n";
  &functions_work();
}

&guess_what();
&functions_work;
&they_can_even_recurse;
