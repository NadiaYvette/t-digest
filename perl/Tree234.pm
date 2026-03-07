package Tree234;
use strict;
use warnings;

# Generic array-backed 2-3-4 tree with monoidal measures.
#
# Constructor takes coderefs:
#   measure_fn  - measure a single key element
#   combine_fn  - monoidal combine of two measures
#   identity_fn - monoidal identity (returns a measure)
#   compare_fn  - compare two keys: returns <0, 0, >0

sub new {
    my ( $class, %args ) = @_;
    my $measure_fn  = $args{measure_fn}  or die "measure_fn required";
    my $combine_fn  = $args{combine_fn}  or die "combine_fn required";
    my $identity_fn = $args{identity_fn} or die "identity_fn required";
    my $compare_fn  = $args{compare_fn}  or die "compare_fn required";
    my $self = bless {
        nodes       => [],     # array of hashes (node pool)
        free_list   => [],     # free node indices
        root        => -1,
        count       => 0,
        measure_fn  => $measure_fn,
        combine_fn  => $combine_fn,
        identity_fn => $identity_fn,
        compare_fn  => $compare_fn,
    }, $class;
    return $self;
}

# --- Node allocation ---

sub _alloc_node {
    my ($self) = @_;
    my $idx;
    if ( @{ $self->{free_list} } ) {
        $idx = pop @{ $self->{free_list} };
        $self->{nodes}[$idx] = {
            n        => 0,
            keys     => [ undef, undef, undef ],
            children => [ -1, -1, -1, -1 ],
            measure  => $self->{identity_fn}->(),
        };
    }
    else {
        $idx = scalar @{ $self->{nodes} };
        push @{ $self->{nodes} }, {
            n        => 0,
            keys     => [ undef, undef, undef ],
            children => [ -1, -1, -1, -1 ],
            measure  => $self->{identity_fn}->(),
        };
    }
    return $idx;
}

sub _free_node {
    my ( $self, $idx ) = @_;
    push @{ $self->{free_list} }, $idx;
}

sub _is_leaf {
    my ( $self, $idx ) = @_;
    return $self->{nodes}[$idx]{children}[0] == -1;
}

sub _is_4node {
    my ( $self, $idx ) = @_;
    return $self->{nodes}[$idx]{n} == 3;
}

# --- Measure recomputation ---

sub _recompute_measure {
    my ( $self, $idx ) = @_;
    my $nd      = $self->{nodes}[$idx];
    my $m       = $self->{identity_fn}->();
    my $combine = $self->{combine_fn};
    my $meas_fn = $self->{measure_fn};

    for my $i ( 0 .. $nd->{n} ) {
        if ( $nd->{children}[$i] != -1 ) {
            $m = $combine->( $m, $self->{nodes}[ $nd->{children}[$i] ]{measure} );
        }
        if ( $i < $nd->{n} ) {
            $m = $combine->( $m, $meas_fn->( $nd->{keys}[$i] ) );
        }
    }
    $nd->{measure} = $m;
}

# --- Split a 4-node child ---

sub _split_child {
    my ( $self, $parent_idx, $child_pos ) = @_;
    my $child_idx = $self->{nodes}[$parent_idx]{children}[$child_pos];

    # Save child data before alloc (which may change array)
    my $cn = $self->{nodes}[$child_idx];
    my $k0 = $cn->{keys}[0];
    my $k1 = $cn->{keys}[1];
    my $k2 = $cn->{keys}[2];
    my @cc = @{ $cn->{children} };

    # Create right node with k2, c2, c3
    my $right_idx = $self->_alloc_node();
    my $rn = $self->{nodes}[$right_idx];
    $rn->{n}           = 1;
    $rn->{keys}[0]     = $k2;
    $rn->{children}[0] = $cc[2];
    $rn->{children}[1] = $cc[3];

    # Shrink child (left) to k0, c0, c1
    $cn = $self->{nodes}[$child_idx];    # re-fetch after alloc
    $cn->{n}           = 1;
    $cn->{keys}[0]     = $k0;
    $cn->{keys}[1]     = undef;
    $cn->{keys}[2]     = undef;
    $cn->{children}[0] = $cc[0];
    $cn->{children}[1] = $cc[1];
    $cn->{children}[2] = -1;
    $cn->{children}[3] = -1;

    $self->_recompute_measure($child_idx);
    $self->_recompute_measure($right_idx);

    # Insert mid_key (k1) into parent at child_pos
    my $pn = $self->{nodes}[$parent_idx];
    for ( my $i = $pn->{n} ; $i > $child_pos ; $i-- ) {
        $pn->{keys}[$i]         = $pn->{keys}[ $i - 1 ];
        $pn->{children}[ $i + 1 ] = $pn->{children}[$i];
    }
    $pn->{keys}[$child_pos]         = $k1;
    $pn->{children}[ $child_pos + 1 ] = $right_idx;
    $pn->{n}++;

    $self->_recompute_measure($parent_idx);
}

# --- Insert into non-full node ---

sub _insert_non_full {
    my ( $self, $idx, $key ) = @_;
    my $nd  = $self->{nodes}[$idx];
    my $cmp = $self->{compare_fn};

    if ( $self->_is_leaf($idx) ) {
        my $pos = $nd->{n};
        while ( $pos > 0 && $cmp->( $key, $nd->{keys}[ $pos - 1 ] ) < 0 ) {
            $nd->{keys}[$pos] = $nd->{keys}[ $pos - 1 ];
            $pos--;
        }
        $nd->{keys}[$pos] = $key;
        $nd->{n}++;
        $self->_recompute_measure($idx);
        return;
    }

    # Find child to descend into
    my $pos = 0;
    while ( $pos < $nd->{n} && $cmp->( $key, $nd->{keys}[$pos] ) >= 0 ) {
        $pos++;
    }

    # If that child is a 4-node, split it first
    if ( $self->_is_4node( $nd->{children}[$pos] ) ) {
        $self->_split_child( $idx, $pos );
        # Re-fetch after split
        $nd = $self->{nodes}[$idx];
        if ( $cmp->( $key, $nd->{keys}[$pos] ) >= 0 ) {
            $pos++;
        }
    }

    $self->_insert_non_full( $nd->{children}[$pos], $key );
    $self->_recompute_measure($idx);
}

# --- Public: insert ---

sub insert {
    my ( $self, $key ) = @_;

    if ( $self->{root} == -1 ) {
        $self->{root} = $self->_alloc_node();
        my $rn = $self->{nodes}[ $self->{root} ];
        $rn->{n}       = 1;
        $rn->{keys}[0] = $key;
        $self->_recompute_measure( $self->{root} );
        $self->{count}++;
        return;
    }

    # If root is a 4-node, split it
    if ( $self->_is_4node( $self->{root} ) ) {
        my $old_root = $self->{root};
        $self->{root} = $self->_alloc_node();
        $self->{nodes}[ $self->{root} ]{children}[0] = $old_root;
        $self->_split_child( $self->{root}, 0 );
    }

    $self->_insert_non_full( $self->{root}, $key );
    $self->{count}++;
}

# --- Public: clear ---

sub clear {
    my ($self) = @_;
    $self->{nodes}     = [];
    $self->{free_list} = [];
    $self->{root}      = -1;
    $self->{count}     = 0;
}

# --- Public: size ---

sub size {
    my ($self) = @_;
    return $self->{count};
}

# --- Public: root_measure ---

sub root_measure {
    my ($self) = @_;
    return $self->{identity_fn}->() if $self->{root} == -1;
    return $self->{nodes}[ $self->{root} ]{measure};
}

# --- In-order traversal ---

sub _for_each_impl {
    my ( $self, $idx, $f ) = @_;
    return if $idx == -1;
    my $nd = $self->{nodes}[$idx];
    for my $i ( 0 .. $nd->{n} ) {
        if ( $nd->{children}[$i] != -1 ) {
            $self->_for_each_impl( $nd->{children}[$i], $f );
        }
        if ( $i < $nd->{n} ) {
            $f->( $nd->{keys}[$i] );
        }
    }
}

# --- Public: collect (in-order into arrayref) ---

sub collect {
    my ($self) = @_;
    my @out;
    $self->_for_each_impl(
        $self->{root},
        sub { push @out, $_[0] }
    );
    return \@out;
}

# --- Subtree count ---

sub _subtree_count {
    my ( $self, $idx ) = @_;
    return 0 if $idx == -1;
    my $nd = $self->{nodes}[$idx];
    my $c  = $nd->{n};
    for my $i ( 0 .. $nd->{n} ) {
        $c += $self->_subtree_count( $nd->{children}[$i] )
          if $nd->{children}[$i] != -1;
    }
    return $c;
}

# --- Public: find_by_weight ---

sub find_by_weight {
    my ( $self, $target, $weight_of ) = @_;
    return { found => 0 } if $self->{root} == -1;
    return $self->_find_by_weight_impl( $self->{root}, $target, 0.0, 0, $weight_of );
}

sub _find_by_weight_impl {
    my ( $self, $idx, $target, $cum, $global_idx, $weight_of ) = @_;
    return { found => 0 } if $idx == -1;

    my $nd          = $self->{nodes}[$idx];
    my $running_cum = $cum;
    my $running_idx = $global_idx;
    my $meas_fn     = $self->{measure_fn};

    for my $i ( 0 .. $nd->{n} ) {
        # Process child
        if ( $nd->{children}[$i] != -1 ) {
            my $child_weight = $weight_of->( $self->{nodes}[ $nd->{children}[$i] ]{measure} );
            if ( $running_cum + $child_weight >= $target ) {
                return $self->_find_by_weight_impl(
                    $nd->{children}[$i], $target, $running_cum, $running_idx, $weight_of
                );
            }
            $running_cum += $child_weight;
            $running_idx += $self->_subtree_count( $nd->{children}[$i] );
        }

        if ( $i < $nd->{n} ) {
            my $key_weight = $weight_of->( $meas_fn->( $nd->{keys}[$i] ) );
            if ( $running_cum + $key_weight >= $target ) {
                return {
                    key        => $nd->{keys}[$i],
                    cum_before => $running_cum,
                    index      => $running_idx,
                    found      => 1,
                };
            }
            $running_cum += $key_weight;
            $running_idx++;
        }
    }

    return { found => 0 };
}

# --- Public: build_from_sorted ---

sub build_from_sorted {
    my ( $self, $sorted ) = @_;
    $self->clear();
    return unless @$sorted;
    $self->{count} = scalar @$sorted;
    $self->{root}  = $self->_build_recursive( $sorted, 0, scalar @$sorted );
}

sub _build_recursive {
    my ( $self, $sorted, $lo, $hi ) = @_;
    my $n = $hi - $lo;
    return -1 if $n <= 0;

    if ( $n <= 3 ) {
        my $idx = $self->_alloc_node();
        $self->{nodes}[$idx]{n} = $n;
        for my $i ( 0 .. $n - 1 ) {
            $self->{nodes}[$idx]{keys}[$i] = $sorted->[ $lo + $i ];
        }
        $self->_recompute_measure($idx);
        return $idx;
    }

    if ( $n <= 7 ) {
        # 2-node
        my $mid   = $lo + int( $n / 2 );
        my $left  = $self->_build_recursive( $sorted, $lo, $mid );
        my $right = $self->_build_recursive( $sorted, $mid + 1, $hi );
        my $idx   = $self->_alloc_node();
        $self->{nodes}[$idx]{n}           = 1;
        $self->{nodes}[$idx]{keys}[0]     = $sorted->[$mid];
        $self->{nodes}[$idx]{children}[0] = $left;
        $self->{nodes}[$idx]{children}[1] = $right;
        $self->_recompute_measure($idx);
        return $idx;
    }

    # 3-node for larger ranges
    my $third = int( $n / 3 );
    my $m1    = $lo + $third;
    my $m2    = $lo + 2 * $third + 1;
    my $c0    = $self->_build_recursive( $sorted, $lo, $m1 );
    my $c1    = $self->_build_recursive( $sorted, $m1 + 1, $m2 );
    my $c2    = $self->_build_recursive( $sorted, $m2 + 1, $hi );
    my $idx   = $self->_alloc_node();
    $self->{nodes}[$idx]{n}           = 2;
    $self->{nodes}[$idx]{keys}[0]     = $sorted->[$m1];
    $self->{nodes}[$idx]{keys}[1]     = $sorted->[$m2];
    $self->{nodes}[$idx]{children}[0] = $c0;
    $self->{nodes}[$idx]{children}[1] = $c1;
    $self->{nodes}[$idx]{children}[2] = $c2;
    $self->_recompute_measure($idx);
    return $idx;
}

1;
