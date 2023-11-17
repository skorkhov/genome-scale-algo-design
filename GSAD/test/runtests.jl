using GSAD
using Test

# define shortcut to module 
M = GSAD

@testset "Slow Reference Implementations" begin
    include("test-slow_reference.jl")
end

@testset "Rank and Select" begin
    include("test-bitvec.jl")
end


@testset "BitCache" begin
    include("test-bitcache.jl")
end

