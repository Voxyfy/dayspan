import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dayspan/core/theme/app_theme.dart';
import 'package:dayspan/core/widgets/illustration.dart';

/// Boş durum çizimleri yükleniyor ve koyu zeminde çiziliyor mu?
///
/// `flutter_svg` çözemediği bir şeyle karşılaşınca çizimin tamamını sessizce
/// atıyor; bu test en azından varlığın okunup ağaca girdiğini doğrular.
/// `DAYSPAN_SHOT=1` ile çalıştırılırsa PNG de yazar — göz kontrolü için.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final files =
      Directory('assets/illustrations')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.svg'))
          .map((f) => f.uri.pathSegments.last.replaceAll('.svg', ''))
          .toList()
        ..sort();

  for (final file in files) {
    testWidgets('$file çizimi yüklenir', (tester) async {
      final kok = GlobalKey();
      await tester.runAsync(
        () => rootBundle.load('assets/illustrations/$file.svg'),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: RepaintBoundary(
            key: kok,
            child: Scaffold(
              body: Center(
                child: EmptyState(
                  asset: 'assets/illustrations/$file.svg',
                  title: 'Title here',
                  body: 'A line of body copy that explains what to do next.',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(IllustrationView), findsOneWidget);

      if (Platform.environment['DAYSPAN_SHOT'] == '1') {
        final sinir =
            kok.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final img = await sinir.toImage(pixelRatio: 2);
          final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
          File(
            '${Platform.environment['DAYSPAN_SHOT_DIR']}/ill-$file.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          img.dispose();
        });
      }
    });
  }
}
