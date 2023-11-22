using Random
using Test
using GSAD

include("TestUtils.jl")


#= test constructor and type utils =#

@testset "RankedBitVector()" begin
    bitvector = BitVector([1, 0, 0])
    v = RankedBitVector(bitvector)
    @test v.bits === bitvector
    @test v.chunks == Int8[0]
    @test v.blocks == Int32[0]

    v = TestUtils.make_bitvec_5chunk(RankedBitVector)
    @test length(v.chunks) == cld(length(v), GSAD.WIDTH_CHUNK)
    @test length(v.blocks) == cld(length(v), GSAD.WIDTH_BLOCK)
    chunks = UInt8[0, 4, 5, 5, 0]
    blocks = UInt32[0, 5]
    @test v.chunks == chunks
    @test v.blocks == blocks
end


#= test rank() and select() =#

@testset "rank1(::RankedBitVector, ...)" TestUtils.test_rank1(RankedBitVector)
@testset "rank1(::RankedBitVector, ...) mem-intensive" TestUtils.test_rank1_memlimit(RankedBitVector)
@testset "select1(::RankedBitVector, ...)" TestUtils.test_select1(RankedBitVector)

