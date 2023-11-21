using GSAD
using Test
using Random

#= test util functions =#

function make_bitvec_small(::Type{T}) where T
    bitvector = BitVector([1, 1, 1, 0, 0, 1, 0, 0])
    T(bitvector)
end

function make_bitvec_medium(::Type{T}) where T
    Random.seed!(1)
    bitvector = bitrand(257)
    T(bitvector)
end

function make_bitvec_5chunk(::Type{T}) where T
    # bitvector long enough to grab all chunks: 
    s1 = [BitVector([1, 1, 0, 1, 1, 0]); falses(58)]
    s2 = [BitVector([0, 0, 1]); falses(61)]
    s5 = BitVector([0, 0, 0, 1])
    bitvector = [s1; s2; falses(64); falses(64); s5]
    T(bitvector)
end

#= 
for bitvectors beyond len=2^32, 
both long and short cache slots have to be used to store long cache val;
handling of that values needs to be tested
=#
function make_bitvec_memlimit(::Type{T}) where T
    len = 2^32 + 3
    bitvector = trues(len)
    T(bitvector)
end

function make_bitrand(::Type{T}, n::Integer) where T
    Random.seed!(1)
    bitvector = bitrand(n)
    T(bitvector)
end


#= test calls =#

@testset "Slow Reference Implementations" include("test-reference.jl")
@testset "bit utils" include("test-bitutils.jl")
@testset "IdxBitVector()" include("test-IdxBitVector.jl")
@testset "rank() and select()" include("test-bitvec-ops.jl")
@testset "CachedBitVector()" include("test-CachedBitVector.jl")
