# show methods for custom types in the package

# =======
# RankedBitVector

Base.show(io::IO, x::RankedBitVector) = Base.show(io, x.bits)
Base.show(io::IO, ::MIME"text/plain", x::RankedBitVector) = print(io, "RankedBitVector: ", x.bits)


# ======= 
# MappedBitVector

function Base.show(io::IO, x::MappedBitVector)
    text = "MappedBitVector (l=$(length(x.bits)), p=$(Int(x.layout.pop)))"
    println(io, text)
end

function Base.show(io::IO, mime::MIME"text/plain", x::MappedBitVector)
    text = [
        "MappedBitVector:",
        "\n",
        "    len: $(length(x.bits))", 
        "\n", 
        "    pop: $(Int(x.layout.pop))"
    ]
    println(io, reduce(*, text))
end
