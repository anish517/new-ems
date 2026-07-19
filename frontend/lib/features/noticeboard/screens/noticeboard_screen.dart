import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';

class NoticeboardScreen extends StatefulWidget {
  const NoticeboardScreen({super.key});
  @override
  State<NoticeboardScreen> createState() => _NoticeboardScreenState();
}

class _NoticeboardScreenState extends State<NoticeboardScreen> {
  List _notices = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    ApiService().get('${AppConstants.noticeboardBase}/').then((r) {
      setState(() { _notices = r.data['results'] ?? r.data; _loading = false; });
    }).catchError((Object _) { setState(() => _loading = false); return null; });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notice Board')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _notices.isEmpty
            ? const Center(child: Text('No notices yet'))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _notices.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final n = _notices[i];
                  return Card(child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: Text(n['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(n['date'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ));
                }),
  );
}
