#!/usr/bin/perl

use strict;

my($MAX_SIZE) = 500; # population size
my($GENERATIONS) = 2000; # how many cycles to run
my($MUTATIONS) = 5; # changes per offspring

my(@consonants) = split(//,"bcdfghjklmnprstvwyz"); # no 'x' or 'z' (too rare)
my(@vowels)     = split(//,"aeiou");

my(@f,@s,@t);

my(%dict);
while (<DATA>) { chomp; $dict{$_}++ }

sub pick_c { return $consonants[int(rand(@consonants))]; }
sub pick_v { return $vowels[int(rand(@vowels))]; }

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
	foreach (1..$MUTATIONS) {
		$choice = int(rand(3));
		if ($choice == 0) {
			substr($f,int(rand(length $f)),1) = &pick_c;
		} elsif ($choice == 1) {
			substr($s,int(rand(length $s)),1) = &pick_v;
		} else {
			substr($t,int(rand(length $t)),1) = &pick_c;
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
foreach (0..$MAX_SIZE-1) {
	push(@population,[undef,join("",map { &pick_c } (1..4)),join("",map { &pick_v } (1..4)),join("",map { &pick_c } (1..4))]);
}

my(@new);
print STDERR "Running $GENERATIONS generations...\n";
map {
	print STDERR ".";
	&score_population(\@population);
	@new = &tweak_population(@population);
	&score_population(\@new);
	@population = (sort { $b->[0] <=> $a->[0] } @population,@new)[0..$MAX_SIZE-1];
	print STDERR "$_\n" if ($_ % 50 == 0);
			
} (1..$GENERATIONS);

# # #

my($output, %uniques);
foreach (@population) {
    $output = join(" : ",@$_);
    next if ($uniques{$output});
    $uniques{$output}++;
    print $output,"\n";
}

__DATA__
bad
bag
bah
ban
bar
bat
bay
bed
beg
bet
bib
bid
big
bin
bit
bob
bog
bop
bow
box
boy
bud
bug	
bum
bun
bur
bus
but
buy
cab
cad
cam
can
cap
car
cat
caw
cob
cod
cog
con
cop
cot
cow
cox
coy
cub
cud
cup
cur
cut
dab
dad
dam
day
deb
den
dew
did
dig
dim
din
dip
dis
doc
dog
don
dos
dot
dub
dud
dug
duh
dun
fad
fan
far
fat
fax
fed
fen
fer
few
fey
fez
fib
fig
fin
fir
fit
fix
fob
fog
fop
for
fox
fun
fur
gab
gad
gag
gal
gap
gas
gay
gel
gem
get
gig
gin
gob
god
gos
got
gum
gun
gut
guy
had
hag
hah
ham
has
hat
haw
hay
hem
hen
hep
her
hes
hew
hex
hey
hid
him
hip
his
hit
hob
hod
hog
hop
hos
hot
how
hub
hug
huh
hum
hut
jab
jag
jam
jar
jaw
jay
jet
jib
jig
job
jog
jot
joy
jug
jut
keg
ken
key
kid
kin
kit
lab
lad
lag
lam
lap
law
lax
lay
led
leg
les
let
lib
lid
lip
lit
lob
log
lop
lot
low
lox
lug
mad
man
map
mar
mas
mat
maw
may
meg
men
mes
met
mew
mid
mil
mix
mob
mod
mom
mop
mow
mud
mug
mum
nab
nag
nap
nay
net
new
nib
nil
nip
nit
nix
nod
non
nor
not
now
nub
nun
nut
pad
pal
pan
pap
par
pas
pat
paw
pay
peg
pen
pep
per
pet
pew
pig
pin
pip
pis
pit
pod
pol
pop
pot
pow
pox
pub
pug
pun
pup
pus
put
rag
ram
ran
rap
rat
raw
ray
red
ref
rep
rev
rib
rid
rig
rim
rip
rob
rod
rot
row
rub
rug
rum
run
rut
sac
sad
sag
sap
sat
saw
sax
say
set
sew
sic
sin
sip
sir
sis
sit
six
sob
sod
sol
son
sop
sot
sow
sox
soy
sub
sum
sun
sup
tab
tad
tag
tam
tan
tap
tar
tat
tax
ten
tic
tin
tip
tog
tom
ton
top
tor
tot
tow
toy
tub
tug
tun
tux
van
vat
vet
vex
vim
vow
wad
wag
wan
war
was
wax
way
web
wed
wen
wet
wig
win
wit
wok
won
wot
wow
yak
yam
yap
yaw
yen
yep
yes
yet
yew
yip
yon
yuk
yum
yup
zap
zed
zip
zit




