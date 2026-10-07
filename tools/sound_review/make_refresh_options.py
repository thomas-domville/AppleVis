"""Original refresh sound options: the moment new content arrives after a
pull. Every one fades in and out; levelled like other confirmations.
Made 2026-10-07."""
import math, os, random, wave

OUT = os.path.dirname(os.path.abspath(__file__))
SR = 44100
random.seed(11)


def write(name, mono, rms_db=-20.0):
    n = len(mono)
    fi = int(SR * 0.008)
    fo = max(1, int(n * 0.3))
    for i in range(min(fi, n)):
        mono[i] *= 0.5 - 0.5 * math.cos(math.pi * i / fi)
    for k in range(fo):
        mono[n - fo + k] *= 0.5 + 0.5 * math.cos(math.pi * k / fo)
    rms = math.sqrt(sum(x * x for x in mono) / n) or 1
    p = max(abs(x) for x in mono) or 1
    g = min(10 ** (rms_db / 20) / rms, 10 ** (-3 / 20) / p)
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


def noise_filtered(n, cutoff_at):
    """Noise through a low-pass whose cutoff follows cutoff_at(t)."""
    out, lp = [], 0.0
    for i in range(n):
        a = math.exp(-2 * math.pi * cutoff_at(i / SR) / SR)
        lp = (1 - a) * random.uniform(-1, 1) + a * lp
        out.append(lp)
    return out


# 1. Swirl: a soft breath of air that brightens as it rises, with a small
#    warm note blooming at the top. "Fresh air."
def swirl():
    dur = 0.7
    n = int(SR * dur)
    air = noise_filtered(n, lambda t: 600 + 5200 * min(1, t / 0.35))
    out = []
    for i in range(n):
        t = i / SR
        a = air[i] * math.sin(math.pi * min(1, t / 0.45)) * (1 if t < 0.45 else 0) * 0.8
        b = 0.0
        if t >= 0.3:
            u = t - 0.3
            b = env(u, 0.02, 5) * (math.sin(2 * math.pi * 880 * u) + 0.3 * math.sin(2 * math.pi * 1320 * u))
        out.append(a + b)
    return out


# 2. Riffle: a quick riffle of pages, getting faster, then settling. "A
#    new page."
def riffle():
    dur = 0.5
    n = int(SR * dur)
    out = [0.0] * n
    times, t, gap = [], 0.0, 0.05
    for _ in range(10):                      # ten page flicks, speeding up
        times.append(t); t += gap; gap = max(0.015, gap * 0.8)
    for k, start in enumerate(times):
        s = int(start * SR)
        burst = noise_filtered(int(SR * 0.02), lambda u: 3000)
        for j, x in enumerate(burst):
            if s + j < n:
                out[s + j] += x * env(j / SR, 0.001, 160) * (0.6 + 0.4 * k / len(times))
    # a soft settle at the end
    for i in range(int(0.3 * SR), n):
        u = i / SR - 0.3
        out[i] += 0.5 * env(u, 0.005, 14) * math.sin(2 * math.pi * 392 * u)
    return out


# 3. Kalimba sparkle: three quick plucked notes, high and light, like a
#    music box waking up. Played quickly so it reads as one gesture.
def kalimba():
    dur = 0.55
    n = int(SR * dur)
    notes = [(0.0, 1046.5), (0.05, 1318.5), (0.1, 1568.0)]  # C6, E6, G6
    out = []
    for i in range(n):
        t = i / SR
        v = 0.0
        for start, f in notes:
            if t >= start:
                u = t - start
                v += env(u, 0.002, 9) * (math.sin(2 * math.pi * f * u) + 0.25 * math.sin(2 * math.pi * f * 2.0 * u) * math.exp(-u * 20))
        out.append(v)
    return out


# 4. Marimba turn: an original version of today's idea, two warm wooden
#    notes rocking once and ending on the higher one. Shorter and rounder.
def marimba_turn():
    dur = 0.6
    n = int(SR * dur)
    notes = [(0.0, 587.33, 0.8), (0.1, 783.99, 0.7), (0.2, 587.33, 0.6), (0.3, 783.99, 1.0)]  # D, G, D, G
    out = []
    for i in range(n):
        t = i / SR
        v = 0.0
        for start, f, amp in notes:
            if t >= start:
                u = t - start
                v += amp * env(u, 0.003, 11) * (math.sin(2 * math.pi * f * u) + 0.15 * math.sin(2 * math.pi * f * 4.0 * u) * math.exp(-u * 30))
        out.append(v)
    return out


# 5. Whoosh-in: a short swoosh that arrives with a tiny soft click, like a
#    new item sliding into place.
def whoosh_in():
    dur = 0.45
    n = int(SR * dur)
    air = noise_filtered(n, lambda t: 400 + 3000 * min(1, t / 0.22))
    out = []
    for i in range(n):
        t = i / SR
        swell = math.sin(math.pi * min(1, t / 0.24)) if t < 0.24 else 0.0
        v = air[i] * swell * 0.9
        if t >= 0.22:
            u = t - 0.22
            v += 0.6 * env(u, 0.002, 40) * math.sin(2 * math.pi * 1400 * u)
        out.append(v)
    return out


# 6. Breath: a warm, soft chord that swells in and fades away, very
#    gentle. For if the others feel too busy.
def breath():
    dur = 0.75
    n = int(SR * dur)
    chord = (392.0, 493.88, 587.33)  # G, B, D
    out = []
    for i in range(n):
        t = i / SR
        swell = math.sin(math.pi * t / dur) ** 1.5
        out.append(swell * sum(math.sin(2 * math.pi * f * t) for f in chord) / 3)
    return out


# Bubbles: three tiny "bloops" rising quickly one after another, light
#    and bubbly, like something fresh coming to the surface.
def bubbles():
    dur = 0.5
    n = int(SR * dur)
    out = [0.0] * n
    for start, base in ((0.0, 480), (0.075, 640), (0.15, 820)):
        phase = 0.0
        for i in range(int(start * SR), n):
            u = i / SR - start
            f = base + base * 0.9 * (1 - math.exp(-u * 30))
            phase += 2 * math.pi * f / SR
            out[i] += env(u, 0.003, 16) * math.sin(phase)
    return out


if __name__ == '__main__':
    # Swirl is kept in the code but not made: the user didn't like it.
    for name, fn in [('refresh_1_riffle', riffle), ('refresh_2_kalimba_sparkle', kalimba),
                     ('refresh_3_marimba_turn', marimba_turn), ('refresh_4_whoosh_in', whoosh_in),
                     ('refresh_5_breath', breath), ('refresh_6_bubbles', bubbles)]:
        write(name + '.wav', fn())
    print('made 6 refresh options')
