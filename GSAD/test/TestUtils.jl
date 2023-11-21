module TestUtils

using Test
using Random
using GSAD

function make_bitvec_small(::Type{T}) where T
    bitvector = BitVector([1, 1, 1, 0, 0, 1, 0, 0])
    T(bitvector)
end

function make_bitvec_medium(::Type{T}) where T
    Random.seed!(1)
    bitvector = bitrand(257)
    T(bitvector)
end

function make_bitvec_5chunk(::Type{T}) where T
    # bitvector long enough to grab all chunks: 
    s1 = [BitVector([1, 1, 0, 1, 1, 0]); falses(58)]
    s2 = [BitVector([0, 0, 1]); falses(61)]
    s5 = BitVector([0, 0, 0, 1])
    bitvector = [s1; s2; falses(64); falses(64); s5]
    T(bitvector)
end

function make_bitvec_memlimit(::Type{T}) where T
    len = 2^32 + 3
    bitvector = trues(len)
    T(bitvector)
end

function make_bitrand(::Type{T}, n::Integer) where T
    Random.seed!(1)
    bitvector = bitrand(n)
    T(bitvector)
end



#= test rank() and select() operation on indexed vectors =#

function test_rank1(::Type{T}) where T
    # short vector with one chunk: 
    v = make_bitvec_small(T)
    @test rank1(v, 2) == 2
    @test rank1(v, 3) == 3
    @test rank1(v, 4) == 3
    @test rank1(v, 8) == 4

    # long vector with 5 chunks
    v = make_bitvec_5chunk(T)
    @test rank1(v, 2) == 2
    @test rank1(v, 3) == 2
    # second short chunk:
    @test rank1(v, 65) == 4
    @test rank1(v, 67) == 5
    # rigth after long chunk:
    @test rank1(v, 257) == 5
    @test rank1(v, 260) == 6

    # compare optimized results with slow reference implementation
    # for a long-ish bitvector:
    v = make_bitrand(T, 100_000)
    bitvec = convert(BitVector, v)
    @test rank1(bitvec, 55) == rank1(v, 55)
    @test rank1(bitvec, 300) == rank1(v, 300)
end

"""
    test_rank1_memlimit(::Type{T}) where T

Test rank operation on long bitvectors.

For bitvectors beyond len=2^32, both long and short cache slots have to be used 
to store long cache val. Test handling of such vals via this fucntion.
"""
function test_rank1_memlimit(::Type{T}) where T
    v = make_bitvec_memlimit(T)
    @test rank1(v, 1000) == UInt64(1000)
    @test rank1(v, 2^32 + 1) == UInt64(2^32 + 1)
end

function test_select1(::Type{T}) where T
    v = make_bitvec_small(T)
    @test select1(v, 4) == 6
    # catching edge cases at low counts: 
    @test select1(v, 1) == 1
    @test select1(v, 2) == 2
    @test select1(v, 3) == 3
    @test_throws BoundsError select1(v, 10)

    v = make_bitvec_5chunk(T)
    @test select1(v, 4) == 5
    @test select1(v, 5) == 67
end

function test_select1_memlimit(::Type{T}) where T
    nothing
end


end
