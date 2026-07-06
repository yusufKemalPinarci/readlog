import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:libris/shared/services/image_storage_service.dart';

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.root);
  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ImageStorageService.saveImage (T1.7)', () {
    late Directory tempRoot;

    setUp(() async {
      tempRoot = await Directory.systemTemp.createTemp('img_store_test');
      PathProviderPlatform.instance = _FakePathProvider(tempRoot.path);
    });

    tearDown(() async {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    });

    test('re-saving the existing cover (source==target) keeps the file', () async {
      final svc = ImageStorageService();

      // First save from an external source.
      final source = File('${tempRoot.path}/picked.jpg');
      await source.writeAsBytes([1, 2, 3, 4]);
      final saved = await svc.saveImage('book1', source.path);
      expect(saved, isNotNull);
      expect(await File(saved!).exists(), isTrue);

      // Now "save" again passing the already-stored cover as the source.
      // This happens when editing a book without changing the cover.
      final resaved = await svc.saveImage('book1', saved);
      expect(resaved, saved,
          reason: 'source==target must return the same path unchanged');
      expect(await File(saved).exists(), isTrue,
          reason: 'the cover must NOT be deleted when re-saved onto itself');
      expect(await File(saved).readAsBytes(), [1, 2, 3, 4]);
    });

    test('saving a new cover replaces the old one and leaves no .tmp', () async {
      final svc = ImageStorageService();

      final source1 = File('${tempRoot.path}/a.jpg');
      await source1.writeAsBytes([1, 1, 1]);
      final saved = await svc.saveImage('book1', source1.path);

      final source2 = File('${tempRoot.path}/b.jpg');
      await source2.writeAsBytes([2, 2, 2, 2]);
      final saved2 = await svc.saveImage('book1', source2.path);

      expect(saved2, saved); // same deterministic target path
      expect(await File(saved2!).readAsBytes(), [2, 2, 2, 2]);
      expect(await File('$saved2.tmp').exists(), isFalse);
    });
  });
}
