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
end

@testset "rank1(::RankedBitVector, ...)" TestUtils.test_rank1(RankedBitVector)
@testset "rank1(::RankedBitVector, ...) mem-intensive" TestUtils.test_rank1_memlimit(RankedBitVector)
@testset "select1(::RankedBitVector, ...)" TestUtils.test_select1(RankedBitVector)


#= MappedBitVector =#

@testset "MappedBitVectorLayout()" begin
    # basic generator on a short vector: 
    bv = TestUtils.make_bitvec_small(BitVector)
    layout = MappedBitVectorLayout(bv)
    @test layout.segpos == UInt64[1]
    @test layout.is_dense == RankedBitVector(BitVector([0]))
    @test layout.subsegpos == Matrix{UInt32}(undef, (0, 0))
    @test layout.is_ddense == RankedBitVector(BitVector())

    bv = trues(4096 + 1)
    layout = MappedBitVectorLayout(bv)
    @test layout.is_dense == RankedBitVector(BitVector([1, 0]))
    @test layout.segpos == UInt64[1, 4097]
    @test layout.is_ddense == RankedBitVector(trues(512))
    @test layout.subsegpos == reshape(UInt32[1:8:4096...], (1, 512))
end


