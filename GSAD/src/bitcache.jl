

struct BitCache64
    cache::UInt64
end

function BitCache64(chunks::Tuple{UInt64, Vararg{UInt64, N}}, offset = 0) where N
    N > 3 && throw(DomainError("At most 4 chunks are accepted; len(chunks) = $(N + 1)"))
    offset >= 2^40 && throw(ArgumentError("offset should be below 2^40: log2(offset)=$(log2(offset))"))

    cache = (offset % UInt64) << 24
    for i in 1:min(3, N + 1) 
        cache_ui8 = count_ones(chunks[i]) % UInt8
        shift_by_bits = (3 - i) * 8
        @show cache, cache_ui8, shift_by_bits
        cache += cache_ui8 << shift_by_bits
    end
    
    BitCache64(cache)
end

function cache_offset(cache::BitCache64, sbl) 
    sbl in 0:3 || throw(BoundsError("sbl has to be between 0 and 4; given $sbl"))
    l = cache.cache >>> 24

    if sbl == 0 
        return l
    end

    s = cache.cache >>> (8 * (3 - sbl)) 
    s = s % UInt8

    return l + s
end


