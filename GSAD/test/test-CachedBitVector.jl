using Test

Base.copy(x::GSAD.BitCache64) = GSAD.BitCache64(x.cache)

@testset "BitCache64" begin
    empty = GSAD.BitCache64(0)
    
    cache = copy(empty)
    GSAD.offset_cache!(cache, 0b11)
    @test cache.cache == UInt64(2^24 + 2^25)

    cache = copy(empty)
    GSAD.offset_cache!(cache, 0b101)
    @test cache.cache == UInt64(2^24 + 2^26)

    cache = copy(empty)
    val = 0
    # push multiple times to the same cache: 
    bits = 0b101
    GSAD.push_cache!(cache, 1, bits)
    val = val + UInt64(bits) << 16
    @test cache.cache == val

    bits = 0b1
    GSAD.push_cache!(cache, 3, bits)
    val = val + UInt64(bits)
    @test cache.cache == val
    
    bits = 0b10100
    GSAD.push_cache!(cache, 2, bits)
    val = val + UInt64(bits) << 8
    @test cache.cache == val

    bits = 2^10
    GSAD.offset_cache!(cache, bits)
    val = val + UInt64(bits) << 24
    @test cache.cache == val
end


@testset "CachedBitVector" begin
    
end



