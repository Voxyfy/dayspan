import 'package:flutter/material.dart';

/// Dayspan renk token'ları.
///
/// Koyu tema öncelikli: yoğun insan uygulamayı toplantı arasında, sabah
/// yataktan, gece yatmadan açıyor; siyah zemin hem OLED'de pil yakmıyor hem
/// karoların neon renklerini taşıyabiliyor. Ritim'in fildişi sıcaklığı burada
/// işe yaramaz — burası bir kokpit, bir defter değil.
///
/// Kural: renk **karonun kendisinde** yaşar. Zemin, yüzey ve metin nötr;
/// kimlik taşıyan tek şey karo rengi ([TilePalette]). Bu dosya ile
/// [AppTheme] dışında hiçbir yer renk sabiti bilmemeli.
abstract final class AppColors {
  /// Sayfa zemini: saf siyah değil, çok koyu bir gri. Saf siyah OLED'de
  /// karoların kenarını "yüzer" gösteriyor ve gri yüzeyler zeminden ayrılmıyor.
  static const background = Color(0xFF0B0B0D);

  /// Nötr karo ve kart yüzeyi.
  static const surface = Color(0xFF1C1C21);

  /// Basılı hâl, ikincil dolgu.
  static const surfaceMuted = Color(0xFF26262C);

  /// İnce ayraç: yalnızca kart içindeki satırlar arasında.
  static const hairline = Color(0xFF2E2E35);

  static const textPrimary = Color(0xFFF5F5F7);
  static const textSecondary = Color(0xFFA1A1AA);
  static const textTertiary = Color(0xFF6B6B75);

  /// Koyu karonun üstünde okunacak metin; renkli karo kendi mürekkebini
  /// [TileColor.ink] ile taşır.
  static const onSurface = textPrimary;

  /// "Şimdi" çizgisi ve birincil eylem. Beyaz: siyah zeminde en yüksek
  /// kontrast ve karo renkleriyle hiç çatışmıyor. Renkli bir vurgu, on farklı
  /// karo renginin yanında on birinci renk olurdu.
  static const accent = Color(0xFFFFFFFF);
  static const onAccent = Color(0xFF0B0B0D);

  /// Tamamlandı. Yalnızca onay dairesi.
  static const done = Color(0xFF34C759);

  /// Gecikmiş / kaçırılmış.
  static const overdue = Color(0xFFFF453A);

  /// Yalnızca yüzen katmanlar: sekme çubuğu, alttan açılan sayfa.
  static const floatingShadow = <BoxShadow>[
    BoxShadow(color: Color(0x80000000), blurRadius: 32, offset: Offset(0, 12)),
  ];
}

/// Karo rengi: doygun bir zemin ve üstünde okunacak mürekkep.
///
/// Neon zeminlerin çoğu açık (sarı, cyan, lime); üstüne beyaz yazı okunmaz.
/// Bu yüzden her renk kendi mürekkebini taşır: sarıda siyah, morda beyaz.
class TileColor {
  const TileColor(this.fill, this.ink, {required this.name});

  final Color fill;
  final Color ink;

  /// Renk seçicide okunan ad. Kullanıcı rengi adıyla anmalı; "üçüncü" değil.
  final String name;

  /// Grafit yüzey üstünde çizilen işaret (ısı haritası hücresi). Renkli
  /// karoda zemin rengi; grafit karoda zemin yüzeyle aynı olduğu için
  /// mürekkep, yoksa hücreler görünmezdi.
  Color get mark => fill == AppColors.surface ? ink : fill;
}

/// Karo paleti. Referans aldığımız arayüzün neon dili: doygun, düz, gölgesiz.
///
/// Yalnızca sona eklenir; sıra değişirse mevcut kullanıcıların karoları renk
/// değiştirir. Koyu karo ([neutral]) da paletin parçası: renkli karolar
/// arasında nefes payı bırakıyor, referansta karoların yarısı koyu.
abstract final class TilePalette {
  static const neutral = TileColor(
    AppColors.surface,
    AppColors.textPrimary,
    name: 'Graphite',
  );

  static const colors = <TileColor>[
    neutral,
    TileColor(Color(0xFFD400FF), Color(0xFFFFFFFF), name: 'Magenta'),
    TileColor(Color(0xFF4A3DFF), Color(0xFFFFFFFF), name: 'Ultraviolet'),
    TileColor(Color(0xFFF2F22A), Color(0xFF0B0B0D), name: 'Lemon'),
    TileColor(Color(0xFFFF3D5A), Color(0xFFFFFFFF), name: 'Coral'),
    TileColor(Color(0xFF1E88FF), Color(0xFFFFFFFF), name: 'Azure'),
    TileColor(Color(0xFFB65CFF), Color(0xFF0B0B0D), name: 'Lilac'),
    TileColor(Color(0xFF34C759), Color(0xFF0B0B0D), name: 'Mint'),
    TileColor(Color(0xFFFF9F0A), Color(0xFF0B0B0D), name: 'Amber'),
    TileColor(Color(0xFF00E5D4), Color(0xFF0B0B0D), name: 'Cyan'),
  ];

  static TileColor at(int index) => colors[index % colors.length];
}
