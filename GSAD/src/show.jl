# show methods for custom types in the package

# =======
# BitVectorRA

Base.show(io::IO, x::BitVectorRA) = Base.show(io, x.bits)
Base.show(io::IO, ::MIME"text/plain", x::BitVectorRA) = print(io, "BitVectorRA: ", x.bits)


# ======= 
# BitVectorRSA

function Base.show(io::IO, x::BitVectorRSA)
    text = "BitVectorRSA (l=$(length(x.bits)), p=$(Int(x.population)))"
    println(io, text)
end

function Base.show(io::IO, mime::MIME"text/plain", x::BitVectorRSA)
    text = [
        "BitVectorRSA:",
        "\n",
        "    len: $(length(x.bits))", 
        "\n", 
        "    pop: $(Int(x.population))"
    ]
    println(io, reduce(*, text))
end
