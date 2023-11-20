using GSAD
using Test

# define shortcut to module 
M = GSAD

@testset "Slow Reference Implementations" begin
    include("test-reference.jl")
end

@testset "bit utils" begin
    include("test-bitutils.jl")
end

@testset "IdxBitVector()" begin
    include("test-IdxBitVector.jl")
end

@testset "CachedBitVector()" begin
    include("test-CachedBitVector.jl")
end

@testset "rank(::T) and select(::T) where T <: Bit Vector" begin
    include("test-bitvec-ops.jl")
end
