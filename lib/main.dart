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
    await FirebaseFirestore.instance.collection('taskGroups').add({
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
                      .collection('tasksList')
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
            .where('title', isEqualTo: widget.title)
            .limit(1)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No tasks yet. Add some!"));
          }

          final groupDoc = snapshot.data!.docs.first;
          final groupId = groupDoc.id;

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('taskGroups')
                .doc(groupId)
                .collection('tasksList')
                .orderBy('timestamp')
                .snapshots(),
            builder: (context, taskSnapshot) {
              if (!taskSnapshot.hasData || taskSnapshot.data!.docs.isEmpty) {
                return const Center(child: Text("No tasks yet. Add some!"));
              }

              final tasksList = taskSnapshot.data!.docs;

              return ListView.builder(
                itemCount: tasksList.length,
                itemBuilder: (context, index) {
                  final task = tasksList[index].data() as Map<String, dynamic>;

                  return ListTile(
                    title: Text(task["title"] ?? "Untitled"),
                    subtitle: Text(task["assignee"] != null && task["assignee"] != ""
                        ? "Assigned to ${task["assignee"]}"
                        : "Unassigned"),
                    leading: Checkbox(
                      value: task["completed"] ?? false,
                      onChanged: (bool? value) {
                        FirebaseFirestore.instance
                            .collection('taskGroups')
                            .doc(groupId)
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
                            .doc(groupId)
                            .collection('tasksList')
                            .doc(tasksList[index].id)
                            .delete();
                      },
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TaskDetailScreen(
                            groupId: groupId,
                            taskId: tasksList[index].id,
                          ),
                        ),
                      );
                    },
                  );
                },
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
class TaskDetailScreen extends StatefulWidget {
  final String groupId;
  final String taskId;

  const TaskDetailScreen({super.key, required this.groupId, required this.taskId});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  Map<String, dynamic>? taskData;
  bool isLoading = true;

  Future<void> _fetchTaskData() async {
    final taskDoc = await FirebaseFirestore.instance
        .collection('taskGroups')
        .doc(widget.groupId)
        .collection('tasksList')
        .doc(widget.taskId)
        .get();

    if (taskDoc.exists) {
      setState(() {
        taskData = taskDoc.data()!;
        isLoading = false;
      });
    }
  }

  void _editTask() {
    final titleController = TextEditingController(text: taskData?['title']);
    final descController = TextEditingController(text: taskData?['description']);
    String? currentAssignee = taskData?['assignee'] ?? "Unassigned";

    showDialog(
      context: context,
      builder: (context) {
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('taskGroups').doc(widget.groupId).get(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

            List<dynamic> sharedUsers = snapshot.data!['sharedWith'];
            List<String> options = ["Unassigned", ...sharedUsers.map((u) => u.toString())];

            return AlertDialog(
              title: const Text("Edit Task"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: "Title"),
                  ),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(labelText: "Description"),
                  ),
                  const SizedBox(height: 10),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: currentAssignee,
                    items: options.map((user) {
                      return DropdownMenuItem(
                        value: user,
                        child: Text(user),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        currentAssignee = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: () async {
                    await FirebaseFirestore.instance
                        .collection('taskGroups')
                        .doc(widget.groupId)
                        .collection('tasksList')
                        .doc(widget.taskId)
                        .update({
                      "title": titleController.text,
                      "description": descController.text,
                      "assignee": currentAssignee == "Unassigned" ? null : currentAssignee,
                    });
                    Navigator.pop(context);
                    _fetchTaskData();
                  },
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _addComment(String commentText) async {
    if (commentText.trim().isEmpty) return;

    await FirebaseFirestore.instance
        .collection('taskGroups')
        .doc(widget.groupId)
        .collection('tasksList')
        .doc(widget.taskId)
        .collection('comments')
        .add({
      "text": commentText.trim(),
      "timestamp": FieldValue.serverTimestamp(),
    });

    _commentController.clear();
  }

  @override
  void initState() {
    super.initState();
    _fetchTaskData();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading || taskData == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(taskData!['title'] ?? "Task Detail"),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _editTask,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Description: ${taskData!['description'] ?? 'No description'}"),
            const SizedBox(height: 8),
            Text("Assignee: ${taskData!['assignee'] ?? 'Unassigned'}"),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text("Completed: "),
                Checkbox(
                  value: taskData!['completed'] ?? false,
                  onChanged: (value) async {
                    await FirebaseFirestore.instance
                        .collection('taskGroups')
                        .doc(widget.groupId)
                        .collection('tasksList')
                        .doc(widget.taskId)
                        .update({"completed": value});
                    _fetchTaskData();
                  },
                ),
              ],
            ),
            const Divider(height: 32),
            const Text("Comments", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('taskGroups')
                    .doc(widget.groupId)
                    .collection('tasksList')
                    .doc(widget.taskId)
                    .collection('comments')
                    .orderBy('timestamp')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Text("Loading comments...");
                  final comments = snapshot.data!.docs;
                  if (comments.isEmpty) return const Text("No comments yet.");

                  return ListView(
                    children: comments.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return ListTile(
                        title: Text(data['text'] ?? ''),
                        subtitle: data['timestamp'] != null
                            ? Text(data['timestamp'].toDate().toString())
                            : null,
                      );
                    }).toList(),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(
                      hintText: "Add a comment...",
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () {
                    _addComment(_commentController.text);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


