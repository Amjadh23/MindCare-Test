import 'package:code_map/screens/educational_background_test/thesis_topic.dart';
import 'package:flutter/material.dart';
import '../../models/user_responses.dart';
import 'cgpa.dart';

class EducationLevel extends StatefulWidget {
  final UserResponses userResponse;

  const EducationLevel({super.key, required this.userResponse});

  @override
  State<EducationLevel> createState() => _EducationLevelState();
}

class _EducationLevelState extends State<EducationLevel> {
  String? selectedLevel; // currently selected education level

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
                      selectedLevel = level; // update selection
                    });
                  },
                );
              },
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (selectedLevel != null) {
                // save selected education level to response object
                widget.userResponse.educationLevel = selectedLevel!;

                // route to different screens based on selection
                // if Doctorate, go to ThesisTopicScreen
                if (selectedLevel == "Doctorate (PhD)") {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ThesisTopic(userResponse: widget.userResponse),
                    ),
                  );
                } else {
                  // else, go to CgpaScreen
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          Cgpa(userResponse: widget.userResponse),
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
