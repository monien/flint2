module Main where

import System.IO.Unsafe

import Data.Typeable

import Foreign.Marshal
import Foreign.Marshal.Array
import Foreign.Storable
import Foreign.Ptr (nullPtr, castPtr)
import Foreign.C.String
import Foreign.C.Types
import Foreign.Marshal.Array (advancePtr)

import Test.QuickCheck
import Control.Monad
import Control.Monad.Reader

import Data.List (permutations)

import Data.Number.Flint

import Fmpz
import FmpzFactor
import FmpzPoly
import Fmpq
import FmpqPoly

main = do
  testFqPolyFactor
  testFmpzModPolyFactor
  
main' = do
  testFmpzMPoly
  testFmpzMPolyQ
  testFq
  testArb
  testAcb
  testAcbModular
  testNF
  testFmpzi
  testNModMat
  testAcbModular
  
testRest = do
  x <- newFmpz
  withFmpz x $ \x -> do
    fmpz_set_ui x 7
    flag <- fmpz_print x
    endl
  let a = 15623679023253334147 :: Fmpz
      b = 13550662568090911171 :: Fmpz
      x = a * b
  print x
  print $ factor x
  withFmpz x $ \x ->
    withNewFmpzFactor $ \f -> do
      fmpz_factor f x
      fmpz_factor_print f
      endl
  r <- newFRandState
  replicateM_ 10 $ do
    withFRandState r $ \r -> do
      withFmpz x $ \x -> do
        fmpz_randbits x r 64
        putStr "random number: "
        fmpz_print x
        endl
        withNewFmpzFactor $ \f -> do
          fmpz_factor f x
          putStr "factorization: "
          fmpz_factor_print f
          endl
  l <- sample' arbitrary :: IO ([Fmpz])
  print l
  let n = 10
  v <- _fmpz_vec_init n
  forM_ [0..fromIntegral n-1] $ \j -> do
    fmpz_set_si (v `advancePtr` j) (fromIntegral (j+1)^2)
  _fmpz_vec_print v n
  f <- newFmpzFactor
  forM_ [0..fromIntegral n-1] $ \j -> do
    withFmpzFactor f $ \f -> do
      fmpz_factor f (v `advancePtr` j)
      fmpz_factor_print f
      endl
  _fmpz_vec_clear v n
  forM_ [0..10] $ \j ->
    print $ hermitePolynomial j
  let poly = product $ map hermitePolynomial [0..10]
  mapM_ print $ factor poly
  a <- newFmpzMat 3 3
  withFmpzMat a fmpz_mat_one
  withFmpzMat a fmpz_mat_print_pretty; endl
  withFmpzMat a $ \a -> do
    p <- fmpz_mat_entry a 0 2
    fmpz_set_ui p 7
  withFmpzMat a fmpz_mat_print_pretty; endl
  d <- newDMat 3 3
  withDMat d $ \d ->
    withFmpzMat a $ \a ->
      fmpz_mat_get_d_mat d a
  withDMat d $ \d ->
    forM_ [0..2] $ \i -> do
      forM_ [0..2] $ \j -> do
        x <- d_mat_get_entry d i j
        print $ x
  poly <- newFmpqPoly
  withFmpqPoly poly $ \poly -> do
    fmpq_poly_legendre_p poly 7
  print poly
  print $ poly^3
  testFmpqMat
  testPadic
  testPadicMat
  testQadic
  testHilbert
  testPerm
  
endl = putStrLn ""

testNModMat = do
  a <- newNModMat 3 3 7
  withNModMat a $ \a -> do
    d <- nmod_mat_det a
    print d
    
testPadic = do
  let p = 7 :: Fmpz
  withNewPadicCtx p 0 128 padic_series $ \ctx -> do
    withNewPadic $ \x -> do
      padic_set_ui x 2 ctx
      padic_print x ctx
      endl
      padic_sqrt x x ctx
      padic_print x ctx
      endl
      padic_neg x x ctx
      padic_print x ctx
      endl
      padic_mul x x x ctx
      padic_print x ctx
      endl
      v <- padic_get_val x
      print v
      prec <- padic_get_prec x
      print prec
      u <- padic_unit x
      fmpz_print u
      endl

testQadic = do
  let c = [1,10,9,8,8,0,2,9,1,3,1]
  p <- newFmpz
  withFmpz p $ \p -> fmpz_set_ui p 11
  withNewQadicCtx p 4 0 128 "a" padic_series $ \ctx -> do
    CQadicCtx pctx _ _ _ _ <- peek ctx
    withNewQadic $ \x -> do
      withFmpzPoly (fromList [3,0,4,8]) $ \poly -> do
        padic_poly_set_fmpz_poly x poly pctx
      newton x c ctx
      putStr "x = "
      qadic_print_pretty x ctx
      putStr "\n"
      y <- horner x c ctx
      withQadic y $ \y -> do
        putStr "y = "
        qadic_print_pretty y ctx
        putStr "\n"
         
newton x c ctx = do
  withNewQadic $ \y ->
    withNewQadic $ \y' -> do
      qadic_set_ui y (c!!0) ctx
      qadic_set_ui y' 0 ctx
      withNewQadic $ \tmp -> 
        forM_ (tail c) $ \c -> do
          qadic_set_ui tmp c ctx
          qadic_mul y' y' x ctx
          qadic_add y' y' y ctx
          qadic_mul y y x ctx
          qadic_add y y tmp ctx
      is_zero <- qadic_is_zero y
      qadic_inv y' y' ctx
      qadic_mul y y y' ctx
      qadic_sub x x y ctx
      when (is_zero /= 1) $ newton x c ctx
  return ()

horner x c ctx = do
  y <- newQadic
  withQadic y $ \y -> do
    qadic_set_ui y (c!!0) ctx
    withNewQadic $ \tmp ->
      forM_ (tail c) $ \c -> do
        qadic_mul y y x ctx
        qadic_set_ui tmp c ctx
        qadic_add y y tmp ctx
  return y

testPadicMat = do
  let p = 11 :: Fmpz
  withNewPadicCtx p 0 128 padic_terse $ \ctx -> do
    mat <- newPadicMat 3 3 20
    withPadicMat mat $ \mat -> do
      withNewFmpqMat 3 3 $ \r -> do
        fmpq_mat_hilbert_matrix r
        padic_mat_set_fmpq_mat mat r ctx
      padic_mat_print mat ctx
      endl
      padic_mat_print_pretty mat ctx
      endl

testFmpqMat = do
  mat <- newFmpqMat 4 4
  withFmpqMat mat $ \mat -> do
    fmpq_mat_hilbert_matrix mat
    p <- fmpq_mat_entry mat 1 2
    -- fmpq_set_ui p 2 5
    -- fmpq_mat_print mat
    endl
    withNewFmpq $ \d -> do
      fmpq_mat_det d mat
      fmpq_print d
      endl
    poly <- newFmpqPoly
    withFmpqPoly poly $ \poly -> fmpq_mat_charpoly poly mat
    print poly

testHilbert = do
  putStrLn "testHilbert:"
  forM_ [1..10] $ \n -> do
    putStr $ show n ++ " "
    mat <- newFmpqMat n n
    withFmpqMat mat $ \mat -> do
      fmpq_mat_hilbert_matrix mat
      withNewFmpq $ \d -> do
        fmpq_mat_det d mat
        withNewFmpz $ \a -> do
          b <- newFmpz
          withFmpz b $ \b -> do
            fmpq_get_fmpz_frac a b d
          print $ factor b

testPerm = do
  let n = 6
  p <- _perm_init n
  q <- _perm_init n
  a <- peekArray (fromIntegral n) p
  print a
  pokeArray p [3, 0, 1, 2, 5, 4]
  _perm_print p n
  endl
  _perm_compose q p p n
  _perm_print q n
  endl
  _perm_compose q p p n
  _perm_compose q q p n
  _perm_print q n
  endl

testFq = do
  let p = 7 :: Fmpz
      poly = fromList [0, 3, 1] :: FmpzPoly
  ctx <- newFqCtx p 4 "a"
  x <- newFq ctx
  tmp <- newFq ctx
  withFqCtx ctx $ \ctx -> do
    withFq x $ \x -> do
      withFq tmp $ \tmp -> do 
        withFmpzPoly poly $ \poly -> fq_set x poly ctx
        fq_print_pretty x ctx
        endl
        endl
        forM_ [0..4] $ \j -> do 
          fq_frobenius tmp x j ctx
          putStr $ show j ++ " "
          fq_print_pretty tmp ctx
          endl
        endl

testFmpqPoly = do
  poly <- newFmpqPoly
  withFmpqPoly poly $ \poly -> do
    arith_bernoulli_polynomial poly 12
  print poly

testFmpzMPoly = do
  ctx <- newFmpzMPolyCtx 3 ord_lex
  poly <- newFmpzMPoly ctx
  
  withFmpzMPolyCtx ctx $ \ctx -> do
    withFmpzMPoly poly $ \poly -> do
      forM_ [0..3] $ \j -> do 
        fmpz_mpoly_symmetric poly j ctx
        fmpz_mpoly_print_pretty poly nullPtr ctx
        endl
  endl  
  x <- newArray =<< traverse newCString ["x", "y", "z"]
  withFmpzMPolyCtx ctx $ \ctx -> do
    withFmpzMPoly poly $ \poly -> do
      forM_ [0..3] $ \j -> do 
        fmpz_mpoly_symmetric poly j ctx
        fmpz_mpoly_print_pretty poly x ctx
        endl 
  endl


testFmpzMPolyQ = do
  ctx <- newFmpzMPolyCtx 7 ord_lex
  num <- newFmpzMPoly ctx
  den <- newFmpzMPoly ctx
  r <- newFmpzMPolyQ ctx
  print $ typeOf num
  print $ typeOf den
  withFmpzMPolyCtx ctx $ \ctx -> do
    withFmpzMPoly num $ \num -> do
      withFmpzMPoly den $ \den -> do
        fmpz_mpoly_symmetric num 1 ctx
        fmpz_mpoly_symmetric den 2 ctx
        print $ typeOf num
        print $ typeOf num
    withFmpzMPolyQ r $ \r -> do
      fmpz_mpoly_q_gen r 5 ctx
      fmpz_mpoly_q_inv r r ctx
      fmpz_mpoly_q_print_pretty r nullPtr ctx
      endl
  endl
  gens <- forM [0..6] $ \j -> mkGen j ctx
  tmp <- newFmpzMPolyQ ctx
  print $ typeOf tmp
  withFmpzMPolyCtx ctx $ \ctx -> do
    withFmpzMPolyQ tmp $ \tmp -> do
      withFmpzMPolyQ r $ \r -> do  
        forM_ gens $ \g -> do
          withFmpzMPolyQ g $ \g -> do
            fmpz_mpoly_q_set r g ctx
            fmpz_mpoly_q_inv r r ctx
            fmpz_mpoly_q_add r r g ctx
            fmpz_mpoly_q_add tmp tmp r ctx
            fmpz_mpoly_q_print_pretty r nullPtr ctx
            endl
        putStrLn $ "\nresult of type \"" ++ show (typeOf tmp) ++ "\":\n"
        fmpz_mpoly_q_print_pretty tmp nullPtr ctx
        endl
    putStrLn "\nnumerator:\n" 
    withFmpzMPolyQNumerator tmp $ \tmp -> do
      fmpz_mpoly_print_pretty tmp nullPtr ctx
      endl
    putStrLn "\ndenominator:\n"
    withFmpzMPolyQDenominator tmp $ \tmp -> do
      fmpz_mpoly_print_pretty tmp nullPtr ctx
      endl
  endl
        
mkGen j ctx = do
  r <- newFmpzMPolyQ ctx
  withFmpzMPolyCtx ctx $ \ctx -> do
    withFmpzMPolyQ r $ \r -> do
      fmpz_mpoly_q_gen r j ctx
  return r

testArb = do
  let prec = 1024
  withNewArb $ \x -> do
    withNewArb $ \pi -> do
      arb_const_pi pi prec
      arb_sqrt x pi prec
      arb_printn x prec arb_str_no_radius
      endl
      arb_mul x x x prec
      arb_printn x prec arb_str_no_radius
      endl
      arb_sub x pi x prec
      arb_printn x prec arb_str_no_radius
      endl
      arb_const_pi x prec
      arb_print x
      endl
      arb_printd x 16
      endl

testAcb = do
  let prec = 1024
  withNewAcb $ \x -> do
    acb_set_si_si x 3 7
    acb_printn x 16 arb_str_no_radius
    endl
    acb_sqrt x x prec
    acb_printn x 16 arb_str_no_radius
    endl
    acb_mul x x x prec
    acb_printn x 16 arb_str_no_radius
    endl
    withNewArb $ \a -> do
      acb_abs a x prec
      arb_mul a a a prec
      arb_printn a 16 arb_str_no_radius
      endl
    withNewAcb $ \pi -> do
      withNewAcb $ \w -> do
        acb_const_pi pi prec
        forM_ [2..10] $ \n -> do
          acb_pow_si w pi n prec
          acb_set_si_si x n 0
          acb_zeta x x prec
          acb_div x x w prec
          acb_inv x x prec
          acb_printn x 32 arb_str_no_radius
          endl
        endl
        
testNF = do
  let poly = fromList [6,-24,42,-46,55,-86,101,-73,38,-20,9,-2,1] :: FmpqPoly
      z = fromList [0, 1] :: FmpqPoly
  nf <- newNF poly
  x <- newNFElem nf
  withNF nf $ \nf -> do 
    withNFElem x $ \x -> do
      withFmpqPoly z $ \z -> do
        nf_elem_set_fmpq_poly x z nf
      nf_elem_pow x x 12 nf
      withCString "a" $ \a -> do
        nf_elem_print_pretty x nf a
        endl
        r <- nfRep x nf
        withFmpqMat r $ \r -> do
          fmpq_mat_print r
  endl

nfRep x nf = do
  (_, n) <- withNewFmpqPoly $ \poly -> do
    nf_elem_get_fmpq_poly poly x nf
    fmpq_poly_degree poly
  a <- newFmpqMat (n+1) (n+1)
  withFmpqMat a $ \a -> do
    nf_elem_rep_mat a x nf
  return a
    
testFmpzi = do
  z <- newFmpzi
  withFmpzi z $ \z -> do
    fmpzi_set_si_si z 3 7
    fmpzi_print z
  endl

testAcbPoly = do
  let prec = 1024
      maxIter = 100
      poly = fromList [7, 0, 5, 1] :: FmpzPoly
  print poly
  cpoly <- newAcbPoly
  withFmpzPoly poly $ \poly -> do
    withAcbPoly cpoly $ \cpoly -> do
      acb_poly_set_fmpz_poly cpoly poly prec
      putStrLn "complex polynomial."
      acb_poly_printd cpoly 16
      endl
      degree <- acb_poly_degree cpoly
      roots <- _acb_vec_init degree
      n <- acb_poly_find_roots roots cpoly nullPtr maxIter prec
      putStrLn $ "found " ++ show n ++ " roots:"
      forM_ [0..n-1] $ \j -> do
        acb_printd (roots `advancePtr` (fromIntegral j)) 16
        endl
      putStrLn "reconstructed polynomial."
      withNewAcbPoly $ \tmp -> do
        acb_poly_product_roots tmp roots n prec
        acb_poly_printd tmp 16
        endl
      _acb_vec_clear roots degree

testAcbHypGeom = do
  let prec = 1024
      maxIter = 100
      poly = hermitePolynomial 7
  print poly
  cpoly <- newAcbPoly
  withFmpzPoly poly $ \poly -> do
    withAcbPoly cpoly $ \cpoly -> do
      withNewAcb $ \z -> do
        acb_poly_set_fmpz_poly cpoly poly prec
        degree <- acb_poly_degree cpoly
        roots <- _acb_vec_init degree
        n <- acb_poly_find_roots roots cpoly nullPtr maxIter prec
        m <- newAcb
        withAcb m $ \m -> do
          acb_set_ui m 7
          forM_ [0..n-1] $ \j -> do
            acb_set z (roots `advancePtr` (fromIntegral j))
            acb_printd z 16
            endl
            acb_hypgeom_hermite_h z m z prec
            acb_printd z 16
            endl
            endl

bernoulliNumber n = unsafePerformIO $ do
  b <- newFmpq
  withFmpq b $ \b -> do
    arith_bernoulli_number b $ (fromIntegral n)
  return b

testSeries = do
  let prec = 1024
  withNewAcbPoly $ \x -> do
    withNewAcbPoly $ \poly -> do
      acb_poly_one x
      acb_poly_shift_left x x 1
      acb_poly_printd x 16
      endl
      putStrLn "sin series"
      acb_poly_sin_series poly x 32 prec
      acb_poly_printd poly 16
      endl
      result <- newAcb
      withAcb result $ \result -> do
        acb_one result
        acb_poly_evaluate_horner result poly result prec
        putStrLn "series evaluation at 1:"
        acb_printd result 16
        endl
      withAcbRe result $ \r -> do
        arb_printd r 16
        endl
      withAcbIm result $ \r -> do
        arb_printd r 16
        endl
      withNewArb $ \y -> do
        arb_one y
        arb_sin y y prec
        arb_printd y 16
        endl

testAcbModular = do
  x <- newPSL2Z
  withPSL2Z x psl2z_print
  endl

numberOfPartitions n = do
  result <- newFmpz
  withFmpz result $ \result -> do
    partitions_fmpz_ui result n
  return result

nextBernoulli = do
  x <- newBernoulliRev 20
  n <- newFmpz
  d <- newFmpz
  replicateM_ 10 $ do
    withBernoulliRev x $ \x -> do
      withFmpz n $ \n -> do
        withFmpz d $ \d -> do
          bernoulli_rev_next n d x
          fmpz_print n
          putStr " "
          fmpz_print d
          endl

testArbHypgeom = do
  fileName <- newCString "flint_test.out"
  mode <- newCString "w"
  cr <- newCString "\n"
  space <- newCString " "
  out <- fopen fileName mode
  let prec = 1024
  withNewArb $ \x -> do
    arb_set_si x (-10)
    withNewArb $ \dx -> do
      arb_set_d dx 0.01
      withNewArb $ \ai -> do
        withNewArb $ \ai' -> do
          withNewArb $ \bi -> do
            withNewArb $ \bi' -> do
              replicateM_ 2000 $ do
                arb_hypgeom_airy ai ai' bi bi' x prec
                -- arb_printn x 16 arb_str_no_radius
                -- putStr " "
                -- arb_printn ai 16 arb_str_no_radius
                -- putStr " "
                -- arb_printn ai' 16 arb_str_no_radius
                -- endl
                arb_fprintn out x 16 arb_str_no_radius
                fputs space out
                arb_fprintn out ai 16 arb_str_no_radius
                fputs space out
                arb_fprintn out ai' 16 arb_str_no_radius
                fputs cr out
                arb_add x x dx prec
  fclose out

-- c file ----------------------------------------------------------------------

foreign import ccall "stdio.h fopen"
  fopen :: CString -> CString -> IO (Ptr CFile)

foreign import ccall "stdio.h fclose"
  fclose :: Ptr CFile -> IO CInt

foreign import ccall "stdio.h fputs"
  fputs :: CString -> Ptr CFile -> IO CInt

--------------------------------------------------------------------------------

testFqPolyFactor = do
  let poly = fromList [1,0,2,2,0,1,1,0,2,2,0,1] :: FmpzPoly
      p = 3 :: Fmpz
  fctx <- newFqCtx p 1 "a"
  foly <- newFqPoly fctx
  f <- newFqPolyFactor fctx
  mtx <- newFmpzModCtx p
  moly <- newFmpzModPoly mtx
  withFqCtx fctx $ \ctx -> do
    withFqPoly foly $ \foly -> do 
      withFmpzModCtx mtx $ \mtx -> do
        withFmpzPoly poly $ \poly -> do
          withFmpzModPoly moly $ \moly -> do
            fmpz_mod_poly_set_fmpz_poly moly poly mtx
            -- fmpz_mod_poly_print moly mtx
            -- endl
            -- withCString "x" $ \x -> do
            --   fmpz_mod_poly_print_pretty moly x mtx
            --   endl
            fq_poly_set_fmpz_mod_poly foly moly ctx
      withCString "x" $ \x -> do
        fq_poly_print_pretty foly x ctx
        endl
      withNewFqPolyFactor fctx $ \f -> do
        withNewFq fctx $ \prefactor -> do
          fq_poly_factor f prefactor foly ctx
          withCString "x" $ \x -> do
            fq_poly_factor_print_pretty f x ctx

testFmpzModPolyFactor = do
  let poly = fromList [1,0,2,2,0,1,1,0,2,2,0,1] :: FmpzPoly
      p = 3 :: Fmpz
  mtx <- newFmpzModCtx p
  moly <- newFmpzModPoly mtx
  fac <- newFmpzModPolyFactor mtx
  withFmpzModCtx mtx $ \mtx -> do
    withFmpzPoly poly $ \poly -> do
      withFmpzModPoly moly $ \moly -> do
        withFmpzModPolyFactor fac $ \fac -> do
          fmpz_mod_poly_set_fmpz_poly moly poly mtx
          fmpz_mod_poly_factor fac moly mtx
          withCString "x" $ \x -> do
            fmpz_mod_poly_factor_print_pretty fac x mtx
