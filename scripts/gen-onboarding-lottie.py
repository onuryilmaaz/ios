#!/usr/bin/env python3
"""Onboarding Lottie animasyonları (kendi çizimimiz). Çıktı: Shared/mobile/assets/lottie/onboarding_<sahne>.json
Android aynı dosyaları kullanır (android/scripts/sync-shared.sh kopyalar).

Zaman çizelgesi: 0-30 giriş (öğeler sırayla belirir, bir kez oynar), 30-150 kesintisiz döngü. Uygulama önce 0-150'yi
bir kez, sonra 30-150'yi döngüde oynatır (iOS OnboardingAnimation.swift, Android OnboardingAnimation.kt: INTRO/END).

Renkler dolgu/çizgi adlarıyla verilir; uygulama çalışırken temadan boyanır:
  accent  vurgu (accent-600 / dark accent-400)
  deep    koyu vurgu (accent-800 / dark accent-200)
  mid     ikincil (accent-200 / dark accent-700)
  soft    zemin (accent-50 / dark accent-900)
  gold    altın (gold-500 / dark gold-300)
  paper   iç ayrıntı (beyaz / dark slate-900)
JSON'daki renkler yalnız varsayılan (Derin Orman, açık tema). Gölge, parıltı, gradyan yok.

Çalıştır:  python3 scripts/gen-onboarding-lottie.py
"""
import json
import math
import os

W = H = 240
FR = 30
INTRO = 30  # giriş bitişi = döngü başı
LOOP = 120  # 4 sn döngü
OP = INTRO + LOOP
OUT = os.path.join(os.path.dirname(__file__), "..", "Shared", "mobile", "assets", "lottie")

DEFAULTS = {
    "accent": 0x1F7356, "deep": 0x154A39, "mid": 0xAED6C3, "soft": 0xEEF6F2, "gold": 0xC48F2B, "paper": 0xFFFFFF,
}


def rgb(role):
    h = DEFAULTS[role]
    return [((h >> 16) & 255) / 255, ((h >> 8) & 255) / 255, (h & 255) / 255, 1]


# MARK: - Özellikler

def static(v):
    return {"a": 0, "k": v}


def anim(kfs, ease=True, hold=False):
    """kfs: [(kare, değer)]; değer sayı ya da liste. Son kare yalnız varış değeri."""
    out = []
    for n, (t, v) in enumerate(kfs):
        s = v if isinstance(v, list) else [v]
        k = {"t": t, "s": s}
        if n < len(kfs) - 1:
            d = len(s)
            if hold:
                k["h"] = 1
            elif ease:
                k["o"] = {"x": [0.42] * d, "y": [0] * d}
                k["i"] = {"x": [0.58] * d, "y": [1] * d}
            else:
                k["o"] = {"x": [0] * d, "y": [0] * d}
                k["i"] = {"x": [1] * d, "y": [1] * d}
        out.append(k)
    return {"a": 1, "k": out}


def loop(kfs, ease=True, hold=False):
    """Döngü zamanında (0-120) kareler; girişte ilk değer tutulur. İlk ve son değer aynı olmalı (kesintisiz döngü)."""
    assert kfs[0][0] == 0 and kfs[-1][0] == LOOP, kfs
    shifted = [(INTRO + t, v) for t, v in kfs]
    return anim([(0, kfs[0][1])] + shifted, ease=ease, hold=hold)


def prop(v):
    return v if isinstance(v, dict) else static(v)


def v3(x, y):
    return [x, y, 100]


# MARK: - Şekiller

def ellipse(cx, cy, w, h=None):
    return {"ty": "el", "p": static([cx, cy]), "s": static([w, w if h is None else h]), "d": 1}


def rect(cx, cy, w, h, r=0):
    return {"ty": "rc", "p": static([cx, cy]), "s": static([w, h]), "r": static(r), "d": 1}


def path(vs, ins=None, outs=None, closed=True):
    n = len(vs)
    return {"ty": "sh", "d": 1, "ks": static({
        "c": closed, "v": [list(v) for v in vs],
        "i": [list(x) for x in (ins or [[0, 0]] * n)], "o": [list(x) for x in (outs or [[0, 0]] * n)],
    })}


def poly(points, closed=True):
    return path(points, closed=closed)


def line(x1, y1, x2, y2):
    return poly([[x1, y1], [x2, y2]], closed=False)


def star(cx, cy, outer, inner, points=4):
    return {"ty": "sr", "sy": 1, "d": 1, "pt": static(points), "p": static([cx, cy]), "r": static(0),
            "ir": static(inner), "is": static(0), "or": static(outer), "os": static(0)}


def arc(cx, cy, r, a0, a1, steps=None):
    """Bezier yay (derece; artan açı ekranda saat yönü)."""
    steps = steps or max(1, int(math.ceil(abs(a1 - a0) / 90)))
    da = (a1 - a0) / steps
    k = 4 / 3 * math.tan(math.radians(da) / 4) * r
    vs, ins, outs = [], [], []
    for i in range(steps + 1):
        a = math.radians(a0 + da * i)
        vs.append([cx + r * math.cos(a), cy + r * math.sin(a)])
        tx, ty = -math.sin(a), math.cos(a)
        ins.append([-tx * k, -ty * k])
        outs.append([tx * k, ty * k])
    return vs, ins, outs


def arc_path(cx, cy, r, a0, a1):
    vs, ins, outs = arc(cx, cy, r, a0, a1)
    return path(vs, ins, outs, closed=False)


def half_dome(cx, base_y, r):
    vs, ins, outs = arc(cx, base_y, r, 180, 360, 2)
    return path(vs, [[0, 0]] + ins[1:], outs[:-1] + [[0, 0]])


def crescent(cx, cy, r, cut_dx, cut_dy, cut_r, n=24):
    """Hilal: r yarıçaplı daireden kayık daire çıkarılır (iki çemberin kesişimi arasında dış ve iç yay)."""
    c1, c2 = (cx, cy), (cx + cut_dx, cy + cut_dy)
    d = math.dist(c1, c2)
    a = (r * r - cut_r * cut_r + d * d) / (2 * d)
    h = math.sqrt(max(r * r - a * a, 0))
    ux, uy = (c2[0] - c1[0]) / d, (c2[1] - c1[1]) / d
    px, py = c1[0] + a * ux, c1[1] + a * uy
    p1, p2 = (px - h * uy, py + h * ux), (px + h * uy, py - h * ux)
    ang = lambda p, c: math.atan2(p[1] - c[1], p[0] - c[0])
    away = math.atan2(-uy, -ux)

    def sweep(c, rad, start, end, through):
        a0, a1 = ang(start, c), ang(end, c)
        for direction in (1, -1):
            delta = ((a1 - a0) * direction) % (2 * math.pi)
            if ((through - a0) * direction) % (2 * math.pi) <= delta:
                return [(c[0] + rad * math.cos(a0 + direction * delta * k / n), c[1] + rad * math.sin(a0 + direction * delta * k / n))
                        for k in range(n + 1)]
        return []

    pts = sweep(c1, r, p1, p2, away) + sweep(c2, cut_r, p2, p1, away)[1:-1]
    return poly([[round(x, 2), round(y, 2)] for x, y in pts])


def fill(role, opacity=100):
    return {"ty": "fl", "nm": role, "c": static(rgb(role)), "o": prop(opacity), "r": 1}


def stroke(role, width, opacity=100, dash=None):
    s = {"ty": "st", "nm": role, "c": static(rgb(role)), "o": prop(opacity), "w": static(width), "lc": 2, "lj": 2, "ml": 4}
    if dash:
        s["d"] = [{"n": "d", "nm": "dash", "v": static(dash[0])}, {"n": "g", "nm": "gap", "v": static(dash[1])},
                  {"n": "o", "nm": "offset", "v": static(0)}]
    return s


def trim(end, start=0):
    return {"ty": "tm", "s": prop(start), "e": prop(end), "o": static(0), "m": 1}


def tr(p=(0, 0), a=(0, 0), s=100, r=0, o=100):
    sv = s if isinstance(s, dict) else static([s, s])
    pv = p if isinstance(p, dict) else static(list(p))
    return {"ty": "tr", "p": pv, "a": static(list(a)), "s": sv, "r": prop(r), "o": prop(o), "sk": static(0), "sa": static(0)}


def group(name, items, transform=None):
    return {"ty": "gr", "nm": name, "it": items + [transform or tr()]}


def pop(name, items, center, delay, overshoot=112):
    """Giriş: öğe `delay` karesinde merkezinden büyüyerek belirir (bir kez)."""
    s = anim([(0, [0, 0]), (delay, [0, 0]), (delay + 9, [overshoot, overshoot]), (delay + 15, [100, 100]), (OP, [100, 100])])
    o = anim([(0, 0), (delay, 0), (delay + 4, 100), (OP, 100)])
    return group(name, items, tr(p=center, a=center, s=s, o=o))


def rise(name, items, base, delay, dy=22):
    """Giriş: öğe aşağıdan yükselerek belirir."""
    p = anim([(0, [base[0], base[1] + dy]), (delay, [base[0], base[1] + dy]), (delay + 14, list(base)), (OP, list(base))])
    o = anim([(0, 0), (delay, 0), (delay + 6, 100), (OP, 100)])
    return group(name, items, tr(p=p, a=base, o=o))


# MARK: - Katman

def layer(name, shapes, p=(120, 120), a=(120, 120), s=100, r=0, o=100):
    sv = s if isinstance(s, dict) else static([s, s, 100])
    pv = p if isinstance(p, dict) else static([p[0], p[1], 0])
    return {"ddd": 0, "ty": 4, "nm": name, "sr": 1, "ao": 0, "ip": 0, "op": OP, "st": 0, "bm": 0,
            "ks": {"o": prop(o), "r": prop(r), "p": pv, "a": static([a[0], a[1], 0]), "s": sv}, "shapes": shapes}


def backdrop():
    return [
        layer("ring", [pop("ring", [ellipse(120, 120, 212), stroke("mid", 1.5, 70, dash=(2, 10))], (120, 120), 2, overshoot=100)],
              r=anim([(0, 0), (OP, 36)], ease=False)),
        layer("disc", [pop("disc", [ellipse(120, 120, 188), fill("soft")], (120, 120), 0, overshoot=106)]),
    ]


def compose(name, layers):
    """layers: üstten alta; zemin en altta."""
    ls = layers + backdrop()
    for i, l in enumerate(ls):
        l["ind"] = i + 1
    return {"v": "5.7.4", "fr": FR, "ip": 0, "op": OP, "w": W, "h": H, "nm": name, "ddd": 0, "assets": [], "layers": ls,
            "markers": [{"tm": INTRO, "cm": "loop", "dr": LOOP}]}


def bob(dy=3, phase=0):
    """Döngü boyunca hafif yukarı aşağı süzülme (katman konumu ile kullanılır: p=(x, y))."""
    return lambda x, y: loop([(0, [x, y, 0]), (30, [x, y - dy, 0]), (60, [x, y, 0]), (90, [x, y - dy, 0]), (LOOP, [x, y, 0])])


# MARK: - Sahneler

def welcome():
    twinkle = lambda t0: loop([(0, 30), (t0, 30), (t0 + 15, 100), (t0 + 30, 30), (LOOP, 30)])
    stars = [layer(f"star{i}", [pop("star", [star(x, y, s, s * 0.38), fill("gold")], (x, y), d)], o=twinkle(t))
             for i, (x, y, s, t, d) in enumerate([(64, 72, 7, 0, 18), (178, 60, 5, 30, 20), (190, 108, 4, 60, 22), (52, 116, 4, 85, 24)])]
    moon = layer("moon", [pop("moon", [crescent(120, 62, 13, 6, -4, 11), fill("gold")], (120, 62), 14)],
                 p=(120, 62), a=(120, 62), r=loop([(0, -10), (60, 10), (LOOP, -10)]))
    # Pencereler sırayla altın yanar (akşam ışıkları).
    glows = [layer(f"glow{i}", [group("glow", [ellipse(x, 152, 5.5), fill("gold")])],
                   o=loop([(0, 0), (t, 0), (t + 12, 100), (t + 40, 100), (t + 52, 0), (LOOP, 0)]))
             for i, (x, t) in enumerate([(100, 10), (140, 30)])]
    # Kubbeden yükselen ışık noktaları.
    motes = [layer(f"mote{i}", [group("mote", [ellipse(x, 100, 3.5), fill("gold")])],
                   p=loop([(0, [120, 120, 0]), (t, [120, 120, 0]), (t + 50, [120, 90, 0]), (LOOP, [120, 90, 0])], ease=False),
                   o=loop([(0, 0), (t, 0), (t + 12, 90), (t + 50, 0), (LOOP, 0)]))
             for i, (x, t) in enumerate([(112, 0), (128, 40), (120, 70)])]
    mosque = layer("mosque", [
        rise("door", [path([[112, 170], [112, 158], [128, 158], [128, 170]], [[0, 0], [0, 4.4], [0, 0], [0, 0]],
                           [[0, 0], [0, 0], [0, -4.4], [0, 0]]), fill("paper")], (120, 170), 8),
        rise("windows", [ellipse(100, 152, 5.5), ellipse(140, 152, 5.5), fill("paper")], (120, 152), 8),
        rise("finial", [rect(120, 106, 3, 12, 1.5), fill("gold")], (120, 112), 12),
        rise("dome", [half_dome(120, 146, 32), fill("accent")], (120, 146), 8),
        rise("body", [rect(120, 158, 72, 24, 4), fill("accent")], (120, 170), 6),
        rise("minaret-l", [rect(74, 138, 10, 64, 3), poly([[69, 107], [74, 92], [79, 107]]), rect(74, 122, 16, 4, 2), fill("deep")], (74, 170), 10, dy=34),
        rise("minaret-r", [rect(166, 138, 10, 64, 3), poly([[161, 107], [166, 92], [171, 107]]), rect(166, 122, 16, 4, 2), fill("deep")], (166, 170), 12, dy=34),
        pop("ground", [rect(120, 172, 136, 5, 2.5), fill("deep")], (120, 172), 4, overshoot=100),
    ])
    return compose("welcome", [moon] + stars + motes + glows + [mosque])


def times():
    """Vakitler ve widget'lar: widget kartında güneş vakit yayında ilerler; üstte genişleyen geri sayım hapı."""
    cx, cy, r = 120, 146, 40
    travel = 104
    angle = lambda t: 192 + 156 * t / travel
    sun_k = [(t, [cx + r * math.cos(math.radians(angle(t))), cy + r * math.sin(math.radians(angle(t))), 0]) for t in range(0, travel + 1, 8)]
    sun_k += [(travel + 6, sun_k[-1][1]), (LOOP, sun_k[0][1])]  # görünmezken başa döner
    sun = layer("sun", [group("sun", [ellipse(120, 120, 14), fill("gold")])], p=loop(sun_k, ease=False), a=(120, 120),
                o=loop([(0, 0), (6, 100), (travel - 4, 100), (travel + 4, 0), (LOOP, 0)]))
    dots = []
    for i, d in enumerate([204, 240, 270, 300, 336]):
        x, y = cx + r * math.cos(math.radians(d)), cy + r * math.sin(math.radians(d))
        t = int((d - 192) / 156 * travel)
        dots.append(layer(f"dot{i}", [group("dot", [ellipse(x, y, 6), fill("accent")])], p=(x, y), a=(x, y),
                          s=loop([(0, v3(100, 100)), (max(t - 3, 1), v3(100, 100)), (t + 3, v3(170, 170)), (t + 12, v3(100, 100)), (LOOP, v3(100, 100))])))
    ring = layer("ring-progress", [group("p", [arc_path(154, 172, 8, -90, 270), trim(loop([(0, 0), (100, 100), (LOOP, 0)], ease=False)), stroke("accent", 3)])])
    card = layer("card", [
        group("ring-bg", [ellipse(154, 172, 16), stroke("mid", 3)]),
        group("text", [rect(98, 168, 40, 6, 3), fill("deep")]),
        group("text2", [rect(92, 178, 28, 5, 2.5), fill("mid")]),
        group("horizon", [line(76, 146, 164, 146), stroke("accent", 2.5)]),
        group("arc", [arc_path(cx, cy, r, 180, 360), stroke("mid", 2.5)]),
        group("card", [rect(120, 146, 124, 92, 18), fill("paper"), stroke("mid", 2)]),
    ])
    card["shapes"] = [pop("card-in", card["shapes"], (120, 146), 4)]
    # Geri sayım hapı (Dinamik Ada / bildirim şeridi): genişler, altın nokta ve metin belirir.
    width = loop([(0, [40, 22]), (8, [40, 22]), (20, [112, 26]), (92, [112, 26]), (104, [40, 22]), (LOOP, [40, 22])])
    pill = layer("pill", [pop("pill", [
        group("label", [rect(132, 66, 52, 6, 3), fill("paper", loop([(0, 0), (16, 0), (24, 100), (90, 100), (96, 0), (LOOP, 0)]))]),
        group("dot", [ellipse(76, 66, 9), fill("gold", loop([(0, 0), (14, 0), (22, 100), (92, 100), (98, 0), (LOOP, 0)]))]),
        group("pill", [{"ty": "rc", "p": static([120, 66]), "s": width, "r": static(13), "d": 1}, fill("deep")]),
    ], (120, 66), 12)])
    return compose("times", [sun, ring] + dots + [pill, card])


def quran():
    left = path([[120, 98], [70, 90], [70, 152], [120, 160]], [[0, 0], [18, -3], [0, 0], [-18, -8]], [[-18, -8], [0, 0], [18, -3], [0, 0]])
    right = path([[120, 98], [170, 90], [170, 152], [120, 160]], [[0, 0], [-18, -3], [0, 0], [18, -8]], [[18, -8], [0, 0], [-18, -3], [0, 0]])

    def lines(x0, x1, name, t0):
        items = [line(x0, y, x1, y - 1 if x0 < 120 else y + 1) for y in (112, 123, 134, 145)]
        return layer(name, [group(name, items + [trim(loop([(0, 0), (t0, 0), (t0 + 24, 100), (LOOP - 12, 100), (LOOP, 0)])), stroke("accent", 2.5, 70)])])

    flip = layer("flip", [group("page", [right, fill("paper"), stroke("accent", 2.5)])], p=(120, 120), a=(120, 120),
                 s=loop([(0, v3(100, 100)), (52, v3(100, 100)), (64, v3(0, 100)), (76, v3(-100, 100)), (LOOP, v3(-100, 100))]),
                 o=loop([(0, 0), (50, 0), (52, 100), (80, 100), (88, 0), (LOOP, 0)]))
    book = layer("book", [pop("book", [
        group("spine", [line(120, 98, 120, 160), stroke("deep", 2.5)]),
        group("left", [left, fill("paper"), stroke("accent", 2.5)]),
        group("right", [right, fill("paper"), stroke("accent", 2.5)]),
        group("cover", [rect(120, 134, 112, 60, 6), fill("accent")]),
    ], (120, 130), 4)], p=bob(2)(120, 130), a=(120, 130))
    # Ezber: dönen tekrar oku içinde altın rozet.
    arrow_v, arrow_i, arrow_o = arc(176, 80, 8, -60, 230)
    end = math.radians(230)
    px, py = 176 + 8 * math.cos(end), 80 + 8 * math.sin(end)
    tx, ty = -math.sin(end), math.cos(end)
    head_pts = [[px + tx * 4.5, py + ty * 4.5], [px - ty * 4, py + tx * 4], [px + ty * 4, py - tx * 4]]
    badge = layer("hifz", [pop("hifz", [
        group("arrow", [path(arrow_v, arrow_i, arrow_o, closed=False), stroke("paper", 2.5)],
              tr(p=(176, 80), a=(176, 80), r=loop([(0, 0), (LOOP, 360)], ease=False))),
        group("head", [poly(head_pts), fill("paper")],
              tr(p=(176, 80), a=(176, 80), r=loop([(0, 0), (LOOP, 360)], ease=False))),
        group("disc", [ellipse(176, 80, 32), fill("gold")]),
    ], (176, 80), 18)])
    return compose("quran", [badge, flip, lines(80, 112, "lines-l", 2), lines(128, 160, "lines-r", 12), book])


def tracker():
    """İbadet takibi ve seri: çubuklar yükselir, alev rozeti titrer, hafta noktaları sırayla yanar."""
    bars = []
    for i, (x, h) in enumerate([(80, 30), (102, 50), (124, 40), (146, 64)]):
        d = 4 + i * 4
        grow = anim([(0, v3(100, 0)), (d, v3(100, 0)), (d + 14, v3(100, 108)), (d + 20, v3(100, 100)), (OP, v3(100, 100))])
        bars.append(layer(f"bar{i}", [group("bar", [rect(x, 160 - h / 2, 15, h, 4), fill("accent" if i == 3 else "mid")])],
                          p=(x, 160), a=(x, 160), s=grow))
    outer = path([[176, 62], [190, 92], [174, 112], [158, 94], [162, 78], [167, 86]],
                 [[-1, 9], [-2, -11], [9, 0], [0, 10], [-3, 6], [-2, -3]], [[4, 8], [2, 12], [-9, 0], [0, -7], [1, 5], [1, -13]])
    inner = path([[174, 88], [181, 101], [174, 109], [167, 101]], [[-3, 4], [0, -6], [4, 0], [0, 5]], [[1, 4], [0, 5], [-4, 0], [0, -6]])
    flame = layer("flame", [pop("flame", [
        group("flame", [inner, fill("paper"), outer, fill("gold")],
              tr(p=(174, 112), a=(174, 112), s=loop([(0, [100, 100]), (15, [94, 107]), (30, [104, 97]), (45, [96, 104]), (60, [100, 100]),
                                                       (75, [94, 107]), (90, [104, 97]), (105, [96, 104]), (LOOP, [100, 100])]))),
    ], (174, 92), 20)])
    days = []
    for i in range(7):
        x = 78 + i * 14
        t = 6 + i * 10
        days.append(layer(f"day{i}", [pop("day", [ellipse(x, 182, 8), fill("accent")], (x, 182), 10 + i * 2)], p=(x, 182), a=(x, 182),
                          o=loop([(0, 30), (t, 30), (t + 5, 100), (100, 100), (110, 30), (LOOP, 30)]),
                          s=loop([(0, v3(100, 100)), (t, v3(100, 100)), (t + 4, v3(150, 150)), (t + 9, v3(100, 100)), (LOOP, v3(100, 100))])))
    base = layer("base", [pop("base", [line(66, 162, 158, 162), stroke("deep", 3)], (112, 162), 2, overshoot=100)])
    return compose("tracker", [flame] + bars + [base] + days)


def tools():
    """Kıble, zikirmatik, kaza: ortada pusula, çevresinde tane tane ilerleyen tesbih."""
    beads = []
    n, br = 24, 76
    for i in range(1, n):  # en alttaki yerde imame
        a = math.radians(90 + i * 360 / n)
        beads.append(ellipse(120 + br * math.cos(a), 120 + br * math.sin(a), 7))
    ring = layer("beads", [pop("beads", beads + [fill("mid")], (120, 120), 6, overshoot=104)])
    # Sayılan tane: 5 karede bir sonraki taneye atlar (zikirmatik).
    steps = [((k - 1) * 5, k * 15) for k in range(1, n)] + [(LOOP, 15)]
    counter = layer("counter", [group("bead", [ellipse(120, 120 + br, 10), fill("accent")])], p=(120, 120), a=(120, 120),
                    r=loop(steps, hold=True), o=anim([(0, 0), (INTRO - 6, 0), (INTRO, 100), (OP, 100)]))
    imame = layer("imame", [pop("imame", [
        group("tassel", [line(120, 203, 120, 214), stroke("gold", 3)]),
        group("imame", [rect(120, 197, 9, 14, 4.5), fill("gold")]),
    ], (120, 197), 10)])
    needle = layer("needle", [pop("needle", [
        group("south", [poly([[120, 120], [113, 123], [120, 156], [127, 123]]), fill("mid")]),
        group("north", [poly([[120, 120], [113, 117], [120, 84], [127, 117]]), fill("accent")]),
    ], (120, 120), 14)], r=loop([(0, -36), (20, 24), (36, -12), (50, 6), (62, 0), (100, 0), (LOOP, -36)]))
    hub = layer("hub", [pop("hub", [ellipse(120, 120, 10), fill("paper"), ellipse(120, 120, 10), stroke("accent", 3)], (120, 120), 16)])
    ticks = []
    for i in range(8):
        a = math.radians(i * 45)
        r1 = 36 if i % 2 == 0 else 40
        ticks.append(group(f"tick{i}", [line(120 + r1 * math.cos(a), 120 + r1 * math.sin(a), 120 + 44 * math.cos(a), 120 + 44 * math.sin(a)),
                                        stroke("accent" if i % 2 == 0 else "mid", 2.5)]))
    dial = layer("dial", [pop("dial", ticks + [group("face", [ellipse(120, 120, 100), fill("paper"), stroke("accent", 3)])], (120, 120), 8)])
    kaaba = layer("kaaba", [pop("kaaba", [
        group("band", [rect(120, 66, 16, 3, 0), fill("gold")]),
        group("cube", [rect(120, 69, 16, 15, 2.5), fill("deep")]),
    ], (120, 69), 18)], p=(120, 69), a=(120, 69), s=loop([(0, v3(100, 100)), (62, v3(100, 100)), (68, v3(118, 118)), (76, v3(100, 100)), (LOOP, v3(100, 100))]))
    return compose("tools", [hub, needle, kaaba, dial, counter, imame, ring])


def prayer_lock():
    """Vakit kilidi: telefondaki uygulamalar kilitlenir, namaz işaretlenince kilit açılır."""
    tiles = [rect(x, y, 22, 22, 7) for x in (104, 136) for y in (94, 126, 158)]
    phone = layer("phone", [pop("phone", [
        group("tiles", tiles + [fill("mid")]),
        group("speaker", [rect(120, 66, 22, 4, 2), fill("mid")]),
        group("frame", [rect(120, 124, 92, 148, 18), fill("paper"), stroke("accent", 3)]),
    ], (120, 124), 4)])
    overlay_o = loop([(0, 0), (12, 0), (22, 88), (92, 88), (104, 0), (LOOP, 0)])
    overlay = layer("overlay", [group("overlay", [rect(120, 128, 80, 120, 12), fill("deep")])], o=overlay_o)
    shackle_v, shackle_i, shackle_o = arc(120, 118, 10, 180, 360, 2)
    shackle_v = [[110, 128]] + shackle_v + [[130, 128]]
    shackle_i = [[0, 0]] + [[0, 0]] + shackle_i[1:] + [[0, 0]]
    shackle_o = [[0, 0]] + shackle_o[:-1] + [[0, 0]] + [[0, 0]]
    lock = layer("lock", [
        group("shackle", [path(shackle_v, shackle_i, shackle_o, closed=False), stroke("gold", 4)],
              tr(p=loop([(0, [0, -8]), (20, [0, -8]), (30, [0, 0]), (84, [0, 0]), (92, [0, -8]), (LOOP, [0, -8])]))),
        group("body", [rect(120, 136, 32, 24, 6), fill("gold")]),
        group("keyhole", [ellipse(120, 134, 6), rect(120, 139, 3, 7, 1.5), fill("deep")]),
    ], o=overlay_o)
    check = layer("check", [
        group("tick", [poly([[141, 84], [146, 89], [155, 79]], closed=False), stroke("paper", 3)]),
        group("disc", [ellipse(148, 84, 26), fill("accent")]),
    ], p=(148, 84), a=(148, 84),
        s=loop([(0, v3(0, 0)), (66, v3(0, 0)), (74, v3(115, 115)), (80, v3(100, 100)), (100, v3(100, 100)), (108, v3(0, 0)), (LOOP, v3(0, 0))]))
    return compose("prayerLock", [check, lock, overlay, phone])


def location():
    drop = anim([(0, [120, 86, 0]), (6, [120, 86, 0]), (16, [120, 146, 0]), (21, [120, 138, 0]), (26, [120, 146, 0]), (INTRO, [120, 146, 0]),
                 (INTRO + 30, [120, 140, 0]), (INTRO + 60, [120, 146, 0]), (INTRO + 90, [120, 140, 0]), (OP, [120, 146, 0])])
    pin = layer("pin", [
        group("hole", [ellipse(120, 100, 22), fill("paper")]),
        group("pin", [path([[120, 70], [148, 100], [120, 146], [92, 100]],
                           [[-15.5, 0], [0, -15.5], [12, -16], [0, 16]], [[15.5, 0], [0, 16], [-12, -16], [0, -15.5]]), fill("accent")]),
    ], p=drop, a=(120, 146), o=anim([(0, 0), (6, 0), (9, 100), (OP, 100)]))
    ripple = lambda name, t0: layer(name, [group("ripple", [ellipse(120, 156, 36, 10), stroke("accent", 2.5)])], p=(120, 156), a=(120, 156),
                                    s=loop([(0, v3(60, 60)), (t0, v3(60, 60)), (t0 + 60, v3(240, 240)), (LOOP, v3(240, 240))], ease=False),
                                    o=loop([(0, 0), (t0, 0), (t0 + 2, 90), (t0 + 60, 0), (LOOP, 0)], ease=False))
    shadow = layer("shadow", [pop("shadow", [ellipse(120, 156, 24, 7), fill("mid")], (120, 156), 14)], p=(120, 156), a=(120, 156),
                   s=loop([(0, v3(100, 100)), (30, v3(80, 80)), (60, v3(100, 100)), (90, v3(80, 80)), (LOOP, v3(100, 100))]))
    roads = layer("roads", [pop("roads", [
        group("road1", [path([[52, 150], [188, 118]], [[0, 0], [-40, 20]], [[40, -30], [0, 0]], closed=False), stroke("mid", 7, 60)]),
        group("road2", [path([[86, 62], [150, 194]], [[0, 0], [10, -40]], [[-20, 40], [0, 0]], closed=False), stroke("mid", 5, 45)]),
        group("path", [path([[64, 182], [120, 160]], [[0, 0], [-24, 8]], [[20, -4], [0, 0]], closed=False), stroke("accent", 2.5, 80, dash=(3, 6))]),
    ], (120, 128), 2, overshoot=100)])
    return compose("location", [pin, ripple("ripple1", 0), ripple("ripple2", 60), shadow, roads])


def notifications():
    swing = loop([(0, 0), (8, 14), (18, -12), (28, 9), (38, -6), (48, 3), (58, 0), (LOOP, 0)])
    bell = layer("bell", [pop("bell", [
        group("knob", [ellipse(120, 82, 10), fill("accent")]),
        group("bell", [path([[120, 86], [143, 112], [147, 138], [156, 150], [84, 150], [93, 138], [97, 112]],
                            [[-13, 0], [0, -12], [0, -8], [-3, -5], [0, 0], [-1, 6], [0, 12]],
                            [[13, 0], [0, 12], [1, 6], [0, 0], [3, -5], [0, -8], [0, -12]]), fill("accent")]),
        group("clapper", [ellipse(120, 155, 14), fill("gold")]),
    ], (120, 120), 6)], p=(120, 78), a=(120, 78), r=swing)
    waves = []
    for i, (side, r, t) in enumerate([(1, 30, 4), (1, 44, 10), (-1, 30, 4), (-1, 44, 10)]):
        a0, a1 = (-35, 35) if side == 1 else (145, 215)
        waves.append(layer(f"wave{i}", [group("wave", [arc_path(120, 122, r + 14, a0, a1), stroke("mid" if r > 30 else "accent", 3)])],
                           o=loop([(0, 0), (t, 0), (t + 8, 100), (t + 34, 0), (LOOP, 0)])))
    # Bildirim şeridi yukarıdan iner.
    banner_p = loop([(0, [120, 22, 0]), (2, [120, 22, 0]), (14, [120, 52, 0]), (88, [120, 52, 0]), (100, [120, 22, 0]), (LOOP, [120, 22, 0])])
    banner_o = loop([(0, 0), (2, 0), (10, 100), (92, 100), (100, 0), (LOOP, 0)])
    banner = layer("banner", [
        group("text", [rect(126, 48, 50, 5, 2.5), fill("deep"), rect(118, 57, 34, 4, 2), fill("mid")]),
        group("icon", [ellipse(88, 52, 14), fill("gold")]),
        group("card", [rect(120, 52, 104, 30, 12), fill("paper"), stroke("mid", 1.5)]),
    ], p=banner_p, a=(120, 52), o=banner_o)
    return compose("notifications", [banner, bell] + waves)


SCENES = {"welcome": welcome, "times": times, "quran": quran, "tracker": tracker, "tools": tools, "prayerLock": prayer_lock,
          "location": location, "notifications": notifications}

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for f in os.listdir(OUT):
        if f.startswith("onboarding_") and f.endswith(".json"):
            os.remove(os.path.join(OUT, f))
    for name, make in SCENES.items():
        data = make()
        with open(os.path.join(OUT, f"onboarding_{name}.json"), "w") as f:
            json.dump(data, f, separators=(",", ":"))
        print(name, len(data["layers"]), "katman")
