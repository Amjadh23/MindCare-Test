import 'package:code_map/screens/educational_background_test/thesis_topic_screen.dart';
import 'package:flutter/material.dart';
import '../../models/user_responses.dart';
import 'cgpa_screen.dart';

class EducationLevelScreen extends StatefulWidget {
  final UserResponses userResponse;

  const EducationLevelScreen({super.key, required this.userResponse});

  @override
  State<EducationLevelScreen> createState() => _EducationLevelScreenState();
}

class _EducationLevelScreenState extends State<EducationLevelScreen> {
  String? selectedLevel;

  final List<String> levels = [
    "SPM (Sijil Pelajaran Malaysia)",
    "STPM (Sijil Tinggi Persekolahan Malaysia)",
    "Diploma",
    "Undergraduate (Bachelor's Degree)",
    "Postgraduate (Master's Degree)",
    "Doctorate (PhD)",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Highest Education")),
      body: Column(
        children: [
          const SizedBox(height: 20),
          const Text(
            "What was your highest level of education?",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: levels.length,
              itemBuilder: (context, index) {
                final level = levels[index];
                return ListTile(
                  title: Text(level),
                  tileColor:
                      selectedLevel == level ? Colors.lightGreenAccent : null,
                  onTap: () {
                    setState(() {
                      selectedLevel = level;
                    });
                  },
                );
              },
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (selectedLevel != null) {
                widget.userResponse.educationLevel = selectedLevel!;
                if (selectedLevel == "Doctorate (PhD)") {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ThesisTopicScreen(userResponse: widget.userResponse),
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          CgpaScreen(userResponse: widget.userResponse),
                    ),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text("Please select an education level.")),
                );
              }
            },
            child: const Text("Next"),
          ),
        ],
      ),
    );
  }
}
