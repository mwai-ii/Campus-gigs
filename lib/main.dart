import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const CampusGigsApp());
}

class CampusGigsApp extends StatelessWidget {
  const CampusGigsApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Campus Gigs',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5)),
      ),
      home: const AuthGate(),
    );
  }
}

// ---------- Auth gate: decides login vs home ----------
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return snap.hasData ? const HomeShell() : const AuthScreen();
      },
    );
  }
}

// ---------- Login / Register ----------
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _isLogin = true;
  bool _loading = false;
  bool _hidePass = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = FirebaseAuth.instance;
      final email = _email.text.trim();
      if (_isLogin) {
        await auth.signInWithEmailAndPassword(email: email, password: _password.text);
      } else {
        await auth.createUserWithEmailAndPassword(email: email, password: _password.text);
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _friendly(e.code));
    } catch (_) {
      setState(() => _error = 'Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendly(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'That email is already registered. Try logging in.';
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Wrong email or password.';
      case 'network-request-failed':
        return 'No internet connection.';
      case 'too-many-requests':
        return 'Too many attempts. Wait a bit and retry.';
      default:
        return 'Auth error: $code';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.work_outline, size: 56, color: cs.primary),
                  const SizedBox(height: 12),
                  Text('Campus Gigs',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const Text('Student talent. Real opportunities.',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                        labelText: 'Email', border: OutlineInputBorder()),
                    validator: (v) {
                      final s = v?.trim() ?? '';
                      if (s.isEmpty) return 'Enter your email';
                      if (!s.contains('@') || !s.contains('.')) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _password,
                    obscureText: _hidePass,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_hidePass ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _hidePass = !_hidePass),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.length < 6) ? 'At least 6 characters' : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: cs.error)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(_isLogin ? 'Log in' : 'Create account'),
                    ),
                  ),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => setState(() {
                              _isLogin = !_isLogin;
                              _error = null;
                            }),
                    child: Text(_isLogin
                        ? "New here? Create an account"
                        : 'Already have an account? Log in'),
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
// ---------- Model ----------
const categories = ['Design', 'Programming', 'Writing', 'Tutoring', 'Other'];

class Gig {
  final String id, title, description, category, posterId, posterEmail, status;
  final int price;
  final DateTime? deadline;
  final String? takenBy, takenByEmail;

  Gig({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.price,
    required this.posterId,
    required this.posterEmail,
    required this.status,
    this.deadline,
    this.takenBy,
    this.takenByEmail,
  });

  factory Gig.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data();
    return Gig(
      id: d.id,
      title: m['title'] ?? '',
      description: m['description'] ?? '',
      category: m['category'] ?? 'Other',
      price: (m['price'] ?? 0) as int,
      posterId: m['posterId'] ?? '',
      posterEmail: m['posterEmail'] ?? '',
      status: m['status'] ?? 'open',
      deadline: (m['deadline'] as Timestamp?)?.toDate(),
      takenBy: m['takenBy'],
      takenByEmail: m['takenByEmail'],
    );
  }

  String get deadlineLabel {
    if (deadline == null) return 'No deadline';
    final d = deadline!.difference(DateTime.now()).inDays;
    if (d < 0) return 'Expired';
    if (d == 0) return 'Due today';
    if (d == 1) return '1 day left';
    return '$d days left';
  }
}

String get _uid => FirebaseAuth.instance.currentUser!.uid;
final _gigs = FirebaseFirestore.instance.collection('gigs');

Future<void> claimGig(Gig g) async {
  final user = FirebaseAuth.instance.currentUser!;
  final ref = _gigs.doc(g.id);
  await FirebaseFirestore.instance.runTransaction((tx) async {
    final snap = await tx.get(ref);
    if (snap.data()?['status'] != 'open') {
      throw 'Someone just took this gig.';
    }
    tx.update(ref, {
      'status': 'taken',
      'takenBy': user.uid,
      'takenByEmail': user.email,
    });
  });
}

// ---------- Shell with bottom navigation ----------
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _gigs.orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
              body: Center(child: Text('Could not load gigs.\n${snap.error}')));
        }
        if (!snap.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final gigs = snap.data!.docs.map(Gig.fromDoc).toList();
        final pages = [
          BrowseTab(gigs: gigs),
          PostTab(onPosted: () => setState(() => _tab = 2)),
          MyGigsTab(gigs: gigs),
        ];
        return Scaffold(
          appBar: AppBar(
            title: const Text('Campus Gigs',
                style: TextStyle(fontWeight: FontWeight.w800)),
            actions: [
              IconButton(
                tooltip: 'Sign out',
                icon: const Icon(Icons.logout),
                onPressed: () => FirebaseAuth.instance.signOut(),
              ),
            ],
          ),
          body: pages[_tab],
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.explore_outlined), label: 'Browse'),
              NavigationDestination(icon: Icon(Icons.add_circle_outline), label: 'Post'),
              NavigationDestination(icon: Icon(Icons.work_outline), label: 'My Gigs'),
            ],
          ),
        );
      },
    );
  }
}

// ---------- Browse ----------
class BrowseTab extends StatefulWidget {
  final List<Gig> gigs;
  const BrowseTab({super.key, required this.gigs});
  @override
  State<BrowseTab> createState() => _BrowseTabState();
}

class _BrowseTabState extends State<BrowseTab> {
  String _category = 'All gigs';
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.toLowerCase();
    final list = widget.gigs.where((g) {
      if (g.status != 'open') return false;
      final catOk = _category == 'All gigs' || g.category == _category;
      final qOk = q.isEmpty ||
          g.title.toLowerCase().contains(q) ||
          g.description.toLowerCase().contains(q) ||
          g.category.toLowerCase().contains(q);
      return catOk && qOk;
    }).toList();
    final chips = ['All gigs', ...categories];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Find your next gig.',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        TextField(
          onChanged: (v) => setState(() => _query = v),
          decoration: InputDecoration(
            hintText: 'Search gigs and skills...',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: chips.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => ChoiceChip(
              label: Text(chips[i]),
              selected: _category == chips[i],
              onSelected: (_) => setState(() => _category = chips[i]),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
                child: Text('No open gigs right now.\nBe the first to post one!',
                    textAlign: TextAlign.center)),
          ),
        for (final g in list) GigCard(gig: g),
      ],
    );
  }
}

// ---------- Post a gig ----------
class PostTab extends StatefulWidget {
  final VoidCallback onPosted;
  const PostTab({super.key, required this.onPosted});
  @override
  State<PostTab> createState() => _PostTabState();
}

class _PostTabState extends State<PostTab> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _price = TextEditingController();
  String _category = categories.first;
  DateTime? _deadline;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 3)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _deadline = d);
  }

  Future<void> _post() async {
    if (!_formKey.currentState!.validate()) return;
    if (_deadline == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Pick a deadline.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final d = _deadline!;
      await _gigs.add({
        'title': _title.text.trim(),
        'description': _desc.text.trim(),
        'category': _category,
        'price': int.parse(_price.text.trim()),
        'deadline': Timestamp.fromDate(DateTime(d.year, d.month, d.day, 23, 59)),
        'posterId': user.uid,
        'posterEmail': user.email,
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
      });
      _title.clear();
      _desc.clear();
      _price.clear();
      setState(() => _deadline = null);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Gig posted!')));
        widget.onPosted();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not post: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Post a gig',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(
                  labelText: 'Title', border: OutlineInputBorder()),
              validator: (v) {
                final s = v?.trim() ?? '';
                if (s.length < 3) return 'At least 3 characters';
                if (s.length > 100) return 'Keep it under 100 characters';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _desc,
              maxLines: 4,
              decoration: const InputDecoration(
                  labelText: 'What needs to be done?',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder()),
              validator: (v) =>
                  (v == null || v.trim().length < 10) ? 'Add some detail (10+ characters)' : null,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(
                  labelText: 'Category', border: OutlineInputBorder()),
              items: [
                for (final c in categories) DropdownMenuItem(value: c, child: Text(c))
              ],
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _price,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Pay (KSh)', border: OutlineInputBorder()),
              validator: (v) {
                final n = int.tryParse(v?.trim() ?? '');
                if (n == null || n < 0) return 'Enter a valid amount';
                return null;
              },
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.event),
              label: Text(_deadline == null
                  ? 'Pick a deadline'
                  : 'Deadline: ${_deadline!.day}/${_deadline!.month}/${_deadline!.year}'),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _post,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Post gig'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- My gigs ----------
class MyGigsTab extends StatefulWidget {
  final List<Gig> gigs;
  const MyGigsTab({super.key, required this.gigs});
  @override
  State<MyGigsTab> createState() => _MyGigsTabState();
}

class _MyGigsTabState extends State<MyGigsTab> {
  bool _posted = true;

  @override
  Widget build(BuildContext context) {
    final mine = widget.gigs
        .where((g) => _posted ? g.posterId == _uid : g.takenBy == _uid)
        .toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Posted by me')),
            ButtonSegment(value: false, label: Text("I'm working on")),
          ],
          selected: {_posted},
          onSelectionChanged: (s) => setState(() => _posted = s.first),
        ),
        const SizedBox(height: 16),
        if (mine.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
                child: Text(_posted
                    ? "You haven't posted any gigs yet."
                    : "You haven't taken any gigs yet.\nHead to Browse and pick one.",
                    textAlign: TextAlign.center)),
          ),
        for (final g in mine) GigCard(gig: g),
      ],
    );
  }
}

// ---------- Card + detail sheet ----------
class GigCard extends StatelessWidget {
  final Gig gig;
  const GigCard({super.key, required this.gig});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mine = gig.posterId == _uid;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => GigSheet(gig: gig),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(gig.category.toUpperCase(),
                      style: TextStyle(
                          color: cs.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1)),
                  if (gig.status != 'open')
                    Chip(
                        label: Text(gig.status == 'done' ? 'Completed' : 'Taken'),
                        visualDensity: VisualDensity.compact)
                  else if (mine)
                    const Chip(
                        label: Text('Yours'), visualDensity: VisualDensity.compact),
                ],
              ),
              const SizedBox(height: 6),
              Text(gig.title,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('KSh ${gig.price}',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(gig.deadlineLabel,
                      style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GigSheet extends StatefulWidget {
  final Gig gig;
  const GigSheet({super.key, required this.gig});
  @override
  State<GigSheet> createState() => _GigSheetState();
}

class _GigSheetState extends State<GigSheet> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String okMsg) async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() => _busy = true);
    try {
      await action();
      nav.pop();
      messenger.showSnackBar(SnackBar(content: Text(okMsg)));
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.gig;
    final isPoster = g.posterId == _uid;
    final isTaker = g.takenBy == _uid;

    Widget action;
    if (g.status == 'open' && !isPoster) {
      action = FilledButton(
        onPressed: _busy ? null : () => _run(() => claimGig(g), 'Gig taken! Contact the poster to get started.'),
        child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Text('Take this gig')),
      );
    } else if (isPoster && g.status == 'taken') {
      action = FilledButton(
        onPressed: _busy
            ? null
            : () => _run(() => _gigs.doc(g.id).update({'status': 'done'}), 'Marked as completed.'),
        child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Text('Mark as completed')),
      );
    } else {
      action = const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(g.category.toUpperCase(),
                style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 1)),
            const SizedBox(height: 6),
            Text(g.title,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('KSh ${g.price}  •  ${g.deadlineLabel}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Text(g.description),
            const SizedBox(height: 16),
            Text('Posted by: ${g.posterEmail}',
                style: TextStyle(color: Colors.grey.shade600)),
            if (g.takenByEmail != null && (isPoster || isTaker))
              Text('Taken by: ${g.takenByEmail}',
                  style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 20),
            action,
            if (isPoster) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => _run(() => _gigs.doc(g.id).delete(), 'Gig deleted.'),
                child: const Text('Delete gig'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

