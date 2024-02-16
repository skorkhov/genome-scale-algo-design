# compute edit distance

"""
    eqpairs(x::String, y::String)

Find pairs of position of equal elements in strings x and y
"""
function eqpairs(x::String, y::String)
    m, n = length(x), length(y)
    # create empty mask to copy when initializing position index
    empty_mask = BitArray(undef, (n, ))
    fill!(empty_mask, false)

    # index of position of each character in y: 
    pos_y = Dict{Char, BitVector}()
    for i in eachindex(y)
        char = y[i]
        if !haskey(pos_y, char)
            pos_y[char] = copy(empty_mask)
        end
        pos_y[char][i] = 1
    end

    # iterate through x, 
    # looking up for every character in x
    # a list of its occurences in y, 
    # and saving each pair
    acc = 0
    pairs = Vector{Tuple{Int, Int}}(undef, m * n)
    for i in eachindex(x)
        char = x[i]
        if haskey(pos_y, char)
            mask_ = pos_y[char]
            n_ = sum(mask_)
            pairs[acc + 1:acc + n_] .= [(i, p) for p in findall(mask_)]
            acc += n_
        end
    end


    return pairs[begin:acc]
end
