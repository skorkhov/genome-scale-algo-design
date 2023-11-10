module GSAD

include("intro.jl")
include("slow_reference.jl")
include("bitvec.jl")

# exports:
export 
    # types:
    IdxBitVector, 
    # methods:
    rank1,
    select1

end # module GSAD
