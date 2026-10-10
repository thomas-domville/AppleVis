"""End of group options for Fetch (2026-10-10).

Plays when VoiceOver, a braille display, or Switch Control lands on the last
row of a group in Fetch: the last new comment, or the post itself when the
group has no comments. It says "this is the last one here", so you can mark
the group as read before moving on. Heard once per group, so these are short
and sit in the quiet group (-18), a little below the guideline ding.

Built from the chosen family (the clip's tap, the mallet, the bell, the felt
piano, the paper fold). Every one fades in and out.

For the user to pick by ear. The guideline ding is copied in as
end_of_group_0_guideline_ding.wav for comparison, and option 1 is the ding
itself, turned down and pitched a little lower, as its sibling."""
import math, os, shutil, wave
from make_family_finish import (HERE, SOUNDS, SR, write, env, bell, mallet, felt, tap, build, noise_burst)

G4, A4, C5, D5, E5, G5, C6 = 392.0, 440.0, 523.25, 587.33, 659.26, 783.99, 1046.5


def read_mono(path):
    w = wave.open(path)
    ch, width, n = w.getnchannels(), w.getsampwidth(), w.getnframes()
    raw = w.readframes(n)
    w.close()
    full = 2 ** (8 * width - 1)
    out = []
    step = ch * width
    for i in range(0, len(raw), step):
        v = int.from_bytes(raw[i:i + width], 'little', signed=width > 1)
        out.append(v / full)
    return out


def ding_lower():
    # 1. The guideline ding's sibling: the same chime, a fourth lower and a
    #    touch longer, so it sounds related but means something else.
    src = read_mono(os.path.join(SOUNDS, 'guideline_ding.wav'))
    ratio = 0.75
    n = int(len(src) / ratio)
    return [src[int(i * ratio)] + (src[min(len(src) - 1, int(i * ratio) + 1)] - src[int(i * ratio)]) * ((i * ratio) % 1) for i in range(n)]


def two_bells_down():
    # 2. "That's the end": two soft bells stepping down, E then C.
    return build(0.5, [(0, E5, 0.8, lambda f, u: bell(f, u, 9)), (0.09, C5, 1.0, lambda f, u: bell(f, u, 7))])


def felt_settle():
    # 3. One low felt-piano note with a quiet fifth above, settling.
    return build(0.5, [(0, C5, 1.0, lambda f, u: felt(f, u, 7)), (0.0, G5, 0.3, lambda f, u: felt(f, u, 9))])


def mallet_tock():
    # 4. A wooden mallet "tock", like reaching the end of a shelf.
    return build(0.35, [(0, G4, 1.0, lambda f, u: mallet(f, u, 16)), (0.0, 1180, 0.35, lambda f, u: tap(f, u))])


def page_end():
    # 5. "End of the page": one tiny paper fold, then a small low bell.
    n = int(SR * 0.5)
    out = [0.0] * n
    burst = noise_burst(int(SR * 0.05), 2600)
    for j, x in enumerate(burst):
        out[j] += 0.5 * x * env(j / SR, 0.004, 60)
    for i in range(int(0.06 * SR), n):
        out[i] += bell(A4, i / SR - 0.06, 8)
    return out


def soft_blip_pair():
    # 6. Two very small, round blips on the same low note: quiet and quick,
    #    for people who hear it many times in a row.
    return build(0.4, [(0, D5, 0.9, lambda f, u: mallet(f, u, 22)), (0.12, D5, 0.7, lambda f, u: mallet(f, u, 22))])


OPTIONS = {
    'end_of_group_1_ding_sibling': ding_lower,
    'end_of_group_2_two_bells_down': two_bells_down,
    'end_of_group_3_felt_settle': felt_settle,
    'end_of_group_4_mallet_tock': mallet_tock,
    'end_of_group_5_page_end': page_end,
    'end_of_group_6_soft_blip_pair': soft_blip_pair,
}

if __name__ == '__main__':
    shutil.copy(os.path.join(SOUNDS, 'guideline_ding.wav'), os.path.join(HERE, 'end_of_group_0_guideline_ding.wav'))
    for name, fn in OPTIONS.items():
        write(os.path.join(HERE, name + '.wav'), fn(), -18)
    print('made', len(OPTIONS), 'End of Group options')
