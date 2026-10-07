"""Round 2 of trial sounds. Every new version fades in and out."""
import math, os, shutil

ns = {}
src = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'make_round1.py'), encoding='utf-8').read()
exec(src.split('# ---- refresh')[0], ns)
read, write, shaped, SRC, OUT = ns['read'], ns['write'], ns['shaped'], ns['SRC'], ns['OUT']


def current(name, label):
    shutil.copy(os.path.join(SRC, name + '.wav'), os.path.join(OUT, f'{label}_1_current.wav'))


def gain(frames, db):
    g = 10 ** (db / 20)
    return [[x * g for x in f] for f in frames]


def softened(frames, sr, cutoff=4500):
    # A gentle one-pole low-pass: takes the edge off very bright sounds.
    a = math.exp(-2 * math.pi * cutoff / sr)
    out, prev = [], None
    for f in frames:
        prev = f if prev is None else [(1 - a) * x + a * p for x, p in zip(f, prev)]
        out.append(prev)
    return out


def trial(name, label, end_s, fade_out_ms, suffix='gentle_start_shorter', fade_in_ms=8, db=0.0, start_s=0.0, soften=False):
    frames, ch, sw, sr = read(name + '.wav')
    frames = frames[int(start_s * sr):]
    if soften:
        frames = softened(frames, sr)
    if db:
        frames = gain(frames, db)
    write(f'{label}_{suffix}.wav', shaped(frames, sr, end_s, fade_in_ms, fade_out_ms), ch, sw, sr)


# Long sounds: keep the body, shorten the fade.
current('reply', 'reply'); trial('reply', 'reply', 1.0, 400, '2_gentle_start_shorter')
current('screen_close', 'screen_close'); trial('screen_close', 'screen_close', 0.8, 300, '2_gentle_start_shorter')
current('search_complete', 'search_complete')
trial('search_complete', 'search_complete', 1.6, 500, '2_shorter_with_voiceover_on')

# Silent padding only: should sound the same, just ends sooner.
current('welcome', 'welcome'); trial('welcome', 'welcome', 1.75, 300, '2_gentle_start_padding_removed')
current('error', 'error'); trial('error', 'error', 0.55, 150, '2_gentle_start_padding_removed')
trial('error', 'error', 0.55, 150, '3_softer_for_small_errors', db=-5.0)
current('tip_popup', 'tip_popup'); trial('tip_popup', 'tip_popup', 0.35, 120, '2_gentle_start_padding_removed')
current('download_complete', 'download_complete'); trial('download_complete', 'download_complete', 0.6, 150, '2_gentle_start_padding_removed')

# Sync complete: slow to reach full volume. Version 3 starts closer to its peak.
current('sync_complete', 'sync_complete')
trial('sync_complete', 'sync_complete', 1.75, 250, '2_gentle_start_padding_removed')
trial('sync_complete', 'sync_complete', 1.45, 250, '3_crisper_start', fade_in_ms=20, start_s=0.3)

# Very bright: a softer-edged version.
current('bookmark_saved', 'bookmark_saved')
trial('bookmark_saved', 'bookmark_saved', 0.76, 200, '2_gentle_start')
trial('bookmark_saved', 'bookmark_saved', 0.76, 200, '3_gentle_start_softer_edge', soften=True)

# Much louder than everything else: 8 dB quieter, with a gentle start.
for name in ['tab_change', 'loading_start', 'picker_tick']:
    frames, ch, sw, sr = read(name + '.wav')
    current(name, name)
    dur = len(frames) / sr
    trial(name, name, dur, max(5, int(dur * 1000 * 0.3)), '2_quieter_gentle_start', fade_in_ms=3, db=-8.0)

# ---- Podcast Play and Pause: new, original, and different from each other.
# Two soft mallet notes: rising for Play, falling for Pause.
sr, sw = 44100, 3


def mallet(freq, t):
    return (0.75 * math.sin(2 * math.pi * freq * t) * math.exp(-t * 9.0)
            + 0.18 * math.sin(2 * math.pi * freq * 2.0 * t) * math.exp(-t * 16.0)
            + 0.07 * math.sin(2 * math.pi * freq * 3.0 * t) * math.exp(-t * 24.0))


def two_notes(f1, f2, gap=0.075, dur=0.38, peak_db=-6.0):
    n = int(sr * dur)
    mono = []
    for i in range(n):
        t = i / sr
        v = mallet(f1, t) * min(1.0, t / 0.005)
        if t >= gap:
            u = t - gap
            v += 0.9 * mallet(f2, u) * min(1.0, u / 0.005)
        mono.append(v)
    p = max(abs(x) for x in mono)
    g = 10 ** (peak_db / 20) / p
    return shaped([[x * g, x * g] for x in mono], sr, dur, 6, 120)


shutil.copy(os.path.join(SRC, 'podcast_play.wav'), os.path.join(OUT, 'podcast_play_and_pause_1_current_same_sound.wav'))
write('podcast_play_2_new_rising.wav', two_notes(523.25, 783.99), 2, sw, sr)   # C5 then G5
write('podcast_pause_2_new_falling.wav', two_notes(783.99, 523.25), 2, sw, sr)  # G5 then C5

print(len(os.listdir(OUT)), 'files')
