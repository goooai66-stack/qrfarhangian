"""پایگاه غذا را از جدول زیر می‌سازد:  python server/tools/build_foods.py

⚠️ همه‌ی اعداد «تخمین اولیه» هستند (جدول‌های عمومی ترکیبات غذایی برای مواد ساده،
و دستور پخت رایج برای غذاهای ترکیبی). هیچ‌کدام با منبع ایرانی یا ترازو سنجیده نشده؛
برای همین verified=false است و اپ کنارشان «تقریبی» نشان می‌دهد.
برای اصلاح: عدد را در همین جدول عوض کن، اگر با منبع یا ترازو سنجیدی نام منبع را در
ستون آخر بنویس (آن ردیف verified می‌شود)، و اسکریپت را دوباره اجرا کن.

هر ردیف: شناسه، نام، نام‌های دیگر، نام انگلیسی، دسته،
          (کالری، پروتئین، کربوهیدرات، چربی، فیبر) در ۱۰۰ گرمِ آماده‌ی خوردن،
          واحدها [(کد واحد، گرم)] — اولی پیش‌فرض است، [منبع تأییدشده]
"""

import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
ESTIMATE = "تخمین اولیه از جدول‌های عمومی ترکیبات غذایی و دستور پخت رایج؛ تأییدنشده"

UNIT_FA = {
    "kafgir": "کفگیر", "ladle": "ملاقه", "plate": "بشقاب", "bowl": "کاسه", "glass": "لیوان",
    "tablespoon": "قاشق غذاخوری", "palm": "کف دست", "piece": "عدد", "slice": "برش", "gram": "گرم",
}

F = [
    # ---- برنج و پلو ----
    ("chelo", "چلو", ["برنج", "برنج سفید", "چلو سفید"], "Chelo (steamed rice)", "rice", (150, 2.8, 30, 2, 0.4), [("kafgir", 100), ("plate", 250)]),
    ("kateh", "کته", ["برنج کته"], "Kateh", "rice", (145, 2.8, 29, 1.8, 0.4), [("kafgir", 110), ("plate", 270)]),
    ("tahdig_rice", "ته‌دیگ برنج", ["ته دیگ", "تهدیگ"], "Rice tahdig", "rice", (290, 4, 45, 10, 0.8), [("piece", 40), ("palm", 60)]),
    ("zereshk_polo", "زرشک‌پلو", ["زرشک پلو"], "Zereshk polo", "rice", (165, 3, 31, 3, 0.8), [("kafgir", 100), ("plate", 250)]),
    ("baghali_polo", "باقالی‌پلو", ["باقالی پلو", "باقلا پلو"], "Baghali polo", "rice", (160, 4, 29, 3, 1.5), [("kafgir", 100), ("plate", 250)]),
    ("sabzi_polo", "سبزی‌پلو", ["سبزی پلو"], "Sabzi polo", "rice", (150, 3, 28, 2.5, 1), [("kafgir", 100), ("plate", 250)]),
    ("lubia_polo", "لوبیاپلو", ["لوبیا پلو"], "Lubia polo", "rice", (175, 6, 26, 5, 1.8), [("kafgir", 100), ("plate", 250)]),
    ("adas_polo", "عدس‌پلو", ["عدس پلو"], "Adas polo", "rice", (175, 5, 31, 3.5, 2.5), [("kafgir", 100), ("plate", 250)]),
    ("estamboli", "استامبولی‌پلو", ["استانبولی", "دمی گوجه", "گوجه پلو"], "Estamboli polo", "rice", (160, 3, 29, 3.5, 1), [("kafgir", 100), ("plate", 250)]),
    ("reshteh_polo", "رشته‌پلو", ["رشته پلو"], "Reshteh polo", "rice", (180, 4, 33, 3.5, 1), [("kafgir", 100), ("plate", 250)]),
    ("kalam_polo", "کلم‌پلو", ["کلم پلو"], "Kalam polo", "rice", (165, 5, 25, 5, 1.5), [("kafgir", 100), ("plate", 250)]),
    ("albaloo_polo", "آلبالوپلو", ["آلبالو پلو"], "Albaloo polo", "rice", (185, 3.5, 36, 3, 0.8), [("kafgir", 100), ("plate", 250)]),
    ("tahchin", "ته‌چین مرغ", ["ته چین", "تهچین"], "Tahchin", "rice", (215, 9, 26, 8, 0.5), [("piece", 150), ("plate", 300)]),
    ("macaroni", "ماکارونی", ["ماکارونی با سس گوشت", "اسپاگتی", "پاستا"], "Macaroni with meat sauce", "rice", (170, 7, 24, 5, 1.5), [("plate", 250), ("kafgir", 100)]),
    # ---- خورش ----
    ("ghormeh_sabzi", "خورش قورمه‌سبزی", ["قورمه‌سبزی", "قورمه سبزی", "قرمه سبزی", "خورش سبزی"], "Ghormeh sabzi", "khoresh", (135, 8, 5, 9, 2), [("ladle", 100), ("bowl", 250)]),
    ("gheymeh", "خورش قیمه", ["قیمه"], "Gheymeh", "khoresh", (150, 8, 9, 9, 2), [("ladle", 100), ("bowl", 250)]),
    ("fesenjan", "فسنجان", ["خورش فسنجان", "فسنجون"], "Fesenjan", "khoresh", (260, 10, 12, 20, 2), [("ladle", 100), ("bowl", 250)]),
    ("khoresh_bademjan", "خورش بادمجان", ["خورش بادنجان"], "Eggplant stew", "khoresh", (130, 6, 6, 9, 2), [("ladle", 100), ("bowl", 250)]),
    ("gheymeh_bademjan", "قیمه بادمجان", ["قیمه بادنجان"], "Gheymeh bademjan", "khoresh", (145, 7, 8, 9.5, 2), [("ladle", 100), ("bowl", 250)]),
    ("khoresh_karafs", "خورش کرفس", ["کرفس"], "Celery stew", "khoresh", (115, 7, 4, 8, 1.5), [("ladle", 100), ("bowl", 250)]),
    ("khoresh_bamieh", "خورش بامیه", ["بامیه خورشی"], "Okra stew", "khoresh", (120, 6, 7, 8, 2), [("ladle", 100), ("bowl", 250)]),
    ("khoresh_aloo", "خورش آلو اسفناج", ["آلو اسفناج"], "Spinach and plum stew", "khoresh", (130, 7, 9, 7.5, 2), [("ladle", 100), ("bowl", 250)]),
    ("khoresh_kadoo", "خورش کدو", ["کدو خورشی"], "Zucchini stew", "khoresh", (110, 6, 6, 7, 1.2), [("ladle", 100), ("bowl", 250)]),
    ("khoresh_morgh", "خوراک مرغ", ["مرغ با سس", "خورش مرغ"], "Chicken in sauce", "khoresh", (150, 15, 3, 9, 0.3), [("piece", 130), ("ladle", 100)]),
    # ---- کباب، گوشت، مرغ، ماهی ----
    ("kabab_koobideh", "کباب کوبیده", ["کوبیده"], "Koobideh kebab", "kabab", (250, 17, 1, 20, 0), [("piece", 90)]),
    ("joojeh_kabab", "جوجه‌کباب", ["جوجه کباب", "جوجه"], "Joojeh kebab", "kabab", (165, 25, 1, 7, 0), [("piece", 150), ("plate", 200)]),
    ("kabab_barg", "کباب برگ", ["برگ"], "Barg kebab", "kabab", (200, 26, 0, 10, 0), [("piece", 120)]),
    ("chenjeh", "چنجه", ["کباب چنجه"], "Chenjeh kebab", "kabab", (210, 25, 0, 12, 0), [("piece", 120)]),
    ("shishlik", "شیشلیک", ["دنده کباب"], "Shishlik", "kabab", (250, 22, 0, 18, 0), [("piece", 100)]),
    ("kabab_tabei", "کباب تابه‌ای", ["کباب تابه ای"], "Pan kebab", "kabab", (230, 15, 4, 17, 0.5), [("piece", 80)]),
    ("jigar", "جگر کبابی", ["جگر"], "Grilled liver", "kabab", (170, 24, 4, 6, 0), [("piece", 50)]),
    ("bal_kababi", "بال کبابی", ["بال مرغ", "بال"], "Grilled chicken wing", "kabab", (220, 18, 0, 16, 0), [("piece", 35)]),
    ("sineh_morgh", "سینه‌ی مرغ پخته", ["سینه مرغ", "مرغ آب‌پز", "مرغ گریل"], "Cooked chicken breast", "protein", (165, 31, 0, 3.6, 0), [("piece", 120)]),
    ("ran_morgh", "ران مرغ پخته", ["ران مرغ", "مرغ"], "Cooked chicken thigh", "protein", (190, 24, 0, 10, 0), [("piece", 110)]),
    ("gusht_pokhteh", "گوشت قرمز پخته", ["گوشت", "گوشت گوسفندی", "گوشت گوساله"], "Cooked red meat", "protein", (250, 25, 0, 16, 0), [("piece", 50), ("tablespoon", 20)]),
    ("mahi_sorkh", "ماهی سرخ‌شده", ["ماهی سرخ کرده", "ماهی"], "Fried fish", "protein", (200, 22, 3, 11, 0), [("piece", 120)]),
    ("mahi_kababi", "ماهی کبابی", ["قزل‌آلا کبابی", "ماهی گریل"], "Grilled fish", "protein", (165, 23, 0, 8, 0), [("piece", 150)]),
    ("ton_mahi", "تن ماهی", ["کنسرو ماهی", "تن"], "Canned tuna in oil", "protein", (200, 26, 0, 10, 0), [("tablespoon", 20), ("piece", 180)]),
    ("tokhm_morgh", "تخم‌مرغ آب‌پز", ["تخم مرغ", "تخم مرغ آب پز"], "Boiled egg", "protein", (155, 13, 1.1, 11, 0), [("piece", 50)]),
    ("nimroo", "نیمرو", ["تخم مرغ نیمرو"], "Fried egg", "protein", (195, 13.5, 1, 15, 0), [("piece", 55)]),
    ("omlet", "املت گوجه", ["املت"], "Tomato omelette", "protein", (130, 7, 4, 9.5, 0.8), [("plate", 200), ("tablespoon", 20)]),
    # ---- آش، سوپ، حبوبات ----
    ("ash_reshteh", "آش رشته", ["آش"], "Ash reshteh", "ash", (95, 4.5, 13, 2.8, 3), [("bowl", 300), ("ladle", 110)]),
    ("ash_jo", "آش جو", [], "Barley ash", "ash", (80, 3, 12, 2.2, 2), [("bowl", 300), ("ladle", 110)]),
    ("adasi", "عدسی", [], "Adasi (lentil soup)", "ash", (110, 7, 16, 2, 5), [("bowl", 250), ("ladle", 100)]),
    ("soup_jo", "سوپ جو", ["سوپ"], "Barley soup", "ash", (65, 2.5, 9, 2, 1.2), [("bowl", 250), ("ladle", 100)]),
    ("soup_morgh", "سوپ مرغ و ورمیشل", ["سوپ ورمیشل", "سوپ مرغ"], "Chicken noodle soup", "ash", (50, 3, 6, 1.5, 0.5), [("bowl", 250), ("ladle", 100)]),
    ("halim", "حلیم", ["هلیم"], "Halim", "ash", (130, 7, 15, 4.5, 1.5), [("bowl", 300), ("ladle", 100)]),
    ("abgoosht", "آبگوشت", ["دیزی"], "Abgoosht", "ash", (120, 7, 9, 6, 2.2), [("bowl", 300), ("ladle", 100)]),
    ("khorak_loobia", "خوراک لوبیا", ["لوبیا چیتی", "لوبیا"], "Bean stew", "ash", (125, 6, 17, 3.5, 5), [("bowl", 250), ("ladle", 100)]),
    ("eshkeneh", "اشکنه", [], "Eshkeneh", "ash", (85, 3.5, 5, 5.5, 0.8), [("bowl", 250), ("ladle", 100)]),
    ("kaleh_pacheh", "کله‌پاچه", ["کله پاچه"], "Kaleh pacheh", "ash", (190, 15, 0, 14, 0), [("bowl", 250)]),
    ("nokhod_pokhteh", "نخود پخته", ["نخود"], "Cooked chickpeas", "ash", (164, 8.9, 27, 2.6, 7.6), [("tablespoon", 15), ("bowl", 160)]),
    # ---- غذاهای محلی و خانگی ----
    ("kashk_bademjan", "کشک بادمجان", ["کشک و بادمجان", "کشک بادنجان"], "Kashk-e bademjan", "local", (140, 4, 8, 10, 2.5), [("tablespoon", 20), ("bowl", 200)]),
    ("mirza_ghasemi", "میرزاقاسمی", ["میرزا قاسمی"], "Mirza ghasemi", "local", (110, 4, 6, 8, 2), [("tablespoon", 20), ("bowl", 200)]),
    ("kotlet", "کتلت", ["کتلت گوشت"], "Kotlet", "local", (230, 13, 13, 14, 1), [("piece", 60)]),
    ("shami", "شامی", ["شامی کباب"], "Shami", "local", (240, 14, 10, 16, 1.5), [("piece", 50)]),
    ("kookoo_sabzi", "کوکو سبزی", ["کوکوسبزی"], "Kookoo sabzi", "local", (190, 9, 6, 14, 2.5), [("piece", 70)]),
    ("kookoo_sibzamini", "کوکو سیب‌زمینی", ["کوکو سیب زمینی"], "Potato kookoo", "local", (200, 6, 17, 12, 1.5), [("piece", 70)]),
    ("dolmeh", "دلمه‌ی برگ مو", ["دلمه"], "Dolmeh", "local", (160, 5, 18, 7.5, 2), [("piece", 30)]),
    ("salad_olovieh", "سالاد الویه", ["الویه"], "Olivier salad", "local", (210, 7, 11, 15, 1.5), [("tablespoon", 25), ("plate", 200)]),
    ("sibzamini_sorkh", "سیب‌زمینی سرخ‌کرده", ["سیب زمینی سرخ کرده", "فرنچ فرایز"], "French fries", "local", (310, 3.5, 41, 15, 3.8), [("plate", 150), ("palm", 60)]),
    ("sibzamini_abpaz", "سیب‌زمینی آب‌پز", ["سیب زمینی", "سیب زمینی آب پز"], "Boiled potato", "local", (87, 1.9, 20, 0.1, 1.8), [("piece", 150)]),
    # ---- فست‌فود ----
    ("falafel", "فلافل", [], "Falafel", "fastfood", (330, 13, 32, 18, 5), [("piece", 20)]),
    ("sambooseh", "سمبوسه", [], "Sambooseh", "fastfood", (300, 6, 30, 17, 2), [("piece", 50)]),
    ("sosis", "سوسیس", ["هات داگ"], "Sausage", "fastfood", (290, 11, 3, 26, 0), [("piece", 45)]),
    ("kalbas", "کالباس", [], "Kalbas (cold cut)", "fastfood", (230, 12, 4, 18, 0), [("slice", 15)]),
    ("hamburger", "همبرگر", ["برگر", "ساندویچ همبرگر"], "Hamburger with bun", "fastfood", (260, 13, 24, 12, 1.2), [("piece", 150)]),
    ("pizza", "پیتزا", ["پیتزا مخلوط"], "Pizza", "fastfood", (265, 11, 30, 11, 2), [("slice", 110)]),
    # ---- سالاد و کنار غذا ----
    ("salad_shirazi", "سالاد شیرازی", [], "Shirazi salad", "side", (40, 1, 6, 1.5, 1.5), [("bowl", 150), ("tablespoon", 15)]),
    ("salad_fasl", "سالاد فصل", ["سالاد کاهو", "سالاد"], "Green salad (no dressing)", "side", (20, 1.2, 3.5, 0.2, 1.5), [("bowl", 120)]),
    ("mast_khiar", "ماست و خیار", ["ماست خیار"], "Yogurt with cucumber", "side", (55, 3, 4, 2.5, 0.3), [("bowl", 150), ("tablespoon", 20)]),
    ("borani_esfenaj", "بورانی اسفناج", ["ماست اسفناج", "بورانی"], "Spinach borani", "side", (65, 3.5, 5, 3, 1), [("bowl", 150), ("tablespoon", 20)]),
    ("torshi", "ترشی", ["ترشی مخلوط", "ترشی لیته"], "Torshi (pickles)", "side", (30, 1, 5, 0.3, 2), [("tablespoon", 15)]),
    ("zeytoon", "زیتون", ["زیتون شور"], "Olives", "side", (145, 1, 4, 15, 3.3), [("piece", 4)]),
    ("zeytoon_parvardeh", "زیتون پرورده", [], "Zeytoon parvardeh", "side", (250, 3, 8, 23, 3), [("tablespoon", 20)]),
    ("sos_mayonez", "سس مایونز", ["مایونز", "سس سفید"], "Mayonnaise", "side", (680, 1, 1, 75, 0), [("tablespoon", 15)]),
    ("sos_ketchup", "سس کچاپ", ["کچاپ", "سس قرمز", "سس گوجه"], "Ketchup", "side", (100, 1, 25, 0.1, 0.3), [("tablespoon", 17)]),
    ("roghan", "روغن مایع", ["روغن", "روغن زیتون", "روغن سرخ‌کردنی"], "Cooking oil", "side", (884, 0, 0, 100, 0), [("tablespoon", 14)]),
    # ---- نان ----
    ("nan_sangak", "نان سنگک", ["سنگک"], "Sangak bread", "bread", (265, 9, 54, 1.5, 5), [("palm", 30), ("piece", 450)]),
    ("nan_barbari", "نان بربری", ["بربری"], "Barbari bread", "bread", (280, 9, 56, 1.5, 2.5), [("palm", 35), ("piece", 450)]),
    ("nan_lavash", "نان لواش", ["لواش"], "Lavash bread", "bread", (275, 9, 56, 1.2, 2.5), [("palm", 15), ("piece", 100)]),
    ("nan_taftoon", "نان تافتون", ["تافتون"], "Taftoon bread", "bread", (270, 9, 55, 1.2, 3), [("palm", 25), ("piece", 200)]),
    ("nan_tost", "نان تست", ["تست", "نان بسته‌ای"], "Toast bread", "bread", (265, 9, 49, 3.2, 2.7), [("slice", 25)]),
    ("nan_baget", "نان باگت", ["باگت", "نان ساندویچی"], "Baguette roll", "bread", (270, 9, 55, 1.5, 2.5), [("piece", 150)]),
    ("nan_shirmal", "نان شیرمال", ["شیرمال"], "Shirmal bread", "bread", (330, 8, 55, 9, 1.5), [("piece", 150), ("palm", 40)]),
    # ---- لبنیات ----
    ("panir", "پنیر", ["پنیر سفید", "پنیر لیقوان", "پنیر تبریز"], "White cheese", "dairy", (250, 15, 2.5, 20, 0), [("tablespoon", 15), ("piece", 30)]),
    ("panir_khamei", "پنیر خامه‌ای", ["پنیر خامه ای"], "Cream cheese", "dairy", (300, 6, 4, 29, 0), [("tablespoon", 15)]),
    ("mast", "ماست", ["ماست ساده", "ماست کم‌چرب"], "Yogurt", "dairy", (60, 3.5, 4.7, 3, 0), [("bowl", 200), ("tablespoon", 15)]),
    ("mast_chekideh", "ماست چکیده", ["ماست پرچرب", "ماست یونانی"], "Strained yogurt", "dairy", (115, 7, 5, 7.5, 0), [("tablespoon", 20), ("bowl", 200)]),
    ("shir", "شیر", ["شیر کم‌چرب", "شیر ساده"], "Milk", "dairy", (50, 3.3, 4.8, 2, 0), [("glass", 240)]),
    ("shir_kakao", "شیرکاکائو", ["شیر کاکائو"], "Chocolate milk", "dairy", (80, 3.2, 11, 2.5, 0.5), [("glass", 240)]),
    ("kareh", "کره", [], "Butter", "dairy", (720, 0.8, 0.6, 81, 0), [("tablespoon", 14), ("piece", 10)]),
    ("khameh", "خامه", ["خامه صبحانه"], "Breakfast cream", "dairy", (300, 2.5, 3.5, 30, 0), [("tablespoon", 15)]),
    ("kashk", "کشک", ["کشک مایع"], "Liquid kashk", "dairy", (105, 10, 8, 3.5, 0), [("tablespoon", 15)]),
    ("bastani", "بستنی سنتی", ["بستنی", "بستنی زعفرانی"], "Saffron ice cream", "dairy", (210, 4, 24, 11, 0), [("piece", 60), ("bowl", 150)]),
    # ---- صبحانه و شیرین‌کننده‌ها ----
    ("asal", "عسل", [], "Honey", "breakfast", (304, 0.3, 82, 0, 0.2), [("tablespoon", 21)]),
    ("moraba", "مربا", ["مربای آلبالو", "مربای هویج"], "Jam", "breakfast", (265, 0.4, 66, 0.1, 0.8), [("tablespoon", 20)]),
    ("halva_ardeh", "حلواارده", ["حلوا ارده", "حلوا شکری"], "Halva ardeh", "breakfast", (520, 12, 50, 31, 3.5), [("tablespoon", 15), ("piece", 30)]),
    ("ardeh", "ارده", ["ارده کنجد"], "Tahini", "breakfast", (595, 17, 21, 54, 9), [("tablespoon", 15)]),
    ("shireh_angoor", "شیره‌ی انگور", ["شیره", "شیره انگور", "شیره خرما"], "Grape syrup", "breakfast", (290, 1, 72, 0, 0.5), [("tablespoon", 20)]),
    ("ghand", "قند", ["حبه قند"], "Sugar cube", "breakfast", (387, 0, 100, 0, 0), [("piece", 2.5)]),
    ("shekar", "شکر", [], "Sugar", "breakfast", (387, 0, 100, 0, 0), [("tablespoon", 12.5)]),
    ("nabat", "نبات", ["شاخه نبات"], "Rock candy", "breakfast", (390, 0, 99, 0, 0), [("piece", 10)]),
    # ---- مغزها و خشکبار ----
    ("gerdoo", "گردو", ["مغز گردو"], "Walnut", "nut", (654, 15, 14, 65, 6.7), [("piece", 5)]),
    ("badam", "بادام", ["بادام درختی", "مغز بادام"], "Almond", "nut", (579, 21, 22, 50, 12.5), [("piece", 1.2)]),
    ("pesteh", "پسته", ["مغز پسته"], "Pistachio", "nut", (560, 20, 28, 45, 10), [("piece", 0.7)]),
    ("fandogh", "فندق", [], "Hazelnut", "nut", (628, 15, 17, 61, 10), [("piece", 1.2)]),
    ("badam_zamini", "بادام‌زمینی", ["بادام زمینی"], "Peanut", "nut", (567, 26, 16, 49, 8.5), [("tablespoon", 9)]),
    ("tokhmeh", "تخمه‌ی آفتابگردان", ["تخمه", "مغز تخمه"], "Sunflower seed kernels", "nut", (584, 21, 20, 51, 8.6), [("tablespoon", 9)]),
    ("keshmesh", "کشمش", ["مویز"], "Raisins", "nut", (299, 3, 79, 0.5, 3.7), [("tablespoon", 10)]),
    ("khorma", "خرما", ["رطب", "خرمای مضافتی"], "Dates", "fruit", (280, 2.5, 75, 0.4, 8), [("piece", 8)]),
    ("anjir_khoshk", "انجیر خشک", [], "Dried fig", "nut", (249, 3.3, 64, 0.9, 9.8), [("piece", 8)]),
    # ---- شیرینی و تنقلات ----
    ("biskuit", "بیسکویت", ["بیسکوییت", "بیسکویت ساده"], "Plain biscuit", "sweet", (450, 7, 72, 15, 2), [("piece", 6)]),
    ("keik", "کیک یزدی", ["کیک", "کیک خانگی"], "Cake", "sweet", (380, 6, 55, 15, 1), [("piece", 40)]),
    ("shirini_tar", "شیرینی تر", ["شیرینی خامه‌ای", "نان خامه‌ای"], "Cream pastry", "sweet", (340, 5, 40, 18, 0.5), [("piece", 50)]),
    ("shirini_khoshk", "شیرینی خشک", ["شیرینی"], "Dry cookie", "sweet", (480, 6, 62, 23, 1.5), [("piece", 12)]),
    ("zoolbia", "زولبیا و بامیه", ["زولبیا", "بامیه"], "Zoolbia and bamieh", "sweet", (380, 3, 58, 16, 0.5), [("piece", 20)]),
    ("gaz", "گز", [], "Gaz", "sweet", (400, 5, 75, 9, 1), [("piece", 15)]),
    ("sohan", "سوهان", [], "Sohan", "sweet", (500, 6, 60, 27, 1), [("piece", 10)]),
    ("baghlava", "باقلوا", [], "Baklava", "sweet", (430, 7, 45, 25, 2), [("piece", 25)]),
    ("sholeh_zard", "شله‌زرد", ["شله زرد"], "Sholeh zard", "sweet", (150, 1.5, 32, 2, 0.3), [("bowl", 150), ("tablespoon", 20)]),
    ("fereni", "فرنی", [], "Fereni", "sweet", (110, 3, 19, 2.5, 0.2), [("bowl", 150)]),
    ("halva", "حلوا", ["حلوای خانگی", "حلوا آردی"], "Flour halva", "sweet", (420, 5, 50, 23, 1.5), [("tablespoon", 20)]),
    ("shokolat", "شکلات", ["شکلات شیری"], "Milk chocolate", "sweet", (535, 7.6, 59, 30, 3.4), [("piece", 5)]),
    ("chips", "چیپس", ["چیپس سیب‌زمینی"], "Potato chips", "sweet", (536, 7, 53, 35, 4.8), [("bowl", 30)]),
    # ---- نوشیدنی ----
    ("doogh", "دوغ", [], "Doogh", "drink", (20, 1.2, 1.5, 0.9, 0), [("glass", 240)]),
    ("chai", "چای", ["چایی", "چای بدون قند"], "Tea (no sugar)", "drink", (1, 0, 0.2, 0, 0), [("glass", 200)]),
    ("ghahveh", "قهوه", ["قهوه تلخ", "اسپرسو"], "Black coffee", "drink", (2, 0.1, 0, 0, 0), [("glass", 150)]),
    ("noshabeh", "نوشابه", ["نوشابه گازدار", "کولا"], "Soft drink", "drink", (42, 0, 10.6, 0, 0), [("glass", 240)]),
    ("delester", "ماءالشعیر", ["دلستر", "ماالشعیر"], "Malt beverage", "drink", (35, 0.3, 8.5, 0, 0), [("glass", 240)]),
    ("ab_miveh", "آبمیوه", ["آب میوه", "آب پرتقال"], "Fruit juice", "drink", (46, 0.5, 11, 0.1, 0.2), [("glass", 240)]),
    ("ab_havij", "آب هویج", [], "Carrot juice", "drink", (40, 0.9, 9.3, 0.2, 0.8), [("glass", 240)]),
    ("sharbat", "شربت", ["شربت آلبالو", "شربت خاکشیر"], "Sweet sharbat", "drink", (45, 0, 11.5, 0, 0), [("glass", 240)]),
    # ---- میوه ----
    ("sib", "سیب", [], "Apple", "fruit", (52, 0.3, 14, 0.2, 2.4), [("piece", 150)]),
    ("moz", "موز", [], "Banana", "fruit", (89, 1.1, 23, 0.3, 2.6), [("piece", 100)]),
    ("portaghal", "پرتقال", [], "Orange", "fruit", (47, 0.9, 12, 0.1, 2.4), [("piece", 130)]),
    ("narengi", "نارنگی", [], "Tangerine", "fruit", (53, 0.8, 13, 0.3, 1.8), [("piece", 75)]),
    ("angoor", "انگور", [], "Grapes", "fruit", (69, 0.7, 18, 0.2, 0.9), [("bowl", 150), ("piece", 5)]),
    ("hendevaneh", "هندوانه", [], "Watermelon", "fruit", (30, 0.6, 7.6, 0.2, 0.4), [("slice", 250)]),
    ("kharbozeh", "خربزه و طالبی", ["خربزه", "طالبی"], "Melon", "fruit", (34, 0.8, 8, 0.2, 0.9), [("slice", 150)]),
    ("anar", "انار", [], "Pomegranate", "fruit", (83, 1.7, 19, 1.2, 4), [("piece", 180), ("bowl", 150)]),
    ("kivi", "کیوی", [], "Kiwi", "fruit", (61, 1.1, 15, 0.5, 3), [("piece", 70)]),
    ("holoo", "هلو", ["شلیل"], "Peach", "fruit", (39, 0.9, 10, 0.3, 1.5), [("piece", 130)]),
    ("zardaloo", "زردآلو", [], "Apricot", "fruit", (48, 1.4, 11, 0.4, 2), [("piece", 35)]),
    ("gilas", "گیلاس", [], "Cherry", "fruit", (63, 1.1, 16, 0.2, 2.1), [("bowl", 140), ("piece", 7)]),
    ("tut_farangi", "توت‌فرنگی", ["توت فرنگی"], "Strawberry", "fruit", (32, 0.7, 7.7, 0.3, 2), [("bowl", 150), ("piece", 12)]),
    ("khormaloo", "خرمالو", [], "Persimmon", "fruit", (70, 0.6, 18.6, 0.2, 3.6), [("piece", 150)]),
    ("golabi", "گلابی", [], "Pear", "fruit", (57, 0.4, 15, 0.1, 3.1), [("piece", 160)]),
    ("aloo", "آلو", ["آلو قرمز", "آلو زرد"], "Plum", "fruit", (46, 0.7, 11.4, 0.3, 1.4), [("piece", 60)]),
    ("anjir", "انجیر تازه", ["انجیر"], "Fresh fig", "fruit", (74, 0.8, 19, 0.3, 2.9), [("piece", 40)]),
    # ---- سبزی ----
    ("khiar", "خیار", [], "Cucumber", "vegetable", (15, 0.7, 3.6, 0.1, 0.5), [("piece", 100)]),
    ("gojeh", "گوجه‌فرنگی", ["گوجه", "گوجه فرنگی"], "Tomato", "vegetable", (18, 0.9, 3.9, 0.2, 1.2), [("piece", 100)]),
    ("havij", "هویج", [], "Carrot", "vegetable", (41, 0.9, 9.6, 0.2, 2.8), [("piece", 60)]),
    ("kahoo", "کاهو", [], "Lettuce", "vegetable", (15, 1.4, 2.9, 0.2, 1.3), [("bowl", 50)]),
    ("sabzi_khordan", "سبزی خوردن", ["سبزی", "ریحان"], "Fresh herbs", "vegetable", (30, 2.5, 4, 0.5, 2.5), [("palm", 30)]),
    ("balal", "بلال", ["ذرت", "ذرت مکزیکی"], "Corn", "vegetable", (96, 3.4, 21, 1.5, 2.4), [("piece", 100), ("bowl", 150)]),
    ("laboo", "لبو", ["چغندر پخته"], "Cooked beet", "vegetable", (44, 1.7, 10, 0.2, 2), [("piece", 80)]),
    ("baghali_pokhteh", "باقالی پخته", ["باقلا", "باقالی"], "Cooked fava beans", "vegetable", (110, 7.6, 19.6, 0.4, 5.4), [("bowl", 150)]),
]


def build() -> list[dict]:
    out, seen = [], set()
    for row in F:
        fid, name, aliases, en, cat, (kcal, p, c, f, fiber), units = row[:7]
        source = row[7] if len(row) > 7 else None
        assert fid not in seen, fid
        seen.add(fid)
        assert all(u in UNIT_FA and g > 0 for u, g in units), fid
        # سازگاری درونی: کالری باید با درشت‌مغذی‌ها بخواند (۴-۴-۹)، وگرنه غلط تایپی است.
        macro = 4 * p + 4 * c + 9 * f
        assert abs(macro - kcal) <= max(25, 0.2 * kcal), (fid, kcal, macro)
        out.append(
            {
                "id": fid,
                "name_fa": name,
                "aliases": aliases,
                "name_en": en,
                "category": cat,
                "per_100g": {"kcal": kcal, "protein": p, "carbs": c, "fat": f, "fiber": fiber},
                "units": [{"unit": u, "name_fa": UNIT_FA[u], "grams": g} for u, g in units]
                + [{"unit": "gram", "name_fa": "گرم", "grams": 1}],
                "default_unit": units[0][0],
                "source": source or ESTIMATE,
                "verified": source is not None,
            }
        )
    return out


if __name__ == "__main__":
    foods = build()
    path = ROOT / "assets/data/foods.json"
    path.write_text(json.dumps(foods, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"{len(foods)} غذا ← {path.relative_to(ROOT)}")
