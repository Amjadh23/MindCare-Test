import 'package:flutter/material.dart';

class CareerRoadmap extends StatefulWidget {
  final String userTestId;
  final String jobIndex;

  const CareerRoadmap(
      {super.key, required this.userTestId, required this.jobIndex});

  @override
  State<CareerRoadmap> createState() => _CareerRoadmapState();
}

class _CareerRoadmapState extends State<CareerRoadmap> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Career Roadmap'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('User Test ID: ${widget.userTestId}'),
            Text('Job Index: ${widget.jobIndex}'),
            Text(
              'Nothing to see here D:',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(
              'Complete your assessments to unlock your personalized career roadmap!',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
