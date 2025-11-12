import 'package:flutter/material.dart';
import '../../models/user_responses.dart';
import 'education_major.dart';

class ThesisTopic extends StatefulWidget {
  final UserResponses userResponse;

  const ThesisTopic({super.key, required this.userResponse});

  @override
  State<ThesisTopic> createState() => _ThesisTopicState();
}

class _ThesisTopicState extends State<ThesisTopic> {
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
                  // save thesis topic to response object
                  widget.userResponse.thesisTopic = thesisTopicController.text;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          EducationMajor(userResponse: widget.userResponse),
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
