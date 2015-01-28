
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE PackageImports #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-} 

{-

   Joel Svensson 2013, 2014

-} 

module Obsidian.CodeGen.CompileIM where 

import Language.C.Quote hiding (Block)
import Language.C.Quote.CUDA as CU

import qualified Language.C.Quote.OpenCL as CL 

import qualified "language-c-quote" Language.C.Syntax as C 

import Obsidian.Exp (IExp(..),IBinOp(..),IUnOp(..))
import Obsidian.Types as T
import Obsidian.DimSpec 
import Obsidian.CodeGen.Program

import Data.Word

{- TODOs:
    
   * Pass a target "platform" to code generator.
      - CUDA
      - OpenCL
      - Sequential C
      - C with OpenMP ? 
   * rewrite some functions here to use  a reader monad. 



   * TODO: Make sure tid always has correct Value 
-} 

---------------------------------------------------------------------------
-- Platform
---------------------------------------------------------------------------
data Platform = PlatformCUDA
              | PlatformOpenCL
              | PlatformC

data Config = Config { configThreadsPerBlock :: Word32,
                       configSharedMem :: Word32}




---------------------------------------------------------------------------
-- compileExp (maybe a bad name)
---------------------------------------------------------------------------
compileExp :: IExp -> Exp 
compileExp (IVar name t) = [cexp| $id:name |]


-- TODO: Fix all this! 
compileExp (IBlockIdx X) = [cexp| $id:("bid")|] -- [cexp| $id:("blockIdx.x") |]
compileExp (IBlockIdx Y) = [cexp| $id:("blockIdx.y") |]
compileExp (IBlockIdx Z) = [cexp| $id:("blockIdx.z") |]

compileExp (IThreadIdx X) = [cexp| $id:("threadIdx.x") |]
compileExp (IThreadIdx Y) = [cexp| $id:("threadIdx.y") |]
compileExp (IThreadIdx Z) = [cexp| $id:("threadIdx.z") |]

compileExp (IBlockDim X) = [cexp| $id:("blockDim.x") |]
compileExp (IBlockDim Y) = [cexp| $id:("blockDim.y") |]
compileExp (IBlockDim Z) = [cexp| $id:("blockDim.z") |]

compileExp (IGridDim X) = [cexp| $id:("GridDim.x") |]
compileExp (IGridDim Y) = [cexp| $id:("GridDim.y") |]
compileExp (IGridDim Z) = [cexp| $id:("GridDim.z") |]

compileExp (IBool True) = [cexp|1|]
compileExp (IBool False) = [cexp|0|]
compileExp (IInt8 n) = [cexp| $int:(toInteger n) |]
compileExp (IInt16 n) = [cexp| $int:(toInteger n) |]
compileExp (IInt32 n) = [cexp| $int:(toInteger n) |]
compileExp (IInt64 n) = [cexp| $lint:(toInteger n) |]

compileExp (IWord8 n) = [cexp| $uint:(toInteger n) |]
compileExp (IWord16 n) = [cexp| $uint:(toInteger n) |]
compileExp (IWord32 n) = [cexp| $uint:(toInteger n) |]
compileExp (IWord64 n) = [cexp| $ulint:(toInteger n) |]

compileExp (IFloat n) = [cexp| $float:(toRational n) |]
compileExp (IDouble n) = [cexp| $double:(toRational n) |]

-- Implementing these may be a bit awkward
-- given there are no vector literals in cuda. 
compileExp (IFloat2 n m) = error "IFloat2 unhandled"
compileExp (IFloat3 n m l) = error "IFloat3 unhandled"
compileExp (IFloat4 n m l k) = error "IFloat4 unhandled"
compileExp (IDouble2 n m) = error "IDouble2 unhandled" 
compileExp (IInt8_2 n m) = error "FIXME"
compileExp (IInt8_3 n m k) = error "FIXME"
compileExp (IInt8_4 n m k l) = error "FIXME"
compileExp (IInt16_2 n m ) = error "FIXME"
compileExp (IInt16_3 n m k) = error "FIXME"
compileExp (IInt16_4 n m k l) = error "FIXME"
compileExp (IInt32_2 n m) = error "FIXME"
compileExp (IInt32_3 n m k) = error "FIXME"
compileExp (IInt32_4 n m k l) = error "FIXME"
compileExp (IInt64_2 n m) = error "FIXME"
compileExp (IInt64_3 n m k) = error "FIXME"
compileExp (IInt64_4 n m k l) = error "FIXME"
compileExp (IWord8_2 n m) = error "FIXME"
compileExp (IWord8_3 n m k) = error "FIXME"
compileExp (IWord8_4 n m k l) = error "FIXME"
compileExp (IWord16_2 n m ) = error "FIXME"
compileExp (IWord16_3 n m k) = error "FIXME"
compileExp (IWord16_4 n m k l) = error "FIXME"
compileExp (IWord32_2 n m) = error "FIXME"
compileExp (IWord32_3 n m k) = error "FIXME"
compileExp (IWord32_4 n m k l) = error "FIXME"
compileExp (IWord64_2 n m) = error "FIXME"
compileExp (IWord64_3 n m k) = error "FIXME"
compileExp (IWord64_4 n m k l) = error "FIXME"


compileExp (IIndex (i1,[e]) t) = [cexp| $(compileExp i1)[$(compileExp e)] |]
compileExp a@(IIndex (_,_) _) = error $ "compileExp: Malformed index expression " ++ show a

compileExp (ICond e1 e2 e3 t) = [cexp| $(compileExp e1) ? $(compileExp e2) : $(compileExp e3) |]

compileExp (IBinOp op e1 e2 t) = go op 
  where
    x = compileExp e1
    y = compileExp e2
    go IAdd = [cexp| $x + $y |]
    go ISub = [cexp| $x - $y |]
    go IMul = [cexp| $x * $y |]
    go IDiv = [cexp| $x / $y |]
    go IMod = [cexp| $x % $y |]
    go IEq = [cexp| $x == $y |]
    go INotEq = [cexp| $x !=  $y |]
    go ILt = [cexp| $x < $y |]
    go IGt = [cexp| $x > $y |]
    go IGEq = [cexp| $x >= $y |]
    go ILEq = [cexp| $x <=  $y |]
    go IAnd = [cexp| $x && $y |]
    go IOr = [cexp| $x  || $y |]
    go IPow = case t of
                Float ->  [cexp|powf($x,$y) |]
                Double -> [cexp|pow($x,$y)  |]
                _      -> error $ "IPow applied at wrong type" 
    go IBitwiseAnd = [cexp| $x & $y |]
    go IBitwiseOr = [cexp| $x | $y |]
    go IBitwiseXor = [cexp| $x ^ $y |]
    go IShiftL = [cexp| $x << $y |]
    go IShiftR = [cexp| $x >> $y |]
compileExp (IUnOp op e t) = go op
  where
    x = compileExp e
    go IBitwiseNeg = [cexp| ~$x|]
    go INot        = [cexp| !$x|]
    go IGetX       = [cexp| $x.x|]
    go IGetY       = [cexp| $x.y|]
    go IGetZ       = [cexp| $x.z|]
    go IGetW       = [cexp| $x.w|]
    
compileExp (IFunCall name es t) = [cexp| $fc |]
  where
    es' = map compileExp es
    fc  = [cexp| $id:(name)($args:(es')) |]

compileExp (ICast e t) = [cexp| ($ty:(compileType t)) $e' |]
  where
    e' = compileExp e

compileType :: T.Type -> C.Type
compileType (Int8) = [cty| typename int8_t |]
compileType (Int16) = [cty| typename int16_t |]
compileType (Int32) = [cty| typename int32_t |]
compileType (Int64) = [cty| typename int64_t |]
compileType (Word8) = [cty| typename uint8_t |]
compileType (Word16) = [cty| typename uint16_t |]
compileType (Word32) = [cty| typename uint32_t |]
compileType (Word64) = [cty| typename uint64_t |]
compileType (Float) = [cty| float |]
compileType (Double) = [cty| double |]

compileType (Vec2 Float) = [cty| float4|]
compileType (Vec3 Float) = [cty| float3|]
compileType (Vec4 Float) = [cty| float2|]

compileType (Vec2 Double) = [cty| double2|]

-- How does this interplay with my use of uint8_t etc. Here it is char!
compileType (Vec2 Int8) = [cty| char2|]
compileType (Vec3 Int8) = [cty| char3|]
compileType (Vec4 Int8) = [cty| char4|]
 
compileType (Vec2 Int16) = [cty| short2|]
compileType (Vec3 Int16) = [cty| short3|]
compileType (Vec4 Int16) = [cty| short4|]

compileType (Vec2 Int32) = [cty| int2|]
compileType (Vec3 Int32) = [cty| int3|]
compileType (Vec4 Int32) = [cty| int4|]

compileType (Vec2 Word8) = [cty| uchar2|]
compileType (Vec3 Word8) = [cty| uchar3|]
compileType (Vec4 Word8) = [cty| uchar4|]
 
compileType (Vec2 Word16) = [cty| ushort2|]
compileType (Vec3 Word16) = [cty| ushort3|]
compileType (Vec4 Word16) = [cty| ushort4|]

compileType (Vec2 Word32) = [cty| uint2|]
compileType (Vec3 Word32) = [cty| uint3|]
compileType (Vec4 Word32) = [cty| uint4|]


compileType (Shared t) = [cty| __shared__ $ty:(compileType t) |]
compileType (Pointer t) = [cty| $ty:(compileType t)* |]
compileType (Volatile t) =  [cty| volatile $ty:(compileType t)|]
compileType t = error $ "compileType: Not implemented " ++ show t

--compileType' (Volatile t) = [cty| volatile $ty:(compileType t)|] 
--compileType' t = compileType t 

{-

  Solve the volatile issue.
  When operating in a warp without syncs Add Volatile to pointers
  and only there!
  Need a way to convey this information all the way from the force functions
  down to the code generator.
  
  Also, Change code generation to declare names of pointers into
  shared memory at different types (that are used in the program)
    __shared__ uint8_t sbase[X]
    uint32_t *sbaseU32 = sbase;
    float *sbaseF = sbase;
  This changes how offsets are computed within code. May need names for each
  intermediate array used in the program
    __shared__ uint8_t sbase[X]
    uint32_t *arr1 = sbase;
    uint32_t *arr2 = (sbase + 16U); 
    float *arr3 = sbase;
    float *arr4 = (sbase + 4U); 
   

-} 

---------------------------------------------------------------------------
-- **     
-- Compile IM
-- ** 
--------------------------------------------------------------------------- 

-- newtype CInfo a = CInfo (State CInfoState a)
--                 deriving (Monad, MonadState CInfoState) 

-- data CInfoState = CInfoState { cInfoTid  :: (Bool,Exp),
--                                cInfoWarpID     :: (Bool,Exp),
--                                cInfoWarpIx     :: (Bool,Exp) } 
-- evalCInfo (CInfo s) = evalState s                     

---------------------------------------------------------------------------
-- Statement t to Stm
---------------------------------------------------------------------------


compileStm :: Platform -> Config -> Statement t -> [Stm]
compileStm p c (SAssign name [] e) =
   [[cstm| $(compileExp name) = $(compileExp e);|]]
compileStm p c (SAssign name [ix] e) = 
   [[cstm| $(compileExp name)[$(compileExp ix)] = $(compileExp e); |]]
compileStm p c (SAtomicOp name ix atop) = 
  case atop of
    AtInc -> [[cstm| atomicInc(&$(compileExp name)[$(compileExp ix)],0xFFFFFFFF); |]]
    AtAdd e -> [[cstm| atomicAdd(&$(compileExp name)[$(compileExp ix)],$(compileExp e));|]]
    AtSub e -> [[cstm| atomicSub(&$(compileExp name)[$(compileExp ix)],$(compileExp e));|]]
    AtExch e -> [[cstm| atomicExch(&$(compileExp name)[$(compileExp ix)],$(compileExp e));|]]

compileStm p c (SCond be im) = [[cstm| if ($(compileExp be)) { $stms:body } |]]
  where 
    body = compileIM p c im  -- (compileIM p c im)
compileStm p c (SSeqFor loopVar n im) = 
    [[cstm| for (int $id:loopVar = 0; $id:loopVar < $(compileExp n); ++$id:loopVar) 
              { $stms:body } |]]
-- end a sequential for loop with a sync (or begin).
-- Maybe only if the loop is on block level (that is across all threads)
--  __syncthreads();} |]]
  where
    body = compileIM p c im -- (compileIM p c im)


-- Just relay to specific compileFunction
compileStm p c a@(SForAll lvl n im) = compileForAll p c a

compileStm p c a@(SDistrPar lvl n im) = compileDistr p c a 

compileStm p c (SSeqWhile b im) =
  [[cstm| while ($(compileExp b)) { $stms:body}|]]
  where
    body = compileIM p c im 

compileStm p c SSynchronize 
  = case p of
      PlatformCUDA -> [[cstm| __syncthreads(); |]]
      PlatformOpenCL -> [[cstm| barrier(CLK_LOCAL_MEM_FENCE); |]]

compileStm _ _ (SAllocate _ _ _) = []
compileStm _ _ (SDeclare name t) = []

compileStm _ _ a = error  $ "compileStm: missing case "

---------------------------------------------------------------------------
-- DistrPar 
---------------------------------------------------------------------------
compileDistr :: Platform -> Config -> Statement t -> [Stm] 
compileDistr PlatformCUDA c (SDistrPar Block n im) =  codeQ ++ codeR
  -- New here is BLOCK virtualisation
  where
    cim = compileIM PlatformCUDA c im  -- ++ [[cstm| __syncthreads();|]]
    
    numBlocks = [cexp| $id:("gridDim.x") |]
    
    blocksQ = [cexp| $exp:(compileExp n) / $exp:numBlocks|]
    blocksR = [cexp| $exp:(compileExp n) % $exp:numBlocks|] 
    
    codeQ = [[cstm| for (int b = 0; b < $exp:blocksQ; ++b) { $stms:bodyQ }|]]
                
    bodyQ = [cstm| $id:("bid") = blockIdx.x * $exp:blocksQ + b;|] : cim  ++  
            [[cstm| bid = blockIdx.x;|],
             [cstm| __syncthreads();|]] -- yes no ? 
         
    codeR = [[cstm| bid = ($exp:numBlocks * $exp:blocksQ) + blockIdx.x;|], 
             [cstm| if (blockIdx.x < $exp:blocksR) { $stms:cim }|],
             [cstm| bid = blockIdx.x;|], 
             [cstm| __syncthreads();|]] -- yes no ? 
                    
-- Can I be absolutely sure that 'n' here is statically known ? 
-- I must look over the functions that can potentially create this IM. 
-- Can make a separate case for unknown 'n' but generate worse code.
-- (That is true for all levels)  
compileDistr PlatformCUDA c (SDistrPar Warp (IWord32 n) im) = codeQ  ++ codeR 
  -- Here the 'im' should be distributed over 'n'warps.
  -- 'im' uses a warpID variable to identify what warp it is.
  -- 'n' may be higher than the actual number of warps we have!
  -- So GPU warp virtualisation is needed. 
  where
    cim = compileIM PlatformCUDA c im

    nWarps   = fromIntegral $ configThreadsPerBlock c `div` 32
    numWarps = [cexp| $int:nWarps|] 

    warpsQ   = [cexp| $int:(n `div` nWarps)|]
    warpsR   = [cexp| $int:(n `mod` nWarps)|]
    
    codeQ = [[cstm| for (int w = 0; w < $exp:warpsQ; ++w) { $stms:bodyQ } |]]
    
    bodyQ = [cstm| warpID = (threadIdx.x / 32) * $exp:warpsQ + w;|] : cim ++
            --[cstm| warpID = w * $exp:warpsQ + (threadIdx.x / 32);|] : cim ++ 
            [[cstm| warpID = threadIdx.x / 32;|]] 

    codeR = case (n `mod` nWarps)  of 
             0 -> [] 
             n -> [[cstm| warpID = ($exp:numWarps * $exp:warpsQ)+ (threadIdx.x / 32);|],
                   [cstm| if (threadIdx.x / 32 < $exp:warpsR) { $stms:cim } |], 
                   [cstm| warpID = threadIdx.x / 32; |], 
                   [cstm| __syncthreads();|]]

---------------------------------------------------------------------------
-- ForAll is compiled differently for different platforms
---------------------------------------------------------------------------
compileForAll :: Platform -> Config -> Statement t -> [Stm]
compileForAll PlatformCUDA c (SForAll Warp  (IWord32 n) im) = codeQ ++ codeR
  where
    nt = 32

    q = n `div` nt
    r = n `mod` nt

    cim = compileIM PlatformCUDA c im 
    
    codeQ =
      case q of
        0 -> []
        1 -> cim
        n -> [[cstm| for ( int vw = 0; vw < $int:q; ++vw) { $stms:body } |], 
              [cstm| $id:("warpIx") = threadIdx.x % 32; |]]
              -- [cstm| __syncthreads();|]]
             where 
               body = [cstm|$id:("warpIx") = vw*$int:nt + (threadIdx.x % 32); |] : cim
               --body = [cstm|$id:("warpIx") = (threadIdx.x % 32) * q + vw; |] : cim

    codeR = 
      case r of 
        0 -> [] 
        n -> [[cstm| if ((threadIdx.x % 32) < $int:r) { 
                            $id:("warpIx") = $int:(q*32) + (threadIdx.x % 32);  
                            $stms:cim } |],
                  -- [cstm| __syncthreads();|],
                  [cstm| $id:("warpIx") = threadIdx.x % 32; |]]

compileForAll PlatformCUDA c (SForAll Block (IWord32 n) im) = goQ ++ goR 
  where
    cim = compileIM PlatformCUDA c im -- ++ [[cstm| __syncthreads();|]]
   
    nt = configThreadsPerBlock c 

    q  = n `quot` nt
    r  = n `rem`  nt 

    -- q is the number full "passes" needed to cover the iteration
    -- space given we have nt threads. 
    goQ =
      case q of
        0 -> []
        1 -> cim -- [cstm|$id:loopVar = threadIdx.x; |]:cim
            --do
            --  stm <- updateTid [cexp| threadIdx.x |]
            --  return $ [cstm| $id:loopVar = threadIdx.x; |] : cim 
        n -> [[cstm| for ( int i = 0; i < $int:q; ++i) { $stms:body } |], 
                                                     --  __syncthreads(); } |], 
              [cstm| $id:("tid") = threadIdx.x; |]]
          --    [cstm| __syncthreads();|]]
             where 
               body = [cstm|$id:("tid") =  i*$int:nt + threadIdx.x; |] : cim
   
    -- r is the number of elements left. 
    -- This generates code for when fewer threads are 
    -- needed than available. (some threads shut down due to the conditional). 
    goR = 
      case (r,q) of 
        (0,_) -> [] 
        --(n,0) -> [[cstm| if (threadIdx.x < $int:n) { 
        --                    $stms:cim } |]] 
        (n,m) -> [[cstm| if (threadIdx.x < $int:n) { 
                            $id:("tid") = $int:(q*nt) + threadIdx.x;  
                            $stms:cim } |], 
                  [cstm| $id:("tid") = threadIdx.x; |]]

compileForAll PlatformCUDA c (SForAll Grid n im) = error "compileForAll: Grid" -- cim
  -- The grid case is special. May need more thought
  -- 
  -- The problem with this case is that
  -- I need to come up with a blocksize (but without any guidance)
  -- from the programmer.
  -- Though! There is no way the programmer could provide any
  -- such info ... 
  where
    cim = compileIM PlatformCUDA c im

compileForAll PlatformC c (SForAll lvl (IWord32 n) im) = go
  where
    body = compileIM PlatformC c im 
    go  = [ [cstm| for (int i = 0; i <$int:n; ++i) { $stms:body } |] ] 
      

--------------------------------------------------------------------------- 
-- CompileIM to list of Stm 
--------------------------------------------------------------------------- 
compileIM :: Platform -> Config -> IMList a -> [Stm]
compileIM pform conf im = concatMap ((compileStm pform conf) . fst) im

---------------------------------------------------------------------------
-- Generate entire Kernel 
---------------------------------------------------------------------------
type Parameters = [(String,T.Type)]

compile :: Platform -> Config -> String -> (Parameters,IMList a) -> Definition
compile pform config kname (params,im)
  = go pform 
  where
    stms = compileIM pform config im
    
    ps = compileParams pform params
    go PlatformCUDA
      = [cedecl| extern "C" __global__ void $id:kname($params:ps) {$items:cudabody} |]
    go PlatformOpenCL
      = [CL.cedecl| __kernel void $id:kname($params:ps) {$stms:stms} |]
    go PlatformC
      = [cedecl| extern "C" void $id:kname($params:ps) {$items:cbody} |] 

    cudabody = (if (configSharedMem config > 0)
                -- then [BlockDecl [cdecl| extern volatile __shared__  typename uint8_t sbase[]; |]] 
                then [BlockDecl [cdecl| __shared__  typename uint8_t sbase[$uint:(configSharedMem config)]; |]] 
                else []) ++
                --[BlockDecl [cdecl| typename uint32_t tid = threadIdx.x; |]] ++
                --[BlockDecl [cdecl| typename uint32_t warpID = threadIdx.x / 32; |],
                --       BlockDecl [cdecl| typename uint32_t warpIx = threadIdx.x % 32; |]] ++
--                [BlockDecl [cdecl| typename uint32_t bid = blockIdx.x; |]] ++
               (if (usesGid im) 
                then [BlockDecl [cdecl| typename uint32_t gid = blockIdx.x * blockDim.x + threadIdx.x; |]]
                else []) ++ 
               (if (usesBid im) 
                then [BlockDecl [cdecl| typename uint32_t bid = blockIdx.x; |]]
                else []) ++ 
               (if (usesTid im) 
                then [BlockDecl [cdecl| typename uint32_t tid = threadIdx.x; |]]
                else []) ++
               (if (usesWarps im) 
                then  [BlockDecl [cdecl| typename uint32_t warpID = threadIdx.x / 32; |],
                       BlockDecl [cdecl| typename uint32_t warpIx = threadIdx.x % 32; |]] 
                else []) ++
                -- All variables used will be unique and can be declared 
                -- at the top level 
                concatMap declares im ++ 
                -- Not sure if I am using language.C correctly. 
                -- Maybe compileSTM should create BlockStms ?
                -- TODO: look how Nikola does it. 
                map BlockStm stms

    cbody = -- add memory allocation 
            map BlockStm stms

-- Declare variables. 
declares :: (Statement t,t) -> [BlockItem]
declares (SDeclare name t,_) = [BlockDecl [cdecl| $ty:(compileType t)  $id:name;|]]
declares (SCond _ im,_) = concatMap declares im 
declares (SSeqWhile _ im,_) = concatMap declares im
declares (SForAll _ _ im,_) = concatMap declares im
declares (SDistrPar _ _ im,_) = concatMap declares im
declares (SSeqFor _ _  im,_) = concatMap declares im
declares _ = []


--------------------------------------------------------------------------- 
-- Parameter lists for functions  (kernel head) 
---------------------------------------------------------------------------
compileParams :: Platform -> Parameters -> [Param]
compileParams PlatformOpenCL = map go
  where
    go (name,Pointer t) = [CL.cparam| global  $ty:(compileType t) $id:name |]
    go (name, t)        = [CL.cparam| $ty:(compileType t) $id:name |]

-- C or CUDA 
compileParams _ = map go
  where
    go (name,t) = [cparam| $ty:(compileType t) $id:name |]
 

---------------------------------------------------------------------------
-- Compile with shared memory arrays declared at top
---------------------------------------------------------------------------
-- CODE DUPLICATION FOR NOW

compileDeclsTop :: Platform -> Config -> [(String,((Word32,Word32),T.Type))] -> String -> (Parameters,IMList a) -> Definition
compileDeclsTop pform config toplevelarrs kname (params,im)
  = go pform 
  where
    stms = compileIM pform config im
    
    ps = compileParams pform params
    go PlatformCUDA
      = [cedecl| extern "C" __global__ void $id:kname($params:ps) {$items:cudabody} |]
    go PlatformOpenCL
      = [CL.cedecl| __kernel void $id:kname($params:ps) {$stms:stms} |]
    go PlatformC
      = [cedecl| extern "C" void $id:kname($params:ps) {$items:cbody} |] 

    cudabody = (if (configSharedMem config > 0)
                -- then [BlockDecl [cdecl| extern volatile __shared__  typename uint8_t sbase[]; |]] 
                then [BlockDecl [cdecl| __shared__  typename uint8_t sbase[$uint:(configSharedMem config)]; |]] 
                else []) ++
                --[BlockDecl [cdecl| typename uint32_t tid = threadIdx.x; |]] ++
                --[BlockDecl [cdecl| typename uint32_t warpID = threadIdx.x / 32; |],
                --       BlockDecl [cdecl| typename uint32_t warpIx = threadIdx.x % 32; |]] ++
--                [BlockDecl [cdecl| typename uint32_t bid = blockIdx.x; |]] ++
               (if (usesGid im) 
                then [BlockDecl [cdecl| typename uint32_t gid = blockIdx.x * blockDim.x + threadIdx.x; |]]
                else []) ++ 
               (if (usesBid im) 
                then [BlockDecl [cdecl| typename uint32_t bid = blockIdx.x; |]]
                else []) ++ 
               (if (usesTid im) 
                then [BlockDecl [cdecl| typename uint32_t tid = threadIdx.x; |]]
                else []) ++
               (if (usesWarps im) 
                then  [BlockDecl [cdecl| typename uint32_t warpID = threadIdx.x / 32; |],
                       BlockDecl [cdecl| typename uint32_t warpIx = threadIdx.x % 32; |]] 
                else []) ++
                -- declare all arrays used
                concatMap declareArr toplevelarrs ++
                -- All variables used will be unique and can be declared 
                -- at the top level 
                concatMap declares im ++ 
                -- Not sure if I am using language.C correctly. 
                -- Maybe compileSTM should create BlockStms ?
                -- TODO: look how Nikola does it. 
                map BlockStm stms

    cbody = -- add memory allocation 
            map BlockStm stms


declareArr :: (String, ((Word32,Word32),T.Type)) -> [BlockItem]
declareArr (arr,((_,addr),t)) =
  [BlockDecl [cdecl| $ty:(compileType t) $id:arr = ($ty:(compileType t))(sbase + $int:addr);|]]
