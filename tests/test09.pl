$line = "abc123def";

# Match groups
$line =~ m/([0-9]+)/;
print $1, "\n";

# Substitution with and without /r: string and int respectively.
print($line =~ s/[0-9]/_/g, "\n");
print($line =~ s/[0-9]/_/rg, "\n");
