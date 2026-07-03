import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  
  const InitializationSettings initializationSettings = InitializationSettings(
    iOS: initializationSettingsIOS,
  );
  
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Timer? _trackingTimer;
  String _status = "Skanner etter parkeringssone...";
  bool _isParked = false;

  final double targetLatitude = 69.684218;
  final double targetLongitude = 18.973769;
  final double radiusInMeters = 100.0;

  @override
  void initState() {
    super.initState();
    _startLocationTracking();
  }

  void _startLocationTracking() async {
    // Sjekker om lokasjonstjenester er aktivert på telefonen
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _status = "Lokasjonstjenester er deaktivert.");
      return;
    }

    // Sjekker tillatelser
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _status = "Lokasjonstilgang ble avvist.");
        return;
      }
    }

    // Starter en kontinuerlig bakgrunnssjekk hvert 10. sekund
    _trackingTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      // Regner ut avstand i meter fra der du er til UiT/UNN i Tromsø
      double distanceInMeters = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        targetLatitude,
        targetLongitude,
      );

      if (distanceInMeters <= radiusInMeters && !_isParked) {
        // Du har kjørt INN på parkeringsplassen
        _isParked = true;
        _sendNotification(
          "Husk å betale parkering for svarte!!!!",
          "Du har ankommet parkeringsområdet i Tromsø.",
        );
        setState(() => _status = "Du er PARKERT");
      } else if (distanceInMeters > radiusInMeters && _isParked) {
        // Du har FORLATT parkeringsplassen
        _isParked = false;
        _sendNotification(
          "Beskjed om å skru av parkering",
          "Du har forlatt parkeringsområdet.",
        );
        setState(() => _status = "Du har FORLATT sonen");
      }
    });
  }

  Future<void> _sendNotification(String title, String body) async {
    const String customSoundFile = 'alarm.mp3';
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      presentBadge: true,
      sound: customSoundFile,
      interruptionLevel: InterruptionLevel.timeSensitive, 
    );
    
    const NotificationDetails platformDetails = NotificationDetails(iOS: iosDetails);
    
    await flutterLocalNotificationsPlugin.show(
      id: DateTime.now().millisecond,
      title: title,
      body: body,
      notificationDetails: platformDetails,
    );
  }

  @override
  void dispose() {
    _trackingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) { 
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Parkerings-varsler Tromsø')),
        body: Center(
          child: Text(
            _status,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
