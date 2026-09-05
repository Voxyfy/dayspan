import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Paketlenmiş çizimler. unDraw kaynaklı, `tool/snap_illustration_palette.py`
/// ile koyu palete çekilmiş. Yalnızca boş durumlarda: pano doluyken görsel
/// yer çalar, yoğun insan açar açmaz veriyi görmeli.
enum Illustration {
  /// unDraw "Relax mode": boş gün bir hata değil, nefes.
  emptyDay('relax-mode'),

  /// unDraw "Add tasks": artı düğmeli pano, karolara gönderme.
  noHabits('add-tasks');

  const Illustration(this.file);

  final String file;

  String get asset => 'assets/illustrations/$file.svg';
}

class IllustrationView extends StatelessWidget {
  const IllustrationView(this.asset, {this.height = 160, super.key});

  final String asset;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(child: SvgPicture.asset(asset, height: height));
  }
}

/// Boş durum: çizim, başlık, tek satır açıklama, isteğe bağlı eylem.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.title,
    required this.body,
    this.illustration,
    this.asset,
    this.action,
    super.key,
  }) : assert(illustration != null || asset != null);

  final Illustration? illustration;

  /// Doğrudan varlık yolu; yalnızca çekim/aday testleri için.
  final String? asset;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IllustrationView(asset ?? illustration!.asset, height: 170),
          const SizedBox(height: 28),
          Text(title, style: text.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            body,
            style: text.bodySmall?.copyWith(height: 1.5),
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[const SizedBox(height: 24), action!],
        ],
      ),
    );
  }
}
