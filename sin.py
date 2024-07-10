import math

STEPS = 16
SCALE = 5

for n in range(STEPS):
    f = 2 * math.pi / STEPS * n
    print("db", round(math.sin(f) * SCALE))
