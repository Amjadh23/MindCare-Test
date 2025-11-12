import 'package:flutter/material.dart';
import '../../models/user_responses.dart';
import 'programming_languages.dart';

class EducationMajor extends StatefulWidget {
  final UserResponses userResponse;

  const EducationMajor({super.key, required this.userResponse});

  @override
  State<EducationMajor> createState() => _EducationMajorState();
}

class _EducationMajorState extends State<EducationMajor> {
  String? selectedMajor;

  final List<String> majors = [
    "Software Engineering",
    "Computer Science",
    "Data Science",
    "Cybersecurity",
    "Artificial Intelligence (AI)",
    "Web Development",
    "Mobile Computing",
    "Cloud Computing",
    "Network Engineering",
    "None"
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Major")),
      body: Column(
        children: [
          const SizedBox(height: 20),
          const Text(
            "What was your major or area of focus during your studies?",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: majors.length,
              itemBuilder: (context, index) {
                final major = majors[index];
                return ListTile(
                  title: Text(major),
                  tileColor:
                      selectedMajor == major ? Colors.lightGreenAccent : null,
                  onTap: () {
                    setState(() {
                      selectedMajor = major;
                    });
                  },
                );
              },
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (selectedMajor != null) {
                // save selected education major to response object
                widget.userResponse.major = selectedMajor!;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ProgrammingLanguages(userResponse: widget.userResponse),
                  ),
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
