import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'dart:io';

import 'package:campusconnect/AdminDashboard.dart';
import 'package:campusconnect/home_page.dart';
import 'package:campusconnect/login_page.dart';
import 'package:campusconnect/reset_password.dart';
import 'package:campusconnect/signup_page.dart';
import 'package:campusconnect/sqlLite/databasehelper.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
bool isTesting = false; // ✅ flag for test mode

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("📩 BG message: ${message.messageId}");
}

Future<void> main({bool testMode = false}) async {
  isTesting = testMode;
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  try {
    final String localTimeZone = await FlutterTimezone.getLocalTimezone();
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(localTimeZone));
    print("📍 Local timezone correctly set to: $localTimeZone");
  } catch (e) {
    print("⚠️ Failed to get local timezone. Defaulting to UTC.");
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('UTC'));
  }

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidSettings);
  await flutterLocalNotificationsPlugin.initialize(initSettings);

  if (!kIsWeb && Platform.isAndroid) {
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(alert: true, badge: true, sound: true);
    print("🔐 Notification permission: ${settings.authorizationStatus}");
  }

  await DatabaseHelper.instance.database;

  runApp(CampusConnectApp());
}

class CampusConnectApp extends StatefulWidget {
  @override
  _CampusConnectAppState createState() => _CampusConnectAppState();
}

class _CampusConnectAppState extends State<CampusConnectApp> {
  @override
  void initState() {
    super.initState();

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      final android = message.notification?.android;

      if (notification != null && android != null) {
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              'campusconnect_channel',
              'Campus Notifications',
              channelDescription: 'Notifications for campus events and classes',
              importance: Importance.max,
              priority: Priority.high,
              showWhen: true,
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final User? user = isTesting ? null : FirebaseAuth.instance.currentUser; // ✅ skip auth in test

    return MaterialApp(
      title: 'CampusConnect',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      debugShowCheckedModeBanner: false,
      home: user != null ? HomePage() : LoginPage(),
      routes: {
        '/login': (context) => LoginPage(),
        '/signup_page': (context) => SignupPage(),
        '/reset_password': (context) => ResetPasswordPage(),
        '/AdminDashboard': (context) => AdminDashboard(),
        '/home': (context) => HomePage(),
      },
    );
  }
}
