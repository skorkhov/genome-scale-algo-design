module GSAD

#= =#

const BLOCK_WIDTH_SHORT = 64
const BLOCK_WIDTH_LONG = 256
const N_SHORT_PER_LONG = 4

include("intro.jl")
include("reference.jl")
include("bitutils.jl")
include("bitvec.jl")
include("bitcache.jl")

# exports:
export 
    # types:
    RankedBitVector, 
    BitCache64,
    CachedBitVector,
    # methods:
    rank1,
    select1

end # module GSAD
