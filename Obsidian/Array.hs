{-# LANGUAGE MultiParamTypeClasses,
             FlexibleInstances,
             GADTs,
             TypeFamilies #-} 

{- Joel Svensson 2012

   Notes:
    2014-04-15: Experimenting with 1D,2D and 3D arrays. 
    2014-04-08: Experimenting with API 
    ---- OUTDATED ----
    2013-08-26: Experimenting with warp programs.
                These do not fit that well in established Idioms!
                TODO: Improve this situation. 
    ---- OUTDATED ----
    2013-01-08: Removed number-of-blocks field from Distribs
    2012-12-10: Drastically shortened. 
-}

module Obsidian.Array (Pull, Push, SPull, DPull, SPush, DPush,
                       Pushable, 
                       mkPull,
                       mkPush,
                       push,
                       setSize,
                       (!),
                       (<:),
                       Array(..),
                       ArrayLength(..),
                       ASize(..),
                       namedGlobal,
                       undefinedGlobal) where

import Obsidian.Exp  
import Obsidian.Types
import Obsidian.Globs
import Obsidian.Program

import Prelude hiding (replicate) 
import Data.List hiding (replicate) 
import Data.Word

---------------------------------------------------------------------------
-- Aliases
---------------------------------------------------------------------------
type SPull = Pull Word32
type DPull = Pull EWord32

type SPush t a = Push t Word32 a
type DPush t a = Push t EWord32 a 
---------------------------------------------------------------------------
-- Create arrays
---------------------------------------------------------------------------
-- | An undefined array. Use as placeholder when generating code
undefinedGlobal n = Pull n $ \gix -> undefined
-- | A named global array. 
namedGlobal name n = Pull n $ \gix -> index name gix
-- namedPull name n = Pull n $ \gix -> index name gix

---------------------------------------------------------------------------
-- Class ArraySize
---------------------------------------------------------------------------
-- | ASize provides conversion to Exp Word32 for array sizes
class (Integral a, Num a) => ASize a where
  sizeConv :: a ->  Exp Word32

instance ASize Word32 where
  sizeConv = fromIntegral

instance ASize (Exp Word32) where
  sizeConv = id 


---------------------------------------------------------------------------
-- Shapes (Only 1,2 and 3d)  || EXPERIMENTAL || 
---------------------------------------------------------------------------


data ZERO  = ZERO
data ONE   = ONE
data TWO   = TWO
data THREE = THREE

data Dynamic s = Dynamic (Dims s EWord32) 
data Static s  = Static  (Dims s Word32)

class Dimensions d where
  type Elt d 
  dims :: d dim -> Dims dim (Elt d) 

  extents :: d dim -> Dims dim EW32
  
  modify :: Dims dim2 (Elt d) -> d dim -> d dim2 

instance Dimensions Dynamic where
  type Elt Dynamic = EW32
  dims (Dynamic s) = s

  extents (Dynamic s) = s 

  modify s1 (Dynamic s) = Dynamic s1

instance Dimensions Static where
  type Elt Static = Word32

  dims (Static s) = s
  
  extents (Static (Dims1 a)) = Dims1 (fromIntegral a)
  extents (Static (Dims2 a b)) = Dims2 (fromIntegral a) (fromIntegral b)
  extents (Static (Dims3 a b c)) = Dims3 (fromIntegral a) (fromIntegral b) (fromIntegral c)
  extents (Static (Dims0)) = Dims0
  
  modify s1 (Static s) = Static s1
  
data Dims b a where
  Dims0 :: Dims ZERO a
  Dims1 :: a -> Dims ONE a 
  Dims2 :: a -> a -> Dims TWO a
  Dims3 :: a -> a -> a -> Dims THREE a

size :: ASize a => Dims b a -> a 
size (Dims0) = 1
size (Dims1 x) = x
size (Dims2 x y) = x * y
size (Dims3 x y z) = x * y * z

data Index b where
  Ix0 :: Index ZERO
  Ix1 :: EW32 -> Index ONE
  Ix2 :: EW32 -> EW32 -> Index TWO
  Ix3 :: EW32 -> EW32 -> EW32 -> Index THREE 

data Pull2 q d a = Pull2 (q d) (Index d -> a)

class MultiDim d1 where
  extractRow   :: Dimensions q => EW32 -> Pull2 q d1 a -> Pull2 q ONE a   
  extractCol   :: Dimensions q => EW32 -> Pull2 q d1 a -> Pull2 q ONE a  
  extractPlane :: Dimensions q => EW32 -> Pull2 q d1 a -> Pull2 q TWO a 

instance MultiDim TWO where
  extractRow r (Pull2 d ixf) = Pull2 d' (\(Ix1 i) -> ixf (Ix2 i r)) 
    where (Dims2 x y) = dims d
          d' = modify (Dims1 x) d
  extractCol c (Pull2 d ixf) = Pull2 d' (\(Ix1 i) -> ixf (Ix2 c i))
    where (Dims2 x y) = dims d
          d' = modify (Dims1 y) d

  extractPlane p arr = arr 
      

-- instance MultiDim THREE 



data Push2 d s t a = Push2 (d s) ((Index s ->  a -> Program Thread ()) -> Program t ()) 

rev2 :: Dimensions d => Pull2 d ONE a -> Pull2 d ONE a
rev2 (Pull2 ds ixf) = Pull2 ds (\(Ix1 i) -> (ixf (Ix1 (n - 1 - i))))
  where
    (Dims1 n) = extents ds 

---------------------------------------------------------------------------
-- Push and Pull arrays
---------------------------------------------------------------------------
-- | Push array. Parameterised over Program type and size type.
data Push p s a =
  Push s ((a -> EWord32 -> TProgram ()) -> Program p ())

-- | Pull array.
data Pull s a = Pull {pullLen :: s, 
                      pullFun :: EWord32 -> a}

-- | Create a push array. 
mkPush :: s
       -> ((a -> EWord32 -> TProgram ()) -> Program t ())
       -> Push t s a
mkPush n p = Push n p 

-- | Create a pull array. 
mkPull n p = Pull n p 

-- Fix this.
--   * you cannot safely resize either push or pull arrays
--   * you can shorten pull arrays safely.  
setSize :: l -> Pull l a -> Pull l a
setSize n (Pull _ ixf) = mkPull n ixf

---------------------------------------------------------------------------
-- Array Class 
---------------------------------------------------------------------------
class ArrayLength a where
  -- | Get the length of an array.
  len :: a s e -> s

instance ArrayLength Pull where
  len    (Pull n ixf) = n

instance ArrayLength (Push t) where
  len  (Push s p) = s

class Array a where
  -- | Array of consecutive integers
  iota      :: ASize s => s -> a s EWord32
  -- | Create an array by replicating an element. 
  replicate :: ASize s => s -> e -> a s e 

  -- | Map a function over an array. 
  aMap      :: (e -> e') -> a s e -> a s e'
  -- | Perform arbitrary permutations (dangerous). 
  ixMap     :: (EWord32 -> EWord32)
               -> a s e -> a s e
  -- -- | Reduce an array using a provided operator. 
  -- fold1     :: (e -> e -> e) -> a Word32 e -> a Word32 e  

  -- would require Choice !
  -- | Append two arrays. 
  append    :: (ASize s, Choice e) => a s e -> a s e -> a s e 
  
  -- technicalities
  -- | Statically sized array to dynamically sized array.
  toDyn     :: a Word32 e -> a EW32 e
  -- | Dynamically sized array to statically sized array. 
  fromDyn   :: Word32 -> a EW32 e -> a Word32 e 
  
instance Array Pull where
  iota   s = Pull s $ \ix -> ix 
  replicate s e = Pull s $ \_ -> e

  aMap   f (Pull n ixf) = Pull n (f . ixf)
  ixMap  f (Pull n ixf) = Pull n (ixf . f) 

  append a1 a2 = Pull (n1+n2)
               $ \ix -> ifThenElse (ix <* (sizeConv n1)) 
                       (a1 ! ix) 
                       (a2 ! (ix - (sizeConv n1)))
    where 
      n1 = len a1
      n2 = len a2 

  -- technicalities
  toDyn (Pull n ixf) = Pull (fromIntegral n) ixf
  fromDyn n (Pull _ ixf) = Pull n ixf 
   
  
instance Array (Push t) where
  iota s = Push s $ \wf ->
    do
      forAll (sizeConv s) $ \ix -> wf ix ix 
  replicate s e = Push s $ \wf ->
    do
      forAll (sizeConv s) $ \ix -> wf e ix 
  aMap   f (Push s p) = Push s $ \wf -> p (\e ix -> wf (f e) ix)
  ixMap  f (Push s p) = Push s $ \wf -> p (\e ix -> wf e (f ix))

  -- unfortunately a Choice constraint. 
  append p1 p2  =
    Push (n1 + n2) $ \wf ->
      do p1 <: wf
         p2 <: \a i -> wf a (sizeConv n1 + i) 
           where 
             n1 = len p1
             n2 = len p2 

   -- technicalities
  toDyn (Push n p) = Push (fromIntegral n) p 
  fromDyn n (Push _ p) = Push n p 
 

---------------------------------------------------------------------------
-- Functor instance Pull/Push arrays
---------------------------------------------------------------------------
instance Array arr => Functor (arr w) where 
  fmap = aMap

---------------------------------------------------------------------------
-- Pushable
---------------------------------------------------------------------------
class Pushable t where
  push :: ASize s => Pull s e -> Push t s e 

instance Pushable Thread where
  push (Pull n ixf) =
    Push n $ \wf -> seqFor (sizeConv n) $ \i -> wf (ixf i) i

instance Pushable Warp where
  push (Pull n ixf) =
    Push n $ \wf ->
      forAll (sizeConv n) $ \i -> wf (ixf i) i

instance Pushable Block where
  push (Pull n ixf) =
    Push n $ \wf ->
      forAll (sizeConv n) $ \i -> wf (ixf i) i

instance Pushable Grid where
  push (Pull n ixf) =
    Push n $ \wf ->
      forAll (sizeConv n) $ \i -> wf (ixf i) i 
  
-- class PushableN t where
--   pushN :: ASize s => Word32 -> Pull s e -> Push t s e

-- instance PushableN Block where
--   pushN n (Pull m ixf) =
--     Push m $ \ wf -> forAll (sizeConv (m `div` fromIntegral n)) $ \tix ->
--     warpForAll 1 $ \_ -> 
--     seqFor (fromIntegral n) $ \ix -> wf (ixf (tix * fromIntegral n + ix))
--                                              (tix * fromIntegral n + ix) 
 
-- instance PushableN Grid where
--   pushN n (Pull m ixf) =
--     Push m $ \ wf -> forAll (sizeConv (m `div` fromIntegral n)) $ \bix ->
--     forAll (fromIntegral n) $ \tix -> wf (ixf (bix * fromIntegral n + tix))
--                                               (bix * fromIntegral n + tix) 

--------------------------------------------------------------------------
-- Indexing, array creation.
---------------------------------------------------------------------------

pushApp (Push _ p) a = p a

infixl 9 <:
(<:) :: Push t s a
        -> (a -> EWord32 -> Program Thread ())
        -> Program t ()
(<:) = pushApp 

infixl 9 ! 
(!) :: Pull s e -> Exp Word32 -> e 
(!) arr = pullFun arr 


