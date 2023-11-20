using Random
using Test

@testset "Split integer into 8+32 bits" begin
    @test_throws DomainError GSAD.split_bits_8plus32(-1)
    @test_throws DomainError GSAD.split_bits_8plus32(1.5)
    
    # for actual numeric inputs: 
    @test (UInt8(1), UInt32(0)) == (GSAD.split_bits_8plus32(1 << (31 + 1)))
    @test (UInt8(2), UInt32(0)) == (GSAD.split_bits_8plus32(1 << (31 + 2)))
    @test (UInt8(4), UInt32(0)) == (GSAD.split_bits_8plus32(1 << (31 + 3)))
    
    i = UInt(131) << 32 + UInt(1077)
    @test (UInt8(131), UInt32(1077)) == GSAD.split_bits_8plus32(i)
end

@testset "IdxBitVector() constructor" begin
    bitvector = BitVector([1, 0, 0])
    v = IdxBitVector(bitvector)
    @test v.v === bitvector
    @test v.short == Int8[]
    @test v.long == Int32[]

    # define bitvector longen than 256 entries:
    len = 257
    bitvector = bitrand(len)
    v = IdxBitVector(bitvector)

    @test v.v === bitvector
    
    cp = cumsum(count_ones.(bitvector.chunks))
    n_chunks = div(len, 64)
    short = UInt8[i%4 != 0 ? cp[i] : 0 for i in 1:n_chunks]
    long = UInt32[cp[i] for i in 1:n_chunks if i%4 == 0]
    @test v.short == short
    @test v.long == long
end


