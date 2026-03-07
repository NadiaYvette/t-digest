# Generic array-backed 2-3-4 tree with monoidal measures.
# Uses R environments for mutable state (environment-based OOP).
#
# Measure: list(weight, count, max_mean, mean_weight_sum)
# Node: list(n, keys, children, measure)
# Node pool as list in an environment, with free list.

# --- Measure operations ---

measure_identity <- function() {
  list(weight = 0, count = 0L, max_mean = -Inf, mean_weight_sum = 0)
}

measure_single <- function(centroid) {
  list(
    weight = centroid$weight,
    count = 1L,
    max_mean = centroid$mean,
    mean_weight_sum = centroid$mean * centroid$weight
  )
}

measure_combine <- function(a, b) {
  list(
    weight = a$weight + b$weight,
    count = a$count + b$count,
    max_mean = max(a$max_mean, b$max_mean),
    mean_weight_sum = a$mean_weight_sum + b$mean_weight_sum
  )
}

centroid_compare <- function(a, b) {
  if (a$mean < b$mean) return(-1L)
  if (a$mean > b$mean) return(1L)
  0L
}

# --- Node helpers ---

new_node <- function() {
  list(
    n = 0L,
    keys = vector("list", 3),
    children = c(-1L, -1L, -1L, -1L),
    measure = measure_identity()
  )
}

# --- Tree234 ---

tree234_new <- function() {
  self <- new.env(parent = emptyenv())
  self$nodes <- list()
  self$free_list <- integer(0)
  self$root <- -1L
  self$count <- 0L
  class(self) <- "tree234"
  self
}

tree234_alloc_node <- function(self) {
  nfree <- length(self$free_list)
  if (nfree > 0L) {
    idx <- self$free_list[nfree]
    self$free_list <- self$free_list[-nfree]
    self$nodes[[idx]] <- new_node()
    return(idx)
  }
  idx <- length(self$nodes) + 1L
  self$nodes[[idx]] <- new_node()
  idx
}

tree234_is_leaf <- function(self, idx) {
  self$nodes[[idx]]$children[1] == -1L
}

tree234_is_4node <- function(self, idx) {
  self$nodes[[idx]]$n == 3L
}

tree234_recompute_measure <- function(self, idx) {
  nd <- self$nodes[[idx]]
  m <- measure_identity()
  for (i in seq_len(nd$n + 1L)) {
    ch <- nd$children[i]
    if (ch != -1L) {
      m <- measure_combine(m, self$nodes[[ch]]$measure)
    }
    if (i <= nd$n) {
      m <- measure_combine(m, measure_single(nd$keys[[i]]))
    }
  }
  self$nodes[[idx]]$measure <- m
}

tree234_split_child <- function(self, parent_idx, child_pos) {
  child_idx <- self$nodes[[parent_idx]]$children[child_pos]
  cnd <- self$nodes[[child_idx]]

  k0 <- cnd$keys[[1]]
  k1 <- cnd$keys[[2]]
  k2 <- cnd$keys[[3]]
  c0 <- cnd$children[1]
  c1 <- cnd$children[2]
  c2 <- cnd$children[3]
  c3 <- cnd$children[4]

  # Create right node with k2, c2, c3
  right_idx <- tree234_alloc_node(self)
  self$nodes[[right_idx]]$n <- 1L
  self$nodes[[right_idx]]$keys[[1]] <- k2
  self$nodes[[right_idx]]$children[1] <- c2
  self$nodes[[right_idx]]$children[2] <- c3

  # Shrink child (left) to k0, c0, c1
  self$nodes[[child_idx]]$n <- 1L
  self$nodes[[child_idx]]$keys[[1]] <- k0
  self$nodes[[child_idx]]$keys[[2]] <- NULL
  self$nodes[[child_idx]]$keys[[3]] <- NULL
  self$nodes[[child_idx]]$children <- c(c0, c1, -1L, -1L)

  tree234_recompute_measure(self, child_idx)
  tree234_recompute_measure(self, right_idx)

  # Insert k1 into parent at child_pos
  pnd <- self$nodes[[parent_idx]]
  pn <- pnd$n

  # Shift keys and children right
  if (pn > child_pos) {
    for (i in seq(pn, child_pos + 1L, by = -1L)) {
      self$nodes[[parent_idx]]$keys[[i + 1L]] <- self$nodes[[parent_idx]]$keys[[i]]
      self$nodes[[parent_idx]]$children[i + 2L] <- self$nodes[[parent_idx]]$children[i + 1L]
    }
  }
  # child_pos is 1-based position of the key slot
  self$nodes[[parent_idx]]$keys[[child_pos]] <- k1
  self$nodes[[parent_idx]]$children[child_pos + 1L] <- right_idx
  self$nodes[[parent_idx]]$n <- pn + 1L

  tree234_recompute_measure(self, parent_idx)
}

tree234_insert_non_full <- function(self, idx, key) {
  nd <- self$nodes[[idx]]

  if (tree234_is_leaf(self, idx)) {
    # Insert key in sorted position
    pos <- nd$n + 1L
    while (pos > 1L && centroid_compare(key, nd$keys[[pos - 1L]]) < 0L) {
      self$nodes[[idx]]$keys[[pos]] <- self$nodes[[idx]]$keys[[pos - 1L]]
      pos <- pos - 1L
    }
    self$nodes[[idx]]$keys[[pos]] <- key
    self$nodes[[idx]]$n <- nd$n + 1L
    tree234_recompute_measure(self, idx)
    return(invisible(NULL))
  }

  # Find child to descend into (1-based)
  pos <- 1L
  while (pos <= nd$n && centroid_compare(key, nd$keys[[pos]]) >= 0L) {
    pos <- pos + 1L
  }

  # If that child is a 4-node, split it first
  child_idx <- self$nodes[[idx]]$children[pos]
  if (tree234_is_4node(self, child_idx)) {
    tree234_split_child(self, idx, pos)
    # After split, mid_key is at keys[[pos]]. Decide which side.
    if (centroid_compare(key, self$nodes[[idx]]$keys[[pos]]) >= 0L) {
      pos <- pos + 1L
    }
  }

  tree234_insert_non_full(self, self$nodes[[idx]]$children[pos], key)
  tree234_recompute_measure(self, idx)
}

tree234_insert <- function(self, key) {
  if (self$root == -1L) {
    self$root <- tree234_alloc_node(self)
    self$nodes[[self$root]]$n <- 1L
    self$nodes[[self$root]]$keys[[1]] <- key
    tree234_recompute_measure(self, self$root)
    self$count <- self$count + 1L
    return(invisible(NULL))
  }

  # If root is a 4-node, split it
  if (tree234_is_4node(self, self$root)) {
    old_root <- self$root
    self$root <- tree234_alloc_node(self)
    self$nodes[[self$root]]$children[1] <- old_root
    tree234_split_child(self, self$root, 1L)
  }

  tree234_insert_non_full(self, self$root, key)
  self$count <- self$count + 1L
}

# In-order traversal: collect all keys into a list
tree234_for_each_impl <- function(self, idx, acc) {
  if (idx == -1L) return(acc)
  nd <- self$nodes[[idx]]
  for (i in seq_len(nd$n + 1L)) {
    ch <- nd$children[i]
    if (ch != -1L) {
      acc <- tree234_for_each_impl(self, ch, acc)
    }
    if (i <= nd$n) {
      acc[[length(acc) + 1L]] <- nd$keys[[i]]
    }
  }
  acc
}

tree234_collect <- function(self) {
  if (self$root == -1L) return(list())
  tree234_for_each_impl(self, self$root, list())
}

tree234_subtree_count <- function(self, idx) {
  if (idx == -1L) return(0L)
  nd <- self$nodes[[idx]]
  cnt <- nd$n
  for (i in seq_len(nd$n + 1L)) {
    ch <- nd$children[i]
    if (ch != -1L) cnt <- cnt + tree234_subtree_count(self, ch)
  }
  cnt
}

tree234_find_by_weight <- function(self, target) {
  if (self$root == -1L) {
    return(list(key = NULL, cum_before = 0, index = 0L, found = FALSE))
  }
  tree234_find_by_weight_impl(self, self$root, target, 0.0, 0L)
}

tree234_find_by_weight_impl <- function(self, idx, target, cum, global_idx) {
  if (idx == -1L) {
    return(list(key = NULL, cum_before = 0, index = 0L, found = FALSE))
  }
  nd <- self$nodes[[idx]]
  running_cum <- cum
  running_idx <- global_idx

  for (i in seq_len(nd$n + 1L)) {
    ch <- nd$children[i]
    if (ch != -1L) {
      child_weight <- self$nodes[[ch]]$measure$weight
      if (running_cum + child_weight >= target) {
        return(tree234_find_by_weight_impl(self, ch, target, running_cum, running_idx))
      }
      running_cum <- running_cum + child_weight
      running_idx <- running_idx + tree234_subtree_count(self, ch)
    }
    if (i <= nd$n) {
      key_weight <- nd$keys[[i]]$weight
      if (running_cum + key_weight >= target) {
        return(list(key = nd$keys[[i]], cum_before = running_cum, index = running_idx, found = TRUE))
      }
      running_cum <- running_cum + key_weight
      running_idx <- running_idx + 1L
    }
  }
  list(key = NULL, cum_before = 0, index = 0L, found = FALSE)
}

tree234_build_recursive <- function(self, sorted, lo, hi) {
  n <- hi - lo
  if (n <= 0L) return(-1L)

  if (n <= 3L) {
    idx <- tree234_alloc_node(self)
    self$nodes[[idx]]$n <- n
    for (i in seq_len(n)) {
      self$nodes[[idx]]$keys[[i]] <- sorted[[lo + i]]
    }
    tree234_recompute_measure(self, idx)
    return(idx)
  }

  if (n <= 7L) {
    mid <- lo + n %/% 2L
    left <- tree234_build_recursive(self, sorted, lo, mid)
    right <- tree234_build_recursive(self, sorted, mid + 1L, hi)
    idx <- tree234_alloc_node(self)
    self$nodes[[idx]]$n <- 1L
    self$nodes[[idx]]$keys[[1]] <- sorted[[mid + 1L]]
    self$nodes[[idx]]$children[1] <- left
    self$nodes[[idx]]$children[2] <- right
    tree234_recompute_measure(self, idx)
    return(idx)
  }

  # For larger, use 3-node

  third <- n %/% 3L
  m1 <- lo + third
  m2 <- lo + 2L * third + 1L
  c0 <- tree234_build_recursive(self, sorted, lo, m1)
  c1 <- tree234_build_recursive(self, sorted, m1 + 1L, m2)
  c2 <- tree234_build_recursive(self, sorted, m2 + 1L, hi)
  idx <- tree234_alloc_node(self)
  self$nodes[[idx]]$n <- 2L
  self$nodes[[idx]]$keys[[1]] <- sorted[[m1 + 1L]]
  self$nodes[[idx]]$keys[[2]] <- sorted[[m2 + 1L]]
  self$nodes[[idx]]$children[1] <- c0
  self$nodes[[idx]]$children[2] <- c1
  self$nodes[[idx]]$children[3] <- c2
  tree234_recompute_measure(self, idx)
  idx
}

tree234_build_from_sorted <- function(self, sorted) {
  tree234_clear(self)
  n <- length(sorted)
  if (n == 0L) return(invisible(NULL))
  self$count <- n
  # sorted is a list of centroid lists, 1-based; build_recursive uses 0-based lo/hi
  self$root <- tree234_build_recursive(self, sorted, 0L, n)
}

tree234_clear <- function(self) {
  self$nodes <- list()
  self$free_list <- integer(0)
  self$root <- -1L
  self$count <- 0L
}

tree234_size <- function(self) {
  self$count
}

tree234_root_measure <- function(self) {
  if (self$root == -1L) return(measure_identity())
  self$nodes[[self$root]]$measure
}
