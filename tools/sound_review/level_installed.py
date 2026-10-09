"""Sets every app sound to its loudness group, measured by its loudest
50 ms moment (how loud it feels), not its whole-file average. Run after
installing any new sound. Leaves notification sounds alone. Only changes a
sound that's more than 1 dB off, and never raises a peak above -1 dB.
Agreed with the user 2026-10-07: Claude sets volumes as it sees fit."""
import math, os, wave

SOUNDS = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'AppleVis', 'Sources', 'Resources', 'Sounds')

# Loudest-moment targets in dB.
TIER = {
    # quiet: frequent, small
    'tab_change': -21, 'tab_change_home': -21, 'tab_change_discover': -21, 'tab_change_for_you': -21,
    'picker_tick': -21, 'loading_start': -21, 'screen_close': -21, 'article_open': -21,
    # waiting ticks: subtle under VoiceOver
    'refresh_tick': -22, 'mouse_patter': -22,
    'tip_popup': -18,
    # frequent confirmation, a little under the rest
    'marked_read': -16, 'all_caught_up': -14, 'unsaved': -16, 'unfollowed': -16, 'unrecommended': -16,
    # medium: confirmations
    'success': -13, 'bookmark_saved': -13, 'reply': -13, 'refresh': -13, 
    'podcast_play': -13, 'podcast_pause': -13, 'podcast_queue': -13, 'followed': -13, 'recommended': -13, 'guideline_ding': -13,
    # fuller: rare moments, errors, going offline
    'error': -11, 'offline': -11, 'welcome': -11, 'search_complete': -11, 'sync_complete': -11, 'download_complete': -11,
}


def load(p):
    w = wave.open(p)
    ch, sw, sr = w.getnchannels(), w.getsampwidth(), w.getframerate()
    raw = w.readframes(w.getnframes()); w.close()
    return [int.from_bytes(raw[i:i + sw], 'little', signed=True) for i in range(0, len(raw), sw)], ch, sw, sr


def loudest(v, ch, sw, sr):
    full = 2 ** (8 * sw - 1)
    m = [v[i] / full for i in range(0, len(v), ch)]
    win = int(sr * 0.05)
    return 20 * math.log10(max(math.sqrt(sum(x * x for x in m[s:s + win]) / win)
                               for s in range(0, max(1, len(m) - win), max(1, win // 4))))


if __name__ == '__main__':
    for name, target in TIER.items():
        p = os.path.join(SOUNDS, name + '.wav')
        if not os.path.exists(p):
            continue
        v, ch, sw, sr = load(p)
        full = 2 ** (8 * sw - 1)
        current = loudest(v, ch, sw, sr)
        change = target - current
        if abs(change) < 1.0:
            continue
        peak = max(abs(x) for x in v) / full
        change = min(change, 20 * math.log10(10 ** (-1 / 20) / peak))
        g = 10 ** (change / 20)
        out = bytearray()
        for x in v:
            out += int(round(max(-full, min(full - 1, x * g)))).to_bytes(sw, 'little', signed=True)
        o = wave.open(p, 'wb'); o.setnchannels(ch); o.setsampwidth(sw); o.setframerate(sr); o.writeframes(bytes(out)); o.close()
        print(f'{name}: {current:.1f} -> {current + change:.1f} dB')
