module GSAD

#= =#

const WIDTH_BLOCK = 256
const WIDTH_CHUNK = 64
const CHUNKS_PER_BLOCK = 4

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
    MappedBitVector,
    MappedBitVectorLayout,
    # methods:
    rank1,
    select1

end # module GSAD
