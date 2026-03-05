package TDigest;
use strict;
use warnings;
use POSIX qw();

# Dunning t-digest for online quantile estimation.
# Merging digest variant with K_1 (arcsine) scale function.

my $PI            = 4.0 * atan2( 1, 1 );
my $DEFAULT_DELTA = 100;
my $BUFFER_FACTOR = 5;
my $INF           = 9**9**9;

sub new {
    my ( $class, %args ) = @_;
    my $delta = $args{delta} || $DEFAULT_DELTA;
    my $self  = bless {
        delta        => $delta + 0.0,
        centroids    => [],             # arrayref of [mean, weight]
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
    return if @{ $self->{buffer} } == 0 && @{ $self->{centroids} } <= 1;

    my @all = ( @{ $self->{centroids} }, @{ $self->{buffer} } );
    $self->{buffer} = [];
    @all = sort { $a->[0] <=> $b->[0] } @all;

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

    $self->{centroids} = \@new;
    return $self;
}

sub quantile {
    my ( $self, $q ) = @_;
    $self->compress() if @{ $self->{buffer} };
    my $centroids = $self->{centroids};
    return undef unless @$centroids;
    return $centroids->[0][0] if @$centroids == 1;

    $q = 0.0 if $q < 0.0;
    $q = 1.0 if $q > 1.0;

    my $n          = $self->{total_weight};
    my $target     = $q * $n;
    my $cumulative = 0.0;
    my $count      = scalar @$centroids;

    for my $i ( 0 .. $count - 1 ) {
        my ( $cmean, $cweight ) = @{ $centroids->[$i] };
        my $mid = $cumulative + $cweight / 2.0;

        if ( $i == 0 ) {
            if ( $target < $cweight / 2.0 ) {
                return $self->{min} if $cweight == 1;
                return $self->{min} +
                  ( $cmean - $self->{min} ) * ( $target / ( $cweight / 2.0 ) );
            }
        }

        if ( $i == $count - 1 ) {
            if ( $target > $n - $cweight / 2.0 ) {
                return $self->{max} if $cweight == 1;
                my $remaining = $n - $cweight / 2.0;
                return $cmean +
                  ( $self->{max} - $cmean ) *
                  ( ( $target - $remaining ) / ( $cweight / 2.0 ) );
            }
            return $cmean;
        }

        my ( $nmean, $nweight ) = @{ $centroids->[ $i + 1 ] };
        my $next_mid = $cumulative + $cweight + $nweight / 2.0;

        if ( $target <= $next_mid ) {
            my $frac;
            if ( $next_mid == $mid ) {
                $frac = 0.5;
            }
            else {
                $frac = ( $target - $mid ) / ( $next_mid - $mid );
            }
            return $cmean + $frac * ( $nmean - $cmean );
        }

        $cumulative += $cweight;
    }

    return $self->{max};
}

sub cdf {
    my ( $self, $x ) = @_;
    $self->compress() if @{ $self->{buffer} };
    my $centroids = $self->{centroids};
    return undef unless @$centroids;
    return 0.0 if $x <= $self->{min};
    return 1.0 if $x >= $self->{max};

    my $n          = $self->{total_weight};
    my $cumulative = 0.0;
    my $count      = scalar @$centroids;

    for my $i ( 0 .. $count - 1 ) {
        my ( $cmean, $cweight ) = @{ $centroids->[$i] };

        if ( $i == 0 ) {
            if ( $x < $cmean ) {
                my $inner_w = $cweight / 2.0;
                my $frac =
                  ( $cmean == $self->{min} )
                  ? 1.0
                  : ( $x - $self->{min} ) / ( $cmean - $self->{min} );
                return ( $inner_w * $frac ) / $n;
            }
            elsif ( $x == $cmean ) {
                return ( $cweight / 2.0 ) / $n;
            }
        }

        if ( $i == $count - 1 ) {
            if ( $x > $cmean ) {
                my $inner_w = $cweight / 2.0;
                my $right_w = $n - $cumulative - $cweight / 2.0;
                my $frac =
                  ( $self->{max} == $cmean )
                  ? 0.0
                  : ( $x - $cmean ) / ( $self->{max} - $cmean );
                return ( $cumulative + $cweight / 2.0 + $right_w * $frac ) / $n;
            }
            else {
                return ( $cumulative + $cweight / 2.0 ) / $n;
            }
        }

        my $mid = $cumulative + $cweight / 2.0;
        my ( $nmean, $nweight ) = @{ $centroids->[ $i + 1 ] };
        my $next_cumulative = $cumulative + $cweight;
        my $next_mid        = $next_cumulative + $nweight / 2.0;

        if ( $x < $nmean ) {
            if ( $cmean == $nmean ) {
                return ( $mid + ( $next_mid - $mid ) / 2.0 ) / $n;
            }
            my $frac = ( $x - $cmean ) / ( $nmean - $cmean );
            return ( $mid + $frac * ( $next_mid - $mid ) ) / $n;
        }

        $cumulative += $cweight;
    }

    return 1.0;
}

sub merge {
    my ( $self, $other ) = @_;
    $other->compress() if @{ $other->{buffer} };
    for my $c ( @{ $other->{centroids} } ) {
        $self->add( $c->[0], $c->[1] );
    }
    return $self;
}

sub size {
    my ($self) = @_;
    return scalar( @{ $self->{centroids} } ) + scalar( @{ $self->{buffer} } );
}

sub centroid_count {
    my ($self) = @_;
    $self->compress() if @{ $self->{buffer} };
    return scalar @{ $self->{centroids} };
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
