import 'package:flutter/material.dart';
import '../../models/user_responses.dart';
import 'major_screen.dart';

class ThesisTopicScreen extends StatefulWidget {
  final UserResponses userResponse;

  const ThesisTopicScreen({super.key, required this.userResponse});

  @override
  State<ThesisTopicScreen> createState() => _ThesisTopicScreenState();
}

class _ThesisTopicScreenState extends State<ThesisTopicScreen> {
  final TextEditingController thesisTopicController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Thesis Topic")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              "What is your thesis topic?",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: thesisTopicController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: "Enter your thesis topic",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (thesisTopicController.text.isNotEmpty) {
                  widget.userResponse.thesisTopic = thesisTopicController.text;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          MajorScreen(userResponse: widget.userResponse),
                    ),
                  );
                }
              },
              child: const Text("Next"),
            ),
          ],
        ),
      ),
    );
  }
}
