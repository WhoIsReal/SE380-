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

  Future<void> _addTaskGroupToFirestore(String title, List<String> sharedUsers) async {
    await FirebaseFirestore.instance.collection('tasksGroups').add({
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

                      await _addTaskGroupToFirestore(taskController.text, selected);

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
        stream: FirebaseFirestore.instance.collection('taskGroups').orderBy('timestamp').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final taskGroups = snapshot.data!.docs;

          return ListView(
            children: taskGroups.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final title = data['title'];
              final users = data['sharedWith'] as List<dynamic>;

              return ListTile(
                title: Text(title),
                subtitle: Text("Shared with ${users.length} people"),
                trailing: const Icon(Icons.group),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TaskListScreen(title: title),
                    ),
                  );
                },
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
    String? selectedAssignee = "Unassigned";

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Add Task"),
          content: StatefulBuilder(
            builder: (context, setInnerState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: taskController,
                      decoration: const InputDecoration(hintText: "Enter task name"),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(hintText: "Enter task description"),
                    ),
                    const SizedBox(height: 20),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text("Assign to:"),
                    ),
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('taskGroups')
                          .where('title', isEqualTo: widget.title)
                          .limit(1)
                          .get()
                          .then((snapshot) => snapshot.docs.first),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const CircularProgressIndicator();

                        List<dynamic> sharedUsers = snapshot.data!['sharedWith'];
                        List<String> options = ["Unassigned", ...sharedUsers.map((u) => u.toString())];

                        return DropdownButton<String>(
                          isExpanded: true,
                          value: selectedAssignee,
                          items: options.map((user) {
                            return DropdownMenuItem(
                              value: user,
                              child: Text(user),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setInnerState(() {
                              selectedAssignee = value;
                            });
                          },
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                if (taskController.text.isNotEmpty) {
                  final groupSnapshot = await FirebaseFirestore.instance
                      .collection('taskGroups')
                      .where('title', isEqualTo: widget.title)
                      .limit(1)
                      .get();

                  final groupId = groupSnapshot.docs.first.id;

                  await FirebaseFirestore.instance
                      .collection('taskGroups')
                      .doc(groupId)
                      .collection('tasks')
                      .add({
                    "title": taskController.text,
                    "description": descController.text,
                    "completed": false,
                    "assignee": selectedAssignee == "Unassigned" ? null : selectedAssignee,
                    "timestamp": FieldValue.serverTimestamp(),
                  });

                  Navigator.pop(context);
                }
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

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('taskGroups')
            .doc(widget.title)
            .collection('tasksList')
            .orderBy('timestamp')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No tasks yet. Add some!"));
          }

          final tasksList = snapshot.data!.docs;

          return ListView.builder(
            itemCount: tasksList.length,
            itemBuilder: (context, index) {
              final task = tasksList[index].data() as Map<String, dynamic>;

              return ListTile(
                title: Text(task["title"] ?? "Untitled"),
                subtitle: Text(task["assignedTo"] != null && task["assignedTo"] != ""
                    ? "Assigned to ${task["assignedTo"]}"
                    : "Unassigned"),
                leading: Checkbox(
                  value: task["completed"] ?? false,
                  onChanged: (bool? value) {
                    FirebaseFirestore.instance
                        .collection('taskGroups')
                        .doc(widget.title)
                        .collection('tasksList')
                        .doc(tasksList[index].id)
                        .update({"completed": value});
                  },
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () {
                    FirebaseFirestore.instance
                        .collection('taskGroups')
                        .doc(widget.title)
                        .collection('tasksList')
                        .doc(tasksList[index].id)
                        .delete();
                  },
                ),
              );
            },
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
