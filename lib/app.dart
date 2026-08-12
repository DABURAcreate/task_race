import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'data/task_repository.dart';
import 'screens/home_screen.dart';
import 'state/stakes_controller.dart';

/// Holds the things every screen needs. Swap the repository here later.
class AppScope extends InheritedWidget {
  final TaskRepository repo;
  final StakesController stakes;

  const AppScope({
    super.key,
    required this.repo,
    required this.stakes,
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
  final StakesController _stakes = StakesController();
  late final Future<void> _initialization = _repo.seed();

  @override
  Widget build(BuildContext context) {
    return AppScope(
      repo: _repo,
      stakes: _stakes,
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