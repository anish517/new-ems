import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});
  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}
class _FeedbackScreenState extends State<FeedbackScreen> {
  List _complaints = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    ApiService().get('${AppConstants.feedbackBase}/').then((r) {
      setState(() { _complaints = r.data['results'] ?? r.data; _loading = false; });
    }).catchError((Object _) { setState(() => _loading = false); return null; });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Feedback & Complaints')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () {},
      backgroundColor: AppColors.primary,
      icon: const Icon(Icons.add), label: const Text('New Complaint'),
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _complaints.isEmpty
            ? const Center(child: Text('No complaints filed'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _complaints.length,
                itemBuilder: (_, i) {
                  final c = _complaints[i];
                  return Card(child: ListTile(
                    title: Text(c['title'] ?? ''),
                    subtitle: Text(c['status'] ?? ''),
                    trailing: Chip(label: Text(c['visibility'] ?? '')),
                  ));
                }),
  );
}
