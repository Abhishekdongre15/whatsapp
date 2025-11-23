import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  runApp(const WhatsappSchedulerApp());
}

class WhatsappSchedulerApp extends StatefulWidget {
  const WhatsappSchedulerApp({super.key});

  @override
  State<WhatsappSchedulerApp> createState() => _WhatsappSchedulerAppState();
}

class _WhatsappSchedulerAppState extends State<WhatsappSchedulerApp>
    with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _groupInviteController = TextEditingController();
  DateTime? _scheduledTime;
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _notificationReady = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _configureNotifications();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _groupInviteController.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _attemptSend();
    }
  }

  Future<void> _configureNotifications() async {
    const initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initializationSettings = InitializationSettings(
      iOS: initializationSettingsIOS,
      macOS: null,
      android: null,
    );
    await _notifications.initialize(initializationSettings);

    final granted = await _notifications
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
        false;

    setState(() {
      _notificationReady = granted;
    });
  }

  Future<void> _scheduleReminder(DateTime when) async {
    _scheduledTime = when;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _attemptSend());

    if (_notificationReady) {
      await _notifications.zonedSchedule(
        0,
        'WhatsApp reminder',
        'App will open WhatsApp to post your message.',
        tz.TZDateTime.from(when, tz.local),
        const NotificationDetails(
          iOS: DarwinNotificationDetails(),
        ),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidAllowWhileIdle: true,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  Future<void> _attemptSend() async {
    final scheduled = _scheduledTime;
    if (scheduled == null) return;

    final now = DateTime.now();
    if (!now.isAfter(scheduled)) return;

    if (_groupInviteController.text.isEmpty ||
        _messageController.text.isEmpty) {
      return;
    }

    final uri = Uri.parse(_groupInviteController.text);

    if (!await canLaunchUrl(uri)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid group invite link or WhatsApp not installed.'),
        ),
      );
      return;
    }

    final encodedMessage = Uri.encodeComponent(_messageController.text);
    final launchUri = Uri.parse('${uri.toString()}&text=$encodedMessage');

    try {
      await launchUrl(launchUri, mode: LaunchMode.externalApplication);
      _scheduledTime = null;
      _pollTimer?.cancel();
    } on PlatformException catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open WhatsApp: ${err.message}')),
      );
    }
  }

  Future<void> _pickTime(BuildContext context) async {
    final timeOfDay = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (timeOfDay == null) return;

    final now = DateTime.now();
    var scheduled = DateTime(
      now.year,
      now.month,
      now.day,
      timeOfDay.hour,
      timeOfDay.minute,
    );

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _scheduleReminder(scheduled);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Scheduled for ${scheduled.toLocal()} — keep the device unlocked near that time.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WhatsApp Scheduler',
      home: Scaffold(
        appBar: AppBar(
          title: const Text('WhatsApp Scheduler'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter a WhatsApp group invite link and your message. '
                'The app will open WhatsApp with the message when the device is unlocked after the scheduled time.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _groupInviteController,
                decoration: const InputDecoration(
                  labelText: 'Group invite link (https://chat.whatsapp.com/...)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  labelText: 'Message to send',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () => _pickTime(context),
                    child: const Text('Schedule time'),
                  ),
                  const SizedBox(width: 12),
                  if (_scheduledTime != null)
                    Text('Scheduled: ${_scheduledTime!.toLocal()}'),
                ],
              ),
              const SizedBox(height: 12),
              if (!_notificationReady)
                const Text(
                  'Notification permission is required to show reminders. You can enable it in Settings.',
                  style: TextStyle(color: Colors.red),
                ),
              const Divider(height: 24),
              const Text(
                'Notes for iOS:\n'
                '- The app cannot silently send messages; it opens WhatsApp with your text and you must tap send.\n'
                '- Keep the app installed and grant notification permissions so the reminder can fire.\n'
                '- Scheduling uses local timers and may require the device to be unlocked near the target time.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
