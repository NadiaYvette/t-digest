! Dunning t-digest for online quantile estimation.
! Merging digest variant with K_1 (arcsine) scale function.
! Uses an array-backed 2-3-4 tree with four-component monoidal measures.
! Fortran 2003+ module with derived types and type-bound procedures.

module tdigest_mod
  implicit none
  private

  integer, parameter :: dp = selected_real_kind(15, 307)
  real(dp), parameter :: PI_VAL = 3.14159265358979323846_dp
  real(dp), parameter :: NEG_INF = -huge(1.0_dp)
  integer, parameter :: DEFAULT_DELTA = 100
  integer, parameter :: BUFFER_FACTOR = 5
  integer, parameter :: INITIAL_POOL = 256

  ! --- Centroid type ---
  type :: centroid_type
    real(dp) :: mean   = 0.0_dp
    real(dp) :: weight = 0.0_dp
  end type centroid_type

  ! --- Four-component monoidal measure ---
  type :: td_measure_type
    real(dp) :: weight          = 0.0_dp
    integer  :: count           = 0
    real(dp) :: max_mean        = -huge(1.0_dp)
    real(dp) :: mean_weight_sum = 0.0_dp
  end type td_measure_type

  ! --- 2-3-4 tree node ---
  type :: tree_node
    integer  :: n = 0                           ! number of keys (1-3)
    type(centroid_type) :: keys(3)
    integer  :: children(4) = [-1,-1,-1,-1]     ! -1 = no child
    type(td_measure_type) :: measure
  end type tree_node

  ! --- 2-3-4 tree (array-backed with free list) ---
  type :: tree234
    type(tree_node), allocatable :: nodes(:)
    integer, allocatable :: free_list(:)
    integer :: pool_size  = 0   ! allocated capacity of nodes array
    integer :: pool_used  = 0   ! high-water mark in nodes array
    integer :: free_count = 0   ! entries in free_list
    integer :: root       = -1
    integer :: cnt        = 0   ! number of keys
  end type tree234

  ! --- Main t-digest type ---
  type, public :: tdigest
    real(dp) :: delta = real(DEFAULT_DELTA, dp)
    type(tree234) :: tree
    real(dp), allocatable :: b_mean(:), b_weight(:)   ! buffer
    integer :: n_buffer = 0
    real(dp) :: total_weight = 0.0_dp
    real(dp) :: min_val =  huge(1.0_dp)
    real(dp) :: max_val = -huge(1.0_dp)
    integer :: buffer_cap = DEFAULT_DELTA * BUFFER_FACTOR
    integer :: b_capacity = 0
  contains
    procedure :: init => tdigest_init
    procedure :: add => tdigest_add
    procedure :: compress => tdigest_compress
    procedure :: quantile => tdigest_quantile
    procedure :: cdf => tdigest_cdf
    procedure :: merge => tdigest_merge
    procedure :: centroid_count => tdigest_centroid_count
    procedure :: k_func => tdigest_k
  end type tdigest

  public :: tdigest_create

contains

  ! =====================================================================
  !  Measure helpers
  ! =====================================================================

  function measure_identity() result(m)
    type(td_measure_type) :: m
    m%weight          = 0.0_dp
    m%count           = 0
    m%max_mean        = NEG_INF
    m%mean_weight_sum = 0.0_dp
  end function

  function measure_single(c) result(m)
    type(centroid_type), intent(in) :: c
    type(td_measure_type) :: m
    m%weight          = c%weight
    m%count           = 1
    m%max_mean        = c%mean
    m%mean_weight_sum = c%mean * c%weight
  end function

  function measure_combine(a, b) result(m)
    type(td_measure_type), intent(in) :: a, b
    type(td_measure_type) :: m
    m%weight          = a%weight + b%weight
    m%count           = a%count + b%count
    m%max_mean        = max(a%max_mean, b%max_mean)
    m%mean_weight_sum = a%mean_weight_sum + b%mean_weight_sum
  end function

  ! =====================================================================
  !  2-3-4 tree internals
  ! =====================================================================

  subroutine tree_ensure_pool(t, needed)
    type(tree234), intent(inout) :: t
    integer, intent(in) :: needed
    type(tree_node), allocatable :: tmp(:)
    integer :: new_cap

    if (needed <= t%pool_size) return
    new_cap = max(needed, t%pool_size * 2, INITIAL_POOL)
    if (allocated(t%nodes)) then
      allocate(tmp(new_cap))
      tmp(1:t%pool_used) = t%nodes(1:t%pool_used)
      call move_alloc(tmp, t%nodes)
    else
      allocate(t%nodes(new_cap))
    end if
    if (.not. allocated(t%free_list)) then
      allocate(t%free_list(new_cap))
    else if (size(t%free_list) < new_cap) then
      allocate(tmp(0))  ! dummy, we need int array
      deallocate(tmp)
      block
        integer, allocatable :: itmp(:)
        allocate(itmp(new_cap))
        itmp(1:t%free_count) = t%free_list(1:t%free_count)
        call move_alloc(itmp, t%free_list)
      end block
    end if
    t%pool_size = new_cap
  end subroutine

  function tree_alloc_node(t) result(idx)
    type(tree234), intent(inout) :: t
    integer :: idx
    type(tree_node) :: blank

    if (t%free_count > 0) then
      idx = t%free_list(t%free_count)
      t%free_count = t%free_count - 1
      t%nodes(idx) = blank
    else
      call tree_ensure_pool(t, t%pool_used + 1)
      t%pool_used = t%pool_used + 1
      idx = t%pool_used
      t%nodes(idx) = blank
    end if
    t%nodes(idx)%children = -1
    t%nodes(idx)%measure = measure_identity()
  end function

  subroutine tree_recompute(t, idx)
    type(tree234), intent(inout) :: t
    integer, intent(in) :: idx
    type(td_measure_type) :: m
    integer :: i, ci

    m = measure_identity()
    do i = 1, t%nodes(idx)%n + 1
      ci = t%nodes(idx)%children(i)
      if (ci /= -1) then
        m = measure_combine(m, t%nodes(ci)%measure)
      end if
      if (i <= t%nodes(idx)%n) then
        m = measure_combine(m, measure_single(t%nodes(idx)%keys(i)))
      end if
    end do
    t%nodes(idx)%measure = m
  end subroutine

  function tree_is_leaf(t, idx) result(res)
    type(tree234), intent(in) :: t
    integer, intent(in) :: idx
    logical :: res
    res = (t%nodes(idx)%children(1) == -1)
  end function

  ! Split a 4-node child at position child_pos (1-based) of parent
  subroutine tree_split_child(t, parent_idx, child_pos)
    type(tree234), intent(inout) :: t
    integer, intent(in) :: parent_idx, child_pos
    integer :: child_idx, right_idx, i
    type(centroid_type) :: k0, k1, k2
    integer :: c0, c1, c2, c3

    child_idx = t%nodes(parent_idx)%children(child_pos)

    ! Save child data
    k0 = t%nodes(child_idx)%keys(1)
    k1 = t%nodes(child_idx)%keys(2)
    k2 = t%nodes(child_idx)%keys(3)
    c0 = t%nodes(child_idx)%children(1)
    c1 = t%nodes(child_idx)%children(2)
    c2 = t%nodes(child_idx)%children(3)
    c3 = t%nodes(child_idx)%children(4)

    ! Allocate right node
    right_idx = tree_alloc_node(t)

    ! Right gets k2, c2, c3
    t%nodes(right_idx)%n = 1
    t%nodes(right_idx)%keys(1) = k2
    t%nodes(right_idx)%children(1) = c2
    t%nodes(right_idx)%children(2) = c3

    ! Shrink child (left) to k0, c0, c1
    t%nodes(child_idx)%n = 1
    t%nodes(child_idx)%keys(1) = k0
    t%nodes(child_idx)%children(1) = c0
    t%nodes(child_idx)%children(2) = c1
    t%nodes(child_idx)%children(3) = -1
    t%nodes(child_idx)%children(4) = -1

    call tree_recompute(t, child_idx)
    call tree_recompute(t, right_idx)

    ! Insert k1 into parent at child_pos, shift right
    do i = t%nodes(parent_idx)%n, child_pos, -1
      t%nodes(parent_idx)%keys(i + 1) = t%nodes(parent_idx)%keys(i)
      t%nodes(parent_idx)%children(i + 2) = t%nodes(parent_idx)%children(i + 1)
    end do
    t%nodes(parent_idx)%keys(child_pos) = k1
    t%nodes(parent_idx)%children(child_pos + 1) = right_idx
    t%nodes(parent_idx)%n = t%nodes(parent_idx)%n + 1

    call tree_recompute(t, parent_idx)
  end subroutine

  ! Insert key into non-full node's subtree (recursive, top-down)
  recursive subroutine tree_insert_nonfull(t, idx, key)
    type(tree234), intent(inout) :: t
    integer, intent(in) :: idx
    type(centroid_type), intent(in) :: key
    integer :: pos, i

    if (tree_is_leaf(t, idx)) then
      ! Insert in sorted position
      pos = t%nodes(idx)%n + 1
      do while (pos > 1)
        if (key%mean < t%nodes(idx)%keys(pos - 1)%mean) then
          t%nodes(idx)%keys(pos) = t%nodes(idx)%keys(pos - 1)
          pos = pos - 1
        else
          exit
        end if
      end do
      t%nodes(idx)%keys(pos) = key
      t%nodes(idx)%n = t%nodes(idx)%n + 1
      call tree_recompute(t, idx)
      return
    end if

    ! Find child to descend into (1-based)
    pos = 1
    do while (pos <= t%nodes(idx)%n)
      if (key%mean >= t%nodes(idx)%keys(pos)%mean) then
        pos = pos + 1
      else
        exit
      end if
    end do

    ! If child is a 4-node, split first
    if (t%nodes(t%nodes(idx)%children(pos))%n == 3) then
      call tree_split_child(t, idx, pos)
      if (key%mean >= t%nodes(idx)%keys(pos)%mean) then
        pos = pos + 1
      end if
    end if

    call tree_insert_nonfull(t, t%nodes(idx)%children(pos), key)
    call tree_recompute(t, idx)
  end subroutine

  ! --- Public tree operations ---

  subroutine tree_insert(t, key)
    type(tree234), intent(inout) :: t
    type(centroid_type), intent(in) :: key
    integer :: old_root, new_root

    if (t%root == -1) then
      t%root = tree_alloc_node(t)
      t%nodes(t%root)%n = 1
      t%nodes(t%root)%keys(1) = key
      call tree_recompute(t, t%root)
      t%cnt = 1
      return
    end if

    ! If root is a 4-node, split it
    if (t%nodes(t%root)%n == 3) then
      old_root = t%root
      new_root = tree_alloc_node(t)
      t%nodes(new_root)%children(1) = old_root
      t%root = new_root
      call tree_split_child(t, t%root, 1)
    end if

    call tree_insert_nonfull(t, t%root, key)
    t%cnt = t%cnt + 1
  end subroutine

  subroutine tree_clear(t)
    type(tree234), intent(inout) :: t
    t%root = -1
    t%cnt = 0
    t%pool_used = 0
    t%free_count = 0
  end subroutine

  function tree_size(t) result(sz)
    type(tree234), intent(in) :: t
    integer :: sz
    sz = t%cnt
  end function

  ! In-order collect all centroids
  recursive subroutine tree_collect_impl(t, idx, arr, pos)
    type(tree234), intent(in) :: t
    integer, intent(in) :: idx
    type(centroid_type), intent(inout) :: arr(:)
    integer, intent(inout) :: pos
    integer :: i

    if (idx == -1) return

    do i = 1, t%nodes(idx)%n + 1
      if (t%nodes(idx)%children(i) /= -1) then
        call tree_collect_impl(t, t%nodes(idx)%children(i), arr, pos)
      end if
      if (i <= t%nodes(idx)%n) then
        pos = pos + 1
        arr(pos) = t%nodes(idx)%keys(i)
      end if
    end do
  end subroutine

  subroutine tree_collect(t, arr, n_out)
    type(tree234), intent(in) :: t
    type(centroid_type), allocatable, intent(out) :: arr(:)
    integer, intent(out) :: n_out
    integer :: pos

    n_out = t%cnt
    if (n_out == 0) then
      allocate(arr(0))
      return
    end if
    allocate(arr(n_out))
    pos = 0
    call tree_collect_impl(t, t%root, arr, pos)
  end subroutine

  ! Find centroid by cumulative weight (for quantile queries)
  subroutine tree_find_by_weight(t, target, found_key, cum_before, found)
    type(tree234), intent(in) :: t
    real(dp), intent(in) :: target
    type(centroid_type), intent(out) :: found_key
    real(dp), intent(out) :: cum_before
    logical, intent(out) :: found

    found = .false.
    cum_before = 0.0_dp
    if (t%root == -1) return
    call find_by_weight_impl(t, t%root, target, 0.0_dp, found_key, cum_before, found)
  end subroutine

  recursive subroutine find_by_weight_impl(t, idx, target, cum_in, &
      found_key, cum_before, found)
    type(tree234), intent(in) :: t
    integer, intent(in) :: idx
    real(dp), intent(in) :: target, cum_in
    type(centroid_type), intent(out) :: found_key
    real(dp), intent(out) :: cum_before
    logical, intent(out) :: found
    real(dp) :: running
    integer :: i, ci
    real(dp) :: child_w, key_w

    found = .false.
    if (idx == -1) return
    running = cum_in

    do i = 1, t%nodes(idx)%n + 1
      ci = t%nodes(idx)%children(i)
      if (ci /= -1) then
        child_w = t%nodes(ci)%measure%weight
        if (running + child_w >= target) then
          call find_by_weight_impl(t, ci, target, running, &
              found_key, cum_before, found)
          return
        end if
        running = running + child_w
      end if
      if (i <= t%nodes(idx)%n) then
        key_w = t%nodes(idx)%keys(i)%weight
        if (running + key_w >= target) then
          found_key = t%nodes(idx)%keys(i)
          cum_before = running
          found = .true.
          return
        end if
        running = running + key_w
      end if
    end do
  end subroutine

  ! Build balanced tree from sorted centroid array
  recursive function tree_build_recursive(t, sorted, lo, hi) result(idx)
    type(tree234), intent(inout) :: t
    type(centroid_type), intent(in) :: sorted(:)
    integer, intent(in) :: lo, hi
    integer :: idx
    integer :: n_elem, mid, third, m1, m2
    integer :: left, right, c0, c1, c2

    n_elem = hi - lo
    idx = -1
    if (n_elem <= 0) return

    if (n_elem <= 3) then
      idx = tree_alloc_node(t)
      t%nodes(idx)%n = n_elem
      t%nodes(idx)%keys(1:n_elem) = sorted(lo+1:lo+n_elem)
      call tree_recompute(t, idx)
      return
    end if

    if (n_elem <= 7) then
      mid = lo + n_elem / 2
      left  = tree_build_recursive(t, sorted, lo, mid)
      right = tree_build_recursive(t, sorted, mid + 1, hi)
      idx = tree_alloc_node(t)
      t%nodes(idx)%n = 1
      t%nodes(idx)%keys(1) = sorted(mid + 1)
      t%nodes(idx)%children(1) = left
      t%nodes(idx)%children(2) = right
      call tree_recompute(t, idx)
      return
    end if

    ! 3-node for larger ranges
    third = n_elem / 3
    m1 = lo + third
    m2 = lo + 2 * third + 1
    c0 = tree_build_recursive(t, sorted, lo, m1)
    c1 = tree_build_recursive(t, sorted, m1 + 1, m2)
    c2 = tree_build_recursive(t, sorted, m2 + 1, hi)
    idx = tree_alloc_node(t)
    t%nodes(idx)%n = 2
    t%nodes(idx)%keys(1) = sorted(m1 + 1)
    t%nodes(idx)%keys(2) = sorted(m2 + 1)
    t%nodes(idx)%children(1) = c0
    t%nodes(idx)%children(2) = c1
    t%nodes(idx)%children(3) = c2
    call tree_recompute(t, idx)
  end function

  subroutine tree_build_from_sorted(t, sorted, n_sorted)
    type(tree234), intent(inout) :: t
    type(centroid_type), intent(in) :: sorted(:)
    integer, intent(in) :: n_sorted

    call tree_clear(t)
    if (n_sorted == 0) return
    t%cnt = n_sorted
    t%root = tree_build_recursive(t, sorted, 0, n_sorted)
  end subroutine

  ! =====================================================================
  !  T-digest implementation
  ! =====================================================================

  function tdigest_create(delta) result(td)
    integer, intent(in), optional :: delta
    type(tdigest) :: td
    integer :: d
    d = DEFAULT_DELTA
    if (present(delta)) d = delta
    call td%init(d)
  end function

  subroutine tdigest_init(self, delta)
    class(tdigest), intent(inout) :: self
    integer, intent(in) :: delta
    self%delta = real(delta, dp)
    self%buffer_cap = ceiling(real(delta, dp) * real(BUFFER_FACTOR, dp))
    self%n_buffer = 0
    self%total_weight = 0.0_dp
    self%min_val = huge(1.0_dp)
    self%max_val = -huge(1.0_dp)
    self%b_capacity = 0
    if (allocated(self%b_mean)) deallocate(self%b_mean)
    if (allocated(self%b_weight)) deallocate(self%b_weight)
    call ensure_buffer_capacity(self, self%buffer_cap)
    call tree_clear(self%tree)
  end subroutine

  subroutine ensure_buffer_capacity(self, needed)
    type(tdigest), intent(inout) :: self
    integer, intent(in) :: needed
    real(dp), allocatable :: tmp(:)
    integer :: new_cap

    if (needed <= self%b_capacity) return
    new_cap = max(needed, self%b_capacity * 2, 64)

    if (allocated(self%b_mean)) then
      allocate(tmp(new_cap))
      tmp(1:self%n_buffer) = self%b_mean(1:self%n_buffer)
      call move_alloc(tmp, self%b_mean)
    else
      allocate(self%b_mean(new_cap))
    end if

    if (allocated(self%b_weight)) then
      allocate(tmp(new_cap))
      tmp(1:self%n_buffer) = self%b_weight(1:self%n_buffer)
      call move_alloc(tmp, self%b_weight)
    else
      allocate(self%b_weight(new_cap))
    end if

    self%b_capacity = new_cap
  end subroutine

  subroutine tdigest_add(self, value, weight)
    class(tdigest), intent(inout) :: self
    real(dp), intent(in) :: value
    real(dp), intent(in), optional :: weight
    real(dp) :: w

    w = 1.0_dp
    if (present(weight)) w = weight

    self%n_buffer = self%n_buffer + 1
    if (self%n_buffer > self%b_capacity) then
      call ensure_buffer_capacity(self, self%n_buffer)
    end if
    self%b_mean(self%n_buffer) = value
    self%b_weight(self%n_buffer) = w
    self%total_weight = self%total_weight + w
    if (value < self%min_val) self%min_val = value
    if (value > self%max_val) self%max_val = value

    if (self%n_buffer >= self%buffer_cap) then
      call self%compress()
    end if
  end subroutine

  function tdigest_k(self, q) result(kval)
    class(tdigest), intent(in) :: self
    real(dp), intent(in) :: q
    real(dp) :: kval
    kval = (self%delta / (2.0_dp * PI_VAL)) * asin(2.0_dp * q - 1.0_dp)
  end function

  subroutine tdigest_compress(self)
    class(tdigest), intent(inout) :: self
    type(centroid_type), allocatable :: all(:), merged(:)
    integer :: total, i, n_tree, n_new, pos
    real(dp) :: weight_so_far, n, proposed, q0, q1
    real(dp) :: old_w, nw

    if (self%n_buffer == 0 .and. tree_size(self%tree) <= 1) return

    n_tree = tree_size(self%tree)
    total = n_tree + self%n_buffer

    ! Collect from tree
    if (n_tree > 0) then
      call tree_collect(self%tree, all, n_tree)
      ! Now extend with buffer
      if (self%n_buffer > 0) then
        block
          type(centroid_type), allocatable :: tmp(:)
          allocate(tmp(total))
          tmp(1:n_tree) = all(1:n_tree)
          do i = 1, self%n_buffer
            tmp(n_tree + i)%mean   = self%b_mean(i)
            tmp(n_tree + i)%weight = self%b_weight(i)
          end do
          call move_alloc(tmp, all)
        end block
      end if
    else
      allocate(all(total))
      do i = 1, self%n_buffer
        all(i)%mean   = self%b_mean(i)
        all(i)%weight = self%b_weight(i)
      end do
    end if
    self%n_buffer = 0

    ! Sort by mean
    call sort_centroids(all, total)

    ! Merge centroids
    allocate(merged(total))
    merged(1) = all(1)
    n_new = 1
    weight_so_far = 0.0_dp
    n = self%total_weight

    do i = 2, total
      proposed = merged(n_new)%weight + all(i)%weight
      q0 = weight_so_far / n
      q1 = (weight_so_far + proposed) / n

      if ((proposed <= 1.0_dp .and. total > 1) .or. &
          (self%k_func(q1) - self%k_func(q0) <= 1.0_dp)) then
        ! Merge into last
        old_w = merged(n_new)%weight
        nw = old_w + all(i)%weight
        merged(n_new)%mean = (merged(n_new)%mean * old_w + &
                               all(i)%mean * all(i)%weight) / nw
        merged(n_new)%weight = nw
      else
        weight_so_far = weight_so_far + merged(n_new)%weight
        n_new = n_new + 1
        merged(n_new) = all(i)
      end if
    end do

    ! Rebuild tree from sorted merged centroids
    call tree_build_from_sorted(self%tree, merged(1:n_new), n_new)

    deallocate(all, merged)
  end subroutine

  subroutine sort_centroids(arr, n)
    type(centroid_type), intent(inout) :: arr(:)
    integer, intent(in) :: n
    integer :: i, j
    type(centroid_type) :: tmp

    ! Insertion sort (adequate for typical centroid counts)
    do i = 2, n
      tmp = arr(i)
      j = i - 1
      do while (j >= 1 .and. arr(j)%mean > tmp%mean)
        arr(j + 1) = arr(j)
        j = j - 1
      end do
      arr(j + 1) = tmp
    end do
  end subroutine

  function tdigest_quantile(self, q) result(res)
    class(tdigest), intent(inout) :: self
    real(dp), intent(in) :: q
    real(dp) :: res
    real(dp) :: qq, n, target, cumulative, mid_val, next_mid, frac, remaining
    real(dp) :: cmean, cweight, nmean, nweight
    type(centroid_type), allocatable :: centroids(:)
    integer :: count, i, n_out

    if (self%n_buffer > 0) call self%compress()
    count = tree_size(self%tree)

    if (count == 0) then
      res = 0.0_dp
      return
    end if

    ! Collect centroids for interpolation
    call tree_collect(self%tree, centroids, n_out)

    if (count == 1) then
      res = centroids(1)%mean
      return
    end if

    qq = q
    if (qq < 0.0_dp) qq = 0.0_dp
    if (qq > 1.0_dp) qq = 1.0_dp

    n = self%total_weight
    target = qq * n
    cumulative = 0.0_dp

    do i = 1, count
      cmean = centroids(i)%mean
      cweight = centroids(i)%weight
      mid_val = cumulative + cweight / 2.0_dp

      if (i == 1) then
        if (target < cweight / 2.0_dp) then
          if (cweight == 1.0_dp) then
            res = self%min_val
            return
          end if
          res = self%min_val + (cmean - self%min_val) * (target / (cweight / 2.0_dp))
          return
        end if
      end if

      if (i == count) then
        if (target > n - cweight / 2.0_dp) then
          if (cweight == 1.0_dp) then
            res = self%max_val
            return
          end if
          remaining = n - cweight / 2.0_dp
          res = cmean + (self%max_val - cmean) * ((target - remaining) / (cweight / 2.0_dp))
          return
        end if
        res = cmean
        return
      end if

      nmean = centroids(i + 1)%mean
      nweight = centroids(i + 1)%weight
      next_mid = cumulative + cweight + nweight / 2.0_dp

      if (target <= next_mid) then
        if (next_mid == mid_val) then
          frac = 0.5_dp
        else
          frac = (target - mid_val) / (next_mid - mid_val)
        end if
        res = cmean + frac * (nmean - cmean)
        return
      end if

      cumulative = cumulative + cweight
    end do

    res = self%max_val
  end function

  function tdigest_cdf(self, x) result(res)
    class(tdigest), intent(inout) :: self
    real(dp), intent(in) :: x
    real(dp) :: res
    real(dp) :: n, cumulative, cmean, cweight, nmean, nweight
    real(dp) :: mid_val, next_mid, next_cumulative, inner_w, right_w, frac
    type(centroid_type), allocatable :: centroids(:)
    integer :: count, i, n_out

    if (self%n_buffer > 0) call self%compress()
    count = tree_size(self%tree)

    if (count == 0) then
      res = 0.0_dp
      return
    end if
    if (x <= self%min_val) then
      res = 0.0_dp
      return
    end if
    if (x >= self%max_val) then
      res = 1.0_dp
      return
    end if

    call tree_collect(self%tree, centroids, n_out)
    n = self%total_weight
    cumulative = 0.0_dp

    do i = 1, count
      cmean = centroids(i)%mean
      cweight = centroids(i)%weight

      if (i == 1) then
        if (x < cmean) then
          inner_w = cweight / 2.0_dp
          if (cmean == self%min_val) then
            frac = 1.0_dp
          else
            frac = (x - self%min_val) / (cmean - self%min_val)
          end if
          res = (inner_w * frac) / n
          return
        else if (x == cmean) then
          res = (cweight / 2.0_dp) / n
          return
        end if
      end if

      if (i == count) then
        if (x > cmean) then
          right_w = n - cumulative - cweight / 2.0_dp
          if (self%max_val == cmean) then
            frac = 0.0_dp
          else
            frac = (x - cmean) / (self%max_val - cmean)
          end if
          res = (cumulative + cweight / 2.0_dp + right_w * frac) / n
          return
        else
          res = (cumulative + cweight / 2.0_dp) / n
          return
        end if
      end if

      mid_val = cumulative + cweight / 2.0_dp
      nmean = centroids(i + 1)%mean
      nweight = centroids(i + 1)%weight
      next_cumulative = cumulative + cweight
      next_mid = next_cumulative + nweight / 2.0_dp

      if (x < nmean) then
        if (cmean == nmean) then
          res = (mid_val + (next_mid - mid_val) / 2.0_dp) / n
          return
        end if
        frac = (x - cmean) / (nmean - cmean)
        res = (mid_val + frac * (next_mid - mid_val)) / n
        return
      end if

      cumulative = cumulative + cweight
    end do

    res = 1.0_dp
  end function

  subroutine tdigest_merge(self, other)
    class(tdigest), intent(inout) :: self
    type(tdigest), intent(inout) :: other
    type(centroid_type), allocatable :: other_centroids(:)
    integer :: i, n_out

    if (other%n_buffer > 0) call other%compress()
    call tree_collect(other%tree, other_centroids, n_out)
    do i = 1, n_out
      call self%add(other_centroids(i)%mean, other_centroids(i)%weight)
    end do
  end subroutine

  function tdigest_centroid_count(self) result(cnt)
    class(tdigest), intent(inout) :: self
    integer :: cnt
    if (self%n_buffer > 0) call self%compress()
    cnt = tree_size(self%tree)
  end function

end module tdigest_mod
