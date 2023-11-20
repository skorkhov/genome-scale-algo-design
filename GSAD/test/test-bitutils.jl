using Test

@testset "bit utils" begin
    @test GSAD.maskr(UInt8, 2) == 0b11
    @test GSAD.maskr(UInt16, 5) == UInt16(0b11111)

    @test GSAD.maskl(UInt8, 4) == 0b11110000
    @test GSAD.maskl(UInt16, 5) == UInt16(0b1111100000000000)

    @test GSAD.maski(UInt8, 5, 2) == 0b00011100
    @test GSAD.maski(UInt8, 8, 0) == 0b11111111

    from, to = 15, 7
    @test count_ones(GSAD.maski(UInt16, from, to)) == from - to
end
