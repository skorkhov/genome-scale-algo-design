
mutable struct BitCache64
    cache::UInt64

    BitCache64() = new(UInt64(0))
    BitCache64(cache::UInt64) = new(cache)
    BitCache64(cache) = new(convert(UInt64, cache))
end

Base.zero(::Type{BitCache64}) = BitCache64()

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
function push_cache(int::Unsigned, i::Integer, bits::Integer) 
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

"get cached values for index `i`"
@inline function get_cache(cache::BitCache64, i) 
    int = cache.cache
    ifelse(
        i == 0, 
        int >> 24, 
        int >> 24 + (int >> (24 - 8i)) % UInt8
    )
end

"""
    CachedBitVector

A bit vector with additional data for O(1) `rank()` and `select()`.

See also: [`IndexedBitVector`](@ref)
"""
mutable struct CachedBitVector <: AbstractRankedBitVector
    bits::BitVector
    cache::Vector{BitCache64}
    
    function CachedBitVector(bits::BitVector)
        n = length(bits)
        n_short = fld(n, WIDTH_CHUNK)       # short block caches stored
        # n_cache = cld(n_short, CHUNKS_PER_BLOCK)
        n_cache = fld(n_short, CHUNKS_PER_BLOCK) + 1
        cache = [BitCache64() for _ in 1:n_cache]
    
        overall = 0
        relative = 0
        for current_short in 1:n_short
            current_long = fld(current_short, CHUNKS_PER_BLOCK) + 1
            # use relative index of short block in long
            # to decide where to store the rank in the cache obj:
            i = current_short % CHUNKS_PER_BLOCK
            
            relative += count_ones(bits.chunks[current_short])
            if i == 0
                # in the first chunk of a long block
                overall += relative
                offset_cache!(cache[current_long], overall) 
                relative = 0
            else 
                push_cache!(cache[current_long], i, relative)
            end
        end
    
        new(bits, cache)
    end
end

Base.length(v::CachedBitVector) = length(v.bits)
Base.size(v::CachedBitVector) = (length(v),)
Base.convert(::Type{BitVector}, x::CachedBitVector) = x.bits

Base.show(io::IO, x::CachedBitVector) = Base.print(x.bits)
# for some reason is necessary to make printing work in the terminal: 
Base.show(io::IO, ::MIME"text/plain", z::CachedBitVector) = print(io, "CachedBitVector: ", z.bits)

function rank(v::CachedBitVector, i::Integer)
    stored_short, pos = divrem(i, WIDTH_CHUNK)
    stored_long = fld(stored_short, CHUNKS_PER_BLOCK) + 1

    idx_in_cache = stored_short % CHUNKS_PER_BLOCK
    rank_in_chunk = count_ones(v.bits.chunks[stored_short + 1] << (64 - pos))
    get_cache(v.cache[stored_long], idx_in_cache) + rank_in_chunk
end
