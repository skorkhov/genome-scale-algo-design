
# smaller number with a given number of bits: 
nbits(n) = 2 ^ n - 1

@testset "BitCache64 type" begin
    chunks = Tuple(UInt64[0, 0, nbits(6), 0])
    cache_ui64 = 6 % UInt64
    bc = BitCache64(chunks)
    @test bc.cache == cache_ui64

    chunks = Tuple(UInt64[1, 1, 1, 1])
    cache_ui64 = UInt64(0)
    for i in 1:3
        cache_ui64 += UInt8(1) << (8 * (3 - i))
    end
    bc = BitCache64(chunks)
    @test bc.cache == cache_ui64
end

@testset "cache_offset(::BitCache64)" begin
    chunks = Tuple(UInt64[0, 0, nbits(6), 0])
    bc = BitCache64(chunks)
    @test M.cache_offset(bc, 0) == UInt64(0)
    @test M.cache_offset(bc, 3) == UInt64(6)

    chunks = Tuple(UInt64[0, 0, nbits(6), 0])
    bc = BitCache64(chunks, 100)
    @test M.cache_offset(bc, 0) == UInt64(100)
    @test M.cache_offset(bc, 3) == UInt64(100 + 6)
end

