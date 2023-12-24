using GSAD
using Test
using Random

#= test calls =#

@testset "Slow Reference Implementations" include("test-reference.jl")
@testset "bit utils" include("test-bitutils.jl")
@testset "RankedBitVector" include("test-rank.jl")
@testset "CachedBitVector" include("test-bitcache.jl")
@testset "SelectBitVector" include("test-select.jl")

