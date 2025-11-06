// main.dart
// Single-file Flutter lab app:
// - Wallpaper Gallery (your original demo, slightly tucked into a tab)
// - SQLite persistence demo (notes CRUD)
// - Firestore persistence demo (items CRUD + search + update)
// - Manual user login with Firestore (no Firebase Auth)
//
// ------------------------- IMPORTANT SETUP -------------------------
// pubspec.yaml (add):
// dependencies:
//   flutter:
//     sdk: flutter
//   cupertino_icons: ^1.0.6
//   sqflite: ^2.3.0
//   path: ^1.9.0
//   path_provider: ^2.1.4
//   cloud_firestore: ^5.4.4
//   firebase_core: ^3.6.0
//
// For Firestore on web/mobile, you MUST initialize Firebase:
// 1) Create a Firebase project, enable Firestore.
// 2) For web: copy your web config into FirebaseOptions below.
//    For Android/iOS: add google-services files as usual.
// ------------------------------------------------------------------

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Firebase
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// SQLite
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// ------------------------- ENTRY POINT -------------------------
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initFirebase(); // Safe to call on all platforms
  runApp(const MyApp());
}

Future<void> _initFirebase() async {
  try {
    if (Firebase.apps.isNotEmpty) return;
    if (kIsWeb) {
      // TODO: Paste your actual web config here from Firebase Console (Project settings).
      const options = FirebaseOptions(
  apiKey: "AIzaSyA9...your_key_here...",
  appId: "1:1234567890:web:abcdef123456",
  messagingSenderId: "1234567890",
  projectId: "my-wallpaper-lab",
  storageBucket: "my-wallpaper-lab.appspot.com",
  authDomain: "my-wallpaper-lab.firebaseapp.com",
);

      await Firebase.initializeApp(options: options);
    } else {
      // On mobile, if you added google-services files properly, this works:
      await Firebase.initializeApp();
    }
  } catch (e) {
    // If you haven't configured Firebase yet, the rest of the app still runs,
    // but Firestore screens will show a friendly message.
    debugPrint("Firebase init error: $e");
  }
}

// ------------------------- APP ROOT -------------------------
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Labs (All-in-One)',
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: const LoginGate(),
      routes: {
        '/home': (context) => const MainTabs(),
        '/detail': (context) => const DetailScreen(),
      },
    );
  }
}

// ------------------------- LOGIN (Manual via Firestore) -------------------------
// Simple manual login screen that checks `users` collection for email+password.
// WARNING: Storing plain text passwords is unsafe; this is for *lab/demo only*.
class LoginGate extends StatefulWidget {
  const LoginGate({super.key});

  @override
  State<LoginGate> createState() => _LoginGateState();
}

class _LoginGateState extends State<LoginGate> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isRegister = false;
  String? _error;
  bool _firebaseReady = Firebase.apps.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _firebaseReady = Firebase.apps.isNotEmpty;
  }

  Future<void> _login() async {
    if (!_firebaseReady) {
      setState(() => _error = 'Firebase not initialized. Configure Firebase first.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    try {
      final email = _emailCtrl.text.trim();
      final pass = _passCtrl.text;

      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .where('password', isEqualTo: pass) // demo only
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        setState(() => _error = 'Invalid credentials.');
      } else {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/home', arguments: email);
      }
    } catch (e) {
      setState(() => _error = 'Login error: $e');
    }
  }

  Future<void> _register() async {
    if (!_firebaseReady) {
      setState(() => _error = 'Firebase not initialized. Configure Firebase first.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    try {
      final email = _emailCtrl.text.trim();
      final pass = _passCtrl.text;

      final exists = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (exists.docs.isNotEmpty) {
        setState(() => _error = 'User already exists.');
        return;
      }
      await FirebaseFirestore.instance.collection('users').add({
        'email': email,
        'password': pass, // demo only
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registered! Please log in.')),
      );
      setState(() {
        _isRegister = false;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = 'Register error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = _firebaseReady;
    return Scaffold(
      appBar: AppBar(title: const Text('Manual Login (Firestore)')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!ready)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '⚠️ Firebase isn’t configured yet.\n'
                        'Firestore features won’t work until you add Firebase config.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: Text(_isRegister ? 'Switch to Login' : 'Switch to Register'),
                    value: _isRegister,
                    onChanged: (v) => setState(() => _isRegister = v),
                  ),
                  const SizedBox(height: 8),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _emailCtrl,
                          decoration: const InputDecoration(labelText: 'Email'),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Enter email' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passCtrl,
                          decoration: const InputDecoration(labelText: 'Password'),
                          obscureText: true,
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Enter password' : null,
                        ),
                        const SizedBox(height: 16),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(_error!,
                                style: const TextStyle(color: Colors.red)),
                          ),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isRegister ? _register : _login,
                                child: Text(_isRegister ? 'Register' : 'Login'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------- MAIN TABS -------------------------
class MainTabs extends StatefulWidget {
  const MainTabs({super.key});

  @override
  State<MainTabs> createState() => _MainTabsState();
}

class _MainTabsState extends State<MainTabs> {
  int _index = 0;

  final _pages = const [
    HomeScreen(),          // Your Wallpaper Gallery
    SqliteNotesScreen(),   // SQLite persistence demo
    FirestoreItemsScreen() // Firestore CRUD + search + update
  ];

  @override
  Widget build(BuildContext context) {
    final userEmail = ModalRoute.of(context)?.settings.arguments as String?;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          ['Wallpaper Gallery', 'SQLite Notes', 'Firestore Items'][_index],
        ),
        actions: [
          if (userEmail != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  userEmail,
                  style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ),
            ),
          IconButton(
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginGate()),
            ),
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.image), label: 'Gallery'),
          NavigationDestination(icon: Icon(Icons.storage), label: 'SQLite'),
          NavigationDestination(icon: Icon(Icons.cloud), label: 'Firestore'),
        ],
      ),
    );
  }
}

// ------------------------- WALLPAPER GALLERY (your code, slightly trimmed) -------------------------
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Wallpaper> _wallpapers = [
    Wallpaper('Nature Landscape', 'https://picsum.photos/seed/nature/400/600'),
    Wallpaper('Abstract Art', 'https://picsum.photos/seed/abstract/400/600'),
    Wallpaper('City Skyline', 'https://picsum.photos/seed/city/400/600'),
    Wallpaper('Ocean Waves', 'https://picsum.photos/seed/ocean/400/600'),
    Wallpaper('Forest Path', 'https://picsum.photos/seed/forest/400/600'),
    Wallpaper('Mountain Peak', 'https://picsum.photos/seed/mountain/400/600'),
    Wallpaper('Desert Dunes', 'https://picsum.photos/seed/desert/400/600'),
    Wallpaper('Starry Night', 'https://picsum.photos/seed/starry/400/600'),
  ];

  List<Wallpaper> _filteredWallpapers = [];

  @override
  void initState() {
    super.initState();
    _filteredWallpapers = _wallpapers;
  }

  void _filterWallpapers(String query) {
    setState(() {
      _filteredWallpapers = _wallpapers
          .where((wp) => wp.title.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  void _addWallpaper(String title, String url) {
    setState(() {
      _wallpapers.add(Wallpaper(title, url));
      _filteredWallpapers = _wallpapers;
    });
  }

  void _showAddWallpaperDialog() {
    final formKey = GlobalKey<FormState>();
    String title = '';
    String url = '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Wallpaper'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) => (v == null || v.isEmpty) ? 'Enter title' : null,
                onSaved: (v) => title = v!,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Image URL'),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter URL';
                  if (!Uri.parse(v).isAbsolute) return 'Enter valid URL';
                  return null;
                },
                onSaved: (v) => url = v!,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                formKey.currentState!.save();
                _addWallpaper(title, url);
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Success'),
                    content: const Text('Image Added'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth > 900
        ? 5
        : (screenWidth > 600 ? 4 : (screenWidth > 400 ? 3 : 2));

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddWallpaperDialog,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Search Wallpapers',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: _filterWallpapers,
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.7,
              ),
              itemCount: _filteredWallpapers.length,
              itemBuilder: (context, index) {
                final wallpaper = _filteredWallpapers[index];
                return GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/detail', arguments: wallpaper),
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Image.network(
                            wallpaper.imageUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, prog) =>
                                prog == null ? child : const Center(child: CircularProgressIndicator()),
                            errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image)),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            wallpaper.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class DetailScreen extends StatelessWidget {
  const DetailScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final wallpaper = ModalRoute.of(context)!.settings.arguments as Wallpaper;
    return Scaffold(
      appBar: AppBar(title: Text(wallpaper.title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
                maxWidth: MediaQuery.of(context).size.width * 0.9,
              ),
              child: Image.network(wallpaper.imageUrl, fit: BoxFit.contain),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Wallpaper set! (Simulation)')),
              ),
              child: const Text('Set as Wallpaper'),
            ),
          ],
        ),
      ),
    );
  }
}

class Wallpaper {
  final String title;
  final String imageUrl;
  Wallpaper(this.title, this.imageUrl);
}

// ------------------------- SQLITE DEMO (Notes CRUD) -------------------------
class SqliteNotesScreen extends StatefulWidget {
  const SqliteNotesScreen({super.key});
  @override
  State<SqliteNotesScreen> createState() => _SqliteNotesScreenState();
}

class _SqliteNotesScreenState extends State<SqliteNotesScreen> {
  late final Future<NotesDb> _dbFuture = NotesDb.open();

  void _showNoteDialog({Note? note}) {
    final titleCtrl = TextEditingController(text: note?.title ?? '');
    final bodyCtrl = TextEditingController(text: note?.body ?? '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(note == null ? 'Add Note' : 'Edit Note'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 8),
            TextField(
              controller: bodyCtrl,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Body'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final db = await _dbFuture;
              if (note == null) {
                await db.insertNote(Note(title: titleCtrl.text, body: bodyCtrl.text));
              } else {
                await db.updateNote(Note(id: note.id, title: titleCtrl.text, body: bodyCtrl.text));
              }
              if (!mounted) return;
              Navigator.pop(context);
              setState(() {});
            },
            child: Text(note == null ? 'Add' : 'Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<NotesDb>(
      future: _dbFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('DB error: ${snap.error}'));
        }
        final db = snap.data!;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _showNoteDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Note'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await db.deleteAll();
                      setState(() {});
                    },
                    icon: const Icon(Icons.delete_sweep),
                    label: const Text('Clear All'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Note>>(
                future: db.getNotes(),
                builder: (context, notesSnap) {
                  if (!notesSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final notes = notesSnap.data!;
                  if (notes.isEmpty) return const Center(child: Text('No notes yet.'));
                  return ListView.separated(
                    itemCount: notes.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final n = notes[i];
                      return ListTile(
                        title: Text(n.title),
                        subtitle: Text(n.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _showNoteDialog(note: n),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () async {
                                await db.deleteNote(n.id!);
                                setState(() {});
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// SQLite helper classes
class NotesDb {
  final Database db;
  NotesDb._(this.db);

  static Future<NotesDb> open() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'notes_lab.db');
    final db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE notes(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            body TEXT NOT NULL
          );
        ''');
      },
    );
    return NotesDb._(db);
  }

  Future<int> insertNote(Note note) =>
      db.insert('notes', {'title': note.title, 'body': note.body});

  Future<List<Note>> getNotes() async {
    final rows = await db.query('notes', orderBy: 'id DESC');
    return rows
        .map((r) => Note(id: r['id'] as int, title: r['title'] as String, body: r['body'] as String))
        .toList();
    }

  Future<int> updateNote(Note note) => db.update(
        'notes',
        {'title': note.title, 'body': note.body},
        where: 'id = ?',
        whereArgs: [note.id],
      );

  Future<int> deleteNote(int id) => db.delete('notes', where: 'id = ?', whereArgs: [id]);

  Future<void> deleteAll() async => db.delete('notes');
}

class Note {
  final int? id;
  final String title;
  final String body;
  Note({this.id, required this.title, required this.body});
}

// ------------------------- FIRESTORE DEMO (CRUD + Search + Update) -------------------------
class FirestoreItemsScreen extends StatefulWidget {
  const FirestoreItemsScreen({super.key});
  @override
  State<FirestoreItemsScreen> createState() => _FirestoreItemsScreenState();
}

class _FirestoreItemsScreenState extends State<FirestoreItemsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  bool get _firebaseReady => Firebase.apps.isNotEmpty;

  Future<void> _showAddOrEditDialog({DocumentSnapshot<Map<String, dynamic>>? doc}) async {
    final titleCtrl = TextEditingController(text: doc?.data()?['title'] ?? '');
    final descCtrl = TextEditingController(text: doc?.data()?['description'] ?? '');
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(doc == null ? 'Add Item (Firestore)' : 'Edit Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 8),
            TextField(
              controller: descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (!_firebaseReady) return;
              final data = {
                'title': titleCtrl.text.trim(),
                'description': descCtrl.text.trim(),
                'updatedAt': FieldValue.serverTimestamp(),
                'createdAt': doc == null ? FieldValue.serverTimestamp() : doc['createdAt'],
              };
              final col = FirebaseFirestore.instance.collection('items');
              if (doc == null) {
                await col.add(data);
              } else {
                await col.doc(doc.id).update(data);
              }
              if (!mounted) return;
              Navigator.pop(context);
            },
            child: Text(doc == null ? 'Add' : 'Save'),
          ),
        ],
      ),
    );
  }

  Query<Map<String, dynamic>> _buildQuery() {
    final col = FirebaseFirestore.instance.collection('items');
    if (_query.isEmpty) {
      return col.orderBy('createdAt', descending: true);
    }
    // Prefix search on 'title' using startAt / endAt.
    final q = _query;
    return col
        .orderBy('title')
        .startAt([q])
        .endAt(['$q\uf8ff']);
  }

  @override
  Widget build(BuildContext context) {
    if (!_firebaseReady) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '⚠️ Firebase not initialized. Add Firebase config to use Firestore.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    labelText: 'Search title (Firestore)',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => _query = v.trim()),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _showAddOrEditDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _buildQuery().snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(child: Text('Firestore error: ${snap.error}'));
              }
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(child: Text('No items found.'));
              }
              return ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final d = docs[i].data();
                  final id = docs[i].id;
                  final title = d['title'] ?? '';
                  final desc = d['description'] ?? '';
                  return ListTile(
                    title: Text(title),
                    subtitle: Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Edit',
                          icon: const Icon(Icons.edit),
                          onPressed: () => _showAddOrEditDialog(doc: docs[i]),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          icon: const Icon(Icons.delete),
                          onPressed: () async {
                            await FirebaseFirestore.instance.collection('items').doc(id).delete();
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
