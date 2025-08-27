import 'dart:convert';
import 'package:http/http.dart' as http;

class AiService {
  final String apiKey;
  AiService({required this.apiKey});

  Future<String> generateCaption(String description) async {
    final url = Uri.parse('https://api.openai.com/v1/chat/completions');
    final body = jsonEncode({
      'model': 'gpt-4o-mini',
      'messages': [
        {
          'role': 'user',
          'content': 'Write 3 fun short captions for this photo: $description'
        }
      ],
      'max_tokens': 100,
      'temperature': 0.7,
    });

    final res = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: body,
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);

      // ✅ Fix: The text is inside "choices[0]['message']['content']"
      final content = data['choices'][0]['message']['content']?.toString();

      if (content == null || content.isEmpty) {
        throw Exception('Empty response from AI');
      }
      return content;
    } else {
      throw Exception('OpenAI error: ${res.body}');
    }
  }
}
