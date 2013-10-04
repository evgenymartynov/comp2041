print "Let's play some hangman\n";

print "Enter a phrase:\n";
$secret = <>;
chomp $secret;

@line = split '', $secret;
@guessed = ();

sub get_guess {
  print "Guess a letter\n";
  return <>;
}

while ($guess = &get_guess) {
  push @guessed, substr $guess, 0, 1;  # Pick out a single char.
  $complete = 1;

  foreach $char (@line) {
    if (grep /$char/, @guessed) {
      print "$char ";
    } else {
      $complete = 0;
      print "_ ";
    }
  }
  print "\n";

  if ($complete) {
    print "congrats!\n";
    last;
  }

  if ($#guessed > 5) {
    print "you lose!\n";
    last;
  }
}
