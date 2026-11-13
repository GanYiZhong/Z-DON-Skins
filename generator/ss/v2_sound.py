"""Original 8-bit SFX for YataiDONSimpleStyle (v2 standalone): every sound the skin used to inherit from
PyTaikoGreen is synthesised here from pulse / triangle / noise voices, so no Green audio is ever loaded.

One small motif family keeps the set consistent: C major pentatonic, pulse leads (12.5 / 25 / 50 %
duty) with a soft one-pole low-pass, short attack/release envelopes (no clicks), peaks near -9 dBFS.
1P cues sit an octave below 2P cues. Output: mono 44.1 kHz Ogg Vorbis (what the Green files were).

    write_all(sounds_dir) -> number of files written
"""
from __future__ import annotations

import os

import numpy as np
import soundfile as sf

SR = 44100
PEAK = 0.35          # ~ -9 dBFS
rng = np.random.default_rng(20261029)   # fixed seed: rebuilds are identical


# ---------------------------------------------------------------- voices
def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def _env(n, attack=0.003, release=0.03, decay=None):
    t = np.arange(n) / SR
    e = np.ones(n)
    a = max(1, int(attack * SR))
    e[:a] = np.linspace(0, 1, a)
    if decay:
        e *= np.exp(-t / decay)
    r = min(n, max(1, int(release * SR)))
    e[-r:] *= np.linspace(1, 0, r)
    return e


def _lp(x, k=0.35):
    """one-pole low-pass: takes the fizz off raw pulse edges"""
    from scipy.signal import lfilter
    return lfilter([k], [1.0, k - 1.0], x)


def tone(f, dur, wave="pulse", duty=0.25, vol=1.0, slide=0.0, vib=0.0, decay=None, attack=0.003, release=0.03):
    n = max(1, int(dur * SR))
    t = np.arange(n) / SR
    freq = f * (2 ** (slide * t / max(dur, 1e-6) / 12))      # slide in semitones over the note
    if vib:
        freq = freq * (1 + 0.012 * np.sin(2 * np.pi * vib * t))
    ph = np.cumsum(freq) / SR % 1.0
    if wave == "pulse":
        x = np.where(ph < duty, 1.0, -1.0)
        x = _lp(x, 0.3)
    elif wave == "tri":
        x = 4 * np.abs(ph - 0.5) - 1
    else:
        raise ValueError(wave)
    return x * _env(n, attack, release, decay) * vol


def noise(dur, vol=1.0, decay=None, k=0.5, period=1, attack=0.001, release=0.02):
    """NES-style noise: held random steps (period in samples = pitch), then low-passed"""
    n = max(1, int(dur * SR))
    steps = rng.uniform(-1, 1, n // max(1, period) + 2)
    x = np.repeat(steps, max(1, period))[:n]
    x = _lp(x, k)
    return x * _env(n, attack, release, decay) * vol


def silence(dur):
    return np.zeros(int(dur * SR))


def cat(*parts):
    return np.concatenate(parts)


def mix(*tracks):
    n = max(len(t) for t in tracks)
    out = np.zeros(n)
    for t in tracks:
        out[:len(t)] += t
    return out


def at(x, sec):
    return cat(silence(sec), x)


def seq(notes, step, wave="pulse", duty=0.25, vol=1.0, gate=0.85, decay=None):
    """notes: midi numbers (None = rest); each lasts `step` seconds (tuple (n, beats) for longer)"""
    parts = []
    for item in notes:
        n, beats = item if isinstance(item, tuple) else (item, 1)
        d = step * beats
        if n is None:
            parts.append(silence(d))
        else:
            parts.append(cat(tone(midi(n), d * gate, wave, duty, vol, decay=decay), silence(d * (1 - gate))))
    return cat(*parts)


# ---------------------------------------------------------------- building blocks
C4, D4, E4, G4, A4 = 60, 62, 64, 67, 69
PENTA = [0, 2, 4, 7, 9]


def blip(n=84, dur=0.035, duty=0.125, vol=0.8):
    return tone(midi(n), dur, duty=duty, vol=vol, release=0.015)


def _pitch(x):
    return x[0] if isinstance(x, tuple) else x


def _tr(x, tr):
    if x is None:
        return None
    return (x[0] + tr, x[1]) if isinstance(x, tuple) else x + tr


def jingle(notes, step=0.07, tr=0, duty=0.25, tail=True, bass=True):
    lead = seq([_tr(x, tr) for x in notes], step, duty=duty, gate=0.8)
    parts = [lead]
    pitched = [_pitch(x) for x in notes if x is not None]
    if bass:
        root = pitched[0] + tr - 24
        parts.append(tone(midi(root), len(lead) / SR, "tri", vol=0.55, release=0.08))
    if tail:   # a soft echo of the last note
        last = pitched[-1] + tr
        parts.append(at(tone(midi(last + 12), 0.18, duty=0.125, vol=0.25, decay=0.08), len(lead) / SR))
    return mix(*parts)


def sweep(f0, semis, dur, duty=0.5, vol=0.7):
    return tone(f0, dur, duty=duty, vol=vol, slide=semis, release=0.04)


def thump(f=110, dur=0.18, vol=1.0):
    return mix(tone(f, dur, "tri", vol=vol, slide=-14, decay=0.06, release=0.04),
               noise(0.05, 0.5 * vol, decay=0.02, k=0.6))


def bgm(chords, melody, bpm=112, bars_rep=2, duty=0.25):
    """a gentle 4/4 loop: triangle bass on beats, 12.5 % arpeggio on eighths, pulse melody on top,
    soft noise hats on the off-beats. chords: list of (root midi, 'maj'|'min'); one bar each."""
    beat = 60.0 / bpm
    bass, arp, hat = [], [], []
    for root, q in chords:
        third = 4 if q == "maj" else 3
        bass.append(seq([root - 12, root - 5, root - 12, root - 5], beat, "tri", vol=0.6, gate=0.7))
        arp.append(seq([root + i for i in (0, third, 7, 12, third + 12, 7, third, 7)], beat / 2,
                       duty=0.125, vol=0.18, gate=0.6))
        hat.append(cat(*[cat(silence(beat / 2), noise(0.03, 0.12, decay=0.012, k=0.9), silence(beat / 2 - 0.03))
                         for _ in range(4)]))
    one = mix(cat(*bass), cat(*arp), cat(*hat), seq(melody, beat / 2, duty=duty, vol=0.42, gate=0.8))
    return cat(*([one] * bars_rep))


# ---------------------------------------------------------------- the catalogue (relative path -> samples)
def catalogue():
    S = {}
    # ---- shared counters / cursor family
    S["result/num_up"] = blip(96, 0.03)
    S["dan_result/num_up"] = blip(91, 0.03)
    S["song_select/add_favorite"] = mix(seq([84, 88, 91, 96], 0.045, duty=0.125, vol=0.7, gate=0.9),
                                        at(tone(midi(100), 0.25, duty=0.125, vol=0.3, decay=0.09), 0.18))
    S["entry/select_costume"] = jingle([72, 79], 0.06, bass=False)
    S["global/voice_timer_0"] = cat(blip(81, 0.09, 0.5, 0.7), silence(0.06), blip(81, 0.09, 0.5, 0.7),
                                    silence(0.06), blip(86, 0.2, 0.5, 0.7))
    S["result/retry_transition"] = mix(sweep(midi(60), 24, 0.35, 0.25, 0.5), noise(0.35, 0.2, k=0.3))
    S["result/crash"] = mix(noise(0.45, 0.9, decay=0.12, k=0.7, period=3), thump(90, 0.25, 0.8))
    S["game_over/jingle"] = jingle([72, 71, 67, None, 64, 62, (60, 3)], 0.12, duty=0.5)

    # ---- result "voices": short melodic cheers, 2P an octave up
    voices = {
        "clear_voice": [67, 72, 76, (79, 2)],
        "fail_voice": [69, 65, (62, 3)],
        "full_combo_voice": [72, 76, 79, 84, 79, (84, 3)],
        "max_clear_voice": [72, 74, 76, 79, 81, (84, 3)],
        "max_fail_voice": [72, 69, 67, 64, (60, 3)],
    }
    for name, notes in voices.items():
        S[f"result/{name}_1p"] = jingle(notes, 0.075)
        S[f"result/{name}_2p"] = jingle(notes, 0.075, tr=12, bass=False)

    # ---- entry
    S["entry/name_entry_vo"] = jingle([67, 72, 76], 0.08)
    S["entry/name_select_bgm"] = bgm([(60, "maj"), (65, "maj"), (69, "min"), (67, "maj")],
                                     [76, None, 79, 76, 74, None, 72, None, 77, None, 76, 74, 72, None, 69, None,
                                      72, None, 76, 72, 69, None, 67, None, 71, None, 74, 71, 67, None, None, None],
                                     bpm=116)
    # ---- settings: a calm loop (the settings screen plays "bgm")
    S["settings/bgm"] = bgm([(65, "maj"), (60, "maj"), (62, "min"), (67, "maj")],
                            [69, None, None, 72, None, 69, 67, None, 64, None, None, 67, None, None, None, None,
                             62, None, 65, 69, None, 67, 65, None, 67, None, 71, None, 74, None, None, None],
                            bpm=96, duty=0.125)
    # ---- loading: a quiet ambience pad (the loading screen expects a Sounds/loading folder)
    S["loading/ambience"] = mix(*[tone(midi(n), 2.4, "tri", vol=0.18, vib=4.5, attack=0.4, release=0.8)
                                  for n in (60, 67, 72)])

    # ---- title
    S["title/bachi_hit"] = thump(130, 0.16)
    S["title/bachi_swipe"] = noise(0.14, 0.45, k=0.25, attack=0.04, release=0.07)
    S["title/camera"] = cat(noise(0.025, 0.8, decay=0.01, k=0.9), silence(0.05), noise(0.04, 0.6, decay=0.015, k=0.8))
    S["title/drumroll"] = cat(*[mix(thump(140, 0.06, 0.6), noise(0.03, 0.3, k=0.8)) for _ in range(16)])
    S["title/drumroll_end"] = mix(thump(110, 0.3, 1.0), noise(0.5, 0.35, decay=0.18, k=0.85, period=2))
    S["title/error"] = cat(tone(midi(50), 0.12, duty=0.5, vol=0.6), silence(0.04), tone(midi(46), 0.22, duty=0.5, vol=0.6))

    # ---- song select voices (option names, sort, sound select, genre calls): 2-3 note motifs
    opts = ["abekobe", "baisaku", "detarame", "doron", "kimagure", "sanbai", "shinuchi", "yonbai"]
    for i, o in enumerate(opts):
        base = 72 + PENTA[i % 5] + (12 if i >= 5 else 0)
        S[f"song_select/options/{o}_1p"] = jingle([base - 12, base - 5], 0.06, bass=False, tail=False)
        S[f"song_select/options/{o}_2p"] = jingle([base, base + 7], 0.06, bass=False, tail=False)
    S["song_select/voice_diff_sort_confirm"] = jingle([72, 76, 79], 0.06)
    S["song_select/voice_diff_sort_level"] = jingle([79, 76], 0.07, bass=False)
    S["song_select/voice_hitsound_select_1p"] = jingle([67, 72], 0.07, bass=False)
    S["song_select/voice_hitsound_select_2p"] = jingle([79, 84], 0.07, bass=False)
    for g, notes in {"9": [72, 74, 76], "10": [76, 74, 72], "11": [72, 79, 76], "15": [67, 72, 79]}.items():
        S[f"song_select/genre_voice/{g}"] = jingle(notes, 0.07, bass=False)

    # ---- retry game (the skin disables it; complete anyway so nothing falls through)
    S["retry_game/appear"] = mix(sweep(midi(72), 12, 0.2, 0.125, 0.5), at(blip(96, 0.08), 0.2))
    S["retry_game/bgm"] = bgm([(57, "min"), (53, "maj"), (60, "maj"), (55, "maj")],
                              [69, None, 72, None, 76, None, 72, None, 69, None, 72, 74, 72, None, None, None,
                               67, None, 72, None, 76, None, 79, None, 74, None, 71, None, 67, None, None, None],
                              bpm=124)
    S["retry_game/clear"] = jingle([72, 76, 79, 84, (88, 3)], 0.08)
    S["retry_game/fail"] = jingle([67, 63, (60, 3)], 0.1)
    S["retry_game/fireworks"] = cat(sweep(midi(60), 20, 0.3, 0.125, 0.35),
                                    mix(noise(0.6, 0.8, decay=0.2, k=0.6, period=4), noise(0.6, 0.3, k=0.95)))
    S["retry_game/lamp_up"] = sweep(midi(72), 7, 0.12, 0.25, 0.6)
    S["retry_game/lamp_down"] = sweep(midi(79), -7, 0.12, 0.25, 0.6)
    S["retry_game/moon"] = mix(*[tone(midi(n), 1.2, "tri", vol=0.3, vib=5, attack=0.15, release=0.4) for n in (72, 76, 79)])
    S["retry_game/whistle"] = tone(midi(88), 0.4, "tri", vol=0.6, slide=5, vib=7, release=0.08)
    S["retry_game/wind"] = noise(1.2, 0.35, k=0.12, attack=0.4, release=0.5)
    for name, notes in {"voice_about_1": [72, 74], "voice_about_2": [74, 72], "voice_clear": [72, 79, 84],
                        "voice_don": [60, 60], "voice_fail": [69, 64], "voice_more": [72, 76, 74],
                        "voice_renda": [72, 72, 72, 76], "voice_yoi": [76, 79]}.items():
        S[f"retry_game/{name}"] = jingle(notes, 0.07, bass=False)
    return S


def write_all(sounds_dir):
    n = 0
    for rel, x in catalogue().items():
        x = np.asarray(x, dtype=np.float64)
        pk = float(np.max(np.abs(x))) or 1.0
        x = (x / pk * PEAK).astype(np.float32)
        p = os.path.join(sounds_dir, rel + ".ogg")
        os.makedirs(os.path.dirname(p), exist_ok=True)
        # libsndfile 1.2's Vorbis encoder overflows the stack on one large write: feed it in blocks
        with sf.SoundFile(p, "w", SR, 1, format="OGG", subtype="VORBIS") as f:
            for i in range(0, len(x), 2048):
                f.write(x[i:i + 2048])
        n += 1
    return n


if __name__ == "__main__":
    import sys
    print(write_all(sys.argv[1]))
