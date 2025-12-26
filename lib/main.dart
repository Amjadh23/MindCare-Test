import 'package:code_map/screens/welcome_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'services/api_service.dart';
import 'firebase_options.dart';

bool isBackendReady = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // load environment variables
  await dotenv.load(fileName: 'assets/.env');

  // initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // pre-warm backend
  await _preWarmBackend();

  runApp(const MyApp());
}

Future<void> _preWarmBackend() async {
  try {
    print("Checking backend health at: ${ApiService.baseUrl}/health");
    final response = await http
        .get(Uri.parse("${ApiService.baseUrl}/health"))
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      isBackendReady = true;
      print("Backend is ready! Response: ${response.body}");
    } else {
      print("Backend responded but with status code: ${response.statusCode}");
    }
  } catch (e) {
    print("Backend not ready yet: $e");
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'CodeMap: Navigate Your IT Future',
      home: WelcomePage(),
    );
  }
}
