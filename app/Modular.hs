module Modular where

import System.IO.Unsafe

import Foreign.Storable
import Foreign.C.String
import Foreign.Marshal.Alloc (free)
import Foreign.Marshal.Array (advancePtr, pokeArray)

import Control.Monad

import Data.List (sort)
import Data.Group
import Data.Ratio

import Data.Number.Flint hiding (numerator, denominator)

mediant l r = unsafePerformIO $ do
  result <- newFmpq
  withFmpq result $ \result -> do
    withFmpq r $ \r -> do
      withFmpq l $ \l -> do
        fmpq_mediant result r l
  return result

fareyNext [x, y] = x : mediant x y : [y]
fareyNext (x:y:xs) = x : mediant x y : fareyNext (y:xs)

fareyIter = iterate fareyNext [0, 1]
farey n = fareyIter !! n

fareyNext' [x, y] = x : mediant' x y : [y]
fareyNext' (x:y:xs) = x : mediant' x y : fareyNext' (y:xs)

fareyIter' = iterate fareyNext' [0, 1]
farey' n = fareyIter' !! n

mediant' x y = (numerator x + numerator y) % (denominator x + denominator y)

class Group' a b where
  action :: a -> b -> b

instance Group' PSL2Z Fmpq where
  action gamma z = unsafePerformIO $ do
    result <- newFmpq
    withPSL2Z gamma $ \gamma -> do
      CPSL2Z a b c d <- peek gamma
      withFmpq result $ \result -> do 
        withNewFmpz $ \p -> do
          withNewFmpz $ \q -> do
            withFmpq z $ \z -> do
              fmpq_get_fmpz_frac p q z
              withNewFmpz $ \tmp -> do
                withNewFmpz $ \num -> do
                  withNewFmpz $ \den -> do
                    fmpz_mul num a p
                    fmpz_mul tmp b q
                    fmpz_add num num tmp
                    fmpz_mul den c p
                    fmpz_mul tmp d q
                    fmpz_add den den tmp
                    fmpq_set_fmpz_frac result num den
    return result

rademacherMatrix :: Fmpq -> PSL2Z
rademacherMatrix x = unsafePerformIO $ do
  result <- newPSL2Z
  withPSL2Z result $ \result -> do
    CPSL2Z a b c d <- peek result
    withFmpq x $ \x -> do
      CFmpq h k <- peek x
      withNewFmpz $ \g -> do
        withNewFmpz $ \r -> do
          withNewFmpz $ \s -> do
            withNewFmpz $ \j -> do
              fmpz_xgcd g r s h k
              cmp <- fmpz_cmp_si r 0
              if cmp < 0 then do
                fmpz_set j r
                fmpz_neg j j
              else do
                fmpz_set j k
                fmpz_sub j j r
              fmpz_set a j
              fmpz_mul b h j
              fmpz_add_ui b b 1
              fmpz_neg b b
              fmpz_divexact b b k
              fmpz_set c k
              fmpz_set d h
              fmpz_neg d d
  return result

-- class Group a => WordProblem a where
--   data Letter a
--   hom :: Letter a -> a
--   toWord :: a -> [(Letter a, Integer)]
--   fromWord :: [(Letter a, Integer)] -> a
--   fromWord w = mconcat $ map (\(x, n) -> hom x `pow` n) w

-- instance WordProblem PSL2Z where
--   data Letter PSL2Z = S | T deriving (Show, Eq)
--   hom S = unsafePerformIO $ newPSL2Z_ 0 (-1) 1 0
--   hom T = unsafePerformIO $ newPSL2Z_ 1 1 0 1
--   toWord x = snd $ unsafePerformIO $ do
--     word <- newPSL2ZWord
--     withPSL2ZWord word $ \w -> do
--       withPSL2Z x $ \x -> psl2z_get_word w x
--       CPSL2ZWord l n <- peek w
--       result <- forM [0 .. fromIntegral n-1] $ \j -> do
--         flag <- fmpz_is_zero (l `advancePtr` j)
--         e <- newFmpz
--         withFmpz e $ \e -> fmpz_set e (l `advancePtr` j)
--         return $ if flag == 1 then (S, 3) else (T, toInteger e)
--       return result
    
-- testWord = do
--   m <- newPSL2Z_ 2889659343093 (-73086250453981)
--                  5380580492512 (-136087478409347)
--   return $ toWord m

  
-- testWord' = do
--   m <- newPSL2Z_ 2889659343093 (-73086250453981)
--                  5380580492512 (-136087478409347)
--   (word, _) <-
--     withNewPSL2ZWord $ \w -> do
--       withPSL2Z m $ \m -> do
--         withNewPSL2Z $ \x -> do
--           psl2z_set x m
--           psl2z_get_word w m
--           g <- newPSL2Z
--           putStr "initial g: "
--           print g
--           withPSL2Z g $ \g -> do
--             psl2z_set_word g w
--           putStr "final g: "
--           print g
--   print word

testWord' = do
  m <- newPSL2Z_ 2889659343093 (-73086250453981)
                 5380580492512 (-136087478409347)
  print m
  let w = toWord' m
  print w
  print $ fromWord' w
  
toWord' x = fst $ unsafePerformIO $ do
  withNewPSL2ZWord $ \w ->
    withPSL2Z x $ \x -> do
      psl2z_get_word w x

fromWord' w = fst $ unsafePerformIO $ do
  withNewPSL2Z $ \x -> do
    withPSL2ZWord w $ \w ->
      psl2z_set_word x w

testPerm' = do
  let n = 12
  u <- _perm_init n
  v <- _perm_init n
  w <- _perm_init n
  pokeArray u [1,0,3,2,5,4,8,9,6,7,11,10]
  pokeArray v [3,0,9,1,10,2,11,6,4,5,8,7]
  pokeArray w [0,2,4,1,6,7,9,10,11,3,5,8]
  s <- _perm_init n
  t <- _perm_init n
  p <- _perm_init n
  _perm_set s u n
  _perm_set t w n
  _perm_inv t t n
  forM_ [u, v, w] $ \p -> do
    _perm_print_pretty p n
    putStr "\n"
  putStrLn "\ngenerators as permutations:\n"
  let g = [[1,1,0,1],[5,-1,6,-1],[7,-3,12,-5]]
  forM_ g $ \[a,b,c,d] -> do
    withNewPSL2Z_ a b c d $ \m -> do
      withNewPSL2ZWord $ \w -> do
        psl2z_get_word w m
        _perm_set_word p s t n w
        psl2z_word_print_pretty w
        putStr "\n"
        putStr "p: "
        _perm_print_pretty p n
        putStr "\n"
  putStrLn "\ncoset representatives:\n"
  let cr =[[1,0,0,1]
         ,[0,1,-1,3]
         ,[0,1,-1,2]
         ,[0,1,-1,1]
         ,[-1,1,-3,2]
         ,[-1,2,-2,3]
         ,[-1,1,-2,1]
         ,[-1,0,-2,-1]
         ,[-2,1,-3,1]
         ,[-1,1,-1,0]
         ,[-1,0,-1,-1]
         ,[-1,-1,-1,-2]]
  let f = testGroup s t n 
  forM_ cr $ \[a,b,c,d] -> do
    withNewPSL2Z_ a b c d $ \m -> do
      withNewPSL2ZWord $ \w -> do
        psl2z_get_word w m
        _perm_set_word p s t n w
        -- psl2z_word_print_pretty w
        -- putStr "\n"
        putStr "p: "
        _perm_print_pretty p n
        putStr "\n"
  putStrLn "\ncoset index:\n"
  ci <- forM cr $ \[a,b,c,d] -> do
    x <- newPSL2Z_ a b c d
    return $ f x
  print ci
  print $ sort ci

testGroup s t n x = unsafePerformIO $ do
  p <- _perm_init n
  withNewPSL2ZWord $ \w -> do
    withPSL2Z x $ \x -> do
      psl2z_get_word w x
      _perm_set_word p s t n w
  flag <- peek p
  return $ fromIntegral flag