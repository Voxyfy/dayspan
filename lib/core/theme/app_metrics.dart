import 'package:flutter/material.dart';

/// Boşluk ölçeği — 4 piksellik ızgara. Ara değer yok.
abstract final class Gap {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const section = 32.0;

  /// Sayfanın sol/sağ kenar payı.
  static const page = 20.0;

  /// Karo içi pay.
  static const tile = 16.0;

  /// Yüzen sekme çubuğunun üstünde bırakılan pay.
  static const floatingClearance = 108.0;

  /// Kaydırılabilir listelerin alt boşluğu. Kabuk içindeki her liste bunu
  /// kullanır; Ritim'de kendi payını yazan ekranlar son satırı çubuğun altına
  /// gömmüştü.
  static const listBottom = floatingClearance + xxl;
}

/// Köşe yarıçapı.
abstract final class Radii {
  static const sm = 12.0;

  /// Karo ve kart. Referanstaki karolar bu ölçüde.
  static const md = 24.0;

  /// Alttan açılan sayfa.
  static const lg = 32.0;
  static const full = 999.0;
}

/// Hareket. Üç süre, tek eğri.
abstract final class Motion {
  static const quick = Duration(milliseconds: 120);
  static const base = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 360);
  static const curve = Curves.easeOutCubic;
}

abstract final class IconSize {
  static const sm = 16.0;
  static const md = 20.0;
  static const lg = 24.0;

  /// Karonun sol üst ikonu: 24 ızgarada silik kalıyordu, kullanıcı büyütmek
  /// istedi (4 Eylül 2026).
  static const tile = 30.0;
  static const xl = 40.0;
}
