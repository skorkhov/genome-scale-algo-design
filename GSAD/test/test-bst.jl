using Test
using GSAD

v = collect(1:10)
A = VectorRMQ(v)
@test rmq(A, 1, 3) == (1, 1)
@test rmq(A, 2, 3) == (2, 2)
@test rmq(A, 5, 10) == (5, 5)
@test rmq(A, 7, 10) == (7, 7)
# i == j: 
@test rmq(A, 7, 7) == (7, 7)
# indexes outside the range:
@test_throws DomainError rmq(A, 0, 3)
@test_throws DomainError rmq(A, 1, 11)

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


# test TreeRMQ

v_keys = 'j':-1:'a'
v_values = 1:10
v = collect(zip(v_keys, v_values))
A = TreeRMQ(v)

order = sortperm(collect(v_keys))
@test collect(keys(A)) == v_keys[order]
@test collect(values(A)) == v_values[order]

@test rmq(A, 'a', 'j') == (1, 'j')
@test rmq(A, 'a', 'i') == (2, 'i')
@test rmq(A, 'a', 'b') == (9, 'b')
@test rmqi(A, 'a', 'b') == 'b'
@test rmqv(A, 'a', 'b') == 9
# bounds outside the range of keys in the tree
@test rmq(A, 'A', 'z') == (1, 'j')

@test_throws MethodError A[1] == 10
@test A['a'] == 10
@test A['j'] == 1
A['e'] = -99
@test A['e'] == -99
@test rmq(A, 'd', 'f') == (-99, 'e')
@test_throws KeyError A['A']

