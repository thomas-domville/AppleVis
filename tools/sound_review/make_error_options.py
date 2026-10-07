"""Original error sound options. Every one fades in and out, and sits a
little firmer than confirmations (errors should cut through, not startle).
Made 2026-10-07 after the user didn't like the current error sound."""
import math, os, wave

OUT = os.path.dirname(os.path.abspath(__file__))
SR = 44100


def write(name, mono, peak_db=-4.5):
    n = len(mono)
    fi = int(SR * 0.006)
    fo = max(1, int(n * 0.25))
    for i in range(min(fi, n)):
        mono[i] *= 0.5 - 0.5 * math.cos(math.pi * i / fi)
    for k in range(fo):
        mono[n - fo + k] *= 0.5 + 0.5 * math.cos(math.pi * k / fo)
    # Levelled by average loudness (about -18 dB, a little firmer than
    # confirmations), with the peak kept below -3 dB.
    rms = math.sqrt(sum(x * x for x in mono) / n) or 1
    p = max(abs(x) for x in mono) or 1
    g = min(10 ** (-18 / 20) / rms, 10 ** (-3 / 20) / p)
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


def mallet(f, t, decay=9.0):
    return (math.sin(2 * math.pi * f * t) * math.exp(-t * decay)
            + 0.25 * math.sin(2 * math.pi * f * 2 * t) * math.exp(-t * decay * 1.8)
            + 0.08 * math.sin(2 * math.pi * f * 3 * t) * math.exp(-t * decay * 2.6))


# 1. Uh-oh: two round, low notes stepping down a minor third, like a
#    gentle "uh-oh". The classic shape, kept soft.
def uh_oh():
    n = int(SR * 0.5)
    out = []
    for i in range(n):
        t = i / SR
        v = min(1, t / 0.005) * mallet(329.63, t, 10)                   # E4
        if t >= 0.13:
            u = t - 0.13
            v += 1.1 * min(1, u / 0.005) * mallet(277.18, u, 7)          # C#4
        out.append(v)
    return out


# 2. Bonk: one low, soft wooden knock whose pitch dips slightly, like
#    bumping into something closed.
def bonk():
    n = int(SR * 0.32)
    out, phase = [], 0.0
    for i in range(n):
        t = i / SR
        f = 240 - 60 * (1 - math.exp(-t * 18))      # dips from 240 to about 180 Hz
        phase += 2 * math.pi * f / SR
        out.append(env(t, 0.004, 14) * (math.sin(phase) + 0.3 * math.sin(2.7 * phase) * math.exp(-t * 30)))
    return out


# 3. Knock-knock: two quick, low knocks, like knocking on a door that
#    doesn't open.
def knock_knock():
    n = int(SR * 0.34)
    out = []
    for i in range(n):
        t = i / SR
        v = 0.0
        for start, f in ((0.0, 196.0), (0.12, 174.6)):          # G3, F3
            if t >= start:
                u = t - start
                v += env(u, 0.003, 26) * (math.sin(2 * math.pi * f * u) + 0.45 * math.sin(2 * math.pi * f * 2.4 * u) * math.exp(-u * 40))
        out.append(v)
    return out


# 4. Soft buzz: a brief, muffled low buzz in two short pulses, the
#    familiar "no" of a buzzer with the harshness taken out.
def soft_buzz():
    n = int(SR * 0.36)
    out = []
    lp = 0.0
    a = math.exp(-2 * math.pi * 900 / SR)          # muffles the buzz
    for i in range(n):
        t = i / SR
        pulse = 1.0 if (t < 0.13 or 0.18 <= t < 0.31) else 0.0
        local = t if t < 0.13 else t - 0.18
        shape = min(1, local / 0.012) * min(1, max(0, (0.13 - local)) / 0.03)
        raw = sum(math.sin(2 * math.pi * 155 * k * t) / k for k in (1, 3, 5, 7))  # soft square-ish
        lp = (1 - a) * raw + a * lp
        out.append(lp * pulse * shape)
    return out


# 5. Not quite: two soft bell notes sounding together that don't quite
#    agree, so it says "something's off" without being loud.
def not_quite():
    n = int(SR * 0.55)
    out = []
    for i in range(n):
        t = i / SR
        v = env(t, 0.008, 7) * (math.sin(2 * math.pi * 392.0 * t) + 0.8 * math.sin(2 * math.pi * 554.37 * t)
                               + 0.15 * math.sin(2 * math.pi * 784.0 * t) * math.exp(-t * 6))
        out.append(v)
    return out


# 6. Deflate: a short, smooth slide downward, like air going out of
#    something.
def deflate():
    n = int(SR * 0.38)
    out, phase = [], 0.0
    for i in range(n):
        t = i / SR
        f = 520 * math.exp(-t * 2.6)                # slides from 520 down to about 195 Hz
        phase += 2 * math.pi * f / SR
        out.append(env(t, 0.01, 4.5) * (math.sin(phase) + 0.2 * math.sin(2 * phase)))
    return out


if __name__ == '__main__':
    for name, fn in [('error_4_uh_oh', uh_oh), ('error_5_bonk', bonk), ('error_6_knock_knock', knock_knock),
                     ('error_7_soft_buzz', soft_buzz), ('error_8_not_quite', not_quite), ('error_9_deflate', deflate)]:
        write(name + '.wav', fn())
    print('made 6 error options')
