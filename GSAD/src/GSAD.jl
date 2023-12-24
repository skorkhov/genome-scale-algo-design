module GSAD

#= =#

const WIDTH_BLOCK = 256
const WIDTH_CHUNK = 64
const CHUNKS_PER_BLOCK = 4

"Supertype for one-dimensional bitvectors with fast rank()."
abstract type AbstractRankedBitVector <: AbstractVector{Bool} end

"Supertype for one-dimensional bitvectors with fast select()."
abstract type AbstractMappedBitVector <: AbstractVector{Bool} end

include("intro.jl")
include("reference.jl")
include("bitutils.jl")
include("rank.jl")
include("bitcache.jl")
include("select.jl")
include("show.jl")

# exports:
export 
    # types:
    RankedBitVector, 
    BitCache64,
    CachedBitVector,
    MappedBitVector,
    MappedBitVectorLayout,
    SelectBitVector,
    # methods:
    rank,
    select

end # module GSAD
