
"""

"""
mutable struct BitCache64
    cache::UInt64

    BitCache64() = new(UInt64(0))
    BitCache64(cache::UInt64) = new(cache)
    BitCache64(cache) = new(convert(UInt64, cache))
end

"""
offset_cache(int::Unsigned, bits::Integer)

Return `bits` with 24 least significant bits of `int` on the right.
"""
@inline function offset_cache(int::Unsigned, bits::Integer)
    cache_type = typeof(int) 
    int & maskr(cache_type, 24) + convert(cache_type, bits) << 24
end
# offset_cache(int, bits) = offset_cache(convert(Unsigned, int), convert(Unsigned, bits))

"Mutating for of `offset_cache()` applied to `BitCache64`"
function offset_cache!(cache::BitCache64, bits::Integer)
    cache.cache = offset_cache(cache.cache, bits)
    return nothing
end

"""
    push_cache(int::Unsigned, i::Integer, bits::Integer)

Return `int` with 8 least significant `bits` stored at `8(i-1)` right offset.

Position `i` is clamped to be in [1,3], but no checks on the width of `bits` are
performed.
"""
@inline function push_cache(int::Unsigned, i::Integer, bits::Integer) 
    # TODO: test with clamp() vs throw error
    i = clamp(i, 1, 3)
    # i in 0:3 || throw(BoundsError("only indexes i in 0:3 settable; i=$i"))

    typeint = typeof(int)
    to = 24 - 8i
    # clear the bits that are being assigned: 
    mask = ~maski(typeint, 8 + to, to)

    int & mask + convert(typeint, bits % UInt8) << to
end


"""
    push_cache!(cache::BitCache64, bits::Integer, i::Integer)

Add 8 least significant `bits` to `i`th position in `cache`.

Constains on `bits` and `i` are the same as in [`push_cache`](@ref).
"""
function push_cache!(cache::BitCache64, i::Integer, bits::Integer)
    cache.cache = push_cache(cache.cache, i, bits)
    return nothing
end


"""
    CachedBitVector

A bit vector with additional data for O(1) `rank()` and `select()`.

See also: [`IndexedBitVector`](@ref)
"""
struct CachedBitVector
    bits::BitVector
    cache::Vector{BitCache64}
    
    function CachedBitVector(bits::BitVector)
        n = length(bits)
        n_cache = cld(n, BLOCK_WIDTH_LONG)
        n_short = div(n, BLOCK_WIDTH_SHORT)
        cache = Vector{BitCache64}(BitCache64(), n_cache)
    
        overall = 0
        relative = 0
        for i_short in 1:n_short
            i_long = cld(i_short, N_SHORT_PER_LONG)
            
            # use relative index of short block in long
            # to decide where to store the rank in the cache obj:
            i = i_short % N_SHORT_PER_LONG
            if i == 0
                offset_cache!(cache[i_long], overall) 
                relative = 0
            else 
                push_cache!(cache[i_long], i, relative)
            end
    
            relative += count_ones(bits.chunks[i_short])
            overall += relative
        end
    
        new(bits, cache)
    end
end

Base.convert(::Type{BitVector}, x::CachedBitVector) = x.bits


function rank1(v::CachedBitVector, i::Integer)
    # i = clamp(i, 1, length(v))
    i_short, pos = divrem(i, BLOCK_WIDTH_SHORT)
    i_long = cld(i_short, N_SHORT_PER_LONG)
    i = i_short % N_SHORT_PER_LONG
    get_cache(v.cache[i_long], i) + v.chunks[i_short + 1] << (64 - pos)
end


#=
function add_offset!(cache::BitCache64, offset)
    offset >= 2^40 && throw(ArgumentError("offset should be below 2^40: log2(offset)=$(log2(offset))"))
    cache.cache = cache.cache + (offset % UInt64) << 24
end

function lookup_offset(cache::BitCache64, sbl) 
    sbl in 0:3 || throw(BoundsError("sbl has to be between 0 and 4; given $sbl"))
    l = cache.cache >>> 24

    if sbl == 0 
        return l
    end

    s = cache.cache >>> (8 * (3 - sbl)) 
    s = s % UInt8

    return l + s
end

struct CachedBitVector
    bits::BitVector
    cache::Vector{BitCache64}
    
    function CachedBitVector(bv::BitVector)
        n = length(bv)
        # lbs = ceil(n, BLOCK_WIDTH_LONG)
        sbs = ceil(n, BLOCK_WIDTH_SHORT)
        cache = Vector{BitCache64}(undef, lbs)

        offset = 0 
        for sbl in 1:4:sbs
            sbu = min(sbs, sbl + 2)
            count_ones.(bc.chunks[sbl:sbu])
        end
        
        offset = 0
        for lb in 1:lbs
            # small block indexes included in large block
            sbl = (lb - 1) * N_SHORT_PER_LONG + 1
            sbu = lb == lbs ? sbs : lb * N_SHORT_PER_LONG
            chunks = @view bv.chunks[sbl:sbu]
            
            # add compile block
            lbcache = BitCache64(Tuple(chunks))
            add_offset!(lbcache, offset)
            cache[lb] = lbcache
            
            # increment offset:
            offset += sum(count_ones.(chunks))
        end

        new(bv, cache)
    end
end
=#

