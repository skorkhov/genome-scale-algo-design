module GSAD

include("intro.jl")
include("reference.jl")
include("bitutils.jl")
include("bitvec.jl")
include("bitcache.jl")

# exports:
export 
    # types:
    IdxBitVector, 
    BitCache64,
    CachedBitVector,
    # methods:
    rank1,
    select1

end # module GSAD
