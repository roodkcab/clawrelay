import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('Must be overridden with a concrete instance');
});
