import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:llmpath/views/home_screen.dart';
import 'package:provider/provider.dart';
import 'providers/location_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyBUGaPDSXrAtKFBpH1bOt7Y8sI7yVhVb_I",
      authDomain: "llmpath-28580.firebaseapp.com",
      projectId: "llmpath-28580",
      storageBucket: "llmpath-28580.firebasestorage.app",
      messagingSenderId: "878699620535",
      appId: "1:878699620535:web:4051d7c3eb3c10a6170532",
      measurementId: "G-9TNLBPF1CE",
    ),
  );

  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => LocationProvider())],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(debugShowCheckedModeBanner: false, home: HomeScreen());
  }
}
