import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'data/task_repository.dart';
import 'screens/home_screen.dart';
import 'state/streak_controller.dart';

/// Holds the things every screen needs. Swap the repository here later.
class AppScope extends InheritedWidget {
  final TaskRepository repo;
  final StreakController streak;

  const AppScope({
    super.key,
    required this.repo,
    required this.streak,
    required super.child,
  });

  static AppScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!;

  @override
  bool updateShouldNotify(AppScope oldWidget) => false;
}

class TaskRaceApp extends StatefulWidget {
  const TaskRaceApp({super.key});

  @override
  State<TaskRaceApp> createState() => _TaskRaceAppState();
}

class _TaskRaceAppState extends State<TaskRaceApp> {
  final TaskRepository _repo = InMemoryTaskRepository();
  final StreakController _streak = StreakController();
  late final Future<void> _initialization = _repo.seed();

  @override
  Widget build(BuildContext context) {
    return AppScope(
      repo: _repo,
      streak: _streak,
      child: MaterialApp(
        title: 'Ghost Timer',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: FutureBuilder<void>(
          future: _initialization,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            return const HomeScreen();
          },
        ),
      ),
    );
  }
}