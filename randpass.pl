#!/usr/bin/perl

# Generate random passwords
#
# Usage: randpass <password_len> <output_chunk_size>

$l = (abs($ARGV[0]) or 16);       # password length
$c = (abs($ARGV[1]) or 4);        # output chunk size
@a = (A..Z,0..9,a..z);            # valid characters
@p = map { $a[rand @a] }(1..$l);  # random password
print join("",@p),"\n";           # output as one line

# insert spaces every <$c> characters, starting from end
map {
    ($_*$c - $l) and splice(@p,$_*$c - $l,0," ");
} (1..$l/$c);

print join("",$_,@p),"\n";        # output as space-delimited chunks
