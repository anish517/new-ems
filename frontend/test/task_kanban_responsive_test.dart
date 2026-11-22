import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ems_app/features/tasks/widgets/task_kanban_board.dart';

void main() {
  final sampleTodo = [
    {
      'id': 1,
      'title': 'Refactor offline cache with very long title to verify mobile ellipsis behavior',
      'description': 'Clean up stale storage keys and write verification tests for mobile screens.',
      'status': 'to-do',
      'priority': 'high',
      'is_personal': true,
      'project': {'id': null, 'name': null},
      'assigned_to': {'id': 10, 'name': 'Alice Developer With A Long Full Name'},
      'progress_count': 2,
      'can_edit': true,
      'can_delete': true,
      'planned_end_date': '2083-08-20',
      'description_pdf': 'https://example.com/spec.pdf',
    },
  ];

  final sampleInProgress = [
    {
      'id': 2,
      'title': 'Implement Push Notifications',
      'description': 'Integrate FCM topic subscription.',
      'status': 'in-progress',
      'priority': 'medium',
      'is_personal': false,
      'project': {'id': 5, 'name': 'Enterprise Mobile Application Redesign'},
      'assigned_to': {'id': 10, 'name': 'Alice Dev'},
      'progress_count': 1,
      'can_edit': false,
      'can_delete': false,
      'planned_end_date': '2083-08-25',
    },
  ];

  Widget buildBoard({
    void Function(String)? onAddCard,
    void Function(Map)? onOpenLogs,
    void Function(Map, String)? onMoveTask,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: TaskKanbanBoard(
            todoTasks: sampleTodo,
            inProgressTasks: sampleInProgress,
            doneTasks: const [],
            isAdmin: false,
            onTapTask: (_) {},
            onOpenLogs: onOpenLogs ?? (_) {},
            onAddCard: onAddCard ?? (_) {},
            onMoveTask: onMoveTask ?? (_, __) {},
            onEditTask: (_) {},
            onDeleteTask: (_) {},
            formatDate: (raw, {fallback}) => raw ?? 'Not set',
          ),
        ),
      ),
    );
  }

  testWidgets('TaskKanbanBoard renders cleanly on compact mobile (320x640) with zero overflow',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    String? addedColumn;
    Map? openedLogsTask;

    await tester.pumpWidget(buildBoard(
      onAddCard: (col) => addedColumn = col,
      onOpenLogs: (t) => openedLogsTask = t,
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Personal'), findsOneWidget);
    expect(find.text('2 Logs'), findsOneWidget);
    expect(find.text('Add Card'), findsWidgets);

    // Tapping "2 Logs" opens progress logs directly
    await tester.tap(find.text('2 Logs'));
    await tester.pumpAndSettle();
    expect(openedLogsTask?['id'], 1);

    // Tapping "+ Add Card" in To Do column pre-selects 'to-do'
    await tester.tap(find.text('Add Card').first);
    await tester.pumpAndSettle();
    expect(addedColumn, 'to-do');
  });

  testWidgets('TaskKanbanBoard renders cleanly on standard mobile (360x780) and switches lanes via quick pills',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildBoard());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Tap the "In Progress" quick-jump pill at top
    await tester.tap(find.text('In Progress').first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('TaskKanbanBoard renders 3 side-by-side columns on desktop (1280x800)',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildBoard());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('To Do'), findsOneWidget);
    expect(find.text('In Progress'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Personal'), findsOneWidget);
    expect(find.text('Enterprise Mobile Application Redesign'), findsOneWidget);
  });
}
