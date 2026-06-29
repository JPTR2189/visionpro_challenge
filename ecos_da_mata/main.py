from __future__ import annotations

import argparse
import os
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Ecos da Mata - jogo 2D")
    parser.add_argument("--smoke-test", action="store_true", help="Inicializa, renderiza um quadro e encerra")
    parser.add_argument("--screenshot", type=Path, help="Salva uma imagem da tela inicial e encerra")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.smoke_test or args.screenshot:
        os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
        os.environ.setdefault("SDL_AUDIODRIVER", "dummy")
    from game.app import GameApp

    return GameApp().run(screenshot=args.screenshot, smoke_test=args.smoke_test)


if __name__ == "__main__":
    raise SystemExit(main())
