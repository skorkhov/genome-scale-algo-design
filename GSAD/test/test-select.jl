# tests for select() data structure

using Random
using Test
using GSAD

include("TestUtils.jl")


#= SelectBitVector =#

@testset "partition(::Vector)" begin
    partition = GSAD.partition

    v = [1:10...]
    @test partition(v, 5) == [[1:5...], [6:10...]]
    @test partition(v, 3) == [[1:3...], [4:6...], [7:9...], [10]]
    @test partition(v, 11) == [[1:10...]]

    # test when vectors does not align with indexes:
    v = [11:20...]
    @test partition(v, 5) == [[11:15...], [16:20...]]
end

@testset "select(::SelectBitVector, j)" begin
    # Dd + S + D(d/s)
    bv_subseg_Ds = BitVector([i % 5 == 1 for i in 1:40])
    bv_subseg_Dd = trues(8)
    bv_seg_D_mixed = repeat([bv_subseg_Dd; bv_subseg_Ds], div(4096, 8 * 2))
    bv_seg_S = [trues(4095); falses(64^4 - 4096); trues(1)]
    bv = SelectBitVector([trues(4096); bv_seg_S; bv_seg_D_mixed])
    
    @test select(bv, 4096) == 4096
    @test select(bv, 4096 + 4095) == 4096 + 4095
    @test select(bv, 4096 + 4096) == 4096 + 64^4
    @test select(bv, 4096 + 4096 + 4096) == 4096 + 64^4 + length(bv_seg_D_mixed) - 4

    # test bounds error:
    @test_throws BoundsError select(bv, 4096 * 3 + 1)
end


#=  LayoutIntRank =#

@testset "LayoutIntRank" begin
    SegmentIntRank = GSAD.SegmentIntRank
    SubsegmentIntRank = GSAD.SubsegmentIntRank
    LayoutIntRank = GSAD.LayoutIntRank

    # Dd + S + D(d/s)
    bv_subseg_Ds = BitVector([i % 5 == 1 for i in 1:40])
    bv_subseg_Dd = trues(8)
    bv_seg_D_mixed = repeat([bv_subseg_Dd; bv_subseg_Ds], div(4096, 8 * 2))
    bv_seg_S = [trues(4095); falses(64^4 - 4096); trues(1)]
    bv = [trues(4096); bv_seg_S; bv_seg_D_mixed]

    layout = LayoutIntRank(bv)
    segments = map(
        SegmentIntRank, 
        [1, 4096 + 1, 4096 + 64^4 + 1],
        [1, 1, 2],
        [true, false, true]
    )
    subsegments = map(
        SubsegmentIntRank, 
        [[0:8:4095...]; vcat([[0, 8] .+ 48 * i for i in 0:255]...)], 
        [1:512...; 512 .+ repeat(1:256, inner = 2)], 
        [repeat([true], 512); repeat([true, false], 256)]
    )

    @test layout.segments == segments
    @test layout.subsegments == subsegments
end


#= MappedBitVector =#

@testset "MappedBitVectorLayout()" begin
    # basic generator on a short vector: 
    bv = TestUtils.make_bitvec_small(BitVector)
    layout = MappedBitVectorLayout(bv)
    @test layout.segpos == UInt64[1]
    @test layout.is_dense == RankedBitVector(BitVector([0]))
    @test layout.subsegpos == UInt32[]
    @test layout.is_ddense == RankedBitVector(BitVector())

    # D + S[one element]
    bv = trues(4096 + 1)
    layout = MappedBitVectorLayout(bv)
    @test layout.is_dense == RankedBitVector(BitVector([1, 0]))
    @test layout.segpos == UInt64[1, 4097]
    @test layout.is_ddense == RankedBitVector(trues(512))
    @test layout.subsegpos == UInt32[0:8:4095...]

    # multiple D segments: 
    bv = trues(4096 * 2)
    layout = MappedBitVectorLayout(bv)
    @test layout.is_dense == RankedBitVector(BitVector([1, 1]))
    @test layout.segpos == UInt64[1, 4097]
    @test layout.is_ddense == RankedBitVector(trues(1024))
    @test layout.subsegpos == UInt32[[0:8:4095...]; [0:8:4095...]]

    # D: Ds x 512
    bv_subseg_Ds = BitVector([i % 5 == 1 for i in 1:40])
    bv = repeat(bv_subseg_Ds, 512)
    layout = MappedBitVectorLayout(bv)
    @test layout.is_dense == RankedBitVector(BitVector([1]))
    @test layout.segpos == UInt64[1]
    @test layout.is_ddense == RankedBitVector(falses(512))
    # subsegpos: 
    @test layout.subsegpos == UInt32[40i for i in 0:(512 - 1)]

    # D: alternating Dd/Ds
    bv_subseg_Ds = BitVector([i % 5 == 1 for i in 1:40])
    bv_subseg_Dd = trues(8)
    bv_seg_D_mixed = repeat([bv_subseg_Dd; bv_subseg_Ds], div(4096, 8 * 2))
    bv = bv_seg_D_mixed
    layout = MappedBitVectorLayout(bv)
    @test layout.is_dense == RankedBitVector(BitVector([1]))
    @test layout.segpos == UInt64[1]
    @test layout.is_ddense == RankedBitVector(BitVector([i % 2 == 1 for i in 1:512]))
    # subsegpos: 
    # alternating chunks of 8+40 bits long (Dd+Ds, up to a whole seg)
    @test layout.subsegpos == vcat([[0, 8] .+ 48 * i for i in 0:255]...)

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
    @test layout.is_dense == RankedBitVector(BitVector([1, 0, 1]))
    @test layout.segpos == UInt64[1, 4097, 4096 + 64^4 + 1]
    @test layout.is_ddense == RankedBitVector([trues(512); [i % 2 == 1 for i in 1:512]])
    exp = UInt32[
        [0:8:4095...];
        vcat([[0, 8] .+ 48 * i for i in 0:255]...)
    ]
    @test layout.subsegpos == exp

    # all bits are 0: 
    bv = falses(4096 * 2)
    layout = MappedBitVectorLayout(bv)
    @test layout.segpos == UInt64[]
    @test layout.is_dense == RankedBitVector(BitVector())
    @test layout.subsegpos == UInt32[]
    @test layout.is_ddense == RankedBitVector(BitVector())
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
    @test res.Ss == reshape([0:4094..., 64^4 - 1], (4096, 1))
    @test res.Ds == reshape([0; 2045 .+ [1:7...]], (8, 1))

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
    @test res.Ss == reshape([0:4094..., 64^4 - 1], (4096, 1))
    @test res.Ds == reshape(repeat([5i for i in 0:7], 256), (8, 256))
end

@testset "select(::MappedBitVector, j)" begin
    # Dd + S + D(d/s)
    bv_subseg_Ds = BitVector([i % 5 == 1 for i in 1:40])
    bv_subseg_Dd = trues(8)
    bv_seg_D_mixed = repeat([bv_subseg_Dd; bv_subseg_Ds], div(4096, 8 * 2))
    bv_seg_S = [trues(4095); falses(64^4 - 4096); trues(1)]
    bv = MappedBitVector([trues(4096); bv_seg_S; bv_seg_D_mixed])
    @test select(bv, 4096) == 4096
    @test select(bv, 4096 + 4095) == 4096 + 4095
    @test select(bv, 4096 + 4096) == 4096 + 64^4
    @test select(bv, 4096 + 4096 + 4096) == 4096 + 64^4 + length(bv_seg_D_mixed) - 4

    # test bounds error:
    @test_throws BoundsError select(bv, 4096 * 3 + 1)
end
