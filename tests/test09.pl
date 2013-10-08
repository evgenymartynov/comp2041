$line = "abc123def";

# Match groups
$line =~ m/([0-9]+)/;
print $1, "\n";

# Result is integer number of subs made
print $line =~ s/[a-c]/_/g;

# Evaluation order test
print $line, ($line =~ s/[0-9]/_/g, "\n");
