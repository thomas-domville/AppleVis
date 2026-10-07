"""Original reply/comment-posted sound options: your words sent off to the
community. Every one fades in and out; levelled like other confirmations,
and kept in the same soft wooden/bell family as the chosen bookmark clip
and refresh bubbles. Made 2026-10-07."""
import math, os, random, wave

OUT = os.path.dirname(os.path.abspath(__file__))
SR = 44100
random.seed(23)


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


def lowpass_noise(n, cutoff_at):
    out, lp = [], 0.0
    for i in range(n):
        a = math.exp(-2 * math.pi * cutoff_at(i / SR) / SR)
        lp = (1 - a) * random.uniform(-1, 1) + a * lp
        out.append(lp)
    return out


# 1. Paper plane: a light swoosh lifting away, with a small bright note as
#    it sails off. "Sent."
def paper_plane():
    n = int(SR * 0.55)
    air = lowpass_noise(n, lambda t: 800 + 3500 * min(1, t / 0.25))
    out = []
    for i in range(n):
        t = i / SR
        v = air[i] * (math.sin(math.pi * min(1, t / 0.28)) if t < 0.28 else 0) * 0.7
        if t >= 0.2:
            u = t - 0.2
            v += 0.7 * env(u, 0.004, 9) * (math.sin(2 * math.pi * 1174.7 * u) + 0.2 * math.sin(2 * math.pi * 2349.3 * u) * math.exp(-u * 15))
        out.append(v)
    return out


# 2. Letter drop: a soft paper "fwump" of an envelope dropping into a
#    mailbox, with a gentle low tap. "Posted."
def letter_drop():
    n = int(SR * 0.4)
    paper = lowpass_noise(n, lambda t: 2200)
    out = []
    for i in range(n):
        t = i / SR
        v = paper[i] * env(t, 0.01, 30) * 0.8
        if t >= 0.06:
            u = t - 0.06
            v += env(u, 0.003, 20) * (math.sin(2 * math.pi * 196 * u) + 0.4 * math.sin(2 * math.pi * 392 * u) * math.exp(-u * 25))
        out.append(v)
    return out


# 3. Chirp: two friendly little chirps, like a quick "hey!" in a
#    conversation.
def chirp():
    n = int(SR * 0.4)
    out = [0.0] * n
    for start, f0, f1 in ((0.0, 1400, 2000), (0.11, 1600, 2300)):
        phase = 0.0
        for i in range(int(start * SR), n):
            u = i / SR - start
            f = f0 + (f1 - f0) * min(1, u / 0.05)
            phase += 2 * math.pi * f / SR
            out[i] += env(u, 0.004, 26) * math.sin(phase)
    return out


# 4. Glass third: two clear glassy notes a third apart, struck almost
#    together. Bright and friendly, but softer than the success chime.
def glass_third():
    n = int(SR * 0.55)
    out = []
    for i in range(n):
        t = i / SR
        v = 0.0
        for start, f in ((0.0, 987.77), (0.04, 1244.5)):  # B5, D#6
            if t >= start:
                u = t - start
                v += env(u, 0.003, 8) * (math.sin(2 * math.pi * f * u) + 0.12 * math.sin(2 * math.pi * f * 2.76 * u) * math.exp(-u * 18))
        out.append(v)
    return out


# 5. Shimmer: a quick, light three-note shimmer stepping down, like a
#    small wind chime brushed once.
def shimmer():
    n = int(SR * 0.6)
    out = []
    notes = ((0.0, 1760.0), (0.045, 1567.98), (0.09, 1318.51))  # A6, G6, E6
    for i in range(n):
        t = i / SR
        v = 0.0
        for start, f in notes:
            if t >= start:
                u = t - start
                v += env(u, 0.002, 7) * math.sin(2 * math.pi * f * u)
        out.append(v)
    return out


# 6. Delivered: a soft wooden tap followed by a small bell, like a note
#    pushed under a door and a tiny "ding" that it arrived.
def delivered():
    n = int(SR * 0.55)
    out = []
    for i in range(n):
        t = i / SR
        v = 0.7 * env(t, 0.002, 40) * (math.sin(2 * math.pi * 520 * t) + 0.3 * math.sin(2 * math.pi * 1430 * t))
        if t >= 0.09:
            u = t - 0.09
            v += env(u, 0.003, 7) * (math.sin(2 * math.pi * 1318.5 * u) + 0.25 * math.sin(2 * math.pi * 2637 * u) * math.exp(-u * 12))
        out.append(v)
    return out


if __name__ == '__main__':
    for name, fn in [('reply_3_paper_plane', paper_plane), ('reply_4_letter_drop', letter_drop), ('reply_5_chirp', chirp),
                     ('reply_6_glass_third', glass_third), ('reply_7_shimmer', shimmer), ('reply_8_delivered', delivered)]:
        write(name + '.wav', fn())
    print('made 6 reply options')
