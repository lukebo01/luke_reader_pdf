import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:pdf_render/pdf_render.dart';
import '../services/pdf_import_service.dart';
import 'pdf_viewer_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui' as ui;

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<File> localPdfFiles = [];
  List<File> folderPdfFiles = [];
  List<File> filteredLocalPdfs = [];
  List<File> filteredFolderPdfs = [];
  Map<String, int> continueReadingData = {}; // percorso file -> ultima pagina
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPdfs();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _loadPdfs() async {
    List<File> localFiles = await PdfImportService.listLocalPdfs();
    localFiles.sort((a, b) => a.path.split('/').last.compareTo(b.path.split('/').last));
    List<File> folderFiles = await PdfImportService.listFolderPdfs();
    folderFiles.sort((a, b) => a.path.split('/').last.compareTo(b.path.split('/').last));

    await _loadContinueReadingData(localFiles + folderFiles);

    setState(() {
      localPdfFiles = localFiles;
      folderPdfFiles = folderFiles;
      filteredLocalPdfs = localFiles;
      filteredFolderPdfs = folderFiles;
    });
  }

  Future<void> _loadContinueReadingData(List<File> files) async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, int> data = {};
    for (var file in files) {
      final lastPage = prefs.getInt('last_page_${file.path}');
      if (lastPage != null && lastPage > 1) {
        data[file.path] = lastPage;
      }
    }
    setState(() {
      continueReadingData = data;
    });
  }

  void _onSearchChanged() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      filteredLocalPdfs = localPdfFiles.where((file) {
        String filename = file.path.split('/').last.toLowerCase();
        return filename.contains(query);
      }).toList();
      filteredFolderPdfs = folderPdfFiles.where((file) {
        String filename = file.path.split('/').last.toLowerCase();
        return filename.contains(query);
      }).toList();
    });
  }

  /// Mostra un bottom sheet con le opzioni: importare ZIP, PDF singolo o selezionare cartella.
  void _showImportOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[850],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: Icon(Icons.archive, color: Colors.tealAccent),
                title: Text('Importa ZIP', style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(context);
                  await PdfImportService.importZip();
                  _loadPdfs();
                },
              ),
              ListTile(
                leading: Icon(Icons.picture_as_pdf, color: Colors.tealAccent),
                title: Text('Importa PDF singolo', style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(context);
                  await PdfImportService.importSinglePdf();
                  _loadPdfs();
                },
              ),
              ListTile(
                leading: Icon(Icons.folder, color: Colors.tealAccent),
                title: Text('Seleziona cartella', style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(context);
                  await PdfImportService.selectFolder();
                  _loadPdfs();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Costruisce la card per visualizzare il PDF.
  Widget _buildPdfCard(File file) {
    return PdfCard(
      file: file,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => PdfViewerScreen(file: file)),
        ).then((_) => _loadContinueReadingData(localPdfFiles + folderPdfFiles));
      },
    );
  }

  /// Costruisce una sezione (es. "PDF Importati" o "PDF dalla Cartella")
  Widget _buildSection(String title, List<File> files) {
    return files.isEmpty
        ? SizedBox.shrink()
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.all(8),
                child: Text(title, style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: files.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: MediaQuery.of(context).orientation == Orientation.portrait ? 2 : 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.7,
                ),
                itemBuilder: (context, index) {
                  return _buildPdfCard(files[index]);
                },
              ),
            ],
          );
  }

  /// Sezione "Continua a guardare" con i file che hanno una pagina salvata > 1.
  Widget _buildContinueReadingSection() {
    if (continueReadingData.isEmpty) return SizedBox.shrink();
    List<File> continueFiles = [];
    continueReadingData.forEach((path, page) {
      continueFiles.add(File(path));
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.all(8),
          child: Text('Continua a guardare', style: TextStyle(fontSize: 18, color: Colors.white)),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: continueFiles.length,
            itemBuilder: (context, index) {
              final file = continueFiles[index];
              final lastPage = continueReadingData[file.path]!;
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => PdfViewerScreen(file: file)),
                  ).then((_) => _loadContinueReadingData(localPdfFiles + folderPdfFiles));
                },
                child: Container(
                  width: 150,
                  margin: EdgeInsets.all(8),
                  child: Column(
                    children: [
                      Expanded(child: PdfCard(file: file, onTap: () {})),
                      Text('Pagina $lastPage', style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Biblioteca PDF'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: _showImportOptions,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Cerca per nome...',
                hintStyle: TextStyle(color: Colors.white54),
                prefixIcon: Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: Colors.grey[800],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildContinueReadingSection(),
            _buildSection('PDF Importati', filteredLocalPdfs),
            _buildSection('PDF dalla Cartella', filteredFolderPdfs),
            if (filteredLocalPdfs.isEmpty && filteredFolderPdfs.isEmpty)
              Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Nessun PDF disponibile', style: TextStyle(color: Colors.white)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Widget per mostrare la card di un PDF con la miniatura della prima pagina.
class PdfCard extends StatelessWidget {
  final File file;
  final VoidCallback onTap;

  PdfCard({required this.file, required this.onTap});

  Future<Uint8List> _generateThumbnail() async {
    final doc = await PdfDocument.openFile(file.path);
    final page = await doc.getPage(1);
    final targetWidth = 150;
    final targetHeight = (targetWidth * page.height / page.width).toInt();
    final pageImage = await page.render(width: targetWidth, height: targetHeight);
    final ui.Image image = pageImage.imageIfAvailable!;
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List bytes = byteData!.buffer.asUint8List();
    await page.document.dispose();
    await doc.dispose();
    return bytes;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: Colors.grey[850],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FutureBuilder<Uint8List>(
              future: _generateThumbnail(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                  return ClipRRect(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                    child: Image.memory(
                      snapshot.data!,
                      fit: BoxFit.cover,
                      height: 150,
                    ),
                  );
                } else {
                  return Container(
                    height: 150,
                    color: Colors.black26,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
              },
            ),
            Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                file.path.split('/').last,
                style: TextStyle(color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            )
          ],
        ),
      ),
    );
  }
}
