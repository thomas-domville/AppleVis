"""Follow sound options, built around the chosen bookmark "clip" (two soft
wooden taps) so Save and Follow sound related but distinct: a wooden tap,
then a small bell for "you'll hear about this". Every one fades in and
out; levelled like other confirmations. Made 2026-10-07."""
import math, os, shutil, wave

OUT = os.path.dirname(os.path.abspath(__file__))
SOUNDS = os.path.join(OUT, '..', '..', 'AppleVis', 'Sources', 'Resources', 'Sounds')
SR = 44100


def write(name, mono, rms_db=-20.0):
    n = len(mono)
    fi = int(SR * 0.006)
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


def tap(f, u, amp=1.0):
    """The clip's wooden tap: a short note with a hollow overtone."""
    return amp * env(u, 0.002, 45) * (math.sin(2 * math.pi * f * u) + 0.3 * math.sin(2 * math.pi * f * 2.76 * u) * math.exp(-u * 60))


def bell(f, u, amp=1.0, decay=8.0):
    return amp * env(u, 0.003, decay) * (math.sin(2 * math.pi * f * u)
                                         + 0.22 * math.sin(2 * math.pi * f * 2.0 * u) * math.exp(-u * 12)
                                         + 0.06 * math.sin(2 * math.pi * f * 3.0 * u) * math.exp(-u * 18))


def build(dur, parts):
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        out.append(sum(fn(t - start) for start, fn in parts if t >= start))
    return out


OPTIONS = {
    # 1. One clip tap, then a tiny high bell: the closest relative of Save.
    'follow_1_tap_and_bell': (0.5, [
        (0.0, lambda u: tap(1180, u, 0.8)),
        (0.08, lambda u: bell(1318.5, u, 0.7)),            # E6
    ]),
    # 2. The same, with a warmer, lower bell that rings a little longer.
    'follow_2_tap_and_warm_bell': (0.6, [
        (0.0, lambda u: tap(1180, u, 0.8)),
        (0.08, lambda u: bell(1046.5, u, 0.8, decay=6.0)),  # C6
    ]),
    # 3. Both clip taps, then a small bell: Save's sound with a bell added.
    'follow_3_clip_then_bell': (0.55, [
        (0.0, lambda u: tap(1180, u, 0.7)),
        (0.055, lambda u: tap(1480, u, 1.0)),
        (0.14, lambda u: bell(1568.0, u, 0.55)),            # G6
    ]),
    # 4. One tap, then a tiny two-note "ding-ding", like a notification
    #    being set up.
    'follow_4_tap_and_ding_ding': (0.6, [
        (0.0, lambda u: tap(1180, u, 0.8)),
        (0.08, lambda u: bell(1318.5, u, 0.55, decay=14)),  # E6
        (0.17, lambda u: bell(1568.0, u, 0.55)),            # G6
    ]),
    # 5. One soft tap and a gentle bell that blooms and fades slowly: the
    #    calmest of the set.
    'follow_5_tap_and_soft_bloom': (0.7, [
        (0.0, lambda u: tap(980, u, 0.6)),
        (0.06, lambda u: bell(1174.7, u, 0.8, decay=5.0) * min(1, u / 0.03)),  # D6, eased in
    ]),
}

if __name__ == '__main__':
    shutil.copy(os.path.join(SOUNDS, 'bookmark_saved.wav'), os.path.join(OUT, 'follow_0_save_clip_for_comparison.wav'))
    for name, (dur, parts) in OPTIONS.items():
        write(name + '.wav', build(dur, parts))
    print('made', len(OPTIONS), 'follow options')
