{-# LANGUAGE ScopedTypeVariables #-} 
             
module Examples where 

import qualified Obsidian.CodeGen.CUDA as CUDA
import Obsidian.CodeGen.CUDA.WithCUDA
-- import Obsidian.CodeGen.CUDA.WithCUDA.Text
import Obsidian.CodeGen.CUDA.WithCUDA.Exec 

import Obsidian.Program
import Obsidian.Exp
import Obsidian.Types
import Obsidian.Array
import Obsidian.Library
import Obsidian.Force

import Data.Word
import Data.Int
import Data.Bits

import qualified Data.Vector.Storable as V

import Control.Monad.State

import Prelude hiding (zipWith,sum,replicate)
import qualified Prelude as P 

---------------------------------------------------------------------------
-- MapFusion example
---------------------------------------------------------------------------

mapFusion :: Pull EInt -> BProgram (Pull EInt)
mapFusion arr =
  do
    imm <- sync $ (fmap (+1) . fmap (*2)) arr
    sync $ (fmap (+3) . fmap (*4)) imm 

input1 :: Pull EInt 
input1 = namedArray "apa" 32

input2 :: Distrib (Pull EInt)
input2 = namedGlobal "apa" 256 32

---------------------------------------------------------------------------
--
---------------------------------------------------------------------------

sync = force 

prg0 = putStrLn$ printPrg$  mapFusion input1

mapFusion' :: Distrib (Pull EInt)
              -> Distrib (BProgram (Pull EInt))
mapFusion' arr = mapD mapFusion arr

toGlobArray :: forall a. Scalar a
               => Distrib (BProgram (Pull (Exp a)))
               -> GlobArray (Exp a)
toGlobArray inp@(Distrib nb bixf) =
  GlobArray nb bs $
    \wf -> ForAllBlocks nb $
           \bix ->
           do -- BProgram do block 
             arr <- bixf bix 
             ForAll bs $ \ix -> wf (arr ! ix) bix ix 
  where
    bs = len $ fst $ runPrg 0 $ bixf 0
  

forceBT :: forall a. Scalar a => GlobArray (Exp a)
           -> Final (GProgram (Distrib (Pull (Exp a))))
forceBT (GlobArray nb bs pbt) = Final $ 
  do
      global <- Output $ Pointer (typeOf (undefined :: Exp a))
      
      pbt (assignTo global bs)
        
      return $ Distrib nb  $ 
        \bix -> (Pull bs (\ix -> index global ((bix * (fromIntegral bs)) + ix)))
    where 
      assignTo name s e b i = Assign name ((b*(fromIntegral s))+i) e


prg1 = putStrLn$ printPrg$ cheat $ (forceBT . toGlobArray . mapFusion') input2


---------------------------------------------------------------------------
-- Permutation test
--------------------------------------------------------------------------- 
--  a post permutation (very little can be done with a GlobArray) 
permuteGlobal :: (Exp Word32 -> Exp Word32 -> (Exp Word32, Exp Word32))
                 -> Distrib (Pull a)
                 -> GlobArray a
permuteGlobal perm distr@(Distrib nb bixf) = 
  GlobArray nb bs $
    \wf -> -- (a -> W32 -> W32 -> TProgram)
       do
         ForAllBlocks nb $
           \bix -> ForAll bs $
                   \tix ->
                   let (bix',tix') = perm bix tix 
                   in wf ((bixf bix) ! tix) bix' tix'
  where 
    bs = len (bixf 0)

--Complicated. 
permuteGlobal' :: (Exp Word32 -> Exp Word32 -> (Exp Word32, Exp Word32))
                 -> Distrib (BProgram (Pull a))
                 -> GlobArray a
permuteGlobal' perm distr@(Distrib nb bixf) = 
  GlobArray nb bs $
    \wf -> -- (a -> W32 -> W32 -> TProgram)
       do
         ForAllBlocks nb $
           \bix ->
           do -- BProgram do block
             arr <- bixf bix
             ForAll bs $ 
               \tix ->
                 let (bix',tix') = perm bix tix
                 in wf (arr ! tix) bix' tix'
  where
    -- Gah. (Does this even work? (for real?)) 
    bs = len $ fst $ runPrg 0 $ bixf 0

---------------------------------------------------------------------------
-- mapD experiments
---------------------------------------------------------------------------
class LocalArrays a
instance LocalArrays (Pull a) 
instance LocalArrays (Push a)
instance (LocalArrays a, LocalArrays b) => LocalArrays (a,b)
instance (LocalArrays a, LocalArrays b, LocalArrays c) => LocalArrays (a,b,c)
  

mapD :: (LocalArrays a, LocalArrays b) =>
        (a -> BProgram b) ->
        (Distrib a -> Distrib (BProgram b))
mapD f inp@(Distrib nb bixf) =
  Distrib nb $ \bid -> f (bixf bid)



---------------------------------------------------------------------------
-- Playing with CUDA launch code generation.
-- Much work needed here.
---------------------------------------------------------------------------

{-
test = putStrLn $ getCUDA $
         do
           kernel <- cudaCapture (forceBT . toGlobArray . mapFusion') input2

           i1 <- cudaUseVector (V.fromList [0..31 :: Int32]) Int32
           o1 <- cudaAlloca 32 Int32
         
           cudaTime "Timing execution of kernel" $ 
             cudaExecute kernel 1 32 [i1] [o1] 

           cudaFree i1
           cudaFree o1 
             
           return ()
-} 

test1 = runCUDA $
         do
           kernel <- cudaCapture (forceBT . toGlobArray . mapFusion') input2

           cudaUseVector (V.fromList [0..31 :: Int32]) Int32 $ \ i1 ->
              cudaAlloca 32 Int32 $ \(o1 :: CUDAVector Int32) -> 
                  cudaTime "Timing execution of kernel" $ 
                    cudaExecute kernel 1 32 i1 o1 
              
             
           return ()


---------------------------------------------------------------------------
-- Strange push array 
---------------------------------------------------------------------------

push1 = push $ zipp (input1,input1)

testApa =  printPrg $ write_ push1

