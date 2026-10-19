"""Synthesize original temple bell and shankh (conch) sounds for the Puja screen.

Pure math, no samples: these sounds are original works owned by the app.
Usage: python tools/make_sounds.py <out_dir> <ffmpeg_exe>
"""
import subprocess
import sys
import wave

import numpy as np

OUT, FFMPEG = sys.argv[1], sys.argv[2]
SR = 44100
rng = np.random.default_rng(7)


def save(name, sig):
    sig = sig / (np.max(np.abs(sig)) + 1e-9) * 0.89
    pcm = (sig * 32767).astype(np.int16)
    wav_path = f'{OUT}/{name}.wav'
    with wave.open(wav_path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    subprocess.run([FFMPEG, '-y', '-loglevel', 'error', '-i', wav_path,
                    '-b:a', '96k', f'{OUT}/{name}.mp3'], check=True)


def bell(dur=4.0, f0=523.0):
    t = np.arange(int(SR * dur)) / SR
    # Inharmonic partials typical of a cast bronze bell: (ratio, level, decay seconds)
    partials = [(0.5, 0.35, 3.2), (1.0, 1.0, 2.6), (1.183, 0.45, 2.0), (1.506, 0.35, 1.6),
                (2.0, 0.55, 1.4), (2.514, 0.3, 1.0), (2.662, 0.25, 0.9), (3.011, 0.2, 0.7),
                (4.166, 0.15, 0.5), (5.433, 0.1, 0.35)]
    sig = np.zeros_like(t)
    for ratio, level, decay in partials:
        f = f0 * ratio
        beat = 1 + 0.004 * np.sin(2 * np.pi * 1.3 * t)  # slight shimmer
        sig += level * np.exp(-t / decay) * np.sin(2 * np.pi * f * t * beat + rng.uniform(0, 6.28))
    # strike transient
    n = int(SR * 0.012)
    strike = rng.normal(0, 1, n) * np.exp(-np.arange(n) / (SR * 0.003))
    sig[:n] += 0.6 * strike
    return sig


def shankh(dur=3.8, f0=233.0):
    t = np.arange(int(SR * dur)) / SR
    env = np.minimum(1, t / 0.6) * np.minimum(1, (dur - t) / 0.5)
    env *= 0.75 + 0.25 * np.minimum(1, t / 2.2)            # swell
    vib = 1 + 0.006 * np.sin(2 * np.pi * 5.2 * t) * np.minimum(1, t / 1.0)
    phase = 2 * np.pi * np.cumsum(f0 * vib) / SR
    sig = np.zeros_like(t)
    for k, level in enumerate([1.0, 0.7, 0.45, 0.3, 0.18, 0.1, 0.06], start=1):
        sig += level * np.sin(k * phase)
    breath = rng.normal(0, 1, len(t))
    # simple one-pole low-pass for breath noise
    for i in range(1, len(breath)):
        breath[i] = 0.92 * breath[i - 1] + 0.08 * breath[i]
    sig = sig * env + 0.25 * breath * env
    # gentle room echo
    d = int(SR * 0.09)
    echo = np.zeros_like(sig)
    echo[d:] = sig[:-d] * 0.25
    return sig + echo


save('bell', bell())
save('shankh', shankh())
print('ok')
