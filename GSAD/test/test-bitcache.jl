using Test
using Random
using GSAD

include("TestUtils.jl")


#= test constructor and type utils =#

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
    v = TestUtils.make_bitvec_5chunk(CachedBitVector)
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


#= test rank() and select() =#

@testset "rank(::CachedBitVector, ...)" TestUtils.test_rank(CachedBitVector)
@testset "rank(::CachedBitVector, ...) mem-intensive" TestUtils.test_rank_memlimit(CachedBitVector)
# @testset "select(::RankedBitVector, ...)" test_select(RankedBitVector)

