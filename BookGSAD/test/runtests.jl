using BookGSAD
using Test

# define shortcut to module 
M = BookGSAD

@testset "Slow Reference Implementations" begin
    include("test-slow_reference.jl")
end

@testset "Rank and Select" begin
    include("test-bitvec.jl")
end
