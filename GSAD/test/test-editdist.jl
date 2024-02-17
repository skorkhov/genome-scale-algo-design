using Test
using GSAD

# TODO: fix test to use order, not just set
x = "qwer"
y = "...rewq---"
matches = [
    (4, 4),
    (3, 5),
    (2, 6),
    (1, 7)
]
@test equalpairs(x, y) == matches

x = "tervetuloa"
y = "teretulemast"
matches = [
    (6, 1),
    (1, 1), 
    (5, 2),
    (2, 2), 
    (3, 3),
    (5, 4),
    (2, 4), 
    (6, 5),
    (1, 5),
    (7, 6),
    (8, 7),
    (5, 8),
    (2, 8),
    (10, 10),
    (6, 12),
    (1, 12)
]
@test equalpairs(x, y) == matches
@test editdist(x, y) == 6

x = "1q3"
y = "123"
@test equalpairs(x, y) == [(1, 1), (3, 3)]
@test editdist(x, y) == 2

x = "tv"
y = "te"
@test editdist(x, y) == 2

x = "ter"
y = "ter"
@test editdist(x, y) == 0

x = "terv"
y = "tere"
@test equalpairs(x, y) == [(1, 1), (2, 2), (3, 3), (2, 4)]
@test editdist(x, y) == 2

x = "tervt"
y = "terea"
@test equalpairs(x, y) == [(5, 1), (1, 1), (2, 2), (3, 3), (2, 4)]
@test editdist(x, y) == 4

x = "vtter"
y = "eater"
@test equalpairs(x, y) == [(4, 1), (3, 3), (2, 3), (4, 4), (5, 5)]
@test editdist(x, y) == 4
