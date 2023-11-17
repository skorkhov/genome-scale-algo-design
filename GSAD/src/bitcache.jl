

mutable struct BitCache64
    cache::UInt64
end

function BitCache64(chunks::Tuple{UInt64, Vararg{UInt64, N}}) where N
    N > 3 && throw(DomainError("At most 4 chunks are accepted; len(chunks) = $(N + 1)"))

    cache = UInt64(0)
    for i in 1:min(3, N + 1) 
        cache_ui8 = count_ones(chunks[i]) % UInt8
        shift_by_bits = (3 - i) * 8
        @show cache, cache_ui8, shift_by_bits
        cache += cache_ui8 << shift_by_bits
    end
    
    BitCache64(cache)
end

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
        lbs = ceil(n, BLOCK_WIDTH_LONG)
        sbs = ceil(n, BLOCK_WIDTH_SHORT)
        cache = Vector{BitCache64}(undef, lbs)
        
        offset = 0
        for lb in 1:lbs
            sbl = (lb - 1) * N_SHORT_PER_LONG + 1
            sbu = lb == lbs ? sbs : lb * N_SHORT_PER_LONG
            chunks = @view bv.chunks[sbl:sbu]
            
            lbcache = BitCache64(Tuple(chunks))
            add_offset!(lbcache, offset)
            cache[lb] = lbcache
            
            # increment offset:
            offset += sum(count_ones.(chunks))
        end

        new(bv, cache)
    end
end
