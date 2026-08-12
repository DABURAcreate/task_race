import 'package:flutter/material.dart';
import '../app.dart';
import '../core/accuracy.dart';
import '../core/formatters.dart';
import '../data/active_session_store.dart';
import '../models/task.dart';
import '../state/stakes_controller.dart';
import 'history_screen.dart';
import 'insights_screen.dart';
import 'timer_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _resumeActiveSessionIfAny(),
    );
  }

  Future<void> _resumeActiveSessionIfAny() async {
    final active = await ActiveSessionStore.load();
    if (active == null || !mounted) return;

    final scope = AppScope.of(context);
    Task? task;
    for (final t in scope.repo.tasks) {
      if (t.id == active.taskId) {
        task = t;
        break;
      }
    }
    if (task == null) {
      await ActiveSessionStore.clear();
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TimerScreen(
          task: task!,
          estimateSeconds: active.estimateSeconds,
          resumeStartedAt: active.startedAt,
        ),
      ),
    );
    if (mounted) setState(() {}); // refresh stats after the run
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final tasks = scope.repo.tasks;
    final grouped = _groupByCategory(tasks);
    final categories = grouped.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ghost Timer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.insights),
            tooltip: 'Weekly insights',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const InsightsScreen()),
            ),
          ),
          ListenableBuilder(
            listenable: scope.stakes,
            builder: (context, _) => IconButton(
              icon: Badge(
                label: Text('${scope.stakes.protectionTokens}'),
                isLabelVisible: scope.stakes.protectionTokens > 0,
                child: const Icon(Icons.shield_outlined),
              ),
              tooltip: 'Skip-penalty tokens',
              onPressed: () => _openShop(context, scope),
            ),
          ),
          ListenableBuilder(
            listenable: scope.stakes,
            builder: (context, _) => Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '🔥 ${scope.stakes.streak}   🪙 ${scope.stakes.coins}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ),
          ),
        ],
      ),
      body: tasks.isEmpty
          ? const Center(child: Text('Add a task to start'))
          : ListView.builder(
        itemCount: categories.length,
        itemBuilder: (context, i) {
          final category = categories[i];
          return _CategorySection(
            category: category,
            tasks: grouped[category]!,
            onTap: _startTask,
            onHistory: _openHistory,
            onLongPress: _openTaskMenu,
            confirmDismiss: _confirmDelete,
            onDismissed: _deleteTask,
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTask,
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Non-deleted tasks, bucketed by category and kept in their original
  /// (creation) order within each bucket.
  Map<String, List<Task>> _groupByCategory(List<Task> tasks) {
    final grouped = <String, List<Task>>{};
    for (final task in tasks) {
      grouped.putIfAbsent(task.category, () => []).add(task);
    }
    return grouped;
  }

  Future<void> _addTask() async {
    final existingCategories = AppScope.of(
      context,
    ).repo.allTasks.map((t) => t.category).toSet();
    final result = await _askTaskDetails(
      title: 'New task',
      actionLabel: 'Add',
      existingCategories: existingCategories,
    );
    if (result == null) return;

    final name = result.name.trim();
    if (name.isEmpty) return;
    final category = result.category.trim().isEmpty
        ? name
        : result.category.trim();

    setState(() => AppScope.of(context).repo.addTask(name, category));
  }

  Future<void> _editTask(Task task) async {
    final existingCategories = AppScope.of(
      context,
    ).repo.allTasks.map((t) => t.category).toSet();
    final result = await _askTaskDetails(
      title: 'Rename task',
      actionLabel: 'Save',
      existingCategories: existingCategories,
      initialName: task.name,
      initialCategory: task.category,
    );
    if (result == null) return;

    final name = result.name.trim();
    if (name.isEmpty) return;
    final category = result.category.trim().isEmpty
        ? name
        : result.category.trim();

    setState(
      () => AppScope.of(
        context,
      ).repo.editTask(task.id, name: name, category: category),
    );
  }

  Future<void> _openTaskMenu(Task task) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Rename'),
              onTap: () => Navigator.pop(context, 'rename'),
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.redAccent),
              title: const Text('Delete'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;

    if (action == 'rename') {
      await _editTask(task);
    } else if (action == 'delete') {
      if (await _confirmDelete(task)) _deleteTask(task);
    }
  }

  Future<bool> _confirmDelete(Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text(
          'This removes "${task.name}" from your task list. Its past runs '
          'stay counted in your category insights.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  void _deleteTask(Task task) {
    setState(() => AppScope.of(context).repo.deleteTask(task.id));
  }

  Future<void> _openShop(BuildContext context, AppScope scope) {
    final stakes = scope.stakes;
    const cost = StakesController.protectionTokenCost;

    return showDialog<void>(
      context: context,
      builder: (context) => ListenableBuilder(
        listenable: stakes,
        builder: (context, _) {
          final canAfford = stakes.coins >= cost;
          return AlertDialog(
            title: const Text('Skip-penalty token'),
            content: Text(
              'Protects your streak the next time you run over an estimate — '
              'no coins lost, streak stays alive. Costs $cost coins.\n\n'
              'You have ${stakes.coins} coins and ${stakes.protectionTokens} '
              'token${stakes.protectionTokens == 1 ? '' : 's'}.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              FilledButton(
                onPressed: canAfford ? stakes.buyProtectionToken : null,
                child: const Text('Buy for 100'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openHistory(Task task) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => HistoryScreen(task: task)),
    );
  }

  Future<void> _startTask(Task task) async {
    final minutes = await _askMinutes(task);
    if (minutes == null || minutes <= 0) return;
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TimerScreen(task: task, estimateSeconds: minutes * 60),
      ),
    );
    setState(() {}); // refresh stats after the run
  }

  Future<({String name, String category})?> _askTaskDetails({
    required String title,
    required String actionLabel,
    required Set<String> existingCategories,
    String initialName = '',
    String initialCategory = '',
  }) {
    final nameController = TextEditingController(text: initialName);
    late TextEditingController categoryController;

    return showDialog<({String name, String category})>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Wash dishes',
              ),
            ),
            const SizedBox(height: 12),
            Autocomplete<String>(
              initialValue: TextEditingValue(text: initialCategory),
              optionsBuilder: (value) {
                if (value.text.isEmpty) return existingCategories;
                final query = value.text.toLowerCase();
                return existingCategories.where(
                  (c) => c.toLowerCase().contains(query),
                );
              },
              fieldViewBuilder: (context, controller, focusNode, onSubmit) {
                categoryController = controller;
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    hintText: 'e.g. Cleaning',
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, (
              name: nameController.text,
              category: categoryController.text,
            )),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }

  Future<int?> _askMinutes(Task task) {
    final controller = TextEditingController(
      text: task.lastEstimateSeconds == null
          ? ''
          : (task.lastEstimateSeconds! ~/ 60).toString(),
    );
    return showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(task.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('How long will this take you?'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(suffixText: 'minutes'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, int.tryParse(controller.text)),
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }
}

/// One category's tasks, collapsed behind a header by default so the home
/// screen stays short as tasks pile up under the same category. Expansion
/// state persists across rebuilds via [PageStorageKey].
class _CategorySection extends StatelessWidget {
  final String category;
  final List<Task> tasks;
  final ValueChanged<Task> onTap;
  final ValueChanged<Task> onHistory;
  final ValueChanged<Task> onLongPress;
  final Future<bool> Function(Task) confirmDismiss;
  final ValueChanged<Task> onDismissed;

  const _CategorySection({
    required this.category,
    required this.tasks,
    required this.onTap,
    required this.onHistory,
    required this.onLongPress,
    required this.confirmDismiss,
    required this.onDismissed,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = averageAccuracyRatio(tasks.expand((t) => t.runs));
    final taskWord = tasks.length == 1 ? 'task' : 'tasks';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: PageStorageKey<String>(category),
        title: Text(category),
        subtitle: Text(
          ratio == null
              ? '${tasks.length} $taskWord'
              : '${tasks.length} $taskWord  •  ${describeAccuracy(ratio)}',
        ),
        children: tasks
            .map(
              (task) => Dismissible(
                key: ValueKey(task.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Icon(
                    Icons.delete,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
                confirmDismiss: (_) => confirmDismiss(task),
                onDismissed: (_) => onDismissed(task),
                child: _TaskCard(
                  task: task,
                  onTap: () => onTap(task),
                  onHistory: () => onHistory(task),
                  onLongPress: () => onLongPress(task),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback onTap;
  final VoidCallback onHistory;
  final VoidCallback onLongPress;

  const _TaskCard({
    required this.task,
    required this.onTap,
    required this.onHistory,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final best = task.bestSeconds;
    final ratio = task.accuracyRatio;

    return Card(
      child: ListTile(
        title: Text(task.name),
        subtitle: Text(
          best == null
              ? 'No runs yet'
              : 'Best ${formatSeconds(best)}  •  ${describeAccuracy(ratio!)}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.history),
              tooltip: 'Run history',
              onPressed: onHistory,
            ),
            const Icon(Icons.play_arrow),
          ],
        ),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}