# compute edit distance

"""
    equalpairs(x::String, y::String)

Find pairs of positions of equal elements in strings x and y in reverse col order.
"""
function equalpairs(x::String, y::String)
    m, n = length(x), length(y)
    # create empty mask to copy when initializing position index
    empty_mask = BitArray(undef, (n, ))
    fill!(empty_mask, false)

    # index of position of each character: 
    posidx = Dict{Char, BitVector}()
    for i in eachindex(x)
        char = x[i]
        if !haskey(posidx, char)
            posidx[char] = copy(empty_mask)
        end
        posidx[char][i] = 1
    end

    # iterate through x, 
    # looking up for every character in x
    # a list of its occurences in y, 
    # and saving each pair
    acc = 0
    pairs = Vector{Tuple{Int, Int}}(undef, m * n)
    for i in eachindex(y)
        char = y[i]
        if haskey(posidx, char)
            mask_ = posidx[char]
            n_ = sum(mask_)
            # TODO: check why _reverse_ col oredr is important
            pairs[acc + 1:acc + n_] .= [(p, i) for p in Iterators.reverse(findall(mask_))]
            # pairs[acc + 1:acc + n_] .= [(p, i) for p in findall(mask_)]
            acc += n_
        end
    end


    return pairs[begin:acc]
end

function editdist(x::String, y::String)
    m, n = length(x), length(y)
    M = equalpairs(x, y)
    T = VectorRMQ(fill(0, m + 1))
    T[1] = 0
    for (i, j) in M
        dij = i + j - 2 + rmqv(T, 1, i)
        d = dij - i - j
        T[i + 1] = d
    end

    return rmqv(T, 1, m + 1) + m + n
end
