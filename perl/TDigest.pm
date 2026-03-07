package TDigest;
use strict;
use warnings;
use POSIX qw();
use Tree234;

# Dunning t-digest for online quantile estimation.
# Merging digest variant with K_1 (arcsine) scale function.
# Uses an array-backed 2-3-4 tree with four-component monoidal measures.

my $PI            = 4.0 * atan2( 1, 1 );
my $DEFAULT_DELTA = 100;
my $BUFFER_FACTOR = 5;
my $INF           = 9**9**9;

# Centroid: [ mean, weight ]
# Measure:  { weight, count, max_mean, mean_weight_sum }

sub _measure_fn {
    my ($c) = @_;
    return {
        weight          => $c->[1],
        count           => 1,
        max_mean        => $c->[0],
        mean_weight_sum => $c->[0] * $c->[1],
    };
}

sub _combine_fn {
    my ( $a, $b ) = @_;
    return {
        weight          => $a->{weight} + $b->{weight},
        count           => $a->{count} + $b->{count},
        max_mean        => ( $a->{max_mean} > $b->{max_mean} ? $a->{max_mean} : $b->{max_mean} ),
        mean_weight_sum => $a->{mean_weight_sum} + $b->{mean_weight_sum},
    };
}

sub _identity_fn {
    return {
        weight          => 0,
        count           => 0,
        max_mean        => -$INF,
        mean_weight_sum => 0,
    };
}

sub _compare_fn {
    my ( $a, $b ) = @_;
    return $a->[0] <=> $b->[0];
}

sub new {
    my ( $class, %args ) = @_;
    my $delta = $args{delta} || $DEFAULT_DELTA;
    my $self  = bless {
        delta        => $delta + 0.0,
        tree         => Tree234->new(
            measure_fn  => \&_measure_fn,
            combine_fn  => \&_combine_fn,
            identity_fn => \&_identity_fn,
            compare_fn  => \&_compare_fn,
        ),
        buffer       => [],
        total_weight => 0.0,
        min          => $INF,
        max          => -$INF,
        buffer_cap   => POSIX::ceil( $delta * $BUFFER_FACTOR ),
    }, $class;
    return $self;
}

sub add {
    my ( $self, $value, $weight ) = @_;
    $value += 0.0;
    $weight = defined $weight ? $weight + 0.0 : 1.0;
    push @{ $self->{buffer} }, [ $value, $weight ];
    $self->{total_weight} += $weight;
    $self->{min} = $value if $value < $self->{min};
    $self->{max} = $value if $value > $self->{max};
    $self->compress() if scalar( @{ $self->{buffer} } ) >= $self->{buffer_cap};
    return $self;
}

sub compress {
    my ($self) = @_;
    my $tree = $self->{tree};
    return if @{ $self->{buffer} } == 0 && $tree->size() <= 1;

    # Collect all centroids from tree and buffer
    my $from_tree = $tree->collect();
    my @all = ( @$from_tree, @{ $self->{buffer} } );
    $self->{buffer} = [];
    @all = sort { $a->[0] <=> $b->[0] } @all;

    # Merge centroids according to K1 scale function
    my @new           = ( [ $all[0][0], $all[0][1] ] );
    my $weight_so_far = 0.0;
    my $n             = $self->{total_weight};

    for my $i ( 1 .. $#all ) {
        my $proposed = $new[-1][1] + $all[$i][1];
        my $q0       = $weight_so_far / $n;
        my $q1       = ( $weight_so_far + $proposed ) / $n;

        if ( $proposed <= 1 && @all > 1 ) {
            _merge_into_last( \@new, $all[$i] );
        }
        elsif ( $self->_k($q1) - $self->_k($q0) <= 1.0 ) {
            _merge_into_last( \@new, $all[$i] );
        }
        else {
            $weight_so_far += $new[-1][1];
            push @new, [ $all[$i][0], $all[$i][1] ];
        }
    }

    # Rebuild tree from sorted merged centroids
    $tree->build_from_sorted( \@new );
    return $self;
}

sub quantile {
    my ( $self, $q ) = @_;
    $self->compress() if @{ $self->{buffer} };
    my $tree = $self->{tree};
    return undef unless $tree->size();
    if ( $tree->size() == 1 ) {
        my $all = $tree->collect();
        return $all->[0][0];
    }

    $q = 0.0 if $q < 0.0;
    $q = 1.0 if $q > 1.0;

    my $centroids = $tree->collect();
    my $count     = scalar @$centroids;
    my $n         = $self->{total_weight};
    my $target    = $q * $n;

    # Build prefix sums
    my @cum;
    $cum[0] = $centroids->[0][1];
    for my $i ( 1 .. $count - 1 ) {
        $cum[$i] = $cum[ $i - 1 ] + $centroids->[$i][1];
    }

    # Handle first centroid edge case
    my $first = $centroids->[0];
    if ( $target < $first->[1] / 2.0 ) {
        return $self->{min} if $first->[1] == 1;
        return $self->{min} +
          ( $first->[0] - $self->{min} ) * ( $target / ( $first->[1] / 2.0 ) );
    }

    # Handle last centroid edge case
    my $last = $centroids->[ $count - 1 ];
    if ( $target > $n - $last->[1] / 2.0 ) {
        return $self->{max} if $last->[1] == 1;
        my $remaining = $n - $last->[1] / 2.0;
        return $last->[0] +
          ( $self->{max} - $last->[0] ) *
          ( ( $target - $remaining ) / ( $last->[1] / 2.0 ) );
    }

    # Binary search on cumulative weights
    my $idx;
    {
        my ( $lo, $hi ) = ( 0, $count - 1 );
        while ( $lo < $hi ) {
            my $mid = int( ( $lo + $hi ) / 2 );
            if ( $cum[$mid] < $target ) {
                $lo = $mid + 1;
            }
            else {
                $hi = $mid;
            }
        }
        $idx = $lo;
    }

    $idx = $count - 2 if $idx >= $count - 1;
    $idx = 0          if $idx < 0;

    my $cumulative = $idx > 0 ? $cum[ $idx - 1 ] : 0.0;
    my $c          = $centroids->[$idx];
    my $mid_val    = $cumulative + $c->[1] / 2.0;

    if ( $idx > 0 && $target < $mid_val ) {
        $idx--;
        $cumulative = $idx > 0 ? $cum[ $idx - 1 ] : 0.0;
        my $c2       = $centroids->[$idx];
        my $mid2     = $cumulative + $c2->[1] / 2.0;
        my $next_c   = $centroids->[ $idx + 1 ];
        my $next_mid = $cumulative + $c2->[1] + $next_c->[1] / 2.0;
        my $frac =
          ( $next_mid == $mid2 ) ? 0.5 : ( $target - $mid2 ) / ( $next_mid - $mid2 );
        return $c2->[0] + $frac * ( $next_c->[0] - $c2->[0] );
    }

    if ( $idx == $count - 1 ) {
        return $c->[0];
    }

    my $next_c   = $centroids->[ $idx + 1 ];
    my $next_mid = $cumulative + $c->[1] + $next_c->[1] / 2.0;

    if ( $target <= $next_mid ) {
        my $frac =
          ( $next_mid == $mid_val )
          ? 0.5
          : ( $target - $mid_val ) / ( $next_mid - $mid_val );
        return $c->[0] + $frac * ( $next_c->[0] - $c->[0] );
    }

    return $self->{max};
}

sub cdf {
    my ( $self, $x ) = @_;
    $self->compress() if @{ $self->{buffer} };
    my $tree = $self->{tree};
    return undef unless $tree->size();
    return 0.0 if $x <= $self->{min};
    return 1.0 if $x >= $self->{max};

    my $centroids = $tree->collect();
    my $count     = scalar @$centroids;
    my $n         = $self->{total_weight};

    # Build prefix sums
    my @cum;
    $cum[0] = $centroids->[0][1];
    for my $i ( 1 .. $count - 1 ) {
        $cum[$i] = $cum[ $i - 1 ] + $centroids->[$i][1];
    }

    # Binary search for position
    my $pos = 0;
    {
        my ( $lo, $hi ) = ( 0, $count );
        while ( $lo < $hi ) {
            my $mid = int( ( $lo + $hi ) / 2 );
            if ( $centroids->[$mid][0] < $x ) {
                $lo = $mid + 1;
            }
            else {
                $hi = $mid;
            }
        }
        $pos = $lo;
    }

    # x is less than the first centroid's mean
    if ( $pos == 0 ) {
        my $c = $centroids->[0];
        if ( $x < $c->[0] ) {
            my $inner_w = $c->[1] / 2.0;
            my $frac =
              ( $c->[0] == $self->{min} )
              ? 1.0
              : ( $x - $self->{min} ) / ( $c->[0] - $self->{min} );
            return ( $inner_w * $frac ) / $n;
        }
        return ( $c->[1] / 2.0 ) / $n;
    }

    # x is >= all centroid means
    if ( $pos == $count ) {
        my $c          = $centroids->[ $count - 1 ];
        my $cumulative = $count > 1 ? $cum[ $count - 2 ] : 0.0;
        if ( $x > $c->[0] ) {
            my $right_w = $n - $cumulative - $c->[1] / 2.0;
            my $frac =
              ( $self->{max} == $c->[0] )
              ? 0.0
              : ( $x - $c->[0] ) / ( $self->{max} - $c->[0] );
            return ( $cumulative + $c->[1] / 2.0 + $right_w * $frac ) / $n;
        }
        return ( $cumulative + $c->[1] / 2.0 ) / $n;
    }

    # x is between centroids[pos-1].mean and centroids[pos].mean
    my $i          = $pos - 1;
    my $c          = $centroids->[$i];
    my $next_c     = $centroids->[$pos];
    my $cumulative = $i > 0 ? $cum[ $i - 1 ] : 0.0;
    my $mid_cdf    = $cumulative + $c->[1] / 2.0;
    my $next_cumulative = $cumulative + $c->[1];
    my $next_mid        = $next_cumulative + $next_c->[1] / 2.0;

    if ( $i == $count - 1 ) {
        if ( $x > $c->[0] ) {
            my $right_w = $n - $cumulative - $c->[1] / 2.0;
            my $frac =
              ( $self->{max} == $c->[0] )
              ? 0.0
              : ( $x - $c->[0] ) / ( $self->{max} - $c->[0] );
            return ( $cumulative + $c->[1] / 2.0 + $right_w * $frac ) / $n;
        }
        return ( $cumulative + $c->[1] / 2.0 ) / $n;
    }

    if ( $x < $next_c->[0] ) {
        if ( $c->[0] == $next_c->[0] ) {
            return ( $mid_cdf + ( $next_mid - $mid_cdf ) / 2.0 ) / $n;
        }
        my $frac = ( $x - $c->[0] ) / ( $next_c->[0] - $c->[0] );
        return ( $mid_cdf + $frac * ( $next_mid - $mid_cdf ) ) / $n;
    }

    return $next_mid / $n;
}

sub merge {
    my ( $self, $other ) = @_;
    $other->compress() if @{ $other->{buffer} };
    my $centroids = $other->{tree}->collect();
    for my $c (@$centroids) {
        $self->add( $c->[0], $c->[1] );
    }
    return $self;
}

sub size {
    my ($self) = @_;
    return $self->{tree}->size() + scalar( @{ $self->{buffer} } );
}

sub centroid_count {
    my ($self) = @_;
    $self->compress() if @{ $self->{buffer} };
    return $self->{tree}->size();
}

sub total_weight { return $_[0]->{total_weight} }
sub min          { return $_[0]->{min} }
sub max          { return $_[0]->{max} }
sub delta        { return $_[0]->{delta} }

# Private methods

sub _k {
    my ( $self, $q ) = @_;
    return ( $self->{delta} / ( 2.0 * $PI ) ) * _asin( 2.0 * $q - 1.0 );
}

sub _asin {
    my ($x) = @_;
    return atan2( $x, sqrt( 1.0 - $x * $x ) );
}

sub _merge_into_last {
    my ( $centroids, $c ) = @_;
    my $last       = $centroids->[-1];
    my $new_weight = $last->[1] + $c->[1];
    $last->[0] = ( $last->[0] * $last->[1] + $c->[0] * $c->[1] ) / $new_weight;
    $last->[1] = $new_weight;
}

1;
