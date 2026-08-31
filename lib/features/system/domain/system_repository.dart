class BackupFile {
  final String name;
  final int size;

  const BackupFile({required this.name, required this.size});
}

abstract class SystemRepository {
  Future<List<BackupFile>> listBackups();

  Future<String> createBackup();
}
