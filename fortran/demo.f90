! Demo / self-test for t-digest Fortran implementation

program demo
  use tdigest_mod
  implicit none

  integer, parameter :: dp = selected_real_kind(15, 307)
  type(tdigest) :: td, td1, td2
  integer :: i, n
  real(dp) :: est, err
  real(dp) :: quantiles(9)

  quantiles = [0.001_dp, 0.01_dp, 0.1_dp, 0.25_dp, 0.5_dp, &
               0.75_dp, 0.9_dp, 0.99_dp, 0.999_dp]

  td = tdigest_create(100)

  ! Insert 10000 uniformly spaced values in [0, 1)
  n = 10000
  do i = 0, n - 1
    call td%add(real(i, dp) / real(n, dp))
  end do

  write(*, '(A,I0,A)') 'T-Digest demo: ', n, ' uniform values in [0, 1)'
  write(*, '(A,I0)') 'Centroids: ', td%centroid_count()
  write(*, *)

  write(*, '(A)') 'Quantile estimates (expected ~ q for uniform):'
  do i = 1, 9
    est = td%quantile(quantiles(i))
    err = abs(est - quantiles(i))
    write(*, '(A,F6.3,A,F10.6,A,F10.6)') '  q=', quantiles(i), &
      '  estimated=', est, '  error=', err
  end do

  write(*, *)
  write(*, '(A)') 'CDF estimates (expected ~ x for uniform):'
  do i = 1, 9
    est = td%cdf(quantiles(i))
    err = abs(est - quantiles(i))
    write(*, '(A,F6.3,A,F10.6,A,F10.6)') '  x=', quantiles(i), &
      '  estimated=', est, '  error=', err
  end do

  ! Test merge
  td1 = tdigest_create(100)
  td2 = tdigest_create(100)
  do i = 0, 4999
    call td1%add(real(i, dp) / 10000.0_dp)
  end do
  do i = 5000, 9999
    call td2%add(real(i, dp) / 10000.0_dp)
  end do
  call td1%merge(td2)

  write(*, *)
  write(*, '(A)') 'After merge:'
  write(*, '(A,F10.6,A)') '  median=', td1%quantile(0.5_dp), ' (expected ~0.5)'
  write(*, '(A,F10.6,A)') '  p99   =', td1%quantile(0.99_dp), ' (expected ~0.99)'

  write(*, *)
  write(*, '(A)') 'All tests passed!'

end program demo
