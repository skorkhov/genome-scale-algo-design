module GSAD

#= Const =#

# rank() constants:
const WIDTH_BLOCK::Int = 256
const WIDTH_CHUNK::Int = 64
const CHUNKS_PER_BLOCK::Int = 4

# select() constants:
const SEG_DENSE_MAXWIDTH::Int = 64^4
const SEG_POPULATION::Int = 64^2
const SUBSEG_DENSE_MAXWIDTH::Int = 64 / 2
const SUBSEG_POPULATION::Int = 8
const N_SUBSEG_PER_SEG::Int = SEG_POPULATION / SUBSEG_POPULATION

#= Types =# 

"Supertype for one-dimensional bitvectors with fast rank()."
abstract type AbstractBitVectorRA <: AbstractVector{Bool} end

"Supertype for one-dimensional bitvectors with fast select()."
abstract type AbstractBitVectorRSA <: AbstractVector{Bool} end


#= Code =#

include("intro.jl")
include("reference.jl")
include("bitutils.jl")
include("rank.jl")
include("bitcache.jl")
include("select.jl")
include("bst.jl")
include("editdist.jl")
include("show.jl")

# exports:
export 
    # types:
    BitVectorRA, 
    BitCache64,
    CachedBitVector,
    BitVectorRSA,
    BitVectorSA,
    VectorRMQ, TreeRMQ,
    # methods:
    rank,
    select,
    rmq, rmqi, rmqv
end # module GSAD
