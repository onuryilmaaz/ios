#!/usr/bin/env python3
"""Mushaf kenar işaretlerini üretir: Salah/Resources/mushaf-marks.generated.json

Kaynak: uygulamanın Mushaf sayfalarını aldığı api.quran.com (Medine Mushafı, Hafs). Her sayfanın ayetleri
çekilir; ayetin `rub_el_hizb_number`'ı bir öncekinden farklıysa yeni çeyrek (rub) o ayette başlar.
Secde ayetleri `sajdah_number` dolu olanlardır (14 ayet; 22:77 yok, Hanefi/Diyanet sayımıyla aynı).

  python3 ios/scripts/gen-mushaf-marks.py
  sh android/scripts/sync-shared.sh   # Android kopyası

Çıktı: {"rub": ["1:1", ...240 ayet anahtarı, sırayla], "sajdah": ["7:206", ...]}.
Hizb başı: (rub sırası - 1) % 4 == 0; hizb numarası (sıra - 1) // 4 + 1.
"""
import json, os, sys, time, urllib.request

OUT = os.path.join(os.path.dirname(__file__), "..", "Salah", "Resources", "mushaf-marks.generated.json")
URL = "https://api.quran.com/api/v4/verses/by_page/{}?per_page=50&fields=rub_el_hizb_number,sajdah_number"


def fetch(page):
    for attempt in range(5):
        try:
            with urllib.request.urlopen(urllib.request.Request(URL.format(page), headers={"User-Agent": "salah-gen"}), timeout=30) as r:
                return json.load(r)["verses"]
        except Exception as error:  # ağ hatası: kısa bekleyip yeniden dene
            print(f"sayfa {page}: {error}", file=sys.stderr)
            time.sleep(2 * (attempt + 1))
    sys.exit(f"sayfa {page} alınamadı")


def main():
    rub, sajdah, last = [], [], None
    for page in range(1, 605):
        for verse in fetch(page):
            if verse["rub_el_hizb_number"] != last:
                last = verse["rub_el_hizb_number"]
                rub.append(verse["verse_key"])
            if verse.get("sajdah_number"):
                sajdah.append(verse["verse_key"])
        if page % 50 == 0:
            print(f"{page}/604", file=sys.stderr)
    assert len(rub) == 240, len(rub)
    assert len(sajdah) == 14, sajdah
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump({"rub": rub, "sajdah": sajdah}, f, ensure_ascii=False, separators=(",", ":"))
        f.write("\n")
    print(f"yazıldı: {os.path.normpath(OUT)}")


if __name__ == "__main__":
    main()
