  import 'package:flutter/material.dart';
  import 'package:flutter/services.dart';
  import 'package:firebase_core/firebase_core.dart';
  import 'screens/calculator_screen.dart';
  import 'firebase_options.dart';
  void main() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Lock to portrait — phones only
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    String? firebaseInitError;
    try {
      await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
    } catch (e) {
      firebaseInitError = e.toString();
    }

    runApp(SentinelApp(firebaseInitError: firebaseInitError));
  }

  class SentinelApp extends StatelessWidget {
    const SentinelApp({super.key, this.firebaseInitError});

    final String? firebaseInitError;

    @override
    Widget build(BuildContext context) {
      return MaterialApp(
        // Disguise: shows as "Calculator" in the app switcher
        title: 'Calculator',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.tealAccent,
            brightness: Brightness.dark,
          ),
          // Calculator uses pure black; other screens use #0D1117
          scaffoldBackgroundColor: Colors.black,
          useMaterial3: true,
        ),
        home: firebaseInitError == null
            ? const CalculatorScreen()
            : FirebaseSetupScreen(error: firebaseInitError!),
      );
    }
  }

  class FirebaseSetupScreen extends StatelessWidget {
    const FirebaseSetupScreen({super.key, required this.error});

    final String error;

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D1117),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF30363D)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.settings_applications_outlined,
                            color: Colors.orangeAccent),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Firebase Setup Required',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'The app could not initialize Firebase for project sentinel102932.',
                      style: TextStyle(
                        color: Colors.grey.shade300,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Add the missing Firebase app config files, then relaunch:',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• android/app/google-services.json\n'
                      '• ios/Runner/GoogleService-Info.plist\n'
                      '• lib/firebase_options.dart',
                      style: TextStyle(
                        color: Colors.grey.shade200,
                        fontSize: 13,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      error,
                      style: TextStyle(
                        color: Colors.red.shade200,
                        fontSize: 12,
                        fontFamily: 'monospace',
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
