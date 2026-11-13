import 'dart:typed_data';

import 'showcase_models.dart';

abstract class ShowcaseRepository {
  Future<ShowcaseList> list();

  Future<void> create(Map<String, dynamic> input);

  Future<void> update(int id, Map<String, dynamic> input);

  Future<void> setActive(int id, {required bool active});

  Future<int> setAllActive({required bool active});

  Future<void> reorder(List<int> ids);

  Future<void> delete(int id);

  Future<ShowcaseImage> uploadImage({
    required Uint8List bytes,
    required String filename,
  });
}
