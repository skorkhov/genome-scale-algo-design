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

@testset "rank1(::RankedBitVector, ...)" TestUtils.test_rank1(RankedBitVector)
@testset "rank1(::RankedBitVector, ...) mem-intensive" TestUtils.test_rank1_memlimit(RankedBitVector)
@testset "select1(::RankedBitVector, ...)" TestUtils.test_select1(RankedBitVector)


#= MappedBitVector =#

@testset "MappedBitVectorLayout()" begin
    # basic generator on a short vector: 
    bv = TestUtils.make_bitvec_small(BitVector)
    layout = MappedBitVectorLayout(bv)
    @test layout.pop == UInt64(4)
    @test layout.segpos == UInt64[1]
    @test layout.is_dense == RankedBitVector(BitVector([0]))
    @test layout.subsegpos == Matrix{UInt32}(undef, (0, 0))
    @test layout.is_ddense == RankedBitVector(BitVector())

    # D + S[one element]
    bv = trues(4096 + 1)
    layout = MappedBitVectorLayout(bv)
    @test layout.pop == UInt64(4096 + 1)
    @test layout.is_dense == RankedBitVector(BitVector([1, 0]))
    @test layout.segpos == UInt64[1, 4097]
    @test layout.is_ddense == RankedBitVector(trues(512))
    @test layout.subsegpos == reshape([1:8:4096...], (512, 1))

    # multiple D segments: 
    bv = trues(4096 * 2)
    layout = MappedBitVectorLayout(bv)
    @test layout.pop == UInt64(4096 * 2)
    @test layout.is_dense == RankedBitVector(BitVector([1, 1]))
    @test layout.segpos == UInt64[1, 4097]
    @test layout.is_ddense == RankedBitVector(trues(1024))
    @test layout.subsegpos == hcat([1:8:4096...], [1:8:4096...])

    # D: Ds x 512
    bv_subseg_Ds = BitVector([i % 5 == 1 for i in 1:40])
    bv = repeat(bv_subseg_Ds, 512)
    layout = MappedBitVectorLayout(bv)
    @test layout.pop == UInt64(4096)
    @test layout.is_dense == RankedBitVector(BitVector([1]))
    @test layout.segpos == UInt64[1]
    @test layout.is_ddense == RankedBitVector(falses(512))
    # subsegpos: 
    exp = UInt32[1 + 40i for i in 0:(512 - 1)]
    @test layout.subsegpos == reshape(exp, (512, 1))

    # D: alternating Dd/Ds
    bv_subseg_Ds = BitVector([i % 5 == 1 for i in 1:40])
    bv_subseg_Dd = trues(8)
    bv_seg_D_mixed = repeat([bv_subseg_Dd; bv_subseg_Ds], div(4096, 8 * 2))
    bv = bv_seg_D_mixed
    layout = MappedBitVectorLayout(bv)
    @test layout.pop == UInt64(4096)
    @test layout.is_dense == RankedBitVector(BitVector([1]))
    @test layout.segpos == UInt64[1]
    @test layout.is_ddense == RankedBitVector(BitVector([i % 2 == 1 for i in 1:512]))
    # subsegpos: 
    # alternating chunks of 8+40 bits long (Dd+Ds, up to a whole seg)
    exp = vcat([[1, 9] .+ 48 * i for i in 0:255]...)
    @test layout.subsegpos == reshape(exp, (512, 1))

    # Dd + S + D(d/s)
    bv_subseg_Ds = BitVector([i % 5 == 1 for i in 1:40])
    bv_subseg_Dd = trues(8)
    bv_seg_D_mixed = repeat([bv_subseg_Dd; bv_subseg_Ds], div(4096, 8 * 2))
    bv_seg_S = [trues(4095); falses(64^4 - 4096); trues(1)]
    bv = [
        trues(4096); 
        bv_seg_S; 
        bv_seg_D_mixed
    ]
    layout = MappedBitVectorLayout(bv)
    @test layout.pop == UInt64(4096 * 3)
    @test layout.is_dense == RankedBitVector(BitVector([1, 0, 1]))
    @test layout.segpos == UInt64[1, 4097, 4096 + 64^4 + 1]
    @test layout.is_ddense == RankedBitVector([trues(512); [i % 2 == 1 for i in 1:512]])
    exp = hcat(
        [1:8:4096...], 
        vcat([[1, 9] .+ 48 * i for i in 0:255]...)
    )
    @test layout.subsegpos == exp

    # all bits are 0: 
    bv = falses(4096 * 2)
    layout = MappedBitVectorLayout(bv)
    @test layout.pop == UInt64(0)
    @test layout.segpos == UInt64[]
    @test layout.is_dense == RankedBitVector(BitVector())
    @test layout.subsegpos == Matrix{UInt32}(undef, (0, 0))
    @test layout.is_ddense == RankedBitVector(BitVector())
end

@testset "MappedID(::MappedBitVectorLayout, j)" begin
    # S segment: 
    bv = falses(4096)
    bv[2000] = 1
    layout = MappedBitVectorLayout(bv)
    res = GSAD.MappedID(layout, 1)
    @test res.segment == GSAD.InIntervalID(1, 0, 1, 2000, false)
    @test res.subsegment == GSAD.InIntervalID()

    # D segment
    bv = trues(4096)
    layout = MappedBitVectorLayout(bv)
    res = GSAD.MappedID(layout, 1)
    @test res.segment == GSAD.InIntervalID(1, 1, 1, 1, true)
    @test res.subsegment == GSAD.InIntervalID(1, 1, 1, 1, true)
    res = GSAD.MappedID(layout, 9)
    @test res.segment == GSAD.InIntervalID(1, 1, 9, 1, true)
    @test res.subsegment == GSAD.InIntervalID(2, 2, 1, 9, true)
    res = GSAD.MappedID(layout, 11)
    @test res.segment == GSAD.InIntervalID(1, 1, 11, 1, true)
    @test res.subsegment == GSAD.InIntervalID(2, 2, 3, 9, true)

    # D + S segments:
    bv = [trues(4096); falses(4089); trues(1); falses(6)]
    layout = MappedBitVectorLayout(bv)
    res = GSAD.MappedID(layout, 4096 + 1)
    @test res.segment == GSAD.InIntervalID(2, 1, 1, 4096 + 4090, false)
    @test res.subsegment == GSAD.InIntervalID()

    # multiple D segments:
    bv = trues(4096 * 2)
    layout = MappedBitVectorLayout(bv)
    # in 1st segment:
    res = GSAD.MappedID(layout, 2000 + 1)
    @test res.segment == GSAD.InIntervalID(1, 1, 2001, 1, true)
    @test res.subsegment == GSAD.InIntervalID(251, 251, 1, 2001, true)
    # in 2nd segment: 
    res = GSAD.MappedID(layout, 4096 + 1)
    @test res.segment == GSAD.InIntervalID(2, 2, 1, 4097, true)
    @test res.subsegment == GSAD.InIntervalID(513, 513, 1, 1, true)

    # Dd + S + D(d/s)
    bv_subseg_Ds = BitVector([i % 5 == 1 for i in 1:40])
    bv_subseg_Dd = trues(8)
    bv_seg_D_mixed = repeat([bv_subseg_Dd; bv_subseg_Ds], div(4096, 8 * 2))
    bv_seg_S = [trues(4095); falses(64^4 - 4096); trues(1)]
    bv = [
        trues(4096); 
        bv_seg_S; 
        bv_seg_D_mixed
    ]
    layout = MappedBitVectorLayout(bv)
    # test:
    # edge case showing up for the last subsegment of the DS;
    # test last-1:
    res = GSAD.MappedID(layout, 4096 + 4096 + 4096 - 8 - 7)
    @test res.segment == GSAD.InIntervalID(3, 2, 4096 - 8 - 7, 4096 + 64^4 + 1, true)
    @test res.subsegment == GSAD.InIntervalID(1023, 512 + 256, 1, length(bv_seg_D_mixed) - 39 - 8, true)
    # test last: 
    res = GSAD.MappedID(layout, 4096 + 4096 + 4096 - 7)
    @test res.segment == GSAD.InIntervalID(3, 2, 4096 - 7, 4096 + 64^4 + 1, true)
    @test res.subsegment == GSAD.InIntervalID(1024, 512 + 256, 1, length(bv_seg_D_mixed) - 39, false)

    # all bits are 0:
    bv = falses(4096 * 2)
    layout = MappedBitVectorLayout(bv)
    @test_throws BoundsError GSAD.MappedID(layout, 1)
end


@testset "iterate(::MappedBitVectorLayout, ...)" begin
    bv = falses(4096)
    bv[2000] = 1
    layout = MappedBitVectorLayout(bv)
    res = GSAD.iterate(layout)
    exp = GSAD.MappedID(layout, 1)
    @test res == exp

    # D + S segments:
    bv = [trues(4096); falses(4089); trues(1); falses(6)]
    layout = MappedBitVectorLayout(bv)
    # iterate through segments: 
    res = GSAD.iterate(layout)
    exp = GSAD.MappedID(layout, 1)
    @test res == exp
    res = GSAD.iterate(layout, exp)
    exp = GSAD.MappedID(layout, 9)
    @test res == exp
    # iterate at the end: 
    res = GSAD.iterate(layout, 4090)
    exp = GSAD.MappedID(layout, 4097)
    @test res == exp
    res = GSAD.iterate(layout, exp)
    @test res === nothing

    # all bits are 0:
    bv = falses(4096 * 2)
    layout = MappedBitVectorLayout(bv)
    res = GSAD.iterate(layout)
    @test res === nothing
end

@testset "start_of(::MappedID)" begin
    bv_sparse = [trues(4095); falses(64^4 - 4096); trues(1)]
    # D + S + D segments:
    bv = [
        trues(4096); 
        bv_sparse; 
        trues(2048 + 1); falses(2045); trues(2048 - 1)
    ]
    layout = MappedBitVectorLayout(bv)

    # last subseg in D1:
    id = GSAD.MappedID(layout, 4096)
    @test GSAD.start_of(id) == 4096 - 8 + 1
    # last subseg in S:
    id = GSAD.MappedID(layout, 4096 + 4096)
    @test GSAD.start_of(id) == 4096 + 1
    # first subseg in D2:
    id = GSAD.MappedID(layout, 4096 + 4096 + 1)
    @test GSAD.start_of(id) == 4096 + 64^4 + 1
    # mid+1 subseg in D2:
    id = GSAD.MappedID(layout, 4096 + 4096 + 2048 + 1)
    @test GSAD.start_of(id) == 4096 + 64^4 + 2048 + 1
end

@testset "MappedBitVector()" begin
    # D + S + D segments:
    bv_sparse = [trues(4095); falses(64^4 - 4096); trues(1)]
    bv = [
        trues(4096); 
        bv_sparse; 
        trues(2048 + 1); falses(2045); trues(2048 - 1)
    ]
    res = MappedBitVector(bv)
    @test res.bits == bv
    # @test res.layout == MappedBitVectorLayout(bv)  # TODO: implement equality
    @test res.Ss == reshape([1:4095..., 64^4], (4096, 1))
    @test res.Ds == reshape([1; 2046 .+ [1:7...]], (8, 1))

    # Dd + S + D(d/s)
    bv_subseg_Ds = BitVector([i % 5 == 1 for i in 1:40])
    bv_subseg_Dd = trues(8)
    bv_seg_D_mixed = repeat([bv_subseg_Dd; bv_subseg_Ds], div(4096, 8 * 2))
    bv_seg_S = [trues(4095); falses(64^4 - 4096); trues(1)]
    bv = [
        trues(4096); 
        bv_seg_S; 
        bv_seg_D_mixed
    ]
    res = MappedBitVector(bv)
    @test res.bits == bv
    @test res.Ss == reshape([1:4095..., 64^4], (4096, 1))
    @test res.Ds == reshape(
        repeat([1 + 5i for i in 0:7], 256), 
        (8, 256)
    )
end

@testset "select1(::MappedBitVector, j)" begin
    # Dd + S + D(d/s)
    bv_subseg_Ds = BitVector([i % 5 == 1 for i in 1:40])
    bv_subseg_Dd = trues(8)
    bv_seg_D_mixed = repeat([bv_subseg_Dd; bv_subseg_Ds], div(4096, 8 * 2))
    bv_seg_S = [trues(4095); falses(64^4 - 4096); trues(1)]
    bv = MappedBitVector([trues(4096); bv_seg_S; bv_seg_D_mixed])
    @test select1(bv, 4096) == 4096
    @test select1(bv, 4096 + 4095) == 4096 + 4095
    @test select1(bv, 4096 + 4096) == 4096 + 64^4
    @test select1(bv, 4096 + 4096 + 4096) == 4096 + 64^4 + length(bv_seg_D_mixed) - 4

    # test bounds error:
    @test_throws BoundsError select1(bv, 4096 * 3 + 1)
end



