import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cityquest/core/theme/app_theme.dart';
import 'package:cityquest/providers/location_provider.dart';
import 'package:cityquest/providers/user_provider.dart';
import 'package:cityquest/providers/quest_provider.dart';
import 'package:cityquest/providers/settings_provider.dart';
import 'package:cityquest/providers/lore_provider.dart';
import 'package:cityquest/providers/campaign_provider.dart';
import 'package:cityquest/features/auth/login_screen.dart';

import 'package:cityquest/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  // Initialize Firebase (will fail gracefully if not configured)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    debugPrint('Firebase not configured — running with mock data');
  }

  runApp(const CityQuestApp());
}

class CityQuestApp extends StatelessWidget {
  const CityQuestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => QuestProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => LoreProvider()),
        ChangeNotifierProvider(create: (_) => CampaignProvider()),
      ],
      child: MaterialApp(
        title: 'CityQuest',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const LoginScreen(),
      ),
    );
  }
}