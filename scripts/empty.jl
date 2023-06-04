# Experiment with alternative implementations of Base.empty()
# see src signature: 
# @edit empty([1, 2, 3])
# @edit empty([1, 2, 3], Float64)

# =======
# src implementation

function newempty1(a::AbstractVector{T}, ::Type{U}=T) where {T,U}
    @show U, Type{U}, T, Type{T}
    Vector{U}()
end

newempty1([1, 2, 3])
newempty1([1, 2, 3], Float64)

# =======
# Explicitly specify DataType as the type of the second argument, U
# then use U to set type of the new array

# Issue: 
# not general enought because not all data types that case serve as types of 
# container elements are declared types (i.e. DataType);
# they can also be UnionAll or Union types.

function newempty2(a::AbstractVector{T}, U::DataType=T) where T
    @show U, Type{U}, T, Type{T}
    Vector{U}()
end

newempty2([1, 2, 3])
newempty2([1, 2, 3], Float64)
# fails with MethodError because didn't match any signature
newempty2([1, 2, 3], Vector)


# =======
# Use second arguemnt type directly

# Issue: 
# fails because in e.g.,
# newempty3([1, 2, 3], Float64)
# the type of the second arg is DataType, 
# which ends up as the container type of the new vector

# doesn't work because in f(Int::U), U becomes DataType
function newempty3(a::AbstractVector{T}, ::U=T) where {T, U}
    @show U, Type{U}, T, Type{T}
    Vector{U}()
end

newempty3([1, 2, 3])
newempty3([1, 2, 3], Float64)


# =======
# Equivalent (?) definition
# (not idiomatic)

function newempty4(a::AbstractVector{T}, U::Type=T) where T
    @show U, Type{U}, T, Type{T}
    Vector{U}()
end

newempty4([1, 2, 3])
newempty4([1, 2, 3], Float64)
# works with UnionAll
newempty4([1, 2, 3], Vector)
empty([1, 2, 3], Vector)
# works with Union:
newempty4([1, 2, 3], Union{Int, String})
empty([1, 2, 3], Union{Int, String})
