"""Original bookmark/save sound options. Every one fades in and out."""
import math, random, os, struct, wave

OUT = r'C:\Users\thoma\dev\AppleVis\tools\sound_review'
SR = 44100
random.seed(7)


def write(name, mono, peak_db=-6.0):
    # gentle fade-in (6 ms) and fade-out (last 25%, cosine), then level
    n = len(mono)
    fi = int(SR * 0.006)
    fo = max(1, int(n * 0.25))
    for i in range(min(fi, n)):
        mono[i] *= 0.5 - 0.5 * math.cos(math.pi * i / fi)
    for k in range(fo):
        mono[n - fo + k] *= 0.5 + 0.5 * math.cos(math.pi * k / fo)
    p = max(abs(x) for x in mono) or 1
    g = 10 ** (peak_db / 20) / p
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


def tone(f, t, partials=((1, 1.0, 0),)):
    return sum(a * math.sin(2 * math.pi * f * m * t) * math.exp(-t * d) for m, a, d in partials)


def bandnoise(n, lo, hi):
    # simple band-limited noise: high-pass then low-pass one-pole filters
    a_lo = math.exp(-2 * math.pi * lo / SR)
    a_hi = math.exp(-2 * math.pi * hi / SR)
    out, hp_prev_in, hp_prev_out, lp = [], 0.0, 0.0, 0.0
    for _ in range(n):
        x = random.uniform(-1, 1)
        hp = a_lo * (hp_prev_out + x - hp_prev_in)
        hp_prev_in, hp_prev_out = x, hp
        lp = (1 - a_hi) * hp + a_hi * lp
        out.append(lp)
    return out


# 1. Tuck: a soft paper swish into a small wooden knock, like slipping a
#    bookmark into a book.
def tuck():
    dur = 0.42
    n = int(SR * dur)
    swish = bandnoise(n, 900, 4500)
    out = []
    for i in range(n):
        t = i / SR
        s = swish[i] * (math.sin(math.pi * min(1, t / 0.13)) if t < 0.13 else 0) * 0.9
        k = 0.0
        if t >= 0.11:
            u = t - 0.11
            k = env(u, 0.003, 22) * (math.sin(2 * math.pi * 330 * u) + 0.35 * math.sin(2 * math.pi * 660 * u) * math.exp(-u * 30))
        out.append(s + k)
    return out


# 2. Droplet: a light, quick upward "bloop", like a drop into water.
def droplet():
    dur = 0.32
    n = int(SR * dur)
    out, phase = [], 0.0
    for i in range(n):
        t = i / SR
        f = 520 + 640 * (1 - math.exp(-t * 28))  # glides up from 520 to about 1160 Hz
        phase += 2 * math.pi * f / SR
        out.append(math.sin(phase) * env(t, 0.004, 12))
    return out


# 3. Felt chime: one warm, round note with a soft shimmer above it.
def felt_chime():
    dur = 0.6
    n = int(SR * dur)
    f = 659.26  # E5
    return [env(i / SR, 0.012, 6.5) * tone(f, i / SR, ((1, 1.0, 0), (1.5, 0.28, 3), (2.0, 0.12, 6), (3.0, 0.04, 10)))
            for i in range(n)]


# 4. Settle: two warm notes stepping down and landing, like placing
#    something somewhere safe.
def settle():
    dur = 0.55
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        v = env(t, 0.006, 10) * tone(784.0, t, ((1, 1.0, 0), (2, 0.2, 8)))           # G5
        if t >= 0.09:
            u = t - 0.09
            v += 1.1 * env(u, 0.006, 6.5) * tone(587.33, u, ((1, 1.0, 0), (2, 0.2, 6)))  # D5
        out.append(v)
    return out


# 5. Clip: two very quick, soft wooden taps, like a clip closing.
def clip():
    dur = 0.24
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        v = 0.0
        for start, f, amp in ((0.0, 1180, 0.7), (0.055, 1480, 1.0)):
            if t >= start:
                u = t - start
                v += amp * env(u, 0.002, 45) * (math.sin(2 * math.pi * f * u) + 0.3 * math.sin(2 * math.pi * f * 2.76 * u) * math.exp(-u * 60))
        out.append(v)
    return out


for name, fn in [('bookmark_4_tuck', tuck), ('bookmark_5_droplet', droplet), ('bookmark_6_felt_chime', felt_chime),
                 ('bookmark_7_settle', settle), ('bookmark_8_clip', clip)]:
    write(name + '.wav', fn())
print(sorted(f for f in os.listdir(OUT) if f.startswith('bookmark')))
