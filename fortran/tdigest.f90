! Dunning t-digest for online quantile estimation.
! Merging digest variant with K_1 (arcsine) scale function.
! Fortran 2003+ module with derived types and type-bound procedures.

module tdigest_mod
  implicit none
  private

  integer, parameter :: dp = selected_real_kind(15, 307)
  real(dp), parameter :: PI_VAL = 3.14159265358979323846_dp
  integer, parameter :: DEFAULT_DELTA = 100
  integer, parameter :: BUFFER_FACTOR = 5

  type, public :: tdigest
    real(dp) :: delta = real(DEFAULT_DELTA, dp)
    real(dp), allocatable :: c_mean(:), c_weight(:)   ! centroids
    real(dp), allocatable :: b_mean(:), b_weight(:)   ! buffer
    integer :: n_centroids = 0
    integer :: n_buffer = 0
    real(dp) :: total_weight = 0.0_dp
    real(dp) :: min_val = huge(1.0_dp)
    real(dp) :: max_val = -huge(1.0_dp)
    integer :: buffer_cap = DEFAULT_DELTA * BUFFER_FACTOR
    integer :: c_capacity = 0
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
    self%n_centroids = 0
    self%n_buffer = 0
    self%total_weight = 0.0_dp
    self%min_val = huge(1.0_dp)
    self%max_val = -huge(1.0_dp)
    self%c_capacity = 0
    self%b_capacity = 0
    if (allocated(self%c_mean)) deallocate(self%c_mean)
    if (allocated(self%c_weight)) deallocate(self%c_weight)
    if (allocated(self%b_mean)) deallocate(self%b_mean)
    if (allocated(self%b_weight)) deallocate(self%b_weight)
    call ensure_buffer_capacity(self, self%buffer_cap)
    call ensure_centroid_capacity(self, self%buffer_cap)
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

  subroutine ensure_centroid_capacity(self, needed)
    type(tdigest), intent(inout) :: self
    integer, intent(in) :: needed
    real(dp), allocatable :: tmp(:)
    integer :: new_cap

    if (needed <= self%c_capacity) return
    new_cap = max(needed, self%c_capacity * 2, 64)

    if (allocated(self%c_mean)) then
      allocate(tmp(new_cap))
      tmp(1:self%n_centroids) = self%c_mean(1:self%n_centroids)
      call move_alloc(tmp, self%c_mean)
    else
      allocate(self%c_mean(new_cap))
    end if

    if (allocated(self%c_weight)) then
      allocate(tmp(new_cap))
      tmp(1:self%n_centroids) = self%c_weight(1:self%n_centroids)
      call move_alloc(tmp, self%c_weight)
    else
      allocate(self%c_weight(new_cap))
    end if

    self%c_capacity = new_cap
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
    real(dp), allocatable :: all_mean(:), all_weight(:)
    integer :: total, i, n_new
    real(dp) :: weight_so_far, n, proposed, q0, q1
    real(dp) :: old_w, nw

    if (self%n_buffer == 0 .and. self%n_centroids <= 1) return

    total = self%n_centroids + self%n_buffer
    allocate(all_mean(total), all_weight(total))

    if (self%n_centroids > 0) then
      all_mean(1:self%n_centroids) = self%c_mean(1:self%n_centroids)
      all_weight(1:self%n_centroids) = self%c_weight(1:self%n_centroids)
    end if
    if (self%n_buffer > 0) then
      all_mean(self%n_centroids+1:total) = self%b_mean(1:self%n_buffer)
      all_weight(self%n_centroids+1:total) = self%b_weight(1:self%n_buffer)
    end if
    self%n_buffer = 0

    ! Sort by mean (simple insertion sort for moderate sizes)
    call sort_by_mean(all_mean, all_weight, total)

    ! Build new centroids
    call ensure_centroid_capacity(self, total)
    self%c_mean(1) = all_mean(1)
    self%c_weight(1) = all_weight(1)
    n_new = 1
    weight_so_far = 0.0_dp
    n = self%total_weight

    do i = 2, total
      proposed = self%c_weight(n_new) + all_weight(i)
      q0 = weight_so_far / n
      q1 = (weight_so_far + proposed) / n

      if ((proposed <= 1.0_dp .and. total > 1) .or. &
          (self%k_func(q1) - self%k_func(q0) <= 1.0_dp)) then
        ! Merge into last
        old_w = self%c_weight(n_new)
        nw = old_w + all_weight(i)
        self%c_mean(n_new) = (self%c_mean(n_new) * old_w + all_mean(i) * all_weight(i)) / nw
        self%c_weight(n_new) = nw
      else
        weight_so_far = weight_so_far + self%c_weight(n_new)
        n_new = n_new + 1
        self%c_mean(n_new) = all_mean(i)
        self%c_weight(n_new) = all_weight(i)
      end if
    end do

    self%n_centroids = n_new
    deallocate(all_mean, all_weight)
  end subroutine

  subroutine sort_by_mean(means, weights, n)
    real(dp), intent(inout) :: means(:), weights(:)
    integer, intent(in) :: n
    integer :: i, j
    real(dp) :: key_m, key_w

    do i = 2, n
      key_m = means(i)
      key_w = weights(i)
      j = i - 1
      do while (j >= 1 .and. means(j) > key_m)
        means(j+1) = means(j)
        weights(j+1) = weights(j)
        j = j - 1
      end do
      means(j+1) = key_m
      weights(j+1) = key_w
    end do
  end subroutine

  function tdigest_quantile(self, q) result(res)
    class(tdigest), intent(inout) :: self
    real(dp), intent(in) :: q
    real(dp) :: res
    real(dp) :: qq, n, target, cumulative, mid, next_mid, frac, remaining
    real(dp) :: cmean, cweight, nmean, nweight
    integer :: count, i

    if (self%n_buffer > 0) call self%compress()
    count = self%n_centroids

    if (count == 0) then
      res = 0.0_dp
      return
    end if
    if (count == 1) then
      res = self%c_mean(1)
      return
    end if

    qq = q
    if (qq < 0.0_dp) qq = 0.0_dp
    if (qq > 1.0_dp) qq = 1.0_dp

    n = self%total_weight
    target = qq * n
    cumulative = 0.0_dp

    do i = 1, count
      cmean = self%c_mean(i)
      cweight = self%c_weight(i)
      mid = cumulative + cweight / 2.0_dp

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

      nmean = self%c_mean(i + 1)
      nweight = self%c_weight(i + 1)
      next_mid = cumulative + cweight + nweight / 2.0_dp

      if (target <= next_mid) then
        if (next_mid == mid) then
          frac = 0.5_dp
        else
          frac = (target - mid) / (next_mid - mid)
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
    real(dp) :: mid, next_mid, next_cumulative, inner_w, right_w, frac
    integer :: count, i

    if (self%n_buffer > 0) call self%compress()
    count = self%n_centroids

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

    n = self%total_weight
    cumulative = 0.0_dp

    do i = 1, count
      cmean = self%c_mean(i)
      cweight = self%c_weight(i)

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
          inner_w = cweight / 2.0_dp
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

      mid = cumulative + cweight / 2.0_dp
      nmean = self%c_mean(i + 1)
      nweight = self%c_weight(i + 1)
      next_cumulative = cumulative + cweight
      next_mid = next_cumulative + nweight / 2.0_dp

      if (x < nmean) then
        if (cmean == nmean) then
          res = (mid + (next_mid - mid) / 2.0_dp) / n
          return
        end if
        frac = (x - cmean) / (nmean - cmean)
        res = (mid + frac * (next_mid - mid)) / n
        return
      end if

      cumulative = cumulative + cweight
    end do

    res = 1.0_dp
  end function

  subroutine tdigest_merge(self, other)
    class(tdigest), intent(inout) :: self
    type(tdigest), intent(inout) :: other
    integer :: i

    if (other%n_buffer > 0) call other%compress()
    do i = 1, other%n_centroids
      call self%add(other%c_mean(i), other%c_weight(i))
    end do
  end subroutine

  function tdigest_centroid_count(self) result(cnt)
    class(tdigest), intent(inout) :: self
    integer :: cnt
    if (self%n_buffer > 0) call self%compress()
    cnt = self%n_centroids
  end function

end module tdigest_mod
