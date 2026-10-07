"""Builds trial versions of app sounds for the user to compare by ear.
Everything fades in and out (the user's rule, 2026-10-07)."""
import wave, struct, math, os, shutil

SRC = r'C:\Users\thoma\dev\AppleVis\AppleVis\Sources\Resources\Sounds'
OUT = r'C:\Users\thoma\dev\AppleVis\tools\sound_review'
os.makedirs(OUT, exist_ok=True)


def read(name):
    w = wave.open(os.path.join(SRC, name))
    ch, sw, sr = w.getnchannels(), w.getsampwidth(), w.getframerate()
    raw = w.readframes(w.getnframes())
    full = 2 ** (8 * sw - 1)
    frames = []
    step = sw * ch
    for i in range(0, len(raw), step):
        frames.append([int.from_bytes(raw[i + c * sw:i + (c + 1) * sw], 'little', signed=True) / full for c in range(ch)])
    return frames, ch, sw, sr


def write(name, frames, ch, sw, sr):
    full = 2 ** (8 * sw - 1) - 1
    out = bytearray()
    for f in frames:
        for c in range(ch):
            v = max(-1.0, min(1.0, f[c]))
            out += int(round(v * full)).to_bytes(sw, 'little', signed=True)
    w = wave.open(os.path.join(OUT, name), 'wb')
    w.setnchannels(ch); w.setsampwidth(sw); w.setframerate(sr)
    w.writeframes(bytes(out)); w.close()


def shaped(frames, sr, end_s, fade_in_ms=8, fade_out_ms=250):
    """Keeps the sound up to end_s, with a gentle fade-in and a cosine fade-out ending at end_s."""
    n = min(len(frames), int(end_s * sr))
    out = [list(f) for f in frames[:n]]
    fi = int(sr * fade_in_ms / 1000)
    for i in range(min(fi, n)):
        g = 0.5 - 0.5 * math.cos(math.pi * i / fi)
        out[i] = [x * g for x in out[i]]
    fo = int(sr * fade_out_ms / 1000)
    for k in range(min(fo, n)):
        i = n - fo + k
        g = 0.5 + 0.5 * math.cos(math.pi * k / fo)
        out[i] = [x * g for x in out[i]]
    return out


# ---- refresh
frames, ch, sw, sr = read('refresh.wav')
shutil.copy(os.path.join(SRC, 'refresh.wav'), os.path.join(OUT, 'refresh_1_current.wav'))
write('refresh_2_gentle_start_shorter.wav', shaped(frames, sr, 1.2, 8, 450), ch, sw, sr)
# Ends on the high note: stop during the high G (about 0.25 to 0.5 s) and let it ring out.
write('refresh_3_ends_on_high_note.wav', shaped(frames, sr, 0.62, 8, 220), ch, sw, sr)

# ---- success
frames, ch, sw, sr = read('success.wav')
shutil.copy(os.path.join(SRC, 'success.wav'), os.path.join(OUT, 'success_1_current.wav'))
write('success_2_gentle_start_shorter.wav', shaped(frames, sr, 0.85, 8, 300), ch, sw, sr)


# A new, original success chime in a major key: A, C sharp, E, rising, with a
# soft bell tone, the same pace as the current one. Fades in and out.
def bell(freq, t):
    # a few bell-like partials, each dying away at its own rate
    return (0.62 * math.sin(2 * math.pi * freq * t) * math.exp(-t * 4.2)
            + 0.22 * math.sin(2 * math.pi * freq * 2.0 * t) * math.exp(-t * 7.0)
            + 0.10 * math.sin(2 * math.pi * freq * 3.01 * t) * math.exp(-t * 11.0)
            + 0.06 * math.sin(2 * math.pi * freq * 4.2 * t) * math.exp(-t * 16.0))


notes = [(0.00, 440.00, 0.75), (0.09, 554.37, 0.80), (0.18, 659.26, 1.00)]  # A4, C#5, E5
dur = 0.9
n = int(sr * dur)
mono = []
for i in range(n):
    t = i / sr
    v = 0.0
    for start, f, amp in notes:
        if t >= start:
            u = t - start
            attack = min(1.0, u / 0.006)  # each note eases in over 6 ms
            v += amp * attack * bell(f, u)
    mono.append(v)
peak = max(abs(x) for x in mono)
target = 10 ** (-4.2 / 20)  # same peak as the current success sound
mono = [x / peak * target for x in mono]
stereo = [[x, x] for x in mono]
write('success_3_major_key_new.wav', shaped(stereo, sr, dur, 8, 300), 2, sw, sr)

print(sorted(os.listdir(OUT)))
