import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Shared To-Do List',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<String> users = [];
  final Map<String, bool> selectedUsers = {};

  Future<void> _fetchUsersFromFirestore() async {
    final snapshot = await FirebaseFirestore.instance.collection('users').get();
    final fetchedUsers = snapshot.docs.map((doc) => doc['name'] as String).toList();

    setState(() {
      users = fetchedUsers;
      selectedUsers.clear();
      for (var user in users) {
        selectedUsers[user] = false;
      }
    });
  }

  Future<void> _addTaskToFirestore(String title, List<String> sharedUsers) async {
    await FirebaseFirestore.instance.collection('tasks').add({
      'title': title,
      'sharedWith': sharedUsers,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  @override
  void initState() {
    super.initState();
    _fetchUsersFromFirestore();
  }

  void _showAddTaskDialog() {
    TextEditingController taskController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setInnerState) {
            return AlertDialog(
              title: const Text("Add New Shared Task"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: taskController,
                      decoration: const InputDecoration(
                        hintText: "Enter task name",
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text("Select users to share with:"),
                    ),
                    ...users.map((user) {
                      return CheckboxListTile(
                        title: Text(user),
                        value: selectedUsers[user],
                        onChanged: (bool? value) {
                          setInnerState(() {
                            selectedUsers[user] = value ?? false;
                          });
                        },
                      );
                    }).toList(),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: () async {
                    if (taskController.text.isNotEmpty) {
                      final selected = selectedUsers.entries
                          .where((entry) => entry.value)
                          .map((entry) => entry.key)
                          .toList();

                      await _addTaskToFirestore(taskController.text, selected);

                      for (var user in users) {
                        selectedUsers[user] = false;
                      }

                      Navigator.pop(context);
                    }
                  },
                  child: const Text("Add"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Shared To-Do List"),
        backgroundColor: Colors.deepPurple,
        centerTitle: true,
        titleTextStyle: const TextStyle(
          fontSize: 22,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('tasks').orderBy('timestamp').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final tasks = snapshot.data!.docs;

          return ListView(
            children: tasks.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final title = data['title'];
              final users = data['sharedWith'] as List<dynamic>;

              return ListTile(
                title: Text(title),
                subtitle: Text("Shared with ${users.length} people"),
                trailing: const Icon(Icons.check_circle_outline),
              );
            }).toList(),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTaskDialog,
        child: const Icon(Icons.add),
        backgroundColor: Colors.deepPurple,
      ),
    );
  }
}

class TaskListScreen extends StatefulWidget {
  final String title;
  const TaskListScreen({super.key, required this.title});

  @override
  _TaskListScreenState createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  List<Map<String, dynamic>> tasks = [];

  void _addTask() {
    TextEditingController taskController = TextEditingController();
    TextEditingController descController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Add Task"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: taskController,
                decoration: const InputDecoration(hintText: "Enter task name"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  hintText: "Enter task description",
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                if (taskController.text.isNotEmpty) {
                  setState(() {
                    tasks.add({
                      "title": taskController.text,
                      "completed": false,
                    });
                  });
                }
                Navigator.pop(context);
              },
              child: const Text("Add"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body:
      tasks.isEmpty
          ? const Center(child: Text("No tasks yet. Add some!"))
          : ListView.builder(
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(tasks[index]["title"]),
            leading: Checkbox(
              value: tasks[index]["completed"],
              onChanged: (bool? value) {
                setState(() {
                  tasks[index]["completed"] = value!;
                });
              },
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                setState(() {
                  tasks.removeAt(index);
                });
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: _addTask,
      ),
    );
  }
}
