"""Ekran görüntülerindeki alfa kanalını kaldırır.

App Store Connect saydamlık içeren ekran görüntülerini kabul etmiyor.
Flutter'ın `RepaintBoundary.toImage` çağrısı her zaman RGBA üretiyor; kareler
görsel olarak tamamen opak olsa bile kanal dosyada duruyor ve yükleme
"ölçü yanlış" gibi okunan genel bir mesajla reddediliyor.

Kanal düşürülürken altına tema zemini konuyor (#0B0B0D). Doğrudan
`convert("RGB")` saydam pikseli siyaha çevirir; bizde zemin zaten siyaha
yakın ama yarı saydam bir öğe eklenirse fark görünürdü.

Kullanım:  python3 tool/flatten_screenshots.py
"""

from pathlib import Path

from PIL import Image

ZEMIN = (11, 11, 13)  # AppColors.background
KOK = Path(__file__).resolve().parent.parent / "screenshots"


def duzlestir(yol: Path) -> bool:
    with Image.open(yol) as gorsel:
        if gorsel.mode != "RGBA":
            return False
        zemin = Image.new("RGB", gorsel.size, ZEMIN)
        zemin.paste(gorsel, mask=gorsel.split()[3])
        zemin.save(yol, "PNG", optimize=True)
    return True


def main() -> None:
    degisen = 0
    for yol in sorted(KOK.glob("ios-*/*.png")):
        if duzlestir(yol):
            degisen += 1
            print(f"  alfa kaldırıldı: {yol.relative_to(KOK.parent)}")
    print(f"{degisen} dosya düzleştirildi.")


if __name__ == "__main__":
    main()
