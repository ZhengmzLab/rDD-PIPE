#!/usr/bin/perl
# juicer's 'short form' to 4dn-pairs converter || Soo Lee, 2017
my $split_sort = 0;

use Getopt::Long;
&GetOptions( 's|split_sort=s' => \$split_sort );

if(@ARGV<1) { print "usage: $0 [-s|--split_sort <nsplit>] input.txt chrom_size outprefix\nRequires sort and bgzip\n"; exit; }
$infile = $ARGV[0];
$chromsizefile = $ARGV[1];
$outfile_prefix = $ARGV[2];

# chromsize file
$k=0;
open CHROMSIZE, $chromsizefile or die "Can't open chromsizefile $chromsizefile";
while(<CHROMSIZE>){
  chomp;
  my ($chr,$size) = split/\s+/;
  $chromsize{$chr}=$size;
  $chromorder{$chr}=$k++;
}
close CHROMSIZE;


# writing to text pairs
open OUT, ">$outfile_prefix.pairs" or die "Can't write to $outfile\n";
print OUT "## pairs format v1.0\n";
print OUT "#sorted: chr1-chr2-pos1-pos2\n";
print OUT "#shape: upper triangle\n";

for my $chr (sort {$chromorder{$a} <=> $chromorder{$b}} keys %chromorder){
  print OUT "#chromsize: $chr $chromsize{$chr}\n";
}

# print out command
# $command_options = $split_sort>0?'-s $split_sort':'';
# print OUT "#command: juicer_shortform2pairs.pl $command_options @ARGV\n"; 
print OUT "#columns: readID chr1 pos1 chr2 pos2 strand1 strand2 frag1 frag2\n";

my $n=0; # line count
open IN, "gunzip -c $infile |" or die "Can't open $infile\n";
while(<IN>){
  chomp;
  my ($s1,$c1,$p1,$f1,$s2,$c2,$p2,$f2) = (split/\s/)[0..7];
  my $ri='.'; 
  $s1 = $s1==0?'+':'-';
  $s2 = $s2==0?'+':'-';
  $c1 = "chr$c1";
  $c2 = "chr$c2";
  next if(!exists $chromorder{$c1} || !exists $chromorder{$c2});  # chromosome filtering
  if($chromorder{$c1} > $chromorder{$c2} || ($chromorder{$c1} == $chromorder{$c2} && $p1>$p2)) { # flip
    print OUT "$ri\t$c2\t$p2\t$c1\t$p1\t$s2\t$s1\t$f2\t$f1\n";
  } else {
    print OUT "$ri\t$c1\t$p1\t$c2\t$p2\t$s1\t$s2\t$f1\t$f2\n";
  }
  $n++;
}

close IN;
close OUT;

# sorting
system("grep '^#' $outfile_prefix.pairs > $outfile_prefix.bsorted.pairs");

if($split_sort>1) {
  my $L = int($n/$split_sort)+1;
  system("grep -v '^#' $outfile_prefix.pairs | split -l $L - $outfile_prefix.pairs.split");
  my $i=0;
  for my $file (split/\n/,`ls -1 $outfile_prefix.pairs.split*`){
    system("sort -k2,2 -k4,4 -k3,3g -k5,5g $file >> $outfile_prefix.bsorted.pairs.split$i");
    $i++;
  }
  system("sort -m -k2,2 -k4,4 -k3,3g -k5,5g $outfile_prefix.bsorted.pairs.split* >> $outfile_prefix.bsorted.pairs"); 
}else{
  system("grep -v '^#' $outfile_prefix.pairs | sort -k2,2 -k4,4 -k3,3g -k5,5g >> $outfile_prefix.bsorted.pairs");
}

# bgzipping
system("bgzip -f $outfile_prefix.bsorted.pairs");

# pairix indexing
#system("pairix -f $outfile_prefix.bsorted.pairs.gz");

# removing text file
system("rm -f $outfile_prefix.pairs");
