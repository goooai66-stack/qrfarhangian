import pytest

PIL = pytest.importorskip("PIL")
from PIL import Image  # noqa: E402

from tools.eval_photos import main, parse_prices, prepare_image  # noqa: E402


def make_photo(path, size=(3000, 2000)):
    im = Image.effect_noise(size, 64).convert("RGB")
    im.save(path, "JPEG", quality=95)


def test_prepare_image_like_app(tmp_path):
    p = tmp_path / "big.jpg"
    make_photo(p)
    data = prepare_image(p)
    assert len(data) <= 200 * 1024
    im = Image.open(__import__("io").BytesIO(data))
    assert max(im.size) <= 1024


def test_parse_prices():
    assert parse_prices("a/b=0.1:0.4, c=1:4") == {"a/b": (0.1, 0.4), "c": (1.0, 4.0)}


def test_end_to_end_with_fake_provider(tmp_path, monkeypatch):
    photos = tmp_path / "photos"
    photos.mkdir()
    for n in ("1.jpg", "2.png"):
        make_photo(photos / n, (400, 300))
    (photos / "notes.txt").write_text("x")
    monkeypatch.setenv("VISION_PROVIDER", "fake")
    out = tmp_path / "eval"
    assert main(["--photos", str(photos), "--prices", "fake=4:20", "--out", str(out)]) == 0
    md = (out / "results.md").read_text(encoding="utf-8")
    assert "| `fake` | 2 | 2 | 0 | 0 |" in md
    assert "چلو 1.5 kafgir (0.86)" in md
    assert "?گوجه کبابی" in md
    csv = (out / "results.csv").read_text(encoding="utf-8")
    assert csv.count("\n") == 3
