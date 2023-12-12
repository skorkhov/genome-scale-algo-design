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
    @test layout.subsegpos == reshape(UInt32[1:8:4096...], (512, 1))

    # multiple D segments: 
    bv = trues(4096 * 2)
    layout = MappedBitVectorLayout(bv)
    @test layout.is_dense == RankedBitVector(BitVector([1, 1]))
    @test layout.segpos == UInt64[1, 4097]
    @test layout.is_ddense == RankedBitVector(trues(1024))
    @test layout.subsegpos == reshape(UInt32[1:8:8192...], (512, 2))

end


@testset "locate_in_segment(::MappedBitVectorLayout, j)" begin
    # sparse segment: 
    bv = falses(4096); bv[2000] = 1
    layout = MappedBitVectorLayout(bv)
    res = GSAD.locate_in_segment(layout, 1)
    @test res == (false, false, 2000, 1, 1)
    
    bv = trues(4096)
    layout = MappedBitVectorLayout(bv)
    res = GSAD.locate_in_segment(layout, 1)
    @test res == (true, true, 1, 1, 1)

    bv = trues(4096)
    layout = MappedBitVectorLayout(bv)
    res = GSAD.locate_in_segment(layout, 9)
    @test res == (true, true, 9, 2, 1)
    res = GSAD.locate_in_segment(layout, 11)
    @test res == (true, true, 9, 2, 3)

    bv = [trues(4096); falses(4089); trues(1); falses(6)]
    layout = MappedBitVectorLayout(bv)
    res = GSAD.locate_in_segment(layout, 4097)
    @test res == (false, false, 4096 + 4090, 1, 1)

    # multiple D segments:
    bv = trues(4096 * 2)
    layout = MappedBitVectorLayout(bv)
    res = GSAD.locate_in_segment(layout, 4096 + 1)
    @test res == (true, true, 4097, 513, 1)
    res = GSAD.locate_in_segment(layout, 4096 + 5)
    @test res == (true, true, 4097, 513, 5)
end


