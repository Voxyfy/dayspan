import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Veritabanındaki ikon adı ile Phosphor ikonu arasındaki eşleme.
///
/// Ad saklanıyor, kod noktası değil: Phosphor sürüm değiştirince kod
/// noktaları kayabiliyor, ad kalıyor. Liste sıralı; düzenleyici bu sırayla
/// gösterir. Yalnızca sona eklenir.
abstract final class HabitIcons {
  static const entries = <(String, IconData)>[
    ('check', PhosphorIconsRegular.check),
    ('notebook', PhosphorIconsRegular.notebook),
    ('bookOpen', PhosphorIconsRegular.bookOpen),
    ('barbell', PhosphorIconsRegular.barbell),
    ('personSimpleRun', PhosphorIconsRegular.personSimpleRun),
    ('personSimpleWalk', PhosphorIconsRegular.personSimpleWalk),
    ('bicycle', PhosphorIconsRegular.bicycle),
    ('plant', PhosphorIconsRegular.plant),
    ('drop', PhosphorIconsRegular.drop),
    ('bed', PhosphorIconsRegular.bed),
    ('moon', PhosphorIconsRegular.moon),
    ('sun', PhosphorIconsRegular.sun),
    ('coffee', PhosphorIconsRegular.coffee),
    ('forkKnife', PhosphorIconsRegular.forkKnife),
    ('appleLogo', PhosphorIconsRegular.appleLogo),
    ('pill', PhosphorIconsRegular.pill),
    ('heartbeat', PhosphorIconsRegular.heartbeat),
    ('deviceMobileSlash', PhosphorIconsRegular.deviceMobileSlash),
    ('brain', PhosphorIconsRegular.brain),
    ('pencilSimple', PhosphorIconsRegular.pencilSimple),
    ('guitar', PhosphorIconsRegular.guitar),
    ('musicNotes', PhosphorIconsRegular.musicNotes),
    ('paintBrush', PhosphorIconsRegular.paintBrush),
    ('camera', PhosphorIconsRegular.camera),
    ('translate', PhosphorIconsRegular.translate),
    ('code', PhosphorIconsRegular.code),
    ('briefcase', PhosphorIconsRegular.briefcase),
    ('envelopeSimple', PhosphorIconsRegular.envelopeSimple),
    ('phone', PhosphorIconsRegular.phone),
    ('users', PhosphorIconsRegular.users),
    ('heart', PhosphorIconsRegular.heart),
    ('handsPraying', PhosphorIconsRegular.handsPraying),
    ('broom', PhosphorIconsRegular.broom),
    ('shoppingCart', PhosphorIconsRegular.shoppingCart),
    ('wallet', PhosphorIconsRegular.wallet),
    ('piggyBank', PhosphorIconsRegular.piggyBank),
    ('cigaretteSlash', PhosphorIconsRegular.cigaretteSlash),
    ('wine', PhosphorIconsRegular.wine),
    ('tooth', PhosphorIconsRegular.tooth),
    ('dog', PhosphorIconsRegular.dog),
    ('star', PhosphorIconsRegular.star),
    ('lightning', PhosphorIconsRegular.lightning),
  ];

  static IconData of(String name) =>
      entries.firstWhere((e) => e.$1 == name, orElse: () => entries.first).$2;
}
