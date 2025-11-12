import 'package:flutter/material.dart';
import '../../models/user_responses.dart';
import '../skill_reflection_test/skill_reflection_screen.dart';

class CourseworkExperience extends StatefulWidget {
  final UserResponses userResponse;

  const CourseworkExperience({super.key, required this.userResponse});

  @override
  State<CourseworkExperience> createState() => _CourseworkExperienceState();
}

class _CourseworkExperienceState extends State<CourseworkExperience> {
  String? selectedExperience;

  final List<String> experiences = [
    "Not Familiar",
    "Somewhat Familiar",
    "Very Familiar"
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Coursework Experience")),
      body: Column(
        children: [
          const SizedBox(height: 20),
          const Text(
            "Is your coursework familiar with any hands-on projects (e.g., Final year project, Internship)?",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: experiences.length,
              itemBuilder: (context, index) {
                final exp = experiences[index];
                return ListTile(
                  title: Text(exp),
                  tileColor: selectedExperience == exp
                      ? Colors.lightGreenAccent
                      : null,
                  onTap: () {
                    setState(() {
                      selectedExperience = exp;
                    });
                  },
                );
              },
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (selectedExperience != null) {
                // save selected coursework experience to response object
                widget.userResponse.courseworkExperience = selectedExperience!;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SkillReflectionScreen(
                        userResponse: widget.userResponse),
                  ),
                );
              }
            },
            child: const Text("Complete"),
          ),
        ],
      ),
    );
  }
}
