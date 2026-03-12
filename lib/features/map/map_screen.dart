import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cityquest/core/theme/app_theme.dart';
import 'package:cityquest/providers/location_provider.dart';
import 'package:cityquest/providers/quest_provider.dart';
import 'package:cityquest/features/map/mock_map_widget.dart';
import 'package:cityquest/features/profile/profile_screen.dart';
import 'package:cityquest/core/widgets/loading_widget.dart';
import 'package:cityquest/core/widgets/app_error_widget.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    final locProvider = context.read<LocationProvider>();
    await locProvider.startTracking();

    if (!mounted) return;

    // Load quests around the user's location
    context.read<QuestProvider>().loadQuests(
          locProvider.latitude,
          locProvider.longitude,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentTab,
        children: [
          _buildMapTab(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentTab,
          onTap: (i) => setState(() => _currentTab = i),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.map_rounded),
              activeIcon: Icon(Icons.map_rounded),
              label: 'Map',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapTab() {
    return Consumer<LocationProvider>(
      builder: (context, locProvider, _) {
        if (locProvider.error != null && !locProvider.isTracking) {
          return AppErrorWidget(
            message: locProvider.error!,
            onRetry: _initLocation,
          );
        }

        return Consumer<QuestProvider>(
          builder: (context, questProvider, _) {
            if (questProvider.isLoading) {
              return const LoadingWidget(message: 'Loading quests...');
            }

            if (questProvider.error != null) {
              return AppErrorWidget(
                message: questProvider.error!,
                onRetry: () => questProvider.loadQuests(
                  locProvider.latitude,
                  locProvider.longitude,
                ),
              );
            }

            return const MockMapWidget();
          },
        );
      },
    );
  }
}
