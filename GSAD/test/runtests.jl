using GSAD
using Test
using Random

#= test calls =#

@testset "Slow Reference Implementations" include("test-reference.jl")
@testset "bit utils" include("test-bitutils.jl")
@testset "IdxBitVector" include("test-bitvec.jl")
@testset "CachedBitVector" include("test-bitcache.jl")
