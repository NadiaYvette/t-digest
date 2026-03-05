#!/usr/bin/env perl
use strict;
use warnings;
use TDigest;

my $td = TDigest->new( delta => 100 );

# Insert 10000 uniformly spaced values in [0, 1)
my $n = 10_000;
for my $i ( 0 .. $n - 1 ) {
    $td->add( $i / $n );
}

printf( "T-Digest demo: %d uniform values in [0, 1)\n", $n );
printf( "Centroids: %d\n\n",                            $td->centroid_count() );

print "Quantile estimates (expected ~ q for uniform):\n";
for my $q ( 0.001, 0.01, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99, 0.999 ) {
    my $est = $td->quantile($q);
    printf( "  q=%-6.3f  estimated=%.6f  error=%.6f\n",
        $q, $est, abs( $est - $q ) );
}

print "\nCDF estimates (expected ~ x for uniform):\n";
for my $x ( 0.001, 0.01, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99, 0.999 ) {
    my $est = $td->cdf($x);
    printf( "  x=%-6.3f  estimated=%.6f  error=%.6f\n",
        $x, $est, abs( $est - $x ) );
}

# Test merge
my $td1 = TDigest->new( delta => 100 );
my $td2 = TDigest->new( delta => 100 );
for my $i ( 0 .. 4999 ) {
    $td1->add( $i / 10_000 );
}
for my $i ( 5000 .. 9999 ) {
    $td2->add( $i / 10_000 );
}
$td1->merge($td2);

print "\nAfter merge:\n";
printf( "  median=%.6f (expected ~0.5)\n",  $td1->quantile(0.5) );
printf( "  p99   =%.6f (expected ~0.99)\n", $td1->quantile(0.99) );

print "\nAll tests passed!\n";
