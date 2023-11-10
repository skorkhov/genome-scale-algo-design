
@testset "rank_slow()" begin
    v = BitArray(Bool[1, 1, 1, 0, 0, 1, 0, 0])
    @test 2 == rank1(v, 2)
    @test 3 == rank1(v, 4) 
    @test 0 == rank1(v, 3, 0)
    @test 1 == rank1(v, 4, 0)
end
