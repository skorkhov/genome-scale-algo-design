
function rank1(v::BitVector, i::Int, c::Int=1)
    # throw error when index out of bounds
    (i < 0 || i > length(v)) && throw(BoundsError(v, i))

    # count occurences of c in v in positions 0:i
    rank = 0
    for pos in 1:i
        rank = rank + (v[pos] == c)
    end

    rank
end 


