import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PdfImportService {
  /// Importa un file ZIP e copia tutti i PDF estratti nella directory dell’app.
  static Future<void> importZip() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (result == null || result.files.isEmpty) return;

    File zipFile = File(result.files.single.path!);
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final dir = await getApplicationDocumentsDirectory();

    for (final file in archive) {
      if (file.isFile && file.name.endsWith('.pdf')) {
        final filename = file.name.split('/').last;
        final outFile = File('${dir.path}/$filename');
        if (!await outFile.exists()) {
          await outFile.writeAsBytes(file.content as List<int>);
        }
      }
    }
  }

  /// Importa un singolo PDF e lo copia nella directory dell’app.
  static Future<void> importSinglePdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null || result.files.isEmpty) return;

    File file = File(result.files.single.path!);
    final dir = await getApplicationDocumentsDirectory();
    final filename = file.path.split('/').last;
    final dest = File('${dir.path}/$filename');
    if (!await dest.exists()) {
      await file.copy(dest.path);
    }
  }

  /// Seleziona una cartella dal file system e salva il suo percorso
  static Future<void> selectFolder() async {
    final selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pdf_folder_path', selectedDirectory);
  }

  /// Legge tutti i file PDF presenti nella directory interna dell’app.
  static Future<List<File>> listLocalPdfs() async {
    final dir = await getApplicationDocumentsDirectory();
    final List<File> pdfFiles = [];
    final directory = Directory(dir.path);
    final files = directory.listSync();
    for (var file in files) {
      if (file is File && file.path.endsWith('.pdf')) {
        pdfFiles.add(file);
      }
    }
    return pdfFiles;
  }

  /// Legge tutti i file PDF presenti nella cartella selezionata dall’utente.
  static Future<List<File>> listFolderPdfs() async {
    final prefs = await SharedPreferences.getInstance();
    final folderPath = prefs.getString('pdf_folder_path');
    if (folderPath == null) return [];
    final directory = Directory(folderPath);
    if (!await directory.exists()) return [];
    final List<File> pdfFiles = [];
    final files = directory.listSync();
    for (var file in files) {
      if (file is File && file.path.toLowerCase().endsWith('.pdf')) {
        pdfFiles.add(file);
      }
    }
    return pdfFiles;
  }
}
