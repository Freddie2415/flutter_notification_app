import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:overlay_support/overlay_support.dart';

const String notifyBoxName = 'notify';

void main() async {
  await Hive.initFlutter();
  Hive.registerAdapter<Notification>(NotificationAdapter());
  await Hive.openBox<Notification>(notifyBoxName);
  runApp(const MyApp());
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Handling a background message: ${message.messageId}");
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return OverlaySupport(
      child: MaterialApp(
        title: 'Notify',
        theme: ThemeData(
          primarySwatch: Colors.deepPurple,
        ),
        debugShowCheckedModeBanner: false,
        home: const HomePage(),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late int _totalNotifications;
  late final FirebaseMessaging _messaging;
  Notification? _notificationInfo;
  List<Notification> notifications = [];
  late Box<Notification> notificationBox;

  @override
  void initState() {
    _totalNotifications = 0;
    checkForInitialMessage();

    registerNotification();

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      Notification notification = Notification(
        title: message.notification?.title,
        body: message.notification?.body,
      );
      print("Message received");
      setState(() {
        _notificationInfo = notification;
        notifications.add(notification);
        _totalNotifications++;
      });
    });

    notificationBox = Hive.box<Notification>(notifyBoxName);
    notifications = notificationBox.values.toList();
    _totalNotifications = notifications.length;

    super.initState();
  }

  void registerNotification() async {
    // 1. Initialize the Firebase app
    await Firebase.initializeApp();

    // 2. Instantiate Firebase Messaging
    _messaging = FirebaseMessaging.instance;

    _messaging.getToken().then((String? token) async {
      print("token: $token");
    });

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 3. On iOS, this helps to take the user permissions
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');

      // For handling the received notifications
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        // Parse the message received
        Notification notification = Notification(
          title: message.notification?.title,
          body: message.notification?.body,
        );

        setState(() {
          _notificationInfo = notification;
          notifications.add(notification);
          notificationBox.add(notification);
          _totalNotifications++;
        });

        if (_notificationInfo != null) {
          // For displaying the notification as an overlay
          showSimpleNotification(
            Text(_notificationInfo!.title!),
            leading: NotificationBadge(totalNotifications: _totalNotifications),
            subtitle: Text(_notificationInfo!.body!),
            background: Colors.cyan.shade700,
            duration: const Duration(seconds: 2),
          );
        }
      });
    } else {
      print('User declined or has not accepted permission');
    }
  }

  // For handling notification when the app is in terminated state
  void checkForInitialMessage() async {
    await Firebase.initializeApp();
    RemoteMessage? initialMessage =
    await FirebaseMessaging.instance.getInitialMessage();

    if (initialMessage != null) {
      Notification notification = Notification(
        title: initialMessage.notification?.title,
        body: initialMessage.notification?.body,
      );
      setState(() {
        _notificationInfo = notification;
        notifications.add(notification);
        _totalNotifications++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notify'),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: ListView(
        children: notifications
            .map(
              (e) =>
              ListTile(
                title: Text(e.title ?? "Title"),
                subtitle: Text(e.body ?? "Subtitle"),
              ),
        )
            .toList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: addItem,
        child: Text(_totalNotifications.toString()),
      ),
    );
  }

  Widget getBody() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'App for capturing Firebase Push Notifications',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 16.0),
        NotificationBadge(totalNotifications: _totalNotifications),
        const SizedBox(height: 16.0),
        _notificationInfo != null
            ? Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TITLE: ${_notificationInfo!.title}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16.0,
              ),
            ),
            const SizedBox(height: 8.0),
            Text(
              'BODY: ${_notificationInfo!.body}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16.0,
              ),
            ),
          ],
        )
            : Container(),
      ],
    );
  }

  void addItem() async {}
}

class NotificationBadge extends StatelessWidget {
  final int totalNotifications;

  const NotificationBadge({
    super.key,
    required this.totalNotifications,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40.0,
      height: 40.0,
      decoration: const BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            '$totalNotifications',
            style: const TextStyle(color: Colors.white, fontSize: 20),
          ),
        ),
      ),
    );
  }
}

class Notification {
  Notification({
    this.title,
    this.body,
  });

  String? title;
  String? body;

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
    };
  }
}

class NotificationAdapter extends TypeAdapter<Notification> {
  @override
  Notification read(BinaryReader reader) {
    final obj = reader.readMap();
    return Notification(
      title: obj['title'] ?? '-',
      body: obj['body'] ?? '-',
    );
  }

  @override
  int get typeId => 1;

  @override
  void write(BinaryWriter writer, Notification obj) {
    writer.writeMap(obj.toMap());
  }
}
