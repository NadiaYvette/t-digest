-- Benchmark / asymptotic-behavior tests for the Haskell t-digest implementation.
-- Compile: ghc -O2 Bench.hs -o bench

module Main where

import Data.IORef
import Data.List (foldl')
import System.CPUTime
import TDigest
import Text.Printf

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

getCPUTimeMs :: IO Double
getCPUTimeMs = do
  t <- getCPUTime
  return (fromIntegral t / 1e9) -- picoseconds -> milliseconds

timeBlock :: IO a -> IO (Double, a)
timeBlock action = do
  t0 <- getCPUTimeMs
  result <- action
  -- Force evaluation
  t1 <- result `seq` getCPUTimeMs
  return (t1 - t0, result)

timeBlock_ :: IO () -> IO Double
timeBlock_ action = do
  (ms, _) <- timeBlock action
  return ms

data TestState = TestState {passCount :: !Int, failCount :: !Int}

newState :: TestState
newState = TestState 0 0

addPass :: IORef TestState -> String -> IO ()
addPass ref label = do
  s <- readIORef ref
  writeIORef ref (s {passCount = passCount s + 1})
  printf "  %s  PASS\n" label

addFail :: IORef TestState -> String -> IO ()
addFail ref label = do
  s <- readIORef ref
  writeIORef ref (s {failCount = failCount s + 1})
  printf "  %s  FAIL\n" label

check :: IORef TestState -> String -> Bool -> IO ()
check ref label True = addPass ref label
check ref label False = addFail ref label

ratioOk :: Double -> Double -> Bool
ratioOk ratio expected = ratio >= expected * 0.5 && ratio <= expected * 3.0

ratioOkWide :: Double -> Double -> Bool
ratioOkWide ratio expected = ratio >= expected * 0.2 && ratio <= expected * 5.0

-- Build a t-digest from n uniform values
buildDigest :: Double -> Int -> TDigest.TDigest
buildDigest delta n =
  let vals = map (\i -> fromIntegral i / fromIntegral n) [0 .. n - 1]
   in foldl' (\td v -> TDigest.add v td) (TDigest.emptyWith delta) vals

main :: IO ()
main = do
  ref <- newIORef newState

  putStrLn "=== T-Digest Asymptotic Behavior Tests (Haskell) ==="
  putStrLn ""

  -- -----------------------------------------------------------------------
  -- Test 1: add() is amortized O(1)
  -- -----------------------------------------------------------------------
  putStrLn "--- Test 1: add() is amortized O(1) ---"

  let sizes = [1000, 10000, 100000, 1000000] :: [Int]
  times <-
    mapM
      ( \n -> do
          let go 0 td = td
              go i td = go (i - 1) (TDigest.add (fromIntegral i / fromIntegral n) td)
          (ms, td) <- timeBlock (return $! go n (TDigest.emptyWith 100))
          printf "  N=%-9d  time=%.1fms\n" n ms
          return ms
      )
      sizes

  mapM_
    ( \i -> do
        let expected = fromIntegral (sizes !! i) / fromIntegral (sizes !! (i - 1)) :: Double
            ratio = (times !! i) / (times !! (i - 1))
        check
          ref
          (printf "N=%d  ratio=%.2f (expected ~%.1f)" (sizes !! i) ratio expected)
          (ratioOk ratio expected)
    )
    [1 .. length sizes - 1]

  putStrLn ""

  -- -----------------------------------------------------------------------
  -- Test 2: Centroid count bounded by O(delta)
  -- -----------------------------------------------------------------------
  putStrLn "--- Test 2: Centroid count bounded by O(delta) ---"

  let delta = 100 :: Double
  mapM_
    ( \n -> do
        let td = buildDigest delta n
            cc = TDigest.centroidCount td
        check
          ref
          (printf "N=%-9d  centroids=%-4d  (delta=%.0f, limit=%d)" n cc delta (5 * round delta :: Int))
          (cc <= 5 * round delta)
    )
    sizes

  putStrLn ""

  -- -----------------------------------------------------------------------
  -- Test 3: Query time independent of N
  -- -----------------------------------------------------------------------
  putStrLn "--- Test 3: Query time independent of N ---"

  let querySizes = [1000, 10000, 100000] :: [Int]
  queryTimes <-
    mapM
      ( \n -> do
          let td = TDigest.compress (buildDigest 100 n)
              iterations = 10000 :: Int
              doQueries 0 = return ()
              doQueries i = do
                let _ = TDigest.quantile 0.5 td
                    _ = TDigest.cdf 0.5 td
                doQueries (i - 1)
          (ms, _) <-
            timeBlock
              ( return $!
                  foldl'
                    ( \acc i ->
                        let q = case TDigest.quantile 0.5 td of Just v -> v; Nothing -> 0
                            c = case TDigest.cdf 0.5 td of Just v -> v; Nothing -> 0
                         in acc + q + c
                    )
                    (0 :: Double)
                    [1 .. iterations]
              )
          let usPerQuery = (ms * 1000.0) / fromIntegral iterations
          printf "  N=%-9d  query_time=%.2fus\n" n usPerQuery
          return usPerQuery
      )
      querySizes

  mapM_
    ( \i -> do
        let ratio = (queryTimes !! i) / (queryTimes !! (i - 1))
        check
          ref
          (printf "N=%d  ratio=%.2f (expected ~1.0)" (querySizes !! i) ratio)
          (ratioOkWide ratio 1.0)
    )
    [1 .. length querySizes - 1]

  putStrLn ""

  -- -----------------------------------------------------------------------
  -- Test 4: Tail accuracy improves with delta
  -- -----------------------------------------------------------------------
  putStrLn "--- Test 4: Tail accuracy improves with delta ---"

  let deltas = [50, 100, 200] :: [Double]
      tailQs = [0.01, 0.001, 0.99, 0.999] :: [Double]
      nAcc = 100000 :: Int

  mapM_
    ( \q -> do
        errors <-
          mapM
            ( \d -> do
                let td = buildDigest d nAcc
                    est = case TDigest.quantile q td of Just v -> v; Nothing -> 0
                    err = abs (est - q)
                printf "  delta=%-5.0f  q=%-6.3f  error=%.6f\n" d q err
                return err
            )
            deltas

        mapM_
          ( \i -> do
              let ok = (errors !! i) <= (errors !! (i - 1)) * 1.5 + 0.001
              check
                ref
                ( printf
                    "delta=%.0f q=%.3f error decreases (%.6f <= %.6f)"
                    (deltas !! i)
                    q
                    (errors !! i)
                    (errors !! (i - 1))
                )
                ok
          )
          [1 .. length deltas - 1]
    )
    tailQs

  putStrLn ""

  -- -----------------------------------------------------------------------
  -- Test 5: Merge preserves weight and accuracy
  -- -----------------------------------------------------------------------
  putStrLn "--- Test 5: Merge preserves weight and accuracy ---"

  let nMerge = 10000 :: Int
      td1_0 =
        foldl'
          (\td i -> TDigest.add (fromIntegral i / fromIntegral nMerge) td)
          (TDigest.emptyWith 100)
          [0 .. nMerge `div` 2 - 1]
      td2_0 =
        foldl'
          (\td i -> TDigest.add (fromIntegral i / fromIntegral nMerge) td)
          (TDigest.emptyWith 100)
          [nMerge `div` 2 .. nMerge - 1]
      wBefore = TDigest.totalWeight td1_0 + TDigest.totalWeight td2_0
      merged = TDigest.merge td1_0 td2_0
      wAfter = TDigest.totalWeight merged

  check
    ref
    (printf "weight_before=%.0f  weight_after=%.0f  (equal)" wBefore wAfter)
    (abs (wBefore - wAfter) < 1e-9)

  let medianEst = case TDigest.quantile 0.5 merged of Just v -> v; Nothing -> 0
      medianErr = abs (medianEst - 0.5)
  check
    ref
    (printf "median_error=%.6f  (< 0.05)" medianErr)
    (medianErr < 0.05)

  let p99Est = case TDigest.quantile 0.99 merged of Just v -> v; Nothing -> 0
      p99Err = abs (p99Est - 0.99)
  check
    ref
    (printf "p99_error=%.6f  (< 0.05)" p99Err)
    (p99Err < 0.05)

  putStrLn ""

  -- -----------------------------------------------------------------------
  -- Test 6: compress is O(n log n)
  -- -----------------------------------------------------------------------
  putStrLn "--- Test 6: compress is O(n log n) ---"

  let compressSizes = [500, 5000, 50000] :: [Int]
  compressTimes <-
    mapM
      ( \bufN -> do
          let buf =
                map
                  ( \i ->
                      let v = fromIntegral i / fromIntegral bufN
                       in v
                  )
                  [0 .. bufN - 1]
              td0 = foldl' (\td v -> TDigest.add v td) (TDigest.emptyWith 10000) buf
          (ms, _) <- timeBlock (return $! TDigest.centroidCount (TDigest.compress td0))
          printf "  buf_n=%-8d  compress_time=%.2fms\n" bufN ms
          return ms
      )
      compressSizes

  mapM_
    ( \i -> do
        let n0 = fromIntegral (compressSizes !! (i - 1)) :: Double
            n1 = fromIntegral (compressSizes !! i) :: Double
            expected = (n1 * logBase 2 n1) / (n0 * logBase 2 n0)
            ratio = (compressTimes !! i) / (compressTimes !! (i - 1))
            ok = ratio >= expected * 0.3 && ratio <= expected * 4.0
        check
          ref
          (printf "buf_n=%d  ratio=%.2f (expected ~%.1f)" (compressSizes !! i) ratio expected)
          ok
    )
    [1 .. length compressSizes - 1]

  putStrLn ""

  -- -----------------------------------------------------------------------
  -- Summary
  -- -----------------------------------------------------------------------
  s <- readIORef ref
  let total = passCount s + failCount s
  printf "Summary: %d/%d tests passed\n" (passCount s) total
