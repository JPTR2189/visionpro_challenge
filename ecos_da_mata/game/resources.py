from __future__ import annotations

import sys
from pathlib import Path

import pygame


def project_root() -> Path:
    """Resolve arquivos tanto no código-fonte quanto em um bundle do PyInstaller."""

    bundle_root = getattr(sys, "_MEIPASS", None)
    if bundle_root:
        return Path(bundle_root)
    return Path(__file__).resolve().parents[1]


class Assets:
    def __init__(self) -> None:
        root = project_root() / "assets"
        self.images = {
            name: pygame.image.load(root / "images" / filename).convert_alpha()
            for name, filename in {
                "player": "guardia.png",
                "firefly": "vagalume.png",
                "boar": "javali.png",
                "tree": "arvore.png",
                "rock": "rocha.png",
                "shrine": "santuario.png",
                "heart": "coracao.png",
                "leaf": "folha.png",
                "ground": "chao.png",
                "logo_bg": "logo_fundo.png",
            }.items()
        }
        self.sounds: dict[str, pygame.mixer.Sound] = {}
        if pygame.mixer.get_init():
            for name, filename in {
                "rescue": "resgate.wav",
                "hit": "impacto.wav",
                "click": "clique.wav",
                "win": "vitoria.wav",
            }.items():
                self.sounds[name] = pygame.mixer.Sound(root / "sounds" / filename)
            pygame.mixer.music.load(root / "sounds" / "floresta.wav")
            pygame.mixer.music.set_volume(0.3)

    def play(self, name: str, volume: float = 1.0) -> None:
        sound = self.sounds.get(name)
        if sound:
            sound.set_volume(volume)
            sound.play()
