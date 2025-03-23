import 'package:http/http.dart' as http;
import 'dart:convert';

class TranslationService {
  static Future<String> translateText(String text) async {
    // Sostituisci l'URL con il tuo endpoint di traduzione e aggiungi la chiave API se necessario
    final url = Uri.parse('https://it.libretranslate.com/translate');
    final apiKey = '';

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json'
      },
      body: jsonEncode({
        'q': text,
        'source': 'auto',
        'target': 'it',
        'format': "text",
		    'alternatives': 3,
		    'api_key': apiKey
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // Assumendo che la risposta contenga il campo 'translatedText'
      return data['translatedText'];
    } else {
      throw Exception('Errore nella traduzione: ${response.statusCode}');
    }
  }
}
