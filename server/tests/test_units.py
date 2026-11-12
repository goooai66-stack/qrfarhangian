import pytest

from app.config import Settings
from app.foods import FoodDB
from app.model_output import InvalidModelOutput, parse_model_output
from app.normalize import levenshtein, normalize
from app.prompt import build_system_prompt
from app.ratelimit import RateLimiter

from .conftest import SAMPLE_FOODS, fake_json

DB = FoodDB.load(SAMPLE_FOODS)


def test_normalize_matches_app():
    assert normalize("قرمه سبزي") == "قرمه سبزی"
    assert normalize("قورمه‌سبزی") == "قورمه سبزی"
    assert normalize("كشك  بادمجان") == "کشک بادمجان"
    assert normalize("کَباب") == "کباب"
    assert normalize("Pizza ۲") == "pizza 2"


def test_search_same_as_app():
    assert DB.search("قرمه سبزي")[0][0].id == "ghormeh_sabzi"
    assert DB.search("کباب کو")[0][0].id == "kabab_koobideh"
    assert DB.search("فسنجن")[0][0].id == "fesenjan"
    assert DB.best_match("پیتزای هاوایی") is None


def test_levenshtein():
    assert levenshtein("کتاب", "کباب") == 1
    assert levenshtein("a", "abcdef", 2) == 3


def test_nutrients_null_propagation():
    grams, n = DB.by_id["chelo"].nutrients("gram", 150)
    assert grams == 150
    assert n == {"kcal": None, "protein": None, "carbs": None, "fat": None}
    grams, _ = DB.by_id["chelo"].nutrients("kafgir", 1)
    assert grams is None


def test_prompt_contains_food_list_and_units():
    p = build_system_prompt(DB)
    assert "ghormeh_sabzi: خورش قورمه‌سبزی" in p
    assert "kafgir: کفگیر" in p
    assert "کالری حساب نکن" in p
    # ترتیب ثابت برای کش پرامپت
    assert p == build_system_prompt(DB)


def test_parse_model_output():
    r = parse_model_output("```json\n" + fake_json(items=[{"food_id": None, "name_fa": " ماست ", "quantity": 1, "unit": "bowl", "confidence": 1.4}]) + "\n```")
    assert r.items[0].name_fa == "ماست"
    assert r.items[0].confidence == 1.0
    assert parse_model_output(fake_json(is_food=False, items=[{"food_id": "chelo", "name_fa": "چلو", "quantity": 1, "unit": "kafgir", "confidence": 1}])).items == []
    with pytest.raises(InvalidModelOutput):
        parse_model_output(fake_json(items=[{"food_id": "x", "name_fa": "", "quantity": 1, "unit": "kafgir", "confidence": 1}]))
    with pytest.raises(InvalidModelOutput):
        parse_model_output(fake_json(items=[{"food_id": "x", "name_fa": "a", "quantity": True, "unit": "kafgir", "confidence": 1}]))


def test_rate_limiter_window():
    rl = RateLimiter(2, 60)
    assert rl.check("a", 0) is None
    assert rl.check("a", 1) is None
    assert rl.check("a", 2) == pytest.approx(58)
    assert rl.check("a", 61) is None


def test_real_food_database_loads_and_is_complete():
    """پایگاه واقعی اپ: همه‌ی غذاها عدد دارند و کالری با درشت‌مغذی‌ها می‌خواند."""
    import json

    real = FoodDB.load(Settings().foods_path)
    assert len(real.foods) >= 150
    rows = json.loads(Settings().foods_path.read_text(encoding="utf-8"))
    for f in rows:
        n = f["per_100g"]
        assert all(n[k] is not None and n[k] >= 0 for k in ("kcal", "protein", "carbs", "fat")), f["id"]
        macro = 4 * n["protein"] + 4 * n["carbs"] + 9 * n["fat"]
        assert abs(macro - n["kcal"]) <= max(25, 0.2 * n["kcal"]), f["id"]
        assert all(u["grams"] and u["grams"] > 0 for u in f["units"]), f["id"]
        # تا وقتی با منبع سنجیده نشده، باید «تقریبی» بماند.
        assert f["verified"] is False or "تخمین" not in f["source"], f["id"]
    assert "chelo: چلو" in build_system_prompt(real)
