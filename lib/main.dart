import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AppSettings.instance.load();
  runApp(const MyApp());
}

class Receipt {
  final int? id;
  final String? firestoreId;
  final String title;
  final String date;
  final double amount;
  final String notes;

  Receipt({
    this.id,
    this.firestoreId,
    required this.title,
    required this.date,
    required this.amount,
    required this.notes,
  });

  Receipt copyWith({
    int? id,
    String? firestoreId,
    String? title,
    String? date,
    double? amount,
    String? notes,
  }) {
    return Receipt(
      id: id ?? this.id,
      firestoreId: firestoreId ?? this.firestoreId,
      title: title ?? this.title,
      date: date ?? this.date,
      amount: amount ?? this.amount,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'title': title,
      'date': date,
      'amount': amount,
      'notes': notes,
      'firestore_id': firestoreId,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory Receipt.fromMap(Map<String, dynamic> map) {
    final amountValue = map['amount'];
    return Receipt(
      id: map['id'] as int?,
      firestoreId: map['firestore_id'] as String?,
      title: map['title'] as String,
      date: map['date'] as String,
      amount: amountValue is int ? amountValue.toDouble() : amountValue as double,
      notes: map['notes'] as String,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'date': date,
      'amount': amount,
      'notes': notes,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory Receipt.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final amountValue = data['amount'];
    return Receipt(
      firestoreId: doc.id,
      title: data['title'] as String,
      date: data['date'] as String,
      amount: amountValue is int ? amountValue.toDouble() : amountValue as double,
      notes: data['notes'] as String,
    );
  }
}

class ReceiptDatabase {
  static final ReceiptDatabase instance = ReceiptDatabase._init();
  static Database? _database;

  ReceiptDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('receipts.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE receipts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        date TEXT NOT NULL,
        amount REAL NOT NULL,
        notes TEXT NOT NULL,
        firestore_id TEXT
      )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE receipts ADD COLUMN firestore_id TEXT');
    }
  }

  Future<Receipt> createReceipt(Receipt receipt) async {
    final db = await instance.database;
    final id = await db.insert('receipts', receipt.toMap());
    return receipt.copyWith(id: id);
  }

  Future<List<Receipt>> readAllReceipts() async {
    final db = await instance.database;
    final result = await db.query('receipts', orderBy: 'date DESC');
    return result.map((json) => Receipt.fromMap(json)).toList();
  }

  Future<void> deleteReceipt(int id) async {
    final db = await instance.database;
    await db.delete('receipts', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> upsertAll(List<Receipt> receipts) async {
    final db = await instance.database;
    await db.delete('receipts');
    for (final receipt in receipts) {
      await db.insert('receipts', receipt.toMap());
    }
  }

  Future<void> clearAll() async {
    final db = await instance.database;
    await db.delete('receipts');
  }

  Future<void> close() async {
    final db = await instance.database;
    await db.close();
    _database = null;
  }
}

class ReceiptRepository {
  static final instance = ReceiptRepository._();
  ReceiptRepository._();

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('receipts');

  Future<Receipt> save(String uid, Receipt receipt) async {
    final doc = await _col(uid).add(receipt.toFirestore());
    final saved = receipt.copyWith(firestoreId: doc.id);
    await ReceiptDatabase.instance.createReceipt(saved);
    return saved;
  }

  Future<List<Receipt>> syncFromFirestore(String uid) async {
    final snap = await _col(uid).orderBy('createdAt', descending: true).get();
    final receipts = snap.docs.map(Receipt.fromFirestore).toList();
    await ReceiptDatabase.instance.upsertAll(receipts);
    return receipts;
  }

  Future<void> delete(String uid, Receipt receipt) async {
    if (receipt.firestoreId != null) {
      await _col(uid).doc(receipt.firestoreId).delete();
    }
    if (receipt.id != null) {
      await ReceiptDatabase.instance.deleteReceipt(receipt.id!);
    }
  }

  Future<void> clearCache() => ReceiptDatabase.instance.clearAll();
}

class AppSettings {
  static final instance = AppSettings._();
  AppSettings._();

  static const _keyCurrency = 'currency_symbol';

  String _currencySymbol = r'$';
  String get currencySymbol => _currencySymbol;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _currencySymbol = prefs.getString(_keyCurrency) ?? r'$';
  }

  Future<void> setCurrencySymbol(String symbol) async {
    _currencySymbol = symbol;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCurrency, symbol);
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Paperless Login',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: Colors.transparent,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color.fromRGBO(49, 27, 146, 0.84),
          elevation: 0,
          foregroundColor: Colors.white,
        ),
      ),
      builder: (context, child) => Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF070B18),
                  Color(0xFF131A35),
                  Color(0xFF1E2A4A),
                ],
              ),
            ),
          ),
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0x338C6CFF),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0x2438B6FF),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          if (child != null) Positioned.fill(child: child),
        ],
      ),
      home: const AuthGate(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              PaperLoadingIcon(size: 120),
              SizedBox(height: 24),
              Text(
                'Loading Paperless...',
                style: TextStyle(color: Colors.white70, fontSize: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }
        return snapshot.hasData ? const HomeScreen() : const LoginScreen();
      },
    );
  }
}

class PaperLoadingIcon extends StatefulWidget {
  final double size;
  const PaperLoadingIcon({super.key, this.size = 100});

  @override
  State<PaperLoadingIcon> createState() => _PaperLoadingIconState();
}

class _PaperLoadingIconState extends State<PaperLoadingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final angle = _controller.value * 2 * 3.1415926535897932;
          final progress = Curves.easeInOut.transform(_controller.value);
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: widget.size,
                  height: widget.size * 0.72,
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(255, 255, 255, 0.96),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: const Color.fromRGBO(0, 0, 0, 0.2),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 14,
                  left: 14,
                  right: 14,
                  bottom: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        height: 6,
                        width: widget.size * 0.3,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: CustomPaint(
                          painter: _PaperScribblePainter(progress),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PaperScribblePainter extends CustomPainter {
  final double progress;
  _PaperScribblePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blueGrey.shade700
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(0, size.height * 0.18);
    path.cubicTo(
      size.width * 0.25,
      size.height * 0.23,
      size.width * 0.4,
      size.height * 0.14,
      size.width * 0.62,
      size.height * 0.25,
    );
    path.cubicTo(
      size.width * 0.78,
      size.height * 0.32,
      size.width * 0.85,
      size.height * 0.2,
      size.width,
      size.height * 0.22,
    );

    final metric = path.computeMetrics().first;
    final currentLength = metric.length * progress;
    final extract = metric.extractPath(0, currentLength);
    canvas.drawPath(extract, paint);

    final lowerPath = Path();
    lowerPath.moveTo(0, size.height * 0.45);
    lowerPath.cubicTo(
      size.width * 0.15,
      size.height * 0.55,
      size.width * 0.35,
      size.height * 0.35,
      size.width * 0.55,
      size.height * 0.5,
    );
    lowerPath.cubicTo(
      size.width * 0.7,
      size.height * 0.62,
      size.width * 0.88,
      size.height * 0.47,
      size.width,
      size.height * 0.52,
    );

    final lowerMetric = lowerPath.computeMetrics().first;
    final lowerCurrent = lowerMetric.length * (progress - 0.2).clamp(0.0, 1.0);
    if (lowerCurrent > 0) {
      canvas.drawPath(lowerMetric.extractPath(0, lowerCurrent), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PaperScribblePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class LoadingDialog extends StatelessWidget {
  final String message;
  const LoadingDialog({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color.fromRGBO(255, 255, 255, 0.08),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PaperLoadingIcon(size: 110),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

class ReceiptListScreen extends StatefulWidget {
  const ReceiptListScreen({super.key});

  @override
  State<ReceiptListScreen> createState() => _ReceiptListScreenState();
}

class _ReceiptListScreenState extends State<ReceiptListScreen> {
  bool _loading = true;
  bool _syncing = false;
  List<Receipt> _receipts = [];

  @override
  void initState() {
    super.initState();
    _loadReceipts();
  }

  Future<void> _loadReceipts() async {
    // Phase 1: show cached data instantly
    final cached = await ReceiptDatabase.instance.readAllReceipts();
    if (!mounted) return;
    setState(() {
      _receipts = cached;
      _loading = false;
      _syncing = true;
    });

    // Phase 2: sync from Firestore
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final synced = await ReceiptRepository.instance.syncFromFirestore(uid);
      if (!mounted) return;
      setState(() {
        _receipts = synced;
      });
    } catch (_) {
      // offline or error — keep cached data
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _openAddReceipt() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddReceiptScreen()),
    );
    if (added == true) _loadReceipts();
  }

  Future<void> _deleteReceipt(Receipt receipt) async {
    setState(() => _receipts.remove(receipt));
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await ReceiptRepository.instance.delete(uid, receipt);
    } catch (_) {
      // restore on failure
      if (mounted) setState(() => _receipts.add(receipt));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete receipt.')),
        );
      }
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Receipt deleted.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddReceipt,
        tooltip: 'Add receipt',
        child: const Icon(Icons.add),
      ),
      appBar: AppBar(
        title: const Text('Receipt History'),
        bottom: _syncing
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(),
              )
            : null,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _receipts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.receipt_long, size: 56, color: Colors.white54),
                          const SizedBox(height: 18),
                          const Text(
                            'No saved receipts yet.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white70, fontSize: 18),
                          ),
                          const SizedBox(height: 24),
                          OutlinedButton.icon(
                            onPressed: _openAddReceipt,
                            icon: const Icon(Icons.add),
                            label: const Text('Add receipt'),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: _receipts.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final receipt = _receipts[index];
                        final date = DateTime.tryParse(receipt.date);
                        final formattedDate = date != null
                            ? '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'
                            : receipt.date;
                        return Dismissible(
                          key: ValueKey(receipt.firestoreId ?? receipt.id ?? index),
                          direction: DismissDirection.endToStart,
                          onDismissed: (_) => _deleteReceipt(receipt),
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
                          ),
                          child: Card(
                            color: const Color.fromRGBO(255, 255, 255, 0.08),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              title: Text(receipt.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              subtitle: Text('$formattedDate · ${receipt.notes}', style: const TextStyle(color: Colors.white70)),
                              trailing: Text('${AppSettings.instance.currencySymbol}${receipt.amount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white)),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found for that email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      default:
        return e.message ?? 'Authentication failed.';
    }
  }

  Future<void> _signIn() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      // AuthGate stream fires → navigates automatically
    } on FirebaseAuthException catch (e) {
      _showError(_friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _loading = true);
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      // AuthGate stream fires → navigates automatically
    } on FirebaseAuthException catch (e) {
      _showError(_friendlyAuthError(e));
    } catch (_) {
      _showError('Google sign-in failed. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showError('Enter your email address first, then tap Forgot password.');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _showError('Password reset email sent to $email');
    } on FirebaseAuthException catch (e) {
      _showError(_friendlyAuthError(e));
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter your email address';
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Enter your password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                const Text(
                  'Welcome back',
                  style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in to continue to Paperless',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 32),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          hintText: 'you@example.com',
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: _validateEmail,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          hintText: 'Enter your password',
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        validator: _validatePassword,
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _loading ? null : _forgotPassword,
                          child: const Text('Forgot password?'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loading ? null : _signIn,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Sign in'),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'or',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: _loading ? null : _signInWithGoogle,
                  icon: const Icon(Icons.login),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text('Sign in with Google'),
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('New here?'),
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const SignUpScreen(),
                                ),
                              ),
                      child: const Text('Create account'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      // AuthGate stream fires → navigates automatically; pop sign-up screen
      if (mounted) Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      final message = switch (e.code) {
        'email-already-in-use' => 'An account already exists for that email.',
        'invalid-email' => 'Invalid email address.',
        'weak-password' => 'Password is too weak.',
        _ => e.message ?? 'Sign-up failed.',
      };
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'New account',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sign up to get started with Paperless',
                    style: TextStyle(fontSize: 15, color: Colors.white70),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'you@example.com',
                      prefixIcon: Icon(Icons.email),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Enter your email';
                      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())) {
                        return 'Enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Enter a password';
                      if (value.length < 6) return 'Password must be at least 6 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmController,
                    obscureText: _obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'Confirm password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureConfirm ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                    validator: (value) {
                      if (value != _passwordController.text) return 'Passwords do not match';
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _loading ? null : _signUp,
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Create account'),
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  void _openProfile(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  void _showScanOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E2A4A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Choose Scan Method',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ScanOptionButton(
                    icon: Icons.qr_code_scanner,
                    label: 'QR Code',
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _startQrScan(context);
                    },
                  ),
                  _ScanOptionButton(
                    icon: Icons.nfc,
                    label: 'NFC',
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _startNfcScan(context);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startQrScan(BuildContext context) async {
    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
    if (raw == null || !mounted) return;
    final receipt = _parseReceiptPayload(raw);
    if (receipt != null) {
      // ignore: use_build_context_synchronously
      await _showReceiptConfirmation(this.context, receipt);
    } else {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(this.context).showSnackBar(
        const SnackBar(content: Text('Could not read receipt data from QR code.')),
      );
    }
  }

  Future<void> _startNfcScan(BuildContext context) async {
    final availability = await NfcManager.instance.checkAvailability();
    if (!mounted) return;
    if (availability != NfcAvailability.available) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(this.context).showSnackBar(
        const SnackBar(content: Text('NFC is not available on this device.')),
      );
      return;
    }

    // ignore: use_build_context_synchronously
    showDialog(
      context: this.context,
      barrierDismissible: true,
      builder: (ctx) => PopScope(
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) NfcManager.instance.stopSession();
        },
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E2A4A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Text('NFC Scan', style: TextStyle(color: Colors.white)),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.nfc, size: 72, color: Colors.white70),
              SizedBox(height: 16),
              Text(
                'Hold your device near an NFC terminal...',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                NfcManager.instance.stopSession();
                Navigator.of(ctx).pop();
              },
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );

    NfcManager.instance.startSession(
      onDiscovered: (NfcTag tag) async {
        String? text;
        try {
          final ndef = Ndef.from(tag);
          if (ndef != null) {
            final msg = ndef.cachedMessage ?? await ndef.read();
            text = _extractNdefText(msg);
          }
        } catch (_) {}

        await NfcManager.instance.stopSession();
        if (!mounted) return;
        // ignore: use_build_context_synchronously
        Navigator.of(this.context).pop();

        if (text != null) {
          final receipt = _parseReceiptPayload(text);
          if (receipt != null && mounted) {
            // ignore: use_build_context_synchronously
            await _showReceiptConfirmation(this.context, receipt);
          } else if (mounted) {
            // ignore: use_build_context_synchronously
            ScaffoldMessenger.of(this.context).showSnackBar(
              const SnackBar(content: Text('Could not read receipt data from NFC tag.')),
            );
          }
        } else if (mounted) {
          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(this.context).showSnackBar(
            const SnackBar(content: Text('No readable data found on NFC tag.')),
          );
        }
      },
    );
  }

  String? _extractNdefText(NdefMessage message) {
    for (final record in message.records) {
      final payload = record.payload;
      if (payload.isEmpty) continue;
      try {
        final typeStr = String.fromCharCodes(record.type);
        if (typeStr == 'T') {
          final langLen = payload[0] & 0x3F;
          return utf8.decode(payload.sublist(1 + langLen));
        }
        if (typeStr == 'U') {
          return utf8.decode(payload.sublist(1));
        }
        return utf8.decode(payload);
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  Receipt? _parseReceiptPayload(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return Receipt(
        title: map['title'] as String? ?? 'Scanned Receipt',
        date: map['date'] as String? ?? DateTime.now().toIso8601String(),
        amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
        notes: map['notes'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _showReceiptConfirmation(BuildContext context, Receipt receipt) async {
    final date = DateTime.tryParse(receipt.date);
    final formattedDate = date != null
        ? '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'
        : receipt.date;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: const Color(0xFF1E2A4A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Save Receipt?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 20),
              _ReceiptDetailRow(label: 'Merchant', value: receipt.title),
              _ReceiptDetailRow(label: 'Amount', value: '${AppSettings.instance.currencySymbol}${receipt.amount.toStringAsFixed(2)}'),
              _ReceiptDetailRow(label: 'Date', value: formattedDate),
              if (receipt.notes.isNotEmpty) _ReceiptDetailRow(label: 'Notes', value: receipt.notes),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                child: const Text('Save to History'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Discard'),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true && mounted) {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await ReceiptRepository.instance.save(uid, receipt);
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(this.context).showSnackBar(
        const SnackBar(content: Text('Receipt saved to history.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Paperless'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () => _openProfile(context),
            tooltip: 'Profile',
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const DrawerHeader(
                decoration: BoxDecoration(color: Colors.deepPurple),
                child: Text(
                  'Menu',
                  style: TextStyle(color: Colors.white, fontSize: 24),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Settings'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.help_outline),
                title: const Text('Help'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HelpScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Sign out'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await ReceiptRepository.instance.clearCache();
                  await GoogleSignIn().signOut();
                  await FirebaseAuth.instance.signOut();
                  // AuthGate stream fires → LoginScreen
                },
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(),
              Column(
                children: [
                  const Text(
                    'Ready to scan documents?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () => _showScanOptions(context),
                    icon: const Icon(Icons.qr_code_scanner, size: 28),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                      child: Text('Scan', style: TextStyle(fontSize: 18)),
                    ),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      minimumSize: const Size(200, 62),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Center(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const ReceiptListScreen()),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(220, 56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('View Receipts', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _currencies = [r'$', '€', '£', '¥', '₹'];
  late String _selectedCurrency;

  @override
  void initState() {
    super.initState();
    _selectedCurrency = AppSettings.instance.currencySymbol;
  }

  Future<void> _onCurrencyChanged(String? symbol) async {
    if (symbol == null) return;
    await AppSettings.instance.setCurrencySymbol(symbol);
    setState(() => _selectedCurrency = symbol);
  }

  Future<void> _confirmClearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2A4A),
        title: const Text('Clear local cache?'),
        content: const Text(
          'Cached receipts will be removed from this device. '
          'Your data in the cloud is not affected.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ReceiptRepository.instance.clearCache();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Local cache cleared.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          children: [
            _SectionLabel('Display'),
            const SizedBox(height: 8),
            _SettingsCard(
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Currency symbol', style: TextStyle(color: Colors.white, fontSize: 15)),
                  ),
                  DropdownButton<String>(
                    value: _selectedCurrency,
                    dropdownColor: const Color(0xFF1E2A4A),
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    underline: const SizedBox(),
                    items: _currencies
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: _onCurrencyChanged,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            _SectionLabel('Data'),
            const SizedBox(height: 8),
            _SettingsCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Clear local cache', style: TextStyle(color: Colors.white)),
                subtitle: const Text(
                  'Removes cached receipts from this device only',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                trailing: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onTap: _confirmClearCache,
              ),
            ),
            const SizedBox(height: 28),
            _SectionLabel('About'),
            const SizedBox(height: 8),
            _SettingsCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Paperless', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('Version 1.0.0+1', style: TextStyle(color: Colors.white54, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w600),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final Widget child;
  const _SettingsCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: child,
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _nameController.text = user?.displayName ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _initials(User user) {
    final name = user.displayName?.trim();
    if (name != null && name.isNotEmpty) {
      final parts = name.split(RegExp(r'\s+'));
      if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      return name[0].toUpperCase();
    }
    final email = user.email ?? '';
    return email.isNotEmpty ? email[0].toUpperCase() : '?';
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    setState(() => _saving = true);
    try {
      await FirebaseAuth.instance.currentUser!.updateDisplayName(name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Display name updated.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update name: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null) return;
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset email sent to $email.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send reset email: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    final isPasswordProvider = user.providerData.any((p) => p.providerId == 'password');

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: Colors.deepPurple,
                  child: Text(
                    _initials(user),
                    style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Email',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Text(
                  user.email ?? '—',
                  style: const TextStyle(color: Colors.white70, fontSize: 15),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Display name',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Your name',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _saving ? null : _saveName,
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                child: _saving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save name'),
              ),
              if (isPasswordProvider) ...[
                const SizedBox(height: 32),
                const Divider(color: Colors.white12),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: _sendPasswordReset,
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  child: const Text('Send password reset email'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class AddReceiptScreen extends StatefulWidget {
  const AddReceiptScreen({super.key});

  @override
  State<AddReceiptScreen> createState() => _AddReceiptScreenState();
}

class _AddReceiptScreenState extends State<AddReceiptScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final receipt = Receipt(
        title: _titleController.text.trim(),
        date: _selectedDate.toIso8601String(),
        amount: double.parse(_amountController.text.trim()),
        notes: _notesController.text.trim(),
      );
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await ReceiptRepository.instance.save(uid, receipt);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save receipt: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Add Receipt')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _titleController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Merchant / Title',
                    prefixIcon: Icon(Icons.store_outlined),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Enter a merchant name' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixIcon: const Icon(Icons.attach_money),
                    prefixText: AppSettings.instance.currencySymbol,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Enter an amount';
                    final n = double.tryParse(v.trim());
                    if (n == null || n < 0) return 'Enter a valid amount';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    child: Text(
                      formattedDate,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    prefixIcon: Icon(Icons.notes_outlined),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  child: _saving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save Receipt'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const _faqs = [
    (
      q: 'How do I scan a receipt?',
      a: 'From the home screen tap Scan, then choose QR Code or NFC. '
          'Point your camera at a QR code or hold the device near an NFC tag. '
          'A confirmation sheet will appear — tap Save to History.',
    ),
    (
      q: 'How do I view my receipt history?',
      a: 'Tap View Receipts on the home screen. '
          'Cached receipts load instantly; the list then refreshes automatically from the cloud.',
    ),
    (
      q: 'How do I delete a receipt?',
      a: 'In Receipt History, swipe any receipt card to the left to reveal the delete action. '
          'The receipt is removed from both this device and the cloud.',
    ),
    (
      q: 'Are my receipts backed up?',
      a: 'Yes. Every receipt is saved to Firestore automatically when you scan it. '
          'Sign in on any device to access the same history.',
    ),
    (
      q: 'What happens when I sign out?',
      a: 'The local cache is cleared from this device. '
          'Your receipts remain safely stored in the cloud and reload the next time you sign in.',
    ),
    (
      q: 'How do I change my display name?',
      a: 'Tap the profile icon in the top-right corner of the home screen, '
          'edit the Display name field, then tap Save name.',
    ),
    (
      q: 'How do I change the currency symbol?',
      a: 'Open the drawer (swipe from the left or tap the menu icon), '
          'go to Settings, and choose a currency symbol under Display.',
    ),
    (
      q: 'How do I reset my password?',
      a: 'On the sign-in screen tap Forgot password? and enter your email. '
          'You can also trigger a reset from the Profile screen.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Help')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: const [
                  Icon(Icons.info_outline, color: Colors.white54, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tap a question to expand the answer.',
                      style: TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ..._faqs.map(
              (item) => _FaqTile(question: item.q, answer: item.a),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  final String question;
  final String answer;

  const _FaqTile({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            collapsedBackgroundColor: Colors.white.withValues(alpha: 0.06),
            backgroundColor: Colors.white.withValues(alpha: 0.09),
            collapsedShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Colors.white12),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Colors.white24),
            ),
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            title: Text(
              question,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            iconColor: Colors.white54,
            collapsedIconColor: Colors.white38,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  answer,
                  style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _detected = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_detected) return;
              final barcode = capture.barcodes.firstOrNull;
              if (barcode?.rawValue != null) {
                _detected = true;
                Navigator.of(context).pop(barcode!.rawValue);
              }
            },
          ),
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white54, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Text(
              'Align QR code within the frame',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanOptionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ScanOptionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: Colors.white),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class _ReceiptDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _ReceiptDetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 14)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
