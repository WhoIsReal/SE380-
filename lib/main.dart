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
  final String currentUserName;
  const HomeScreen({super.key, required this.currentUserName});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<String> users = [];
  final Map<String, bool> selectedUsers = {};

  Future<void> _fetchUsersFromFirestore() async {
    final snapshot = await FirebaseFirestore.instance.collection('users').get();
    final fetchedUsers =
        snapshot.docs.map((doc) => doc['name'] as String).toList();

    setState(() {
      users = fetchedUsers;
      selectedUsers.clear();
      for (var user in users) {
        selectedUsers[user] = false;
      }
    });
  }

  Future<void> _addTaskGroupToFirestore(
    String title,
    List<String> sharedUsers,
  ) async {
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

  void _showAddTaskGroupDialog() {
    TextEditingController taskController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setInnerState) {
            return AlertDialog(
              title: const Text(
                "Add New Shared Task Group",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              content: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Task Name Field
                      TextField(
                        controller: taskController,
                        decoration: InputDecoration(
                          hintText: "Enter task group name",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 12.0, horizontal: 16.0),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Users Section
                      const Text(
                        "Select users to share with:",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 10),

                      // User checkboxes
                      Column(
                        children: users.map((user) {
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 2,
                            child: CheckboxListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                              title: Text(user),
                              value: selectedUsers[user],
                              onChanged: (bool? value) {
                                setInnerState(() {
                                  selectedUsers[user] = value ?? false;
                                });
                              },
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                          );
                        }).toList(),
                      ),

                      // Validation message
                      if (selectedUsers.entries.every((entry) => !entry.value))
                        const Padding(
                          padding: EdgeInsets.only(top: 8.0),
                          child: Text(
                            "Please select at least one user.",
                            style: TextStyle(color: Colors.red, fontSize: 14),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                // Cancel Button
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text(
                    "Cancel",
                    style: TextStyle(color: Colors.red),
                  ),
                ),
                // Add Button
                TextButton(
                  onPressed: () async {
                    if (taskController.text.isNotEmpty) {
                      final selected = selectedUsers.entries
                          .where((entry) => entry.value)
                          .map((entry) => entry.key)
                          .toList();

                      // Validate if at least one user is selected
                      if (selected.isEmpty) {
                        setInnerState(() {
                          // Force rebuild to show validation message
                        });
                        return; // Do not proceed with adding if no user is selected
                      }

                      await _addTaskGroupToFirestore(
                        taskController.text,
                        selected,
                      );

                      // Reset selected users
                      for (var user in users) {
                        selectedUsers[user] = false;
                      }

                      Navigator.pop(context);
                    }
                  },
                  child: const Text(
                    "Add",
                    style: TextStyle(color: Colors.blue),
                  ),
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
        backgroundColor: Colors.blue,
        centerTitle: true,
        titleTextStyle: const TextStyle(
          fontSize: 22,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: widget.currentUserName.isEmpty
          ? const Center(child: Text("User not found. Please login again."))
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('taskGroups')
            .where('sharedWith', arrayContains: widget.currentUserName)
            .orderBy('timestamp')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text("Error: ${snapshot.error}"),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No task groups shared with you."));
          }

          final taskGroups = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: taskGroups.length,
            itemBuilder: (context, index) {
              final doc = taskGroups[index];
              final data = doc.data() as Map<String, dynamic>;
              final title = data['title'];
              final users = data['sharedWith'] as List<dynamic>;
              final groupId = doc.id; // Task Group ID to delete the group later

              return Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  leading: CircleAvatar(
                    backgroundColor: Colors.blueAccent,
                    child: Text(
                      title[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text(
                    "Shared with ${users.length} people",
                    style: const TextStyle(fontSize: 13),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          _showDeleteConfirmationDialog(groupId); // Call the delete dialog
                        },
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TaskListScreen(
                            title: title,
                            currentUserName: widget.currentUserName,
                          ),
                        )
                    );
                  },
                ),
              );
            },
          );

        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTaskGroupDialog,
        child: const Icon(Icons.add),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _showDeleteConfirmationDialog(String groupId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Task Group'),
          content: const Text('Are you sure you want to delete this task group? This will also delete all tasks within it.'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close the dialog
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                await _deleteTaskGroup(groupId); // Delete the task group
                Navigator.pop(context); // Close the dialog
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteTaskGroup(String groupId) async {
    try {
      // Fetch all tasks under this task group
      var tasksSnapshot = await FirebaseFirestore.instance
          .collection('taskGroups')
          .doc(groupId)
          .collection('tasksList')
          .get();

      // If tasks exist, delete them
      if (tasksSnapshot.docs.isNotEmpty) {
        for (var taskDoc in tasksSnapshot.docs) {
          await taskDoc.reference.delete(); // Delete each task
        }
      }

      // Now delete the task group itself
      await FirebaseFirestore.instance
          .collection('taskGroups')
          .doc(groupId)
          .delete();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task group and tasks deleted successfully')),
      );
    } catch (e) {
      print("Error deleting task group and tasks: $e"); // Error handling
    }
  }

}

class TaskListScreen extends StatefulWidget {
  final String title;
  final String currentUserName;

  const TaskListScreen({
    super.key,
    required this.title,
    required this.currentUserName,
  });

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
          title: const Text(
            "Add Task",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: StatefulBuilder(
            builder: (context, setInnerState) {
              return ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 600, // Maximum height for the dialog
                  maxWidth: 500,  // Maximum width for the dialog, increased for more space
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch, // Stretches children horizontally
                      children: [
                        // Task Title Field (larger horizontally)
                        TextField(
                          controller: taskController,
                          decoration: InputDecoration(
                            hintText: "Enter task name",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10.0),
                              borderSide: const BorderSide(color: Colors.grey),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 16.0, horizontal: 20.0),
                          ),
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 16),

                        // Scrollable Description Field (larger horizontally)
                        const Text(
                          "Description:",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 180, // Increased height for more space
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Scrollbar(
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: TextField(
                                controller: descController,
                                decoration: const InputDecoration(
                                  hintText: "Enter task description",
                                  border: InputBorder.none,
                                ),
                                keyboardType: TextInputType.multiline,
                                maxLines: null,
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Assignee Dropdown (larger horizontally)
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "Assign to:",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 10),
                        FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('taskGroups')
                              .where('title', isEqualTo: widget.title)
                              .limit(1)
                              .get()
                              .then((snapshot) => snapshot.docs.first),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const CircularProgressIndicator();
                            }

                            List<dynamic> sharedUsers =
                            snapshot.data!['sharedWith'];
                            List<String> options = [
                              "Unassigned",
                              ...sharedUsers.map((u) => u.toString()),
                            ];

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey),
                              ),
                              child: DropdownButton<String>(
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
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          actions: [
            // Cancel Button
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "Cancel",
                style: TextStyle(color: Colors.red),
              ),
            ),
            // Add Button (styled)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              ),
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
              child: const Text(
                "Add",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue, // Blue background
        elevation: 4.0, // Subtle shadow for depth
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(16), // Rounded bottom corners
          ),
        ),
      ),


      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
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
            stream:
                FirebaseFirestore.instance
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

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      title: Text(
                        task["title"] ?? "Untitled",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.black87,
                        ),
                      ),
                      subtitle: Text(
                        task["assignee"] != null && task["assignee"] != ""
                            ? "Assigned to ${task["assignee"]}"
                            : "Unassigned",
                        style: TextStyle(
                          color: task["assignee"] != null && task["assignee"] != ""
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
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
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          // Show confirmation dialog
                          showDialog(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: const Text("Delete Task"),
                                content: const Text("Are you sure you want to delete this task?"),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context); // Close the dialog if "Cancel" is pressed
                                    },
                                    child: const Text("Cancel"),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      // Delete the task from Firestore if "Delete" is pressed
                                      await FirebaseFirestore.instance
                                          .collection('taskGroups')
                                          .doc(groupId)
                                          .collection('tasksList')
                                          .doc(tasksList[index].id)
                                          .delete();

                                      Navigator.pop(context); // Close the dialog after deletion
                                    },
                                    child: const Text("Delete"),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TaskDetailScreen(
                              groupId: groupId,
                              taskId: tasksList[index].id,
                              currentUserName: widget.currentUserName,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );

            },
          );
        },
      ),

      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        backgroundColor: Colors.blue,
        onPressed: _addTask,
      ),
    );
  }
}

class TaskDetailScreen extends StatefulWidget {
  final String groupId;
  final String taskId;
  final String currentUserName;

  const TaskDetailScreen({
    super.key,
    required this.groupId,
    required this.taskId,
    required this.currentUserName,
  });

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  Map<String, dynamic>? taskData;
  bool isLoading = true;

  Future<void> _fetchTaskData() async {
    final taskDoc =
        await FirebaseFirestore.instance
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
    final descController = TextEditingController(
      text: taskData?['description'],
    );
    String? currentAssignee = taskData?['assignee'] ?? "Unassigned";

    showDialog(
      context: context,
      builder: (context) {
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('taskGroups')
              .doc(widget.groupId)
              .get(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            List<dynamic> sharedUsers = snapshot.data!['sharedWith'];
            List<String> options = [
              "Unassigned",
              ...sharedUsers.map((u) => u.toString()),
            ];

            return AlertDialog(
              title: const Text(
                "Edit Task",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              content: StatefulBuilder(
                builder: (context, setInnerState) {
                  return ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxHeight: 600,
                      maxWidth: 500,
                    ),
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Task Title
                            TextField(
                              controller: titleController,
                              decoration: InputDecoration(
                                labelText: "Title",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10.0),
                                  borderSide: const BorderSide(color: Colors.grey),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: 16.0, horizontal: 20.0),
                              ),
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 16),

                            // Description
                            const Text(
                              "Description:",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 180,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Scrollbar(
                                thumbVisibility: true,
                                child: SingleChildScrollView(
                                  padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                                  child: TextField(
                                    controller: descController,
                                    decoration: const InputDecoration(
                                      hintText: "Enter task description",
                                      border: InputBorder.none,
                                    ),
                                    keyboardType: TextInputType.multiline,
                                    maxLines: null,
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Assignee
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "Assign to:",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey),
                              ),
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: currentAssignee,
                                items: options.map((user) {
                                  return DropdownMenuItem(
                                    value: user,
                                    child: Text(user),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setInnerState(() {
                                    currentAssignee = value!;
                                  });
                                },
                                underline: const SizedBox(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              actions: [
                // Cancel Button
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(color: Colors.red),
                  ),
                ),
                // Save Button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  ),
                  onPressed: () async {
                    await FirebaseFirestore.instance
                        .collection('taskGroups')
                        .doc(widget.groupId)
                        .collection('tasksList')
                        .doc(widget.taskId)
                        .update({
                      "title": titleController.text,
                      "description": descController.text,
                      "assignee": currentAssignee == "Unassigned"
                          ? null
                          : currentAssignee,
                    });
                    Navigator.pop(context);
                    _fetchTaskData();
                  },
                  child: const Text(
                    "Save",
                    style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
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
      "author": widget.currentUserName, // <-- eklenen satır
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
        title: Text(
          taskData!['title'] ?? "Task Detail",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue,
        elevation: 4.0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(16),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: _editTask,
            tooltip: 'Edit Task',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title and Description Section
            Text(
              "Description:",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              taskData!['description'] ?? 'No description',
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 16),

            // Assignee Section
            Text(
              "Assignee:",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              taskData!['assignee'] ?? 'Unassigned',
              style: TextStyle(fontSize: 16, color: Colors.black87),
            ),
            const SizedBox(height: 16),

            // Completed Checkbox Section
            Row(
              children: [
                const Text(
                  "Completed: ",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
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

            // Divider for Comments Section
            const Divider(height: 32, thickness: 1.5, color: Colors.grey),
            const Text(
              "Comments",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.blueGrey,
              ),
            ),
            const SizedBox(height: 10),

            // StreamBuilder for Comments
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
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());
                  final comments = snapshot.data!.docs;
                  if (comments.isEmpty)
                    return const Center(child: Text("No comments yet."));

                  return ListView(
                    children: comments.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          title: Text(
                            data['text'] ?? '',
                            style: TextStyle(fontSize: 16),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (data['author'] != null)
                                Text(
                                  "By: ${data['author']}",
                                  style: TextStyle(color: Colors.blueGrey, fontSize: 14),
                                ),
                              if (data['timestamp'] != null)
                                Text(
                                  data['timestamp'].toDate().toString(),
                                  style: TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),

            const SizedBox(height: 10),

            // Comment Input Section
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: "Add a comment...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue),
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
