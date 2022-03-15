import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:liberaqua/posicao.dart';
import 'package:uuid/uuid.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: FirebaseOptions(
        apiKey: "AIzaSyCVE4qf8oNqj2NEqf3ZaSxsKRvfSf_u82Y",
        appId: "1:689767465655:web:1dac8c1325115ccc3bc332",
        messagingSenderId: "689767465655",
        projectId: "liberaqua-84cc0",
        storageBucket: "liberaqua-84cc0.appspot.com"
    ),
    name: "LiberAqua"
  );
  //final CollectionReference _contatos = FirebaseFirestore.instance.collection('contatos');
  //_contatos.add({"nome": "Maria", "idade": "50"});
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<Marker> allMarkers = [];

  late GoogleMapController _controller;
  final GeolocatorPlatform _geolocatorPlatform = GeolocatorPlatform.instance;
  late Position position;
  final _textController = TextEditingController();
  final GoogleSignIn googleSignIn = GoogleSignIn();
  User? _currentUser;
  FirebaseAuth auth = FirebaseAuth.instance;
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    Geolocator.getCurrentPosition().then((location) => {
          setState(() {
            position:location;
          })
        });
    FirebaseAuth.instance.authStateChanges().listen((user) {
      setState(() {
        _currentUser = user;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentUser != null
            ? 'Eai ${_currentUser?.displayName}'
            : "LiberAqua"),
        elevation: 0,
        actions: <Widget>[
          _currentUser != null
          ? IconButton(onPressed: (){
            FirebaseAuth.instance.signOut();
            googleSignIn.signOut();
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Logout")));
          }, icon: Icon(Icons.exit_to_app))
              :Container()
        ],
      ),
      body: Stack(children: [
        Container(
          height: MediaQuery.of(context).size.height,
          width: MediaQuery.of(context).size.width,
          child: GoogleMap(
            initialCameraPosition: CameraPosition(
                target: LatLng(0,0),
                zoom: 12.0),
            markers: Set.from(allMarkers),
            onMapCreated: iniciaMapa,
          ),
        ),
      ]),
      floatingActionButton: new FloatingActionButton(
        onPressed: () => modal(context),
        child: new Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  iniciaMapa(GoogleMapController controller) async {
    _controller = controller;
    FirebaseFirestore.instance.collection('posicoes').get().then((value) {
      if(value.docs.isNotEmpty){
        for( int i = 0; i < value.docs.length; ++i){
          Posicao posicao = new Posicao(value.docs[i]["nome"], value.docs[i]["latitude"], value.docs[i]["longitude"]);
          addMarker(posicao);
        }
      }
    });
    if(!await _handlePermission()) return;
    position = await Geolocator.getCurrentPosition();
    _controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
          target: LatLng(position.latitude, position.longitude), zoom: 15.0),
    ));
  }

  addPonto() async {
    User? user = await _getUser(context: context);
    if(user == null) {
      const snackBar = SnackBar(content: Text("Login invalido"),
      backgroundColor: Colors.red,);
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    }

    if(!await _handlePermission()) return;
    position = await Geolocator.getCurrentPosition();
    Posicao posicao = new Posicao(_textController.text, position.latitude, position.longitude);
    final CollectionReference _posicoes = FirebaseFirestore.instance.collection('posicoes');
    _posicoes.add({"nome": posicao.nome, "latitude": posicao.latitude, "longitude": posicao.longitude});
    addMarker(posicao);
    _controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
          target: LatLng(position.latitude, position.longitude), zoom: 15.0),
    ));
  }

  addMarker(Posicao posicao){
    allMarkers.add(Marker(
        markerId: MarkerId(Uuid().v1()),
        draggable: false,
        infoWindow: InfoWindow(title: posicao.nome),
        position: LatLng(posicao.latitude, posicao.longitude)));
    setState(() {
      allMarkers = allMarkers;
    });
  }

  modal(BuildContext context) {
    showModalBottomSheet(
        context: context,
        builder: (BuildContext context) {
          return Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
            TextField(
              controller: _textController,
              decoration:
                  InputDecoration.collapsed(hintText: "Adicione um nome"),
            ),
            ElevatedButton(
              child: const Text('Close BottomSheet'),
              onPressed: () async {
                Navigator.pop(context);
                addPonto();
              },
            )
          ]);
        });
  }

  Future<bool> _handlePermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await _geolocatorPlatform.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    permission = await _geolocatorPlatform.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await _geolocatorPlatform.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  Future<User?> _getUser({required BuildContext context}) async {
    User? user;
    if(_currentUser != null) return _currentUser;
    final GoogleSignInAccount? googleSignInAccount = await googleSignIn.signIn();

    if(googleSignInAccount != null){
      final GoogleSignInAuthentication googleSignInAuthentication = await googleSignInAccount.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleSignInAuthentication.accessToken,
        idToken: googleSignInAuthentication.idToken,
      );
      try {
        final UserCredential userCredential = await auth.signInWithCredential(credential);
        user = userCredential.user;
      } on FirebaseAuthException catch (e) {
        print(e);
      }catch(e) {
        print(e);
      }
    }
    return user;
  }
}
