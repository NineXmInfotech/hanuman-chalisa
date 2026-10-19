"""Generate the built-in Hindi recitation with the Kokoro open-source voice model.

Creates one MP3 per verse (same order as lib/chalisa_data.dart) for each voice,
plus durations.json. Run in CI (see .github/workflows/generate-audio.yml).
"""
import json
import os
import re
import subprocess

import numpy as np
import soundfile as sf
from kokoro import KPipeline

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'audio_out')
VOICES = ['hm_omega', 'hf_alpha']   # male, female
SPEED = 0.85
RATE = 24000
GAP = 0.45  # seconds of silence after each verse

src = open(os.path.join(ROOT, 'lib', 'chalisa_data.dart'), encoding='utf-8').read()
verses = re.findall(r"hindi: '((?:[^'\\]|\\.)*)'", src)
verses = [v.replace("\\'", "'").replace('\\n', '\n') for v in verses]
assert len(verses) == 43, len(verses)


def clean(text):
    text = text.replace('\n', ' । ')
    text = text.replace('॥', '।')
    text = re.sub(r'\s+', ' ', text).strip()
    return text


pipeline = KPipeline(lang_code='h')
os.makedirs(OUT, exist_ok=True)
durations = {}

for voice in VOICES:
    vdir = os.path.join(OUT, voice)
    os.makedirs(vdir, exist_ok=True)
    durations[voice] = []
    for i, verse in enumerate(verses, start=1):
        chunks = []
        for _, _, audio in pipeline(clean(verse), voice=voice, speed=SPEED):
            if audio is not None:
                chunks.append(np.asarray(audio, dtype=np.float32))
        wav = np.concatenate(chunks) if chunks else np.zeros(RATE, dtype=np.float32)
        wav = np.concatenate([wav, np.zeros(int(RATE * GAP), dtype=np.float32)])
        wav_path = os.path.join(vdir, f'v{i:02d}.wav')
        mp3_path = os.path.join(vdir, f'v{i:02d}.mp3')
        sf.write(wav_path, wav, RATE)
        subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', wav_path,
                        '-ac', '1', '-ar', '24000', '-b:a', '48k', mp3_path], check=True)
        os.remove(wav_path)
        durations[voice].append(round(len(wav) / RATE, 2))
        print(voice, i, durations[voice][-1], 's')

    # One combined preview file per voice, handy for listening on a phone.
    listfile = os.path.join(vdir, 'list.txt')
    with open(listfile, 'w') as f:
        for i in range(1, len(verses) + 1):
            f.write(f"file 'v{i:02d}.mp3'\n")
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-f', 'concat', '-safe', '0',
                    '-i', listfile, '-c', 'copy',
                    os.path.join(OUT, f'preview_{voice}.mp3')], check=True)
    os.remove(listfile)

with open(os.path.join(OUT, 'durations.json'), 'w') as f:
    json.dump(durations, f, indent=1)
print({v: round(sum(d) / 60, 2) for v, d in durations.items()}, 'minutes')
