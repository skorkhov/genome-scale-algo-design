using Test
using GSAD

@testset "RMQ segment tree" begin
    v = collect(1:10)
    A = VectorRMQ(v)

    @test rmq(A, 1, 3) == 1
    @test rmq(A, 2, 3) == 2
    @test rmq(A, 5, 10) == 5
    @test rmq(A, 7, 10) == 7
end
