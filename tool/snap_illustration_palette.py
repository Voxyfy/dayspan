# -*- coding: utf-8 -*-
"""unDraw çizimlerini Dayspan'ın koyu, tek renkli paletine oturtur.

Kural: renk karoda yaşar. Çizimde renk olsa on karo renginin yanında on
birinci renk olur; bu yüzden çizimler **tek renk**: beyaz vurgu, gri tonlar,
koyu yüzeyler. unDraw'ın birincil rengi (#6C63FF, orta açıklık) beyaza
gider — çizimin "vurgu" dediği yer bizde de vurgu olur.

Açıklık ters çevrilir: açık zemin için çizilmiş bir çizimde koyu konturlar
siyah zeminde kaybolur, açık yüzeyler kör edici bir leke olur.

Degradeler düz renge çevrilir: `flutter_svg` çözemediği degradede çizimin
tamamını sessizce atıyor.

Kullanım: `python3 tool/snap_illustration_palette.py`
"""
import colorsys
import glob
import os
import re

BG = '0B0B0D'
SURFACE = '1C1C21'
SURFACE_2 = '26262C'
SURFACE_3 = '3A3A42'
GREY = '6B6B75'
GREY_LIGHT = 'A1A1AA'
GREY_PALE = 'D4D4D8'
WHITE = 'F5F5F7'

# Nötrler: (kaynak açıklık, hedef). Açık → koyu yüzey, koyu → açık kontur.
NOTRLER = [
    (1.00, SURFACE_3), (0.96, SURFACE_2), (0.92, SURFACE_2), (0.86, SURFACE_3),
    (0.65, GREY), (0.45, GREY_LIGHT), (0.30, GREY_PALE), (0.20, WHITE), (0.11, WHITE),
]

RENK_OZNITELIKLERI = ('fill', 'stroke', 'stop-color', 'flood-color', 'color')


def hsl(hexcode):
    r, g, b = (int(hexcode[i:i + 2], 16) / 255 for i in (0, 2, 4))
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    return h * 360, s, l


def snap(hexcode):
    h, s, l = hsl(hexcode)
    if s < 0.16:
        return min(NOTRLER, key=lambda n: abs(n[0] - l))[1]
    # Renkli yüzeyler: en açıklar (zemin lekeleri) koyu yüzey, orta açıklık
    # (unDraw'ın birincil rengi) beyaz, koyular açık gri.
    if l > 0.86:
        return SURFACE
    if l > 0.74:
        return SURFACE_3
    if l > 0.52:
        return WHITE
    if l > 0.34:
        return GREY_PALE
    return GREY_LIGHT


def degrade_renkleri(icerik):
    ham, href = {}, {}
    desen = r'<(?:linear|radial)Gradient\b([^>]*?)(?:/>|>(.*?)</(?:linear|radial)Gradient>)'
    for m in re.finditer(desen, icerik, re.S):
        oznitelik, govde = m.group(1), m.group(2) or ''
        kimlik = re.search(r'id="([^"]+)"', oznitelik)
        if not kimlik:
            continue
        durak = re.search(r'stop-color="(#[0-9a-fA-F]{6})"', govde)
        if durak:
            ham[kimlik.group(1)] = durak.group(1)
        else:
            bagli = re.search(r'xlink:href="#([^"]+)"', oznitelik)
            if bagli:
                href[kimlik.group(1)] = bagli.group(1)
    for kimlik, hedef in href.items():
        gorulen = set()
        while hedef in href and hedef not in gorulen:
            gorulen.add(hedef)
            hedef = href[hedef]
        if hedef in ham:
            ham[kimlik] = ham[hedef]
    return ham


def duzlestir(icerik):
    for kimlik, renk in degrade_renkleri(icerik).items():
        icerik = icerik.replace('url(#%s)' % kimlik, renk)
    icerik = re.sub(r'<(linear|radial)Gradient\b.*?</\1Gradient>', '', icerik, flags=re.S)
    icerik = re.sub(r'<(?:linear|radial)Gradient\b[^>]*/>', '', icerik)
    return re.sub(r'url\(#[^)]*\)', '#' + SURFACE_2, icerik)


def oturt(icerik):
    sayac = [0]

    def degistir(m):
        oznitelik, renk = m.group(1), m.group(2)
        yeni = snap(renk.lstrip('#').lower())
        if '#' + yeni.lower() == renk.lower():
            return m.group(0)
        sayac[0] += 1
        return '%s="#%s"' % (oznitelik, yeni)

    desen = r'(%s)="(#[0-9a-fA-F]{6})"' % '|'.join(RENK_OZNITELIKLERI)
    return re.sub(desen, degistir, icerik), sayac[0]


def main():
    for path in sorted(glob.glob('assets/illustrations/*.svg')):
        icerik = open(path, encoding='utf-8').read()
        # Üç haneli renkleri (#fff) altıya aç; eşleme altı hane bekliyor.
        icerik = re.sub(r'(fill|stroke|stop-color)="#([0-9a-fA-F])([0-9a-fA-F])([0-9a-fA-F])"',
                        lambda m: '%s="#%s%s%s%s%s%s"' % (m.group(1), *[c for c in (m.group(2), m.group(2), m.group(3), m.group(3), m.group(4), m.group(4))]), icerik)
        icerik = duzlestir(icerik)
        icerik, renk = oturt(icerik)
        open(path, 'w', encoding='utf-8').write(icerik)
        print('%-24s %3d renk' % (os.path.basename(path), renk))


if __name__ == '__main__':
    main()
