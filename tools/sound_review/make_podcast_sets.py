"""Podcast sound sets: Play, Pause and Added to Queue from one instrument
each, so the three sound like a family. Play goes up, Pause comes down,
Queue is a small "added to the list" figure. Every sound fades in and out.
Made 2026-10-07; levelled afterwards by level_installed.py when installed."""
import math, os, wave

OUT = os.path.dirname(os.path.abspath(__file__))
SR = 44100


def write(name, mono, target_db=-13.0):
    n = len(mono)
    fi = int(SR * 0.005)
    fo = max(1, int(n * 0.3))
    for i in range(min(fi, n)):
        mono[i] *= 0.5 - 0.5 * math.cos(math.pi * i / fi)
    for k in range(fo):
        mono[n - fo + k] *= 0.5 + 0.5 * math.cos(math.pi * k / fo)
    # level by the loudest 50 ms moment (how loud it feels)
    win = int(SR * 0.05)
    loud = max(math.sqrt(sum(x * x for x in mono[s:s + win]) / win) for s in range(0, max(1, n - win), win // 4)) or 1
    p = max(abs(x) for x in mono) or 1
    g = min(10 ** (target_db / 20) / loud, 10 ** (-1 / 20) / p)
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


def sequence(dur, notes, voice):
    """notes: (start seconds, frequency, loudness)."""
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        out.append(sum(amp * voice(f, t - s) for s, f, amp in notes if t >= s))
    return out


# Instruments
def mallet(f, u):
    return env(u, 0.003, 10) * (math.sin(2 * math.pi * f * u) + 0.2 * math.sin(2 * math.pi * f * 4.0 * u) * math.exp(-u * 30))


def bell(f, u):
    return env(u, 0.003, 7) * (math.sin(2 * math.pi * f * u) + 0.25 * math.sin(2 * math.pi * f * 2.0 * u) * math.exp(-u * 10)
                               + 0.07 * math.sin(2 * math.pi * f * 3.0 * u) * math.exp(-u * 16))


def felt_piano(f, u):
    # soft hammer: a gentle attack, warm, a little overtone that fades fast
    return env(u, 0.008, 6) * (math.sin(2 * math.pi * f * u) + 0.35 * math.sin(2 * math.pi * f * 2.0 * u) * math.exp(-u * 14)
                               + 0.1 * math.sin(2 * math.pi * f * 3.0 * u) * math.exp(-u * 22))


def glide(f0, f1, dur, decay=7):
    """A smooth pitch slide from f0 to f1, like a record spinning up or down."""
    n = int(SR * dur)
    out, phase = [], 0.0
    for i in range(n):
        t = i / SR
        f = f0 + (f1 - f0) * (1 - math.exp(-t * 14))
        phase += 2 * math.pi * f / SR
        out.append(env(t, 0.006, decay) * (math.sin(phase) + 0.2 * math.sin(2 * phase)))
    return out


def bubble(base, u, rise=0.9):
    f = base + base * rise * (1 - math.exp(-u * 30))
    return f


def bubbles(starts_bases, dur, falling=False):
    n = int(SR * dur)
    out = [0.0] * n
    for start, base in starts_bases:
        phase = 0.0
        for i in range(int(start * SR), n):
            u = i / SR - start
            f = base * (1 - 0.45 * (1 - math.exp(-u * 30))) if falling else bubble(base, u)
            phase += 2 * math.pi * f / SR
            out[i] += env(u, 0.003, 16) * math.sin(phase)
    return out


C5, D5, E5, G5, A5, C6 = 523.25, 587.33, 659.26, 783.99, 880.0, 1046.5

SETS = {
    # A. Soft mallet: wooden and warm, like the bookmark clip's family.
    'A_mallet': {
        'play':  sequence(0.4, [(0, C5, 0.8), (0.07, G5, 1.0)], mallet),
        'pause': sequence(0.4, [(0, G5, 0.9), (0.07, C5, 1.0)], mallet),
        'queue': sequence(0.42, [(0, E5, 0.8), (0.09, E5, 0.9)], mallet),
    },
    # B. Warm bell: rounder and a little more musical.
    'B_bell': {
        'play':  sequence(0.5, [(0, D5, 0.8), (0.08, A5, 1.0)], bell),
        'pause': sequence(0.5, [(0, A5, 0.9), (0.08, D5, 1.0)], bell),
        'queue': sequence(0.5, [(0, E5, 0.8), (0.07, G5, 0.7), (0.14, E5, 0.8)], bell),
    },
    # C. Felt piano: soft, gentle hammer, the most relaxed set.
    'C_felt_piano': {
        'play':  sequence(0.55, [(0, C5, 0.8), (0.09, E5, 0.85), (0.18, G5, 1.0)], felt_piano),
        'pause': sequence(0.55, [(0, G5, 0.9), (0.09, E5, 0.85), (0.18, C5, 1.0)], felt_piano),
        'queue': sequence(0.45, [(0, E5, 0.8), (0.1, G5, 0.9)], felt_piano),
    },
    # D. Spin: smooth slides, like a record spinning up for Play and winding
    #    down for Pause. Queue is a tiny lift.
    'D_spin': {
        'play':  glide(330, 660, 0.35),
        'pause': glide(660, 330, 0.35),
        'queue': [a + b for a, b in zip(glide(500, 620, 0.32, decay=12), [0.0] * int(SR * 0.08) + glide(560, 700, 0.24, decay=12))],
    },
    # E. Bubbles: the same family as the new refresh sound. Bubbles rising
    #    for Play, sinking for Pause, two small ones for Queue.
    'E_bubbles': {
        'play':  bubbles([(0, 420), (0.08, 560)], 0.4),
        'pause': bubbles([(0, 900), (0.08, 700)], 0.4, falling=True),
        'queue': bubbles([(0, 600), (0.07, 600)], 0.35),
    },
}

if __name__ == '__main__':
    for set_name, sounds in SETS.items():
        for kind, mono in sounds.items():
            write(f'podcast_{set_name}_{kind}.wav', list(mono))
    print('made', len(SETS), 'podcast sets')
