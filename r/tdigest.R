# Dunning t-digest for online quantile estimation.
# Merging digest variant with K_1 (arcsine) scale function.
# Environment-based OOP implementation.

DEFAULT_DELTA <- 100
BUFFER_FACTOR <- 5

tdigest_new <- function(delta = DEFAULT_DELTA) {
  self <- new.env(parent = emptyenv())
  self$delta <- as.double(delta)
  self$centroids_mean <- numeric(0)
  self$centroids_weight <- numeric(0)
  self$buffer_mean <- numeric(0)
  self$buffer_weight <- numeric(0)
  self$total_weight <- 0.0
  self$min_val <- Inf
  self$max_val <- -Inf
  self$buffer_cap <- ceiling(delta * BUFFER_FACTOR)
  class(self) <- "tdigest"
  self
}

tdigest_k <- function(self, q) {
  (self$delta / (2.0 * pi)) * asin(2.0 * q - 1.0)
}

tdigest_add <- function(self, value, weight = 1.0) {
  value <- as.double(value)
  weight <- as.double(weight)
  self$buffer_mean <- c(self$buffer_mean, value)
  self$buffer_weight <- c(self$buffer_weight, weight)
  self$total_weight <- self$total_weight + weight
  if (value < self$min_val) self$min_val <- value
  if (value > self$max_val) self$max_val <- value
  if (length(self$buffer_mean) >= self$buffer_cap) {
    tdigest_compress(self)
  }
  invisible(self)
}

tdigest_compress <- function(self) {
  nbuf <- length(self$buffer_mean)
  ncent <- length(self$centroids_mean)
  if (nbuf == 0 && ncent <= 1) return(invisible(self))

  all_mean <- c(self$centroids_mean, self$buffer_mean)
  all_weight <- c(self$centroids_weight, self$buffer_weight)
  self$buffer_mean <- numeric(0)
  self$buffer_weight <- numeric(0)

  ord <- order(all_mean)
  all_mean <- all_mean[ord]
  all_weight <- all_weight[ord]
  total <- length(all_mean)

  new_mean <- all_mean[1]
  new_weight <- all_weight[1]
  weight_so_far <- 0.0
  n <- self$total_weight

  for (i in 2:total) {
    last_idx <- length(new_mean)
    proposed <- new_weight[last_idx] + all_weight[i]
    q0 <- weight_so_far / n
    q1 <- (weight_so_far + proposed) / n

    if ((proposed <= 1 && total > 1) ||
        (tdigest_k(self, q1) - tdigest_k(self, q0) <= 1.0)) {
      # Merge into last centroid
      old_w <- new_weight[last_idx]
      nw <- old_w + all_weight[i]
      new_mean[last_idx] <- (new_mean[last_idx] * old_w + all_mean[i] * all_weight[i]) / nw
      new_weight[last_idx] <- nw
    } else {
      weight_so_far <- weight_so_far + new_weight[last_idx]
      new_mean <- c(new_mean, all_mean[i])
      new_weight <- c(new_weight, all_weight[i])
    }
  }

  self$centroids_mean <- new_mean
  self$centroids_weight <- new_weight
  invisible(self)
}

tdigest_quantile <- function(self, q) {
  if (length(self$buffer_mean) > 0) tdigest_compress(self)
  count <- length(self$centroids_mean)
  if (count == 0) return(NA)
  if (count == 1) return(self$centroids_mean[1])

  if (q < 0.0) q <- 0.0
  if (q > 1.0) q <- 1.0

  n <- self$total_weight
  target <- q * n
  cumulative <- 0.0

  for (i in 1:count) {
    cmean <- self$centroids_mean[i]
    cweight <- self$centroids_weight[i]
    mid <- cumulative + cweight / 2.0

    if (i == 1) {
      if (target < cweight / 2.0) {
        if (cweight == 1) return(self$min_val)
        return(self$min_val + (cmean - self$min_val) * (target / (cweight / 2.0)))
      }
    }

    if (i == count) {
      if (target > n - cweight / 2.0) {
        if (cweight == 1) return(self$max_val)
        remaining <- n - cweight / 2.0
        return(cmean + (self$max_val - cmean) * ((target - remaining) / (cweight / 2.0)))
      }
      return(cmean)
    }

    nmean <- self$centroids_mean[i + 1]
    nweight <- self$centroids_weight[i + 1]
    next_mid <- cumulative + cweight + nweight / 2.0

    if (target <= next_mid) {
      if (next_mid == mid) {
        frac <- 0.5
      } else {
        frac <- (target - mid) / (next_mid - mid)
      }
      return(cmean + frac * (nmean - cmean))
    }

    cumulative <- cumulative + cweight
  }

  self$max_val
}

tdigest_cdf <- function(self, x) {
  if (length(self$buffer_mean) > 0) tdigest_compress(self)
  count <- length(self$centroids_mean)
  if (count == 0) return(NA)
  if (x <= self$min_val) return(0.0)
  if (x >= self$max_val) return(1.0)

  n <- self$total_weight
  cumulative <- 0.0

  for (i in 1:count) {
    cmean <- self$centroids_mean[i]
    cweight <- self$centroids_weight[i]

    if (i == 1) {
      if (x < cmean) {
        inner_w <- cweight / 2.0
        frac <- if (cmean == self$min_val) 1.0 else (x - self$min_val) / (cmean - self$min_val)
        return((inner_w * frac) / n)
      } else if (x == cmean) {
        return((cweight / 2.0) / n)
      }
    }

    if (i == count) {
      if (x > cmean) {
        inner_w <- cweight / 2.0
        right_w <- n - cumulative - cweight / 2.0
        frac <- if (self$max_val == cmean) 0.0 else (x - cmean) / (self$max_val - cmean)
        return((cumulative + cweight / 2.0 + right_w * frac) / n)
      } else {
        return((cumulative + cweight / 2.0) / n)
      }
    }

    mid <- cumulative + cweight / 2.0
    nmean <- self$centroids_mean[i + 1]
    nweight <- self$centroids_weight[i + 1]
    next_cumulative <- cumulative + cweight
    next_mid <- next_cumulative + nweight / 2.0

    if (x < nmean) {
      if (cmean == nmean) {
        return((mid + (next_mid - mid) / 2.0) / n)
      }
      frac <- (x - cmean) / (nmean - cmean)
      return((mid + frac * (next_mid - mid)) / n)
    }

    cumulative <- cumulative + cweight
  }

  1.0
}

tdigest_merge <- function(self, other) {
  if (length(other$buffer_mean) > 0) tdigest_compress(other)
  for (i in seq_along(other$centroids_mean)) {
    tdigest_add(self, other$centroids_mean[i], other$centroids_weight[i])
  }
  invisible(self)
}

tdigest_size <- function(self) {
  length(self$centroids_mean) + length(self$buffer_mean)
}

tdigest_centroid_count <- function(self) {
  if (length(self$buffer_mean) > 0) tdigest_compress(self)
  length(self$centroids_mean)
}
