"""Original tab-change options: switching between Home, Discover and For You.
Frequent, so short and in the quiet tier. Every one fades in and out.
Made 2026-10-07."""
import math, os, random, wave

OUT = os.path.dirname(os.path.abspath(__file__))
SR = 44100
random.seed(41)


def write(name, mono, rms_db=-24.0):
    n = len(mono)
    fi = int(SR * 0.004)
    fo = max(1, int(n * 0.35))
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


def noise(n, cutoff):
    a = math.exp(-2 * math.pi * cutoff / SR)
    out, lp = [], 0.0
    for _ in range(n):
        lp = (1 - a) * random.uniform(-1, 1) + a * lp
        out.append(lp)
    return out


def note(f, dur, decay=22, hollow=0.25):
    n = int(SR * dur)
    return [env(i / SR, 0.002, decay) * (math.sin(2 * math.pi * f * i / SR)
                                         + hollow * math.sin(2 * math.pi * f * 2.76 * i / SR) * math.exp(-i / SR * 50))
            for i in range(n)]


# 1. Felt click: a muted little switch click, like a soft-touch button.
def felt_click():
    n = int(SR * 0.09)
    burst = noise(n, 1800)
    return [burst[i] * env(i / SR, 0.001, 70) + 0.4 * env(i / SR, 0.001, 60) * math.sin(2 * math.pi * 900 * i / SR) for i in range(n)]


# 2. Page flick: a single quick page turn, matching the paper "fold" of
#    screen close.
def page_flick():
    n = int(SR * 0.14)
    burst = noise(n, 3200)
    return [burst[i] * math.sin(math.pi * min(1, (i / SR) / 0.14)) ** 2 for i in range(n)]


# 3. Wood block: one soft, short wooden knock, like the bookmark clip's
#    little brother.
def wood_block():
    return note(880, 0.14, decay=40, hollow=0.3)


# 4. Pop: a single tiny soft "bloop", a cousin of the refresh bubbles.
def pop():
    n = int(SR * 0.13)
    out, phase = [], 0.0
    for i in range(n):
        t = i / SR
        f = 600 + 500 * (1 - math.exp(-t * 40))
        phase += 2 * math.pi * f / SR
        out.append(env(t, 0.003, 30) * math.sin(phase))
    return out


# 5. Glass tap: one very light, clear glassy tap.
def glass_tap():
    return note(1760, 0.15, decay=30, hollow=0.12)


if __name__ == '__main__':
    for name, fn in [('tab_change_3_felt_click', felt_click), ('tab_change_4_page_flick', page_flick),
                     ('tab_change_5_wood_block', wood_block), ('tab_change_6_pop', pop),
                     ('tab_change_7_glass_tap', glass_tap)]:
        write(name + '.wav', fn())
    # 8. A set: each tab its own pitch, same soft wooden tone. Low for Home,
    #    middle for Discover, high for For You (G5, C6, E6).
    for tab, f in (('home', 783.99), ('discover', 1046.5), ('for_you', 1318.5)):
        write(f'tab_change_8_set_{tab}.wav', note(f, 0.16, decay=28, hollow=0.2))
    print('made tab options')


# The chosen design (2026-10-07): the pop (option 6), pitched per tab, low
# for Home, middle for Discover, high for For You. Same shape, scaled.
def pop_at(scale):
    n = int(SR * 0.13)
    out, phase = [], 0.0
    for i in range(n):
        t = i / SR
        f = (600 + 500 * (1 - math.exp(-t * 40))) * scale
        phase += 2 * math.pi * f / SR
        out.append(env(t, 0.003, 30) * math.sin(phase))
    return out


def make_pop_set():
    for tab, scale in (('home', 0.75), ('discover', 1.0), ('for_you', 1.335)):
        write(f'tab_pop_{tab}.wav', pop_at(scale))
