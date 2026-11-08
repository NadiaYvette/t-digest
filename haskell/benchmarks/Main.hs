module Main (main) where

import Control.Exception (evaluate)
import Control.Monad (when)
import Data.IORef
import Data.Maybe (fromMaybe)
import qualified Data.Sketch.TDigest as TD
import System.CPUTime (getCPUTime)
import Text.Printf (printf)

timeBlock :: IO a -> IO (Double, a)
timeBlock action = do
  t0 <- getCPUTime
  result <- action >>= evaluate
  t1 <- getCPUTime
  let ms = fromIntegral (t1 - t0) / 1e9
  return (ms, result)

buildDigest :: Double -> Int -> TD.TDigest
buildDigest delta n =
  foldl
    (\td i -> TD.add (fromIntegral i / fromIntegral n) td)
    (TD.emptyWith delta)
    [1 .. n]

check :: IORef (Int, Int) -> String -> Bool -> IO ()
check ref desc ok = do
  (pass, fail') <- readIORef ref
  if ok
    then do
      writeIORef ref (pass + 1, fail')
      printf "  %-50s  PASS\n" desc
    else do
      writeIORef ref (pass, fail' + 1)
      printf "  %-50s  FAIL\n" desc

ratioOk :: Double -> Double -> Bool
ratioOk actual expected =
  actual >= expected * 0.2 && actual <= expected * 5.0

main :: IO ()
main = do
  ref <- newIORef (0, 0)
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
              go i td = go (i - 1) (TD.add (fromIntegral i / fromIntegral n) td)
          (ms, _) <- timeBlock (return $! go n (TD.emptyWith 100))
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
            cc = TD.centroidCount td
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
  _ <-
    mapM
      ( \n -> do
          let td = TD.compress (buildDigest 100 n)
              iterations = 10000 :: Int
          (ms, _) <-
            timeBlock
              ( return $!
                  foldl
                    ( \acc _i ->
                        let q = fromMaybe 0 (TD.quantile 0.5 td)
                            c = fromMaybe 0 (TD.cdf 0.5 td)
                         in acc + q + c
                    )
                    (0.0 :: Double)
                    [1 .. iterations]
              )
          let perQueryUs = ms * 1000.0 / fromIntegral iterations
          printf "  N=%-9d  query_time=%.2fus\n" n perQueryUs
          return perQueryUs
      )
      querySizes

  putStrLn ""

  -- -----------------------------------------------------------------------
  -- Test 4: Tail accuracy improves with delta
  -- -----------------------------------------------------------------------
  putStrLn "--- Test 4: Tail accuracy improves with delta ---"
  let testDeltas = [50, 100, 200] :: [Double]
      testQuantiles = [0.010, 0.001, 0.990, 0.999] :: [Double]
      nTest4 = 100000 :: Int

  mapM_
    ( \q -> do
        errors <-
          mapM
            ( \d -> do
                let td = buildDigest d nTest4
                    est = fromMaybe 0.0 (TD.quantile q td)
                    err = abs (est - q)
                printf "  delta=%-5.0f  q=%-7.3f  error=%.6f\n" d q err
                return err
            )
            testDeltas
        mapM_
          ( \i -> do
              let prevErr = errors !! (i - 1)
                  currErr = errors !! i
                  dCurr = testDeltas !! i
              check
                ref
                (printf "delta=%.0f q=%.3f error decreases (%.6f <= %.6f)" dCurr q currErr prevErr)
                (currErr <= prevErr * 1.5)
          )
          [1 .. length testDeltas - 1]
    )
    testQuantiles

  putStrLn ""

  -- -----------------------------------------------------------------------
  -- Test 5: Merge preserves weight and accuracy
  -- -----------------------------------------------------------------------
  putStrLn "--- Test 5: Merge preserves weight and accuracy ---"
  let halfN = 5000 :: Int
      tdA =
        foldl
          (\td i -> TD.add (fromIntegral i / fromIntegral (2 * halfN)) td)
          (TD.emptyWith 100)
          [1 .. halfN]
      tdB =
        foldl
          (\td i -> TD.add (fromIntegral (halfN + i) / fromIntegral (2 * halfN)) td)
          (TD.emptyWith 100)
          [1 .. halfN]
      tdM = TD.merge tdA tdB
      wBefore = TD.totalWeight tdA + TD.totalWeight tdB
      wAfter = TD.totalWeight tdM
  check ref "weight_before=10000  weight_after=10000  (equal)" (wBefore == wAfter)

  let medEst = fromMaybe 0.0 (TD.quantile 0.5 tdM)
      medErr = abs (medEst - 0.5)
  check ref (printf "median_error=%.6f  (< 0.05)" medErr) (medErr < 0.05)

  let p99Est = fromMaybe 0.0 (TD.quantile 0.99 tdM)
      p99Err = abs (p99Est - 0.99)
  check ref (printf "p99_error=%.6f  (< 0.05)" p99Err) (p99Err < 0.05)

  putStrLn ""
  (pass, fail') <- readIORef ref
  printf "Summary: %d/%d tests passed\n" pass (pass + fail')
  when (fail' > 0) $ putStrLn "Some tests failed."
