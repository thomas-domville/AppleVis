"""All Caught Up options (2026-10-08).

Plays when everything is read: the last item in Fetch, Mark All as Read in
Fetch, and the same in Home's New view. Not "that worked" (the success
sound) but "nothing left, relax": each one comes to rest. Built from the
chosen family (the clip's tap, the mallet, the bell, the felt piano, the
bubbles, the paper fold), and every one fades in and out.

For the user to pick by ear. The current success sound is copied in as
caught_up_0_current_success.wav for comparison. Levelled a little softer
than confirmations (-14), since it follows the marked-read sound."""
import math, os, shutil
from make_family_finish import (HERE, SOUNDS, SR, write, env, bell, mallet, felt, tap, build, noise_burst)

C4, E4, G4, A4, C5, D5, E5, G5, A5, C6 = 261.63, 329.63, 392.0, 440.0, 523.25, 587.33, 659.26, 783.99, 880.0, 1046.5


def soft_bell(decay):
    return lambda f, u: bell(f, u, decay)


def settle_bells():
    # 1. Three soft bells stepping down and coming to rest on C: "all done".
    return build(1.2, [(0, G5, 0.7, soft_bell(7)), (0.14, E5, 0.75, soft_bell(6)), (0.3, C5, 1.0, soft_bell(3.5))])


def mallet_woof():
    # 2. Goldie's nod: a low, happy two-note "wuff-wuff" on the mallet, then
    #    a soft bell above it, like a wagging tail.
    return build(1.0, [(0, A4, 0.9, lambda f, u: mallet(f, u, 14)), (0.13, C5, 1.0, lambda f, u: mallet(f, u, 12)),
                       (0.34, E5, 0.55, soft_bell(4))])


def felt_cadence():
    # 3. Felt piano: a short phrase that resolves home, C E G then the low C.
    return build(1.3, [(0, C5, 0.75, felt), (0.11, E5, 0.75, felt), (0.22, G5, 0.8, felt),
                       (0.4, C4, 0.9, lambda f, u: felt(f, u, 3.5)), (0.4, C5, 0.5, lambda f, u: felt(f, u, 3.5))])


def bubbles_settle():
    # 4. The refresh bubbles, slowing and sinking, landing on a warm low bell.
    n = int(SR * 1.2)
    out = [0.0] * n
    for start, base in ((0, 820), (0.11, 680), (0.24, 560)):
        phase = 0.0
        for i in range(int(start * SR), n):
            u = i / SR - start
            f = base * (1 - 0.35 * (1 - math.exp(-u * 25)))
            phase += 2 * math.pi * f / SR
            out[i] += 0.8 * env(u, 0.003, 15) * math.sin(phase)
    for i in range(int(0.36 * SR), n):
        out[i] += 0.9 * bell(G4, i / SR - 0.36, 3.5)
    return out


def fold_and_bell():
    # 5. "Put away": the screen-close paper fold, then one soft bell.
    n = int(SR * 1.1)
    out = [0.0] * n
    for start, cutoff in ((0.0, 3400), (0.06, 2000)):
        s = int(start * SR)
        burst = noise_burst(int(SR * 0.06), cutoff)
        for j, x in enumerate(burst):
            if s + j < n:
                out[s + j] += 0.6 * x * env(j / SR, 0.004, 55)
    for i in range(int(0.16 * SR), n):
        out[i] += bell(E5, i / SR - 0.16, 3.2)
    return out


def warm_sigh():
    # 6. A soft major chord that blooms and settles, like a contented sigh,
    #    with a single tap of the clip to start.
    n = int(SR * 1.3)
    out = []
    for i in range(n):
        t = i / SR
        swell = min(1, t / 0.18) * math.exp(-t * 2.4)
        pad = sum(math.sin(2 * math.pi * f * t) for f in (C5, E5, G5)) / 3
        out.append(0.9 * swell * pad + (0.5 * tap(1180, t) if t < 0.2 else 0))
    return out


OPTIONS = {
    'caught_up_1_settling_bells': settle_bells,
    'caught_up_2_goldie_wuff': mallet_woof,
    'caught_up_3_felt_resolve': felt_cadence,
    'caught_up_4_bubbles_settle': bubbles_settle,
    'caught_up_5_put_away': fold_and_bell,
    'caught_up_6_contented_sigh': warm_sigh,
}

if __name__ == '__main__':
    shutil.copy(os.path.join(SOUNDS, 'success.wav'), os.path.join(HERE, 'caught_up_0_current_success.wav'))
    for name, fn in OPTIONS.items():
        write(os.path.join(HERE, name + '.wav'), fn(), -14)
    print('made', len(OPTIONS), 'All Caught Up options')
