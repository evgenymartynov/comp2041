# This is a demo of string interpolation

$num = 42;
$str = "potato";
@lst = (1, 2, 3);
%hsh = ( 'a' => 'apple', '2' => 'potato', '42' => 'life' );

print "$num is $hsh{42}\n";
print "Things: $num $str $lst %hsh\n";
print "Note that hashes don't get printed normally\n";

print "But this will print it as perl would: ", %hsh, "\n";
print "up to the order of keys, because perl is a $str\n";

print "There is a slight issue though: \"\@lst\" is different to \@lst.\n";
print "...oh, and above line shows how to escape interpolations.\n\n";

print "This is quoted: @lst <-- this should be space-separated in Perl5\n";
print "And this is not: ", @lst, "\n";
print "WTF, perl?\n";

push @lst, 4, 5;
$hsh{apple} = 'not banana';
print "I can even modify the things and it still works! @lst\n", %hsh, "\n";
