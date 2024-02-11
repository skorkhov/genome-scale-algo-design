using GSAD
using Test
using Random

#= test calls =#

@testset "Slow Reference Implementations" include("test-reference.jl")
@testset "bit utils" include("test-bitutils.jl")
@testset "BitVectorRA" include("test-rank.jl")
@testset "CachedBitVector" include("test-bitcache.jl")
@testset "BitVectorSA" include("test-select.jl")
@testset "Search Trees" include("test-bst.jl")

