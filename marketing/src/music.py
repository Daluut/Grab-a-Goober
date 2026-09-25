# 10 s royalty-free chiptune jingle for the trailer (pure Python, no samples)
import math, random, struct, wave
SR, DUR, BPM = 44100, 10.0, 128
beat = 60 / BPM
N = int(SR * DUR)
buf = [0.0] * N
def add(t0, dur, fn, vol):
    i0 = int(t0 * SR)
    for i in range(int(dur * SR)):
        j = i0 + i
        if 0 <= j < N:
            buf[j] += fn(i / SR, dur) * vol
def square(f):
    return lambda t, d: (1 if math.sin(2 * math.pi * f * t) > 0 else -1) * math.exp(-t * 6)
def tri(f):
    return lambda t, d: (2 / math.pi) * math.asin(math.sin(2 * math.pi * f * t)) * min(1, (d - t) * 20)
def kick(t, d):
    return math.sin(2 * math.pi * (50 + 120 * math.exp(-t * 30)) * t) * math.exp(-t * 9)
random.seed(3)
def snare(t, d):
    return (random.random() * 2 - 1) * math.exp(-t * 18)
def whoosh(t, d):
    k = t / d
    return (random.random() * 2 - 1) * math.sin(math.pi * k) * 0.8
note = lambda n: 440 * 2 ** ((n - 69) / 12)
# C - G - Am - F, one chord per bar (4 beats)
chords = [[60, 64, 67], [55, 59, 62], [57, 60, 64], [53, 57, 60]]
bars = int(DUR / (beat * 4)) + 1
for bar in range(bars):
    ch = chords[bar % 4]
    t0 = bar * beat * 4
    for b in range(4):
        add(t0 + b * beat, 0.35, kick, 0.9)
        if b % 2 == 1:
            add(t0 + b * beat, 0.2, snare, 0.25)
        add(t0 + b * beat, beat * 0.9, tri(note(ch[0] - 24)), 0.35)  # bass
    for s in range(8):  # arpeggio in 8th notes
        n = ch[[0, 1, 2, 1, 0, 2, 1, 2][s]] + 12
        add(t0 + s * beat / 2, beat / 2 * 0.95, square(note(n)), 0.09)
for cut in (2.2, 4.4, 6.8, 8.6):  # whoosh on every cutscene change
    add(cut - 0.25, 0.5, whoosh, 0.35)
for n in (72, 76, 79, 84):  # ta-da on the end card
    add(8.6, 1.3, tri(note(n)), 0.12)
peak = max(abs(x) for x in buf)
fade = lambda i: min(1, (N - i) / (SR * 0.4))
with wave.open("../trailer_music.wav", "w") as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, buf[i] / peak * 0.85 * fade(i))) * 32767)) for i in range(N)))
print("music ok", round(peak, 2))
