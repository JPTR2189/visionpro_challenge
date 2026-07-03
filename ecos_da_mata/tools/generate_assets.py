"""Gera os assets visuais e sonoros originais de Ecos da Mata.

Execute a partir da raiz do projeto com:
    python tools/generate_assets.py
"""

from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
IMAGE_DIR = ROOT / "assets" / "images"
SOUND_DIR = ROOT / "assets" / "sounds"
SCALE = 4


def canvas(size: tuple[int, int] = (16, 16)) -> tuple[Image.Image, ImageDraw.ImageDraw]:
    image = Image.new("RGBA", size, (0, 0, 0, 0))
    return image, ImageDraw.Draw(image)


def save_pixel(image: Image.Image, name: str) -> None:
    image.resize((image.width * SCALE, image.height * SCALE), Image.Resampling.NEAREST).save(
        IMAGE_DIR / name
    )


def make_player() -> None:
    image, draw = canvas()
    draw.ellipse((5, 1, 10, 6), fill="#f2c9a0")
    draw.rectangle((4, 2, 11, 3), fill="#305d42")
    draw.rectangle((6, 5, 9, 6), fill="#50352b")
    draw.rectangle((4, 6, 11, 12), fill="#e4a53a")
    draw.rectangle((5, 7, 10, 10), fill="#315b45")
    draw.rectangle((3, 7, 4, 11), fill="#f2c9a0")
    draw.rectangle((11, 7, 12, 11), fill="#f2c9a0")
    draw.rectangle((5, 12, 7, 15), fill="#40352e")
    draw.rectangle((9, 12, 11, 15), fill="#40352e")
    draw.point((6, 4), fill="#1c2321")
    draw.point((9, 4), fill="#1c2321")
    save_pixel(image, "guardia.png")


def make_firefly() -> None:
    image, draw = canvas()
    draw.ellipse((5, 4, 10, 11), fill="#fff3a1")
    draw.rectangle((7, 3, 8, 5), fill="#4c342d")
    draw.ellipse((2, 5, 6, 9), fill="#bde9de")
    draw.ellipse((9, 5, 13, 9), fill="#bde9de")
    draw.rectangle((6, 7, 9, 10), fill="#f7d94c")
    save_pixel(image, "vagalume.png")


def make_boar() -> None:
    image, draw = canvas()
    draw.rectangle((3, 6, 12, 12), fill="#6e4a3a")
    draw.rectangle((1, 7, 5, 11), fill="#76513f")
    draw.rectangle((10, 4, 12, 7), fill="#5b3b31")
    draw.rectangle((4, 12, 6, 14), fill="#342a27")
    draw.rectangle((10, 12, 12, 14), fill="#342a27")
    draw.point((3, 8), fill="#171918")
    draw.point((1, 10), fill="#cba66f")
    save_pixel(image, "javali.png")


def make_tree() -> None:
    image, draw = canvas()
    draw.rectangle((6, 8, 9, 15), fill="#6a4229")
    draw.rectangle((3, 4, 12, 11), fill="#245b3e")
    draw.rectangle((5, 1, 10, 7), fill="#2f7049")
    draw.rectangle((1, 6, 6, 10), fill="#2b6844")
    draw.rectangle((10, 6, 14, 10), fill="#1f563a")
    draw.point((5, 5), fill="#7db358")
    draw.point((10, 8), fill="#7db358")
    save_pixel(image, "arvore.png")


def make_rock() -> None:
    image, draw = canvas()
    draw.polygon([(2, 12), (4, 5), (8, 2), (13, 6), (14, 12)], fill="#66756d")
    draw.polygon([(4, 6), (8, 3), (10, 7), (6, 8)], fill="#87948d")
    save_pixel(image, "rocha.png")


def make_shrine() -> None:
    image, draw = canvas()
    draw.rectangle((2, 12, 13, 15), fill="#6b6251")
    draw.rectangle((4, 5, 11, 13), fill="#8a806c")
    draw.rectangle((6, 1, 9, 7), fill="#b0a789")
    draw.rectangle((7, 3, 8, 5), fill="#6be0a6")
    draw.point((5, 7), fill="#cbc09d")
    draw.point((10, 9), fill="#cbc09d")
    save_pixel(image, "santuario.png")


def make_heart() -> None:
    image, draw = canvas((10, 10))
    draw.rectangle((1, 2, 8, 5), fill="#e65151")
    draw.rectangle((2, 1, 4, 7), fill="#e65151")
    draw.rectangle((5, 1, 7, 7), fill="#e65151")
    draw.rectangle((3, 6, 6, 8), fill="#e65151")
    draw.point((4, 9), fill="#e65151")
    draw.point((2, 2), fill="#ff8a80")
    save_pixel(image, "coracao.png")


def make_leaf() -> None:
    image, draw = canvas((12, 12))
    draw.ellipse((1, 1, 10, 9), fill="#5eaa54")
    draw.line((2, 9, 9, 2), fill="#285d3a", width=1)
    save_pixel(image, "folha.png")


def make_ground() -> None:
    rng = random.Random(42)
    image = Image.new("RGB", (32, 32), "#173f34")
    draw = ImageDraw.Draw(image)
    for _ in range(55):
        x, y = rng.randrange(32), rng.randrange(32)
        color = rng.choice(("#1d4939", "#22513d", "#14372f"))
        draw.rectangle((x, y, x + rng.randrange(1, 3), y + rng.randrange(1, 3)), fill=color)
    image.resize((128, 128), Image.Resampling.NEAREST).save(IMAGE_DIR / "chao.png")


def make_logo() -> None:
    image = Image.new("RGBA", (480, 180), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle((8, 8, 472, 172), radius=28, fill="#102e29", outline="#65d49b", width=5)
    for x, y, r in ((55, 45, 8), (420, 80, 6), (385, 35, 4), (90, 135, 5)):
        draw.ellipse((x - r, y - r, x + r, y + r), fill="#f8e868")
    image.save(IMAGE_DIR / "logo_fundo.png")


def write_wav(name: str, seconds: float, sample_fn, volume: float = 0.35) -> None:
    sample_rate = 22050
    frame_count = int(seconds * sample_rate)
    with wave.open(str(SOUND_DIR / name), "w") as output:
        output.setparams((1, 2, sample_rate, frame_count, "NONE", "not compressed"))
        frames = bytearray()
        for index in range(frame_count):
            time = index / sample_rate
            value = max(-1.0, min(1.0, sample_fn(time, seconds)))
            frames.extend(struct.pack("<h", int(value * volume * 32767)))
        output.writeframes(frames)


def make_sounds() -> None:
    def ambient(t: float, _: float) -> float:
        chord = (math.sin(2 * math.pi * 130.81 * t) + math.sin(2 * math.pi * 164.81 * t)) * 0.22
        melody_notes = (261.63, 293.66, 329.63, 293.66, 246.94, 220.0, 246.94, 293.66)
        note = melody_notes[int(t * 2) % len(melody_notes)]
        envelope = 0.5 + 0.5 * math.sin(2 * math.pi * 2 * t)
        melody = math.sin(2 * math.pi * note * t) * envelope * 0.16
        return chord + melody

    def collect(t: float, seconds: float) -> float:
        frequency = 500 + 900 * (t / seconds)
        return math.sin(2 * math.pi * frequency * t) * (1 - t / seconds)

    def hit(t: float, seconds: float) -> float:
        rng = math.sin(t * 15031) * math.sin(t * 8317)
        return rng * (1 - t / seconds)

    def click(t: float, seconds: float) -> float:
        return math.sin(2 * math.pi * 420 * t) * (1 - t / seconds)

    def win(t: float, seconds: float) -> float:
        notes = (261.63, 329.63, 392.0, 523.25)
        note = notes[min(int(t / (seconds / 4)), 3)]
        local = (t % (seconds / 4)) / (seconds / 4)
        return math.sin(2 * math.pi * note * t) * (1 - local * 0.45)

    write_wav("floresta.wav", 8.0, ambient, 0.24)
    write_wav("resgate.wav", 0.45, collect, 0.32)
    write_wav("impacto.wav", 0.35, hit, 0.28)
    write_wav("clique.wav", 0.12, click, 0.25)
    write_wav("vitoria.wav", 1.5, win, 0.3)


def main() -> None:
    IMAGE_DIR.mkdir(parents=True, exist_ok=True)
    SOUND_DIR.mkdir(parents=True, exist_ok=True)
    make_player()
    make_firefly()
    make_boar()
    make_tree()
    make_rock()
    make_shrine()
    make_heart()
    make_leaf()
    make_ground()
    make_logo()
    make_sounds()
    print(f"Assets gerados em {ROOT / 'assets'}")


if __name__ == "__main__":
    main()
