#!/usr/bin/env python3
"""Yurtdışı ülke/eyalet/şehir listesini üretir: Shared/mobile/src/constants/world-locations.json

Kaynak: Diyanet verisini sunan ezanvakti.imsakiyem.com (uygulamanın vakit için zaten kullandığı servis;
aynı ilçe kimlikleri /prayer/times/<id>/<aralık> ucunda çalışır). Türkiye dahil edilmez (states.json +
all-districts.json). Servis dakikalık istek sınırı koyar (429); betik yavaş ilerler (~15 dk).

  python3 ios/scripts/gen-world-locations.py [--cache <dizin>]
  sh android/scripts/sync-shared.sh   # Android kopyası

Ülke adları uygulamada ISO koduyla seçili dilde gösterilir; ISO eşlemesi macOS'un Türkçe ülke adlarından
(Foundation Locale) otomatik, eşleşmeyenler aşağıdaki MANUAL tablosundan.
"""
import json, os, re, subprocess, sys, tempfile, time, unicodedata, urllib.error, urllib.request

API = "https://ezanvakti.imsakiyem.com/api/locations"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Shared/mobile/src/constants/world-locations.json")
TURKEY = "2"

MANUAL = {
    "ABD": "US", "INGILTERE": "GB", "SARABISTAN": "SA", "BIRLESIKARAPEMIRLIGI": "AE",
    "HOLLANDAANTILLERI": "CW", "UKRAYNAKIRIM": None, "CECENISTAN": None, "KUZEYKIBRIS": None,
    "ATLANTIKOKYANUSU": None, "KUDUS": None, "MONTSERRATUK": "MS", "DEMOKRATIKKONGOCUMHURIYETI": "CD",
    "MAURITIUSADASI": "MU", "GUAMADASI": "GU", "PITCAIRNADASI": "PN", "MANADASI": "IM",
    "BOSNAHERSEK": "BA", "CEKCUMHURIYETI": "CZ", "MAKEDONYA": "MK", "FILDISISAHILI": "CI",
    "YESILBURUN": "CV", "SEYSELADALARI": "SC", "STLUCIA": "LC", "HONGKONG": "HK", "MAKAO": "MO",
    "GRONLAND": "GL", "DOGUTIMOR": "TL", "ESWATINI": "SZ", "PORTORIKO": "PR", "REUNION": "RE",
    "GUADELOPE": "GP", "KOMORLAR": "KM", "ANTIGUAVEBARBUDA": "AG", "TRINIDATVETOBAGO": "TT",
    "ORTAAFRIKACUMHURIYETI": "CF", "DOMINIKCUMHURIYETI": "DO", "DOMINIK": "DM", "EKVATORGINESI": "GQ",
    "SOMALI": "SO", "BAHAMALAR": "BS", "MIKRONEZYA": "FM", "FILISTIN": "PS", "VATIKAN": "VA",
    "KOSOVA": "XK", "KOSTARIKA": "CR", "ASCENSION": "AC", "SVALBARD": "SJ", "YENIKALEDONYA": "NC",
    "PAPUAYENIGINE": "PG", "YENIZELANDA": "NZ", "GUNEYKORE": "KR", "KUZEYKORE": "KP",
    "GUNEYAFRIKA": "ZA", "GUNEYSUDAN": "SS", "SRILANKA": "LK", "ELSALVADOR": "SV", "SIERRALEONE": "SL",
    "TAYVAN": "TW", "CIN": "CN", "MYANMAR": "MM", "LESOTO": "LS", "BOTSVANA": "BW", "SILI": "CL",
    "KAMBOCYA": "KH", "CAD": "TD", "BENIN": "BJ", "MAYOTTE": "YT", "MARTINIK": "MQ", "ARUBA": "AW",
    "BERMUDA": "BM", "ANGUILLA": "AI", "NIUE": "NU", "PALAU": "PW", "TONGA": "TO", "SAMOA": "WS",
    "FIJI": "FJ", "VANUATU": "VU", "LIECHTENSTEIN": "LI", "ANDORRA": "AD", "MONAKO": "MC",
    "MOLDAVYA": "MD", "ETYOPYA": "ET", "EKVATOR": "EC",
}
# Konum servisleri adanın tamamına CY der; Diyanet'te Güney Kıbrıs yok.
GEO = {"KUZEYKIBRIS": "CY"}
# ISO kodu olmayanların görünen adı (Diyanet adları Türkçe karaktersiz).
NAMES = {"KUZEYKIBRIS": "Kuzey Kıbrıs", "UKRAYNAKIRIM": "Ukrayna-Kırım", "CECENISTAN": "Çeçenistan", "KUDUS": "Kudüs"}
# Şehir değil deniz noktaları (~10 bin kayıt); listeye alınmaz.
SKIP = {"ATLANTIKOKYANUSU"}

ISO_SWIFT = """
import Foundation
let tr = Locale(identifier: "tr_TR")
var out: [String: String] = [:]
for r in Locale.Region.isoRegions where r.identifier.count == 2 {
  if let n = tr.localizedString(forRegionCode: r.identifier) { out[r.identifier] = n }
}
print(String(data: try! JSONSerialization.data(withJSONObject: out), encoding: .utf8)!)
"""


def get(path):
    for _ in range(10):
        try:
            return json.load(urllib.request.urlopen(f"{API}/{path}", timeout=20))["data"]
        except urllib.error.HTTPError as e:
            time.sleep(30 if e.code == 429 else 5)
        except Exception:
            time.sleep(5)
    raise RuntimeError(f"alınamadı: {path}")


def cached(cache, name, fetch):
    path = os.path.join(cache, name) if cache else None
    if path and os.path.exists(path):
        return json.load(open(path))
    data = fetch()
    if path:
        json.dump(data, open(path, "w"), ensure_ascii=False)
    return data


def fold(s):
    s = unicodedata.normalize("NFKD", s.replace("İ", "I").replace("ı", "i"))
    return re.sub(r"[^A-Z0-9]", "", "".join(c for c in s if not unicodedata.combining(c)).upper())


def title(s):
    s = s.replace("İ", "i").lower()
    return re.sub(r"(^|[\s\-/(.'])(\w)", lambda m: m.group(1) + m.group(2).upper(), s)


def main():
    cache = sys.argv[sys.argv.index("--cache") + 1] if "--cache" in sys.argv else None
    if cache:
        os.makedirs(cache, exist_ok=True)
    with tempfile.NamedTemporaryFile("w", suffix=".swift", delete=False) as f:
        f.write(ISO_SWIFT)
    iso_tr = json.loads(subprocess.run(["swift", f.name], capture_output=True, text=True, check=True).stdout)
    by_fold = {fold(n): code for code, n in iso_tr.items()}

    countries = cached(cache, "countries.json", lambda: get("countries"))
    out_c, out_s, out_d, unmatched = [], [], [], []
    for c in countries:
        if c["_id"] == TURKEY:
            continue
        key = fold(c["name"])
        if key in SKIP:
            continue
        iso = MANUAL[key] if key in MANUAL else by_fold.get(key)
        if iso is None and key not in MANUAL:
            unmatched.append(c["name"])
        entry = {"id": c["_id"], "name": NAMES.get(key) or title(c["name"])}
        if iso:
            entry["iso"] = iso
        if key in GEO:
            entry["geo"] = GEO[key]
        states = cached(cache, f"s{c['_id']}.json", lambda: (time.sleep(1.5), get(f"states?countryId={c['_id']}"))[1])
        kept = 0
        for s in states:
            ds = cached(cache, f"d{s['_id']}.json", lambda: (time.sleep(1.5), get(f"districts?stateId={s['_id']}"))[1])
            if not ds:
                continue
            kept += 1
            out_s.append({"_id": s["_id"], "name": title(s["name"]), "country_id": c["_id"]})
            out_d += [{"_id": d["_id"], "name": title(d["name"]), "state_id": s["_id"]} for d in ds]
        if kept:
            out_c.append(entry)

    with open(OUT, "w") as f:
        json.dump({"countries": out_c, "states": out_s, "districts": out_d}, f, ensure_ascii=False, separators=(",", ":"))
    print(f"{len(out_c)} ülke, {len(out_s)} eyalet, {len(out_d)} şehir -> {OUT}")
    if unmatched:
        print("ISO eşleşmeyen (MANUAL'a ekle):", ", ".join(unmatched))


if __name__ == "__main__":
    main()
