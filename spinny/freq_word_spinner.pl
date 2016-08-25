#!/usr/bin/perl

use strict;

my($POOL_SIZE) = 1000; # population size
my($GENERATIONS) = 5000; # how many cycles to run
my($MUTATIONS) = 6; # max changes per offspring

my(@letters) = ("a".."z");

my(@f,@s,@t);

my(%dict);
while (<DATA>) { chomp; $dict{$_}++ }

sub pick_letter { return $letters[int(rand(@letters))]; }

# pass in strings of letters
sub score_blocks {
	my($f,$s,$t) = @_;
	my($score) = 0;
	my(@key,$word);
	my(%seen);
	foreach (unpack("aaaa",$f)) {
		$key[0] = $_;
		foreach (unpack("aaaa",$s)) {
			$key[1] = $_;
			foreach (unpack("aaaa",$t)) {
				$key[2] = $_;
				$word = join("",@key);
				next if ($seen{$word});
				$score++ if ($dict{$word});
				$seen{$word}++;
			}
		}
	}
	return $score;
}

# set the scores in a population of block options
sub score_population {
	my($pop) = @_;
	foreach (@$pop) {
		$_->[0] = &score_blocks($_->[1],$_->[2],$_->[3]);
	}
}

# adjust the letters in the blocks at random
sub tweak_blocks {
	my($f,$s,$t) = @_;
	my($choice);
	foreach (1..int(rand($MUTATIONS))+1) {
		$choice = int(rand(3));
		if ($choice == 0) {
			substr($f,int(rand(length $f)),1) = &pick_letter;
		} elsif ($choice == 1) {
			substr($s,int(rand(length $s)),1) = &pick_letter;
		} else {
			substr($t,int(rand(length $t)),1) = &pick_letter;
		}
	}
	$f = join("",sort split(//,$f)); 
	$s = join("",sort split(//,$s)); 
	$t = join("",sort split(//,$t)); 
	return ($f,$s,$t);
}

# make a new, tweaked population starting from the passed-in population
sub tweak_population {
	my(@pop) = @_;
	my(@new) = [];
	foreach (@pop) {
		push(@new,[0,&tweak_blocks($_->[1],$_->[2],$_->[3])]);
	}
	return @new;
}

my(@population);


# initial random population
foreach (0..$POOL_SIZE-1) {
	push(@population,[undef,join("",map { &pick_letter } (1..4)),join("",map { &pick_letter } (1..4)),join("",map { &pick_letter } (1..4))]);
}

my(@new);
print STDERR "Running $GENERATIONS generations...\n";
map {
	print STDERR ".";
	&score_population(\@population);
	@new = &tweak_population(@population);
	&score_population(\@new);
	@population = (sort { $b->[0] <=> $a->[0] } @population,@new)[0..$POOL_SIZE-1];
	print STDERR "$_\n" if ($_ % 50 == 0);
			
} (1..$GENERATIONS);

foreach (@population) {
	print join(" : ",@$_),"\n";
}

__DATA__
the
and
for
are
but
not
you
all
any
can
had
her
was
one
our
out
day
get
has
him
his
how
man
new
now
old
see
two 
way
who
boy
did
its
let
put
say
she
too
use 

