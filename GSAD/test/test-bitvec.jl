using Random

@testset "Split integer into 8+32 bits" begin
    @test_throws DomainError M.split_bits_8plus32(-1)
    @test_throws DomainError M.split_bits_8plus32(1.5)
    
    # for actual numeric inputs: 
    @test (UInt8(1), UInt32(0)) == (M.split_bits_8plus32(1 << (31 + 1)))
    @test (UInt8(2), UInt32(0)) == (M.split_bits_8plus32(1 << (31 + 2)))
    @test (UInt8(4), UInt32(0)) == (M.split_bits_8plus32(1 << (31 + 3)))
    
    i = UInt(131) << 32 + UInt(1077)
    @test (UInt8(131), UInt32(1077)) == M.split_bits_8plus32(i)
end

@testset "IndBitVector() constructor" begin
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

@testset "rank_within_uint64()" begin
    v = BitArray(Bool[1, 1, 1, 0, 0, 1, 0, 0])
    i = v.chunks[1]
    @test 2 == M.rank_within_uint64(i, 2)
    @test 3 == M.rank_within_uint64(i, 3)
    @test 3 == M.rank_within_uint64(i, 4)
end

@testset "rank1()" begin
    # short vector with one chunk: 
    bitvector = BitVector([1, 1, 1, 0, 0, 1, 0, 0])
    v = IdxBitVector(bitvector)
    @test 2 == rank1(v, 2)
    @test 3 == rank1(v, 3)
    @test 3 == rank1(v, 4)
    @test 4 == rank1(v, 8)

    # bitvector long enough to grab all chunks: 
    s1 = [BitVector([1, 1, 0, 1, 1, 0]); falses(58)]
    s2 = [BitVector([0, 0, 1]); falses(61)]
    s5 = BitVector([0, 0, 0, 1])
    bitvector = [s1; s2; falses(64); falses(64); s5]
    v = IdxBitVector(bitvector)

    @test 2 == rank1(v, 2)
    @test 2 == rank1(v, 3)
    # second short chunk:
    @test 4 == rank1(v, 65)
    @test 5 == rank1(v, 67)
    # rigth after long chunk:
    @test 5 == rank1(v, 257)
    @test 6 == rank1(v, 260)

    # for some
    bitvector = bitrand(1_000_000)
    v = IdxBitVector(bitvector)
    @test rank_slow(v.v, 55) == rank1(v, 55)
    @test rank_slow(v.v, 200) == rank1(v, 200)
end

@testset "select1(::IdxBitVector, j)" begin
    bitvector = BitVector([1, 1, 1, 0, 0, 1, 0, 0])
    v = IdxBitVector(bitvector)
    @test select1(v, 4) == 6
    @test select1(v, 1) == 1
    @test select1(v, 2) == 2
    @test select1(v, 3) == 3

    # bitvector long enough to grab all chunks: 
    s1 = [BitVector([1, 1, 0, 1, 1, 0]); falses(58)]
    s2 = [BitVector([0, 0, 1]); falses(61)]
    s5 = BitVector([0, 0, 0, 1])
    bitvector = [s1; s2; falses(64); falses(64); s5]
    v = IdxBitVector(bitvector)
    @test select1(v, 4) == 5
    @test select1(v, 5) == 67
end


