"""Finishing the sound family (2026-10-07).

To install (Claude's call, as the user asked): Recommend, the three "undo"
sounds, and the screen-open "unfold".
For the user to review: new Welcome options.

All built from the chosen family (the clip's wooden tap, the mallet, the
bell, the bubbles, the paper fold), and every one fades in and out.
Levelled afterwards by level_installed.py when installed."""
import math, os, random, wave

HERE = os.path.dirname(os.path.abspath(__file__))
SOUNDS = os.path.join(HERE, '..', '..', 'AppleVis', 'Sources', 'Resources', 'Sounds')
SR = 44100
random.seed(53)


def write(path, mono, target_db):
    n = len(mono)
    fi = int(SR * 0.005)
    fo = max(1, int(n * 0.3))
    for i in range(min(fi, n)):
        mono[i] *= 0.5 - 0.5 * math.cos(math.pi * i / fi)
    for k in range(fo):
        mono[n - fo + k] *= 0.5 + 0.5 * math.cos(math.pi * k / fo)
    win = int(SR * 0.05)
    loud = max(math.sqrt(sum(x * x for x in mono[s:s + win]) / win) for s in range(0, max(1, n - win), win // 4)) or 1
    p = max(abs(x) for x in mono) or 1
    g = min(10 ** (target_db / 20) / loud, 10 ** (-1 / 20) / p)
    full = 2 ** 23 - 1
    data = bytearray()
    for x in mono:
        v = int(round(max(-1, min(1, x * g)) * full)).to_bytes(3, 'little', signed=True)
        data += v + v
    w = wave.open(path, 'wb')
    w.setnchannels(2); w.setsampwidth(3); w.setframerate(SR)
    w.writeframes(bytes(data)); w.close()


def env(t, attack, decay):
    return min(1.0, t / attack) * math.exp(-t * decay)


def tap(f, u):
    return env(u, 0.002, 45) * (math.sin(2 * math.pi * f * u) + 0.3 * math.sin(2 * math.pi * f * 2.76 * u) * math.exp(-u * 60))


def bell(f, u, decay=8.0):
    return env(u, 0.003, decay) * (math.sin(2 * math.pi * f * u) + 0.22 * math.sin(2 * math.pi * f * 2.0 * u) * math.exp(-u * 12)
                                   + 0.06 * math.sin(2 * math.pi * f * 3.0 * u) * math.exp(-u * 18))


def mallet(f, u, decay=10.0):
    return env(u, 0.003, decay) * (math.sin(2 * math.pi * f * u) + 0.2 * math.sin(2 * math.pi * f * 4.0 * u) * math.exp(-u * 30))


def felt(f, u, decay=5.0):
    return env(u, 0.01, decay) * (math.sin(2 * math.pi * f * u) + 0.35 * math.sin(2 * math.pi * f * 2.0 * u) * math.exp(-u * 12)
                                  + 0.1 * math.sin(2 * math.pi * f * 3.0 * u) * math.exp(-u * 20))


def build(dur, parts):
    n = int(SR * dur)
    return [sum(amp * fn(f, i / SR - s) for s, f, amp, fn in parts if i / SR >= s) for i in range(n)]


def noise_burst(n, cutoff):
    a = math.exp(-2 * math.pi * cutoff / SR)
    out, lp = [], 0.0
    for _ in range(n):
        lp = (1 - a) * random.uniform(-1, 1) + a * lp
        out.append(lp)
    return out


A5, Cs6, C6, E6, G5, D6, E5 = 880.0, 1108.73, 1046.5, 1318.5, 783.99, 1174.66, 659.26

# ---------------------------------------------------------------- install
INSTALL = {
    # Recommend: the clip's tap, then a warm, bright major pair, a friendly
    # nod. A step brighter than Save and Follow.
    'recommended': (-13, build(0.5, [(0, 1180, 0.7, tap), (0.07, A5, 0.8, bell), (0.07, Cs6, 0.6, bell)])),
    # Undo sounds: softer, and the other way round from their "on" sound.
    # Unsave: the clip's two taps falling instead of rising.
    'unsaved': (-16, build(0.24, [(0, 1480, 0.8, tap), (0.055, 1180, 1.0, tap)])),
    # Unfollow: the tap, then the follow bell stepping down and fading.
    'unfollowed': (-16, build(0.5, [(0, 1180, 0.7, tap), (0.07, E6, 0.6, lambda f, u: bell(f, u, 14)),
                                    (0.14, C6, 0.7, lambda f, u: bell(f, u, 9))])),
    # No longer recommend: the recommend pair, gentler and stepping down.
    'unrecommended': (-16, build(0.5, [(0, 1180, 0.6, tap), (0.07, Cs6, 0.6, lambda f, u: bell(f, u, 14)),
                                       (0.13, A5, 0.7, lambda f, u: bell(f, u, 9))])),
}


def unfold():
    # The partner of the screen-close "fold": two tiny paper sounds,
    # brightening, as if a page is opened out. Quiet, like the fold.
    n = int(SR * 0.26)
    out = [0.0] * n
    for start, cutoff in ((0.0, 2000), (0.07, 3400)):
        s = int(start * SR)
        burst = noise_burst(int(SR * 0.06), cutoff)
        for j, x in enumerate(burst):
            if s + j < n:
                out[s + j] += x * env(j / SR, 0.004, 55)
    return out


# ---------------------------------------------------------------- review
def bubbles_rise():
    n = int(SR * 0.9)
    out = [0.0] * n
    for start, base in ((0, 420), (0.08, 520), (0.16, 640)):
        phase = 0.0
        for i in range(int(start * SR), n):
            u = i / SR - start
            f = base * (1 + 0.9 * (1 - math.exp(-u * 30)))
            phase += 2 * math.pi * f / SR
            out[i] += env(u, 0.003, 14) * math.sin(phase)
    # and a warm bell to land on
    for i in range(int(0.26 * SR), n):
        u = i / SR - 0.26
        out[i] += 0.9 * bell(1046.5, u, 4.5)
    return out


def sunrise():
    # a soft chord that blooms quickly (not slowly), with a bell on top
    n = int(SR * 1.1)
    out = []
    for i in range(n):
        t = i / SR
        swell = min(1, t / 0.12) * math.exp(-t * 2.6)
        pad = sum(math.sin(2 * math.pi * f * t) for f in (523.25, 659.26, 783.99)) / 3
        out.append(swell * pad + (0.6 * bell(1567.98, t - 0.1, 4) if t >= 0.1 else 0))
    return out


WELCOME = {
    # 2. A warm felt-piano greeting rising C, E, G, landing on the high C.
    'welcome_2_felt_piano_hello': lambda: build(1.1, [(0, 523.25, 0.7, felt), (0.1, 659.26, 0.75, felt),
                                                      (0.2, 783.99, 0.8, felt), (0.3, 1046.5, 1.0, felt)]),
    # 3. The podcast mallet's family: a quick wooden arpeggio up, like a
    #    friendly wave.
    'welcome_3_mallet_wave': lambda: build(0.9, [(0, 523.25, 0.7, mallet), (0.07, 659.26, 0.75, mallet),
                                                 (0.14, 783.99, 0.8, mallet), (0.21, 1046.5, 1.0, lambda f, u: mallet(f, u, 6))]),
    # 4. Two soft bells, "hel-lo", a gentle doorbell for coming home.
    'welcome_4_hello_bells': lambda: build(1.0, [(0, 783.99, 0.9, lambda f, u: bell(f, u, 5)),
                                                 (0.18, 1046.5, 1.0, lambda f, u: bell(f, u, 4))]),
    # 5. The refresh bubbles rising, landing on a warm bell.
    'welcome_5_bubbles_and_bell': bubbles_rise,
    # 6. A soft chord that blooms quickly with a bell on top: a short,
    #    brighter take on today's slow swell.
    'welcome_6_quick_sunrise': sunrise,
}

if __name__ == '__main__':
    for name, (db, mono) in INSTALL.items():
        write(os.path.join(SOUNDS, name + '.wav'), mono, db)
    write(os.path.join(SOUNDS, 'article_open.wav'), unfold(), -21)
    import shutil
    shutil.copy(os.path.join(SOUNDS, 'welcome.wav'), os.path.join(HERE, 'welcome_1_current.wav'))
    for name, fn in WELCOME.items():
        write(os.path.join(HERE, name + '.wav'), fn(), -11)
    print('installed recommend, undo sounds and unfold; made welcome options')
