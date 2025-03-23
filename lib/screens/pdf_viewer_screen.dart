import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/translation_service.dart';

class PdfViewerScreen extends StatefulWidget {
  final File file;

  const PdfViewerScreen({Key? key, required this.file}) : super(key: key);

  @override
  _PdfViewerScreenState createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  final PdfViewerController _pdfViewerController = PdfViewerController();
  final FocusNode _focusNode = FocusNode();

  bool _isControlPressed = false;
  Timer? _textSelectionTimer;
  String _selectedText = '';

  @override
  void initState() {
    super.initState();
    // Richiedi il focus per catturare gli eventi da tastiera.
    _focusNode.requestFocus();
    _loadLastPage();
  }

  /// Carica l’ultima pagina letta salvata per questo file.
  Future<void> _loadLastPage() async {
    final prefs = await SharedPreferences.getInstance();
    final lastPage = prefs.getInt('last_page_${widget.file.path}') ?? 1;
    // Attendi un breve intervallo per assicurarti che il PDF sia caricato.
    Future.delayed(Duration(milliseconds: 500), () {
      _pdfViewerController.jumpToPage(lastPage);
    });
  }

  /// Callback per la gestione della selezione del testo.
  void _onTextSelectionChanged(PdfTextSelectionChangedDetails details) {
    _textSelectionTimer?.cancel();
    if (details.selectedText != null && details.selectedText!.isNotEmpty) {
      setState(() {
        _selectedText = details.selectedText!;
      });
      _textSelectionTimer = Timer(Duration(seconds: 1), () {
        _translateSelectedText(_selectedText);
      });
    } else {
      setState(() {
        _selectedText = '';
      });
    }
  }

  /// Richiama il servizio di traduzione e mostra il risultato in un dialog.
  Future<void> _translateSelectedText(String text) async {
    try {
      final translation = await TranslationService.translateText(text);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Traduzione'),
          content: Text(translation),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Chiudi'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante la traduzione: $e')),
      );
    }
  }

  /// Gestisce gli eventi della rotella del mouse per aggiornare lo zoom.
  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent && _isControlPressed) {
      double currentZoom = _pdfViewerController.zoomLevel;
      double zoomChange = -event.scrollDelta.dy * 0.01;
      double newZoom = currentZoom + zoomChange;
      if (newZoom < 1.0) newZoom = 1.0;
      if (newZoom > 3.0) newZoom = 3.0;
      setState(() {
        _pdfViewerController.zoomLevel = newZoom;
      });
    }
  }

  /// Salva l’ultima pagina letta per il file corrente.
  Future<void> _saveLastPage(int page) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_page_${widget.file.path}', page);
  }

  @override
  void dispose() {
    _textSelectionTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: _focusNode,
      onKey: (RawKeyEvent event) {
        setState(() {
          _isControlPressed = event.isControlPressed;
        });
      },
      child: Listener(
        onPointerSignal: _handlePointerSignal,
        child: Scaffold(
          appBar: AppBar(
            title: Text(widget.file.path.split('/').last),
          ),
          body: SfPdfViewer.file(
            widget.file,
            key: _pdfViewerKey,
            controller: _pdfViewerController,
            enableDoubleTapZooming: true,
            enableTextSelection: true,
            onTextSelectionChanged: _onTextSelectionChanged,
            onPageChanged: (PdfPageChangedDetails details) {
              _saveLastPage(details.newPageNumber);
            },
            initialZoomLevel: 1,
            interactionMode: PdfInteractionMode.selection,
            scrollDirection: PdfScrollDirection.vertical,
            pageLayoutMode: PdfPageLayoutMode.continuous,
            onZoomLevelChanged: (PdfZoomDetails details) {
              print("Nuovo livello di zoom: ${details.newZoomLevel}");
            },
            initialScrollOffset: Offset.zero,
          ),
        ),
      ),
    );
  }
}
