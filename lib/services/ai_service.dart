import 'dart:convert';
import 'package:http/http.dart' as http;

// ✅ Gemini API Key
const String APIKey = 'AIzaSyCOIFDPY2GZAe5EVSrM7O-rOl6HTUYTU8Y';

class AiService {
  Future<String> generateCaption(String description) async {
    // Pass the API key as a query parameter
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta2/models/text-bison-001:generate?key=$APIKey',
    );

    final body = jsonEncode({
      "prompt": {
        "text": "Write 3 fun short captions for this photo: $description"
      },
      "temperature": 0.7,
      "maxOutputTokens": 100
    });

    // Only Content-Type header is required
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final content = data['candidates']?[0]?['output']?.toString();

      if (content == null || content.isEmpty) {
        throw Exception('Empty response from AI');
      }
      return content;
    } else {
      throw Exception('Gemini API error: ${res.body}');
    }
  }
}
