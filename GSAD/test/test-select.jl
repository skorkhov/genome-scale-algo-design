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

@testset "MappedBitVector()" begin

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
    # layout: 
    @test res.is_dense == RankedBitVector(BitVector([1, 0, 1]))
    @test res.segpos == UInt64[1, 4097, 4096 + 64^4 + 1]
    @test res.is_ddense == RankedBitVector([trues(512); [i % 2 == 1 for i in 1:512]])
    exp = UInt32[
        [0:8:4095...];
        vcat([[0, 8] .+ 48 * i for i in 0:255]...)
    ]
    @test res.subsegpos == exp
    # caches: 
    @test res.Ss == reshape([0:4094..., 64^4 - 1], (4096, 1))
    @test res.Ds == reshape(repeat([5i for i in 0:7], 256), (8, 256))

    # all bits are 0: 
    bv = falses(4096 * 2)
    res = MappedBitVector(bv)
    @test res.bits == bv
    # layout:
    @test res.segpos == UInt64[]
    @test res.is_dense == RankedBitVector(BitVector())
    @test res.subsegpos == UInt32[]
    @test res.is_ddense == RankedBitVector(BitVector())
    # caches: 
    @test res.Ss == Matrix{UInt32}(undef, (4096, 0))
    @test res.Ds == Matrix{UInt32}(undef, (8, 0))
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
