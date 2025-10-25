// REMO YUK — Full App (main.dart)
// Includes: Provider state management, Firebase Auth & Firestore integration, UI polish, form validation,
// payment simulation, WhatsApp deeplink (url_launcher).
//
// Setup:
// 1) Add in pubspec.yaml dependencies:
//    provider, firebase_core, firebase_auth, cloud_firestore, url_launcher, intl
// 2) Add Firebase config files (google-services.json / GoogleService-Info.plist)
// 3) Put image assets under assets/ and list them in pubspec.yaml
// 4) Run: flutter pub get
// 5) Run the app

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// -------------------- Models --------------------
class CarModel {
  final String id;
  final String name;
  final int pricePerDay;
  final String asset;
  CarModel({required this.id, required this.name, required this.pricePerDay, required this.asset});
}

class Booking {
  final String id;
  final String userId;
  final CarModel car;
  final DateTime start;
  final DateTime end;
  final bool isMatic;
  final bool withDriver;
  final int total;
  final String status;

  Booking({required this.id, required this.userId, required this.car, required this.start, required this.end, required this.isMatic, required this.withDriver, required this.total, this.status = 'pending'});

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'carId': car.id,
        'carName': car.name,
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'isMatic': isMatic,
        'withDriver': withDriver,
        'total': total,
        'status': status,
        'createdAt': DateTime.now().toIso8601String(),
      };
}

// -------------------- Services --------------------
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<UserCredential> signUp(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> signIn(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}

class BookingService {
  final CollectionReference _col = FirebaseFirestore.instance.collection('bookings');

  Future<void> saveBooking(Booking b) async {
    await _col.add(b.toMap());
  }

  Stream<QuerySnapshot> getUserBookings(String userId) {
    return _col.where('userId', isEqualTo: userId).orderBy('createdAt', descending: true).snapshots();
  }
}

// -------------------- Provider --------------------
class BookingProvider with ChangeNotifier {
  final List<Booking> _bookings = [];
  List<Booking> get bookings => _bookings;

  void add(Booking b) {
    _bookings.insert(0, b);
    notifyListeners();
  }

  void clear() {
    _bookings.clear();
    notifyListeners();
  }
}

// -------------------- Main --------------------
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MultiProvider(providers: [ChangeNotifierProvider(create: (_) => BookingProvider())], child: MyApp()));
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Remo Yuk',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.yellow as MaterialColor?,
        scaffoldBackgroundColor: Colors.white,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Poppins',
      ),
      home: AuthGate(),
    );
  }
}

// Auth gate: if logged in -> Home, else -> Splash -> Login
class AuthGate extends StatelessWidget {
  final AuthService _auth = AuthService();
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.active) {
          if (snap.data != null) return HomePage();
          return SplashScreen();
        }
        return Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}

// -------------------- Pages --------------------
// --- Splash ---
class SplashScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(child: Center(child: Image.asset('assets/car.png', fit: BoxFit.contain))),
            SizedBox(height: 12),
            Text('REMO YUK', style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
            SizedBox(height: 6),
            Text('Sewa Mobil, Mudah dan Aman', style: TextStyle(color: Colors.white70)),
            SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow, foregroundColor: Colors.black, padding: EdgeInsets.symmetric(horizontal: 36, vertical: 14), shape: StadiumBorder()),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LoginPage())),
              child: Text('Get Started   >>>'),
            ),
            SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

// --- Login ---
class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _loading = false;
  final AuthService _auth = AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(alignment: Alignment.topLeft, child: Text('Log In', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold))),
                  SizedBox(height: 12),
                  TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(prefixIcon: Icon(Icons.email), hintText: 'Email'), validator: (v) => v==null||v.isEmpty? 'Email required' : null),
                  SizedBox(height: 8),
                  TextFormField(controller: _password, obscureText: true, decoration: InputDecoration(prefixIcon: Icon(Icons.lock), hintText: 'Password'), validator: (v) => v==null||v.isEmpty? 'Password required' : null),
                  SizedBox(height: 12),
                  Row(children: [Checkbox(value: true, onChanged: (_) {}), Text('Remember me')]),
                  SizedBox(height: 8),
                  _loading ? CircularProgressIndicator() : ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow, foregroundColor: Colors.black, minimumSize: Size(double.infinity, 48), shape: StadiumBorder()),
                    onPressed: () async {
                      if (!_formKey.currentState!.validate()) return;
                      setState(()=>_loading=true);
                      try {
                        await _auth.signIn(_email.text.trim(), _password.text);
                        // on success, stream will redirect via AuthGate
                      } on FirebaseAuthException catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Auth error')));
                      } finally {
                        setState(()=>_loading=false);
                      }
                    },
                    child: Text('Log In'),
                  ),
                  SizedBox(height: 12),
                  TextButton(onPressed: ()=>Navigator.push(context, MaterialPageRoute(builder: (_)=>SignUpPage())), child: Text("Don't have an account? Sign Up")),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- SignUp ---
class SignUpPage extends StatefulWidget {
  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _password2 = TextEditingController();
  final AuthService _auth = AuthService();
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Container(
            padding: EdgeInsets.all(18),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(alignment: Alignment.topLeft, child: Text('Sign Up', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold))),
                  SizedBox(height: 12),
                  TextFormField(controller: _email, decoration: InputDecoration(hintText: 'Email'), validator: (v)=>v==null||v.isEmpty?'Required':null),
                  SizedBox(height: 8),
                  TextFormField(controller: _password, obscureText: true, decoration: InputDecoration(hintText: 'Password'), validator: (v)=>v==null||v.length<6?'Min 6 chars':null),
                  SizedBox(height: 8),
                  TextFormField(controller: _password2, obscureText: true, decoration: InputDecoration(hintText: 'Confirm Password'), validator: (v)=>v!=_password.text?'Passwords do not match':null),
                  SizedBox(height: 12),
                  _loading? CircularProgressIndicator(): ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow, foregroundColor: Colors.black, minimumSize: Size(double.infinity, 46), shape: StadiumBorder()),
                    onPressed: () async {
                      if (!_formKey.currentState!.validate()) return;
                      setState(()=>_loading=true);
                      try {
                        await _auth.signUp(_email.text.trim(), _password.text);
                        Navigator.pop(context);
                      } on FirebaseAuthException catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Auth error')));
                      } finally { setState(()=>_loading=false); }
                    },
                    child: Text('Sign Up'),
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

// --- Home ---
class HomePage extends StatelessWidget {
  final List<CarModel> cars = [
    CarModel(id: 'brio', name: 'Honda Brio', pricePerDay: 250000, asset: 'assets/brio.png'),
    CarModel(id: 'innova', name: 'Toyota Innova', pricePerDay: 300000, asset: 'assets/innova.png'),
    CarModel(id: 'avanza', name: 'Toyota Avanza', pricePerDay: 200000, asset: 'assets/avanza.png'),
    CarModel(id: 'fortuner', name: 'Toyota Fortuner', pricePerDay: 750000, asset: 'assets/fortuner.png'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, title: Text('Home', style: TextStyle(color: Colors.black)), actions: [IconButton(onPressed: ()=>Navigator.push(context, MaterialPageRoute(builder: (_)=>HelpCenterPage())), icon: Icon(Icons.help_outline, color: Colors.black))]),
      body: Padding(
        padding: EdgeInsets.all(12),
        child: GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.84, crossAxisSpacing: 12, mainAxisSpacing: 12),
          itemCount: cars.length,
          itemBuilder: (_, i) => CarCard(car: cars[i]),
        ),
      ),
      bottomNavigationBar: BottomNavBar(),
    );
  }
}

class CarCard extends StatelessWidget {
  final CarModel car;
  CarCard({required this.car});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: ()=>Navigator.push(context, MaterialPageRoute(builder: (_)=>DetailPage(car: car))),
      child: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Center(child: Image.asset(car.asset, fit: BoxFit.contain))),
          SizedBox(height: 8),
          Text(car.name, style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Text('Rp.${car.pricePerDay.toString()},-/hari', style: TextStyle(color: Colors.grey[700])),
          SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [Icon(Icons.favorite_border)])
        ]),
      ),
    );
  }
}

// --- Detail & Booking ---
class DetailPage extends StatefulWidget {
  final CarModel car;
  DetailPage({required this.car});
  @override
  _DetailPageState createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  DateTime? _start;
  DateTime? _end;
  bool _isMatic = false;
  bool _withDriver = true;

  int getDays() {
    if (_start == null || _end == null) return 0;
    final days = _end!.difference(_start!).inDays;
    return days <= 0 ? 1 : days;
  }

  int calcTotal() {
    int days = getDays();
    int base = widget.car.pricePerDay * (days==0?1:days);
    if (_withDriver) base += 50000 * (days==0?1:days);
    if (_isMatic) base += 20000;
    return base;
  }

  Future pickDate(BuildContext ctx, bool isStart) async {
    final now = DateTime.now();
    final initial = isStart ? (_start ?? now) : (_end ?? now.add(Duration(days: 1)));
    final first = isStart ? now : (_start ?? now);
    final dt = await showDatePicker(context: ctx, initialDate: initial, firstDate: first, lastDate: now.add(Duration(days: 365)));
    if (dt != null) setState(() => isStart ? _start = dt : _end = dt);
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd/MM/yyyy');
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, title: Text('Detail', style: TextStyle(color: Colors.black))),
      bottomNavigationBar: BottomNavBar(),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Image.asset(widget.car.asset, height: 180)),
          SizedBox(height: 12),
          Text(widget.car.name, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          SizedBox(height: 6),
          Text('Rp.${widget.car.pricePerDay.toString()},-/hari', style: TextStyle(color: Colors.grey[700])),
          SizedBox(height: 12),
          Text('Transmisi'),
          Row(children: [ChoiceChip(label: Text('Matic'), selected: _isMatic, onSelected: (v){setState(()=>_isMatic=true);}), SizedBox(width: 8), ChoiceChip(label: Text('Manual'), selected: !_isMatic, onSelected: (v){setState(()=>_isMatic=false);})]),
          SizedBox(height: 12),
          Text('Pilihan Sewa'),
          Row(children: [ChoiceChip(label: Text('Driver'), selected: _withDriver, onSelected: (v){setState(()=>_withDriver=true);}), SizedBox(width: 8), ChoiceChip(label: Text('Lepas Kunci'), selected: !_withDriver, onSelected: (v){setState(()=>_withDriver=false);})]),
          SizedBox(height: 12),
          Row(children: [Expanded(child: ElevatedButton(onPressed: ()=>pickDate(context, true), child: Text(_start==null?'Pilih Start Tanggal':'Start: ${df.format(_start!)}'))), SizedBox(width: 8), Expanded(child: ElevatedButton(onPressed: ()=>pickDate(context, false), child: Text(_end==null?'Pilih End Tanggal':'End: ${df.format(_end!)}')))]),
          SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Durasi'), Text('${getDays()} Hari')]),
          SizedBox(height: 12),
          Container(padding: EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Rincian Harga', style: TextStyle(fontWeight: FontWeight.bold)), SizedBox(height: 8), Text('Harga dasar: Rp.${widget.car.pricePerDay} x ${getDays()==0?1:getDays()} = Rp.${widget.car.pricePerDay * (getDays()==0?1:getDays())}'), if (_withDriver) Text('Biaya driver: Rp.50.000 x ${getDays()==0?1:getDays()} = Rp.${50000 * (getDays()==0?1:getDays())}'), if (_isMatic) Text('Biaya transmisi (Matic): Rp.20.000 (flat)'), Divider(), Text('Total: Rp.${calcTotal()}', style: TextStyle(fontWeight: FontWeight.bold))])),
          SizedBox(height: 12),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow, foregroundColor: Colors.black, minimumSize: Size(double.infinity, 46), shape: StadiumBorder()), onPressed: () async {
            if (_start==null || _end==null) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pilih tanggal terlebih dahulu'))); return; }
            final user = FirebaseAuth.instance.currentUser;
            if (user==null) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Silakan login terlebih dahulu'))); return; }
            final booking = Booking(id: '', userId: user.uid, car: widget.car, start: _start!, end: _end!, isMatic: _isMatic, withDriver: _withDriver, total: calcTotal());
            Navigator.push(context, MaterialPageRoute(builder: (_)=>PaymentPage(booking: booking)));
          }, child: Text('Konfirmasi'))
        ]),
      ),
    );
  }
}

// --- Payment ---
class PaymentPage extends StatefulWidget {
  final Booking booking;
  PaymentPage({required this.booking});
  @override
  _PaymentPageState createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  bool _processing = false;
  final BookingService _bs = BookingService();

  Future<void> _confirmPayment() async {
    setState(()=>_processing=true);
    try {
      // Simulate payment
      await Future.delayed(Duration(seconds: 2));
      // Save booking to Firestore
      await _bs.saveBooking(widget.booking);
      // Add to local provider
      Provider.of<BookingProvider>(context, listen:false).add(widget.booking);
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_)=>SuccessPage(total: widget.booking.total)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment/save failed')));
    } finally {
      setState(()=>_processing=false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM yyyy');
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, title: Text('Payment', style: TextStyle(color: Colors.black))),
      bottomNavigationBar: BottomNavBar(),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Image.asset(widget.booking.car.asset, height: 160)),
          SizedBox(height: 8),
          Text(widget.booking.car.name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('Periode: ${df.format(widget.booking.start)} - ${df.format(widget.booking.end)}'),
          SizedBox(height: 8),
          Text('Total Pembayaran: Rp.${widget.booking.total}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Spacer(),
          _processing? Center(child: CircularProgressIndicator()) : ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow, foregroundColor: Colors.black, minimumSize: Size(double.infinity, 48), shape: StadiumBorder()), onPressed: _confirmPayment, child: Text('Konfirmasi Pembayaran'))
        ]),
      ),
    );
  }
}

// --- Success ---
class SuccessPage extends StatelessWidget {
  final int total;
  SuccessPage({required this.total});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(padding: EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(16)), child: Icon(Icons.check_circle_outline, size: 96, color: Colors.green)),
        SizedBox(height: 16),
        Text('Pembayaran telah berhasil!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Text('Total: Rp.$total'),
        SizedBox(height: 20),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow, foregroundColor: Colors.black), onPressed: ()=>Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_)=>HomePage()), (r)=>false), child: Text('Kembali ke Beranda'))
      ])),
    );
  }
}

// --- Help Center ---
class HelpCenterPage extends StatelessWidget {
  final String wa = '087765672011';
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, title: Text('Help Center', style: TextStyle(color: Colors.black))),
      bottomNavigationBar: BottomNavBar(),
      body: Padding(padding: EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Chat via WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)), SizedBox(height: 8),
        ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, minimumSize: Size(double.infinity, 48), side: BorderSide(color: Colors.grey.shade300), shape: StadiumBorder()), icon: Icon(Icons.whatsapp), label: Text(wa), onPressed: () async { final uri = Uri.parse('https://wa.me/$wa'); if (await canLaunchUrl(uri)) await launchUrl(uri); }),
        SizedBox(height: 16),
        Text('Kunjungi media sosial kami', style: TextStyle(fontWeight: FontWeight.bold)), SizedBox(height: 8),
        ElevatedButton(onPressed: (){}, child: Text('Facebook: Remo.Yuks')),
        ElevatedButton(onPressed: (){}, child: Text('Instagram: Remo.Yuks')),
      ])),
    );
  }
}

// --- Bottom Nav ---
class BottomNavBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BottomAppBar(child: Container(height: 64, padding: EdgeInsets.symmetric(horizontal: 12), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [IconButton(onPressed: ()=>Navigator.pushReplacement(context, MaterialPageRoute(builder: (_)=>HomePage())), icon: Icon(Icons.home)), IconButton(onPressed: ()=>Navigator.push(context, MaterialPageRoute(builder: (_)=>BookingListPage())), icon: Icon(Icons.receipt_long)), IconButton(onPressed: ()=>Navigator.push(context, MaterialPageRoute(builder: (_)=>HelpCenterPage())), icon: Icon(Icons.help))])));
  }
}

// --- Booking List (user bookings from provider & firestore) ---
class BookingListPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Scaffold(body: Center(child: Text('Please login')));
    final bs = BookingService();
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, title: Text('My Bookings', style: TextStyle(color: Colors.black))),
      body: StreamBuilder<QuerySnapshot>(stream: bs.getUserBookings(user.uid), builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator());
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return Center(child: Text('Belum ada booking'));
        return ListView.builder(itemCount: docs.length, itemBuilder: (_, i) {
          final d = docs[i].data() as Map<String, dynamic>;
          return ListTile(title: Text(d['carName'] ?? '-'), subtitle: Text('Rp.${d['total']} - ${d['status']}'));
        });
      }),
    );
  }
}
