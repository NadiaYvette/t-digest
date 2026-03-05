defmodule TDigest do
  @moduledoc """
  Dunning t-digest for online quantile estimation.
  Merging digest variant with K1 (arcsine) scale function.
  """

  @default_delta 100
  @buffer_factor 5

  defstruct centroids: [],
            buffer: [],
            total_weight: 0.0,
            min: :infinity,
            max: :neg_infinity,
            delta: @default_delta,
            buffer_cap: @default_delta * @buffer_factor

  @doc "Create a new t-digest with given compression parameter delta."
  def new(delta \\ @default_delta) do
    %TDigest{
      delta: delta * 1.0,
      buffer_cap: iceil(delta * @buffer_factor)
    }
  end

  @doc "Add a value with optional weight to the digest."
  def add(%TDigest{} = td, value, weight \\ 1.0) do
    value = value * 1.0
    weight = weight * 1.0

    td = %{
      td
      | buffer: [{value, weight} | td.buffer],
        total_weight: td.total_weight + weight,
        min: min_val(td.min, value),
        max: max_val(td.max, value)
    }

    if length(td.buffer) >= td.buffer_cap do
      compress(td)
    else
      td
    end
  end

  @doc "Force compression of buffered centroids."
  def compress(%TDigest{buffer: [], centroids: centroids} = td) when length(centroids) <= 1,
    do: td

  def compress(%TDigest{} = td) do
    all = (td.centroids ++ td.buffer) |> Enum.sort_by(fn {mean, _w} -> mean end)
    [{m0, w0} | rest] = all
    n = td.total_weight

    {new_centroids, _wsf} =
      Enum.reduce(rest, {[{m0, w0}], 0.0}, fn {mean, weight}, {acc, weight_so_far} ->
        {last_mean, last_weight} = hd(acc)
        proposed = last_weight + weight
        q0 = weight_so_far / n
        q1 = (weight_so_far + proposed) / n

        cond do
          proposed <= 1 and length(all) > 1 ->
            new_weight = last_weight + weight
            new_mean = (last_mean * last_weight + mean * weight) / new_weight
            {[{new_mean, new_weight} | tl(acc)], weight_so_far}

          k(q1, td.delta) - k(q0, td.delta) <= 1.0 ->
            new_weight = last_weight + weight
            new_mean = (last_mean * last_weight + mean * weight) / new_weight
            {[{new_mean, new_weight} | tl(acc)], weight_so_far}

          true ->
            {[{mean, weight} | acc], weight_so_far + last_weight}
        end
      end)

    %{td | centroids: Enum.reverse(new_centroids), buffer: []}
  end

  @doc "Estimate the value at quantile q (0..1)."
  def quantile(%TDigest{} = td, q) do
    td = if td.buffer != [], do: compress(td), else: td
    quantile_internal(td, q)
  end

  defp quantile_internal(%TDigest{centroids: []}, _q), do: nil
  defp quantile_internal(%TDigest{centroids: [{mean, _w}]}, _q), do: mean

  defp quantile_internal(%TDigest{} = td, q) do
    q = q |> max(0.0) |> min(1.0)
    n = td.total_weight
    target = q * n
    centroids = td.centroids
    count = length(centroids)

    walk_quantile(centroids, 0, count, 0.0, target, n, td.min, td.max)
  end

  defp walk_quantile([], _i, _count, _cum, _target, _n, _mn, mx), do: mx

  defp walk_quantile([{mean, weight} | rest], i, count, cumulative, target, n, mn, mx) do
    # Left boundary
    if i == 0 and target < weight / 2.0 do
      if weight == 1 do
        mn
      else
        mn + (mean - mn) * (target / (weight / 2.0))
      end
    else
      # Right boundary
      if i == count - 1 do
        if target > n - weight / 2.0 do
          if weight == 1 do
            mx
          else
            remaining = n - weight / 2.0
            mean + (mx - mean) * ((target - remaining) / (weight / 2.0))
          end
        else
          mean
        end
      else
        mid = cumulative + weight / 2.0
        {next_mean, next_weight} = hd(rest)
        next_mid = cumulative + weight + next_weight / 2.0

        if target <= next_mid do
          frac = if next_mid == mid, do: 0.5, else: (target - mid) / (next_mid - mid)
          mean + frac * (next_mean - mean)
        else
          walk_quantile(rest, i + 1, count, cumulative + weight, target, n, mn, mx)
        end
      end
    end
  end

  @doc "Estimate the CDF at value x."
  def cdf(%TDigest{} = td, x) do
    td = if td.buffer != [], do: compress(td), else: td
    cdf_internal(td, x)
  end

  defp cdf_internal(%TDigest{centroids: []}, _x), do: nil
  defp cdf_internal(%TDigest{} = td, x) when x <= td.min, do: 0.0
  defp cdf_internal(%TDigest{} = td, x) when x >= td.max, do: 1.0

  defp cdf_internal(%TDigest{} = td, x) do
    n = td.total_weight
    centroids = td.centroids
    count = length(centroids)
    walk_cdf(centroids, 0, count, 0.0, x, n, td.min, td.max)
  end

  defp walk_cdf([], _i, _count, _cum, _x, _n, _mn, _mx), do: 1.0

  defp walk_cdf([{mean, weight} | rest], i, count, cumulative, x, n, mn, mx) do
    cond do
      i == 0 and x < mean ->
        inner_w = weight / 2.0
        frac = if mean == mn, do: 1.0, else: (x - mn) / (mean - mn)
        inner_w * frac / n

      i == 0 and x == mean ->
        weight / 2.0 / n

      i == count - 1 ->
        if x > mean do
          inner_w = weight / 2.0
          right_w = n - cumulative - inner_w
          frac = if mx == mean, do: 0.0, else: (x - mean) / (mx - mean)
          (cumulative + inner_w + right_w * frac) / n
        else
          (cumulative + weight / 2.0) / n
        end

      true ->
        mid = cumulative + weight / 2.0
        {next_mean, next_weight} = hd(rest)
        next_cumulative = cumulative + weight
        next_mid = next_cumulative + next_weight / 2.0

        if x < next_mean do
          if mean == next_mean do
            (mid + (next_mid - mid) / 2.0) / n
          else
            frac = (x - mean) / (next_mean - mean)
            (mid + frac * (next_mid - mid)) / n
          end
        else
          walk_cdf(rest, i + 1, count, cumulative + weight, x, n, mn, mx)
        end
    end
  end

  @doc "Merge another t-digest into this one."
  def merge(%TDigest{} = td, %TDigest{} = other) do
    other = if other.buffer != [], do: compress(other), else: other

    Enum.reduce(other.centroids, td, fn {mean, weight}, acc ->
      add(acc, mean, weight)
    end)
  end

  @doc "Number of centroids (after compression)."
  def centroid_count(%TDigest{} = td) do
    td = if td.buffer != [], do: compress(td), else: td
    length(td.centroids)
  end

  # K1 scale function: k(q, delta) = (delta / (2*pi)) * asin(2*q - 1)
  defp k(q, delta) do
    delta / (2.0 * :math.pi()) * :math.asin(2.0 * q - 1.0)
  end

  defp min_val(:infinity, v), do: v
  defp min_val(a, b) when a <= b, do: a
  defp min_val(_a, b), do: b

  defp max_val(:neg_infinity, v), do: v
  defp max_val(a, b) when a >= b, do: a
  defp max_val(_a, b), do: b

  defp iceil(x) when is_integer(x), do: x
  defp iceil(x), do: Float.ceil(x) |> trunc()
end
