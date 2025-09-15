import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class SkillGapAnalysis extends StatefulWidget {
  final int userTestId;
  final int selectedJobId;

  const SkillGapAnalysis({
    super.key,
    required this.userTestId,
    required this.selectedJobId,
  });

  @override
  State<SkillGapAnalysis> createState() => _SkillGapAnalysisState();
}

class _SkillGapAnalysisState extends State<SkillGapAnalysis> {
  Map<String, dynamic>? _gapData;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchGapAnalysis();
  }

  Future<void> _fetchGapAnalysis() async {
    setState(() => _isLoading = true);

    try {
      final allGaps =
          await ApiService.getGapAnalysis(userTestId: widget.userTestId);

      // Find gap for the selected job
      final gapEntry = allGaps.firstWhere(
        (g) => g["job_index"] == widget.selectedJobId,
        orElse: () => {},
      );

      if (gapEntry.isEmpty || gapEntry["gap_analysis"] == null) {
        setState(() {
          _errorMessage = "No gap analysis found for this job.";
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _gapData = Map<String, dynamic>.from(gapEntry["gap_analysis"]);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Widget _buildTable(Map<String, dynamic> data, String title) {
    if (data.isEmpty) return const SizedBox.shrink();
    final entries = data.entries.toList();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(1),
                3: FlexColumnWidth(1),
              },
              border: TableBorder.all(color: Colors.grey.shade300),
              children: [
                const TableRow(
                  decoration: BoxDecoration(color: Colors.grey),
                  children: [
                    Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('Name',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white))),
                    Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('Required',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white))),
                    Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('User Level',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white))),
                    Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('Status',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white))),
                  ],
                ),
                ...entries.map((e) {
                  final status = e.value['status'] ?? '-';
                  return TableRow(
                    children: [
                      Padding(
                          padding: const EdgeInsets.all(8), child: Text(e.key)),
                      Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(e.value['required_level'] ??
                              e.value['required'] ??
                              '-')),
                      Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(e.value['user_level'] ?? '-')),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          status,
                          style: TextStyle(
                            color: status == 'Achieved'
                                ? Colors.green
                                : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Skill Gap Analysis")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Text(_errorMessage!,
                      style: const TextStyle(color: Colors.red)),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    children: [
                      Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Suggested Career Path:",
                                style:
                                    TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _gapData?['job_title'] ?? 'Selected Job',
                                style: const TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            ],
                          )),
                      const SizedBox(height: 12),
                      _buildTable(
                          Map<String, dynamic>.from(_gapData?['skills'] ?? {}),
                          "Skills"),
                      _buildTable(
                          Map<String, dynamic>.from(
                              _gapData?['knowledge'] ?? {}),
                          "Knowledge"),
                    ],
                  ),
                ),
    );
  }
}
