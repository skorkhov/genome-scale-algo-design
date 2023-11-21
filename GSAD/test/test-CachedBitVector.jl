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
    bitvector = BitVector([1, 0, 0])
    v = CachedBitVector(bitvector)
    
    @test v.bits == bitvector
    @test length(v.cache) == 1
    @test v.cache[1].cache == GSAD.BitCache64().cache

    # for longer vector that uses cache: 
    v = make_bitvec_5chunk(CachedBitVector)
    # first cache: 
    c1 = GSAD.BitCache64()
    GSAD.push_cache!(c1, 1, 4)
    GSAD.push_cache!(c1, 2, 5)
    GSAD.push_cache!(c1, 3, 5)
    c2 = GSAD.BitCache64()
    GSAD.offset_cache!(c2, 5)

    @test length(v.cache) == 2
    @test v.cache[1].cache == c1.cache
    @test v.cache[2].cache == c2.cache
end


# @testset "rank1(::CachedBitVector)" begin
#     v = make_bitvec_small(CachedBitVector)
#     @test rank1(v, 2) == 2
#     @test rank1(v, 3) == 3
#     @test rank1(v, 4) == 3
#     @test rank1(v, 8) == 4

#     # long vector with 5 chunks
#     v = make_bitvec_5chunk(CachedBitVector)
#     @test rank1(v, 2) == 2
#     @test rank1(v, 3) == 2
#     # second short chunk:
#     @test rank1(v, 65) == 4
#     @test rank1(v, 67) == 5
#     # rigth after long chunk:
#     @test rank1(v, 257) == 5
#     @test rank1(v, 260) == 6
# end


