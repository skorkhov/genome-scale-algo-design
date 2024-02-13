using Test
using GSAD

v = collect(1:10)
A = VectorRMQ(v)
@test rmq(A, 1, 3) == (1, 1)
@test rmq(A, 2, 3) == (2, 2)
@test rmq(A, 5, 10) == (5, 5)
@test rmq(A, 7, 10) == (7, 7)

A[1] = -1
@test A[1] == -1
@test rmq(A, 1, 5) == (-1, 1)
@test rmqv(A, 1, 5) == -1
@test rmqi(A, 1, 5) == 1

A[5] = -99
@test A[5] == -99
@test rmq(A, 2, 4) == (2, 2)
@test rmq(A, 2, 10) == (-99, 5)
@test rmqv(A, 2, 10) == -99
@test rmqi(A, 2, 10) == 5
