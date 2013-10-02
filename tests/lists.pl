@lst = ['a', 'b', 1, -1];
@lst = (1, 2, 3);
print @lst, "\n";

push @lst, 4, 5;
unshift @lst, -1, 0;
print @lst, "\n";

print pop @lst, "\n";
print shift @lst, "\n";
print @lst, "\n";

print(unshift(@lst, "head"), "\n");
print(push(@lst, "tail"), "\n");
