import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:rayanpharma/auth/login.dart';
import 'package:rayanpharma/pages/first_page.dart';
import 'firebase_options.dart';
import 'package:rayanpharma/widgets/product_page.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: kIsWeb
        ? const FirebaseOptions(

          )
        : DefaultFirebaseOptions.currentPlatform,
  );

  // Request notification permissions


  // Get the FCM token (handle potential errors)



  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: FirebaseAuth.instance.authStateChanges().first,
      builder: (context, AsyncSnapshot<User?> snapshot) {
        // Show a loading screen while checking authentication
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        return MaterialApp(
          theme: ThemeData(
    useMaterial3: false, // Disable Material 3 to prevent overrides
          ),
          debugShowCheckedModeBanner: false,
          home: snapshot.hasData ? MainMenu() : Login(),
        );
          },
        );
      }
    
  }
