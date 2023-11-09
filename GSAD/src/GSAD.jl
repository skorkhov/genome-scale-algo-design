module GSAD

include("intro.jl")
include("slow_reference.jl")
include("bitvec.jl")

# exports:
export 
    # slow reference methods: 
    rank_slow,
    # types:
    IdxBitVector, 
    # methods:
    rank1,
    select1

end # module GSAD
