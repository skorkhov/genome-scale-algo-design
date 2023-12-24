using Random
using Test
using GSAD

include("TestUtils.jl")


#= RakedBitVector =#

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

    # test weird edge case: 
    bitvector = [trues(512); repeat(BitVector([1, 0]), 256)]
    v = RankedBitVector(bitvector)
    @test length(v.chunks) == cld(length(v), GSAD.WIDTH_CHUNK)
    @test length(v.blocks) == cld(length(v), GSAD.WIDTH_BLOCK)
    blocks = UInt32[0, 256, 512, 640]
    chunks = UInt8[
        0, 64, 128, 192, 0, 64, 128, 192,
        0, 32, 64, 96, 0, 32, 64, 96
    ]
    @test v.chunks == chunks
    @test v.blocks == blocks
end

@testset "rank(::RankedBitVector, ...)" TestUtils.test_rank(RankedBitVector)
@testset "rank(::RankedBitVector, ...) mem-intensive" TestUtils.test_rank_memlimit(RankedBitVector)
@testset "select(::RankedBitVector, ...)" TestUtils.test_select(RankedBitVector)
