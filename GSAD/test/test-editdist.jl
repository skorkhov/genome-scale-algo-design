using Test

x = "qwer"
y = "...rewq---"
@test GSAD.eqpairs(x, y) == [(1, 7), (2, 6), (3, 5), (4, 4)]
