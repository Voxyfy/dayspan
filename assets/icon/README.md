# Uygulama ikonu

Kaynak `app_icon.svg` (1024×1024): koyu zemin (#0B0B0D) üstünde tamamlanmış
karo (#3A3A42, uygulamadaki grafit karodan iki ton açık; aynı ton ana ekranda
zeminle karışıyordu). Cam efekti yok, iOS 26 kendi veriyor.

Üretim (QuickLook SVG'yi WebKit ile basar; ImageMagick'in kendi SVG çizeri
gradyan ve path'leri düşürüyor):

```bash
qlmanage -t -s 1024 -o assets/icon assets/icon/app_icon.svg
# iOS: Contents.json'daki her boyuta magick -resize
# Android: mipmap-*/ic_launcher.png (48…192) ve adaptif ön katman
#          app_icon_foreground.svg → mipmap-*/ic_launcher_foreground.png (108…432)
```
