from pathlib import Path
import wave


ROOT = Path(__file__).resolve().parents[1]


def test_required_images_exist_and_are_not_empty() -> None:
    expected = {
        "guardia.png", "vagalume.png", "javali.png", "arvore.png", "rocha.png",
        "santuario.png", "coracao.png", "folha.png", "chao.png", "logo_fundo.png",
    }
    image_dir = ROOT / "assets" / "images"
    assert expected <= {path.name for path in image_dir.glob("*.png")}
    assert all((image_dir / name).stat().st_size > 100 for name in expected)


def test_audio_assets_are_valid_wav_files() -> None:
    expected = {"floresta.wav", "resgate.wav", "impacto.wav", "clique.wav", "vitoria.wav"}
    sound_dir = ROOT / "assets" / "sounds"
    for name in expected:
        with wave.open(str(sound_dir / name), "rb") as audio:
            assert audio.getnchannels() == 1
            assert audio.getframerate() == 22050
            assert audio.getnframes() > 0
