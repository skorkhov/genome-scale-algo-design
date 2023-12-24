# tests for select() data structure

using Random
using Test
using GSAD

include("TestUtils.jl")

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

@testset "select1(::SelectBitVector, j)" begin
    # Dd + S + D(d/s)
    bv_subseg_Ds = BitVector([i % 5 == 1 for i in 1:40])
    bv_subseg_Dd = trues(8)
    bv_seg_D_mixed = repeat([bv_subseg_Dd; bv_subseg_Ds], div(4096, 8 * 2))
    bv_seg_S = [trues(4095); falses(64^4 - 4096); trues(1)]
    bv = SelectBitVector([trues(4096); bv_seg_S; bv_seg_D_mixed])
    
    @test select1(bv, 4096) == 4096
    @test select1(bv, 4096 + 4095) == 4096 + 4095
    @test select1(bv, 4096 + 4096) == 4096 + 64^4
    @test select1(bv, 4096 + 4096 + 4096) == 4096 + 64^4 + length(bv_seg_D_mixed) - 4

    # test bounds error:
    @test_throws BoundsError select1(bv, 4096 * 3 + 1)
end
