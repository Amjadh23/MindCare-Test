import 'package:flutter/material.dart';
import 'education_level_screen.dart';
import '../../models/user_responses.dart';

class EducationalBackgroundTestScreen extends StatelessWidget {
  const EducationalBackgroundTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Expanded(
            child: Center(
              child: Text(
                'Educational Background Test',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // initialize empty response object to track user's progress
                  // this object will be passed through all test screens
                  UserResponses userResponse =
                      UserResponses(followUpAnswers: {});

                  // navigate to education level selection screen
                  // pass the response object to collect user inputs
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          EducationLevelScreen(userResponse: userResponse),
                    ),
                  );
                },
                child: const Text('Start'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
