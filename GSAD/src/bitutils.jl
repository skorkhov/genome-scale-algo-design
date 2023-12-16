
@inline maskr(::Type{T}, n::Integer) where T <: Unsigned = typemax(T) >> (sizeof(T) * 8 - n)
@inline maskl(::Type{T}, n::Integer) where T <: Unsigned = typemax(T) << (sizeof(T) * 8 - n)

@inline function maski(::Type{T}, from::Int, to::Int) where T <: Unsigned
    # `from` and `to` refer to the bit position from the least significant bits
    # e.g. T, from, to = UInt8, 5, 3 ==> 8[000]6 5[111]3 2[00]1
    xor(maskr(T, from), maskr(T, to))
end
