module GSAD

include("intro.jl")
include("slow_reference.jl")
include("bitvec.jl")
include("bitcache.jl")

# exports:
export 
    # types:
    IdxBitVector, 
    BitCache64,
    # methods:
    rank1,
    select1

end # module GSAD
