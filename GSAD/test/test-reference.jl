
@testset "rank_slow()" begin
    v = BitArray(Bool[1, 1, 1, 0, 0, 1, 0, 0])
    @test 2 == rank(v, 2)
    @test 3 == rank(v, 4) 
    @test 0 == rank(v, 3, 0)
    @test 1 == rank(v, 4, 0)
end
