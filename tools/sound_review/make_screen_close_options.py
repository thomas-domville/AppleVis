"""Original screen-close options: a sheet or screen closing. Frequent, so
soft and short (the quiet tier). Every one fades in and out.
Made 2026-10-07."""
import math, os, random, wave

OUT = os.path.dirname(os.path.abspath(__file__))
SR = 44100
random.seed(31)


def write(name, mono, rms_db=-24.0):
    n = len(mono)
    fi = int(SR * 0.006)
    fo = max(1, int(n * 0.3))
    for i in range(min(fi, n)):
        mono[i] *= 0.5 - 0.5 * math.cos(math.pi * i / fi)
    for k in range(fo):
        mono[n - fo + k] *= 0.5 + 0.5 * math.cos(math.pi * k / fo)
    rms = math.sqrt(sum(x * x for x in mono) / n) or 1
    p = max(abs(x) for x in mono) or 1
    g = min(10 ** (rms_db / 20) / rms, 10 ** (-6 / 20) / p)
    full = 2 ** 23 - 1
    data = bytearray()
    for x in mono:
        v = int(round(max(-1, min(1, x * g)) * full)).to_bytes(3, 'little', signed=True)
        data += v + v
    w = wave.open(os.path.join(OUT, name), 'wb')
    w.setnchannels(2); w.setsampwidth(3); w.setframerate(SR)
    w.writeframes(bytes(data)); w.close()


def env(t, attack, decay):
    return min(1.0, t / attack) * math.exp(-t * decay)


def noise(n, cutoff_at):
    out, lp = [], 0.0
    for i in range(n):
        a = math.exp(-2 * math.pi * cutoff_at(i / SR) / SR)
        lp = (1 - a) * random.uniform(-1, 1) + a * lp
        out.append(lp)
    return out


# 1. Swoosh down: a soft, short sweep of air going from bright to dark,
#    like a panel sliding shut.
def swoosh_down():
    n = int(SR * 0.3)
    air = noise(n, lambda t: 3800 * math.exp(-t * 9) + 300)
    return [air[i] * math.sin(math.pi * min(1, (i / SR) / 0.3)) for i in range(n)]


# 2. Cabinet: a soft, low wooden "tock", like a small cabinet door
#    closing gently.
def cabinet():
    n = int(SR * 0.28)
    out = []
    for i in range(n):
        t = i / SR
        out.append(env(t, 0.003, 24) * (math.sin(2 * math.pi * 210 * t) + 0.4 * math.sin(2 * math.pi * 580 * t) * math.exp(-t * 40)))
    return out


# 3. Fold: a quick paper fold, two tiny soft crinkles close together.
def fold():
    n = int(SR * 0.26)
    out = [0.0] * n
    for start in (0.0, 0.07):
        s = int(start * SR)
        burst = noise(int(SR * 0.05), lambda u: 2600)
        for j, x in enumerate(burst):
            if s + j < n:
                out[s + j] += x * env(j / SR, 0.002, 70)
    return out


# 4. Glass settle: two very soft glassy notes stepping down a third, high
#    and light, like a lid set down on glass.
def glass_settle():
    n = int(SR * 0.4)
    out = []
    for i in range(n):
        t = i / SR
        v = env(t, 0.003, 12) * math.sin(2 * math.pi * 1318.5 * t)          # E6
        if t >= 0.06:
            u = t - 0.06
            v += 0.9 * env(u, 0.003, 10) * math.sin(2 * math.pi * 1046.5 * u)  # C6
        out.append(v)
    return out


# 5. Puff: a very soft, low puff of air. The most subtle of the set.
def puff():
    n = int(SR * 0.2)
    air = noise(n, lambda t: 900)
    return [air[i] * env(i / SR, 0.01, 22) for i in range(n)]


# 6. Tuck in: a soft mid note that glides gently down and settles, like
#    something being tucked away.
def tuck_in():
    n = int(SR * 0.3)
    out, phase = [], 0.0
    for i in range(n):
        t = i / SR
        f = 520 * math.exp(-t * 2.2) + 140
        phase += 2 * math.pi * f / SR
        out.append(env(t, 0.006, 11) * math.sin(phase))
    return out


if __name__ == '__main__':
    for name, fn in [('screen_close_3_swoosh_down', swoosh_down), ('screen_close_4_cabinet', cabinet),
                     ('screen_close_5_fold', fold), ('screen_close_6_glass_settle', glass_settle),
                     ('screen_close_7_puff', puff), ('screen_close_8_tuck_in', tuck_in)]:
        write(name + '.wav', fn())
    print('made 6 screen close options')
