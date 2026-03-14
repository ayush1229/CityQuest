import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cityquest/core/theme/app_theme.dart';
import 'package:cityquest/providers/settings_provider.dart';
import 'package:cityquest/providers/quest_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.deepNavy,
      appBar: AppBar(
        backgroundColor: AppTheme.deepNavy,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'SETTINGS',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
            color: AppTheme.accentGold,
          ),
        ),
        centerTitle: true,
      ),
      body: Consumer2<SettingsProvider, QuestProvider>(
        builder: (context, settings, questProvider, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Map Settings Section ──
                _buildSectionHeader('Map Display'),
                const SizedBox(height: 12),

                _buildSettingsTile(
                  icon: Icons.view_in_ar_rounded,
                  title: '3D View',
                  subtitle: 'Enable 3D perspective with building depth',
                  trailing: Switch(
                    value: settings.is3DMode,
                    onChanged: settings.toggle3DMode,
                    activeColor: AppTheme.accentGold,
                  ),
                ).animate().fadeIn(duration: 300.ms, delay: 100.ms),

                _buildSettingsTile(
                  icon: Icons.apartment_rounded,
                  title: '3D Buildings',
                  subtitle: 'Show extruded building shapes on map',
                  trailing: Switch(
                    value: settings.showBuildingsLayer,
                    onChanged: settings.toggleBuildings,
                    activeColor: AppTheme.accentGold,
                  ),
                ).animate().fadeIn(duration: 300.ms, delay: 200.ms),

                _buildSettingsTile(
                  icon: Icons.traffic_rounded,
                  title: 'Traffic Layer',
                  subtitle: 'Show real-time traffic conditions',
                  trailing: Switch(
                    value: settings.showTraffic,
                    onChanged: settings.toggleTraffic,
                    activeColor: AppTheme.accentGold,
                  ),
                ).animate().fadeIn(duration: 300.ms, delay: 300.ms),

                const SizedBox(height: 20),

                // ── Map Style Section ──
                _buildSectionHeader('Map Style'),
                const SizedBox(height: 12),

                _buildMapStyleSelector(settings).animate().fadeIn(duration: 300.ms, delay: 400.ms),

                const SizedBox(height: 28),

                // ── Quest Settings Section ──
                _buildSectionHeader('Quest Settings'),
                const SizedBox(height: 12),

                _buildSettingsTile(
                  icon: Icons.radar_rounded,
                  title: 'Search Radius',
                  subtitle: 'Current: ${_formatRadius(questProvider.searchRadius)}',
                  trailing: SizedBox(
                    width: 180,
                    child: Slider(
                      value: questProvider.searchRadius,
                      min: 250,
                      max: 10000,
                      divisions: 39,
                      activeColor: AppTheme.accentGold,
                      inactiveColor: AppTheme.cardDark,
                      label: _formatRadius(questProvider.searchRadius),
                      onChanged: (val) => questProvider.setSearchRadius(val),
                    ),
                  ),
                ).animate().fadeIn(duration: 300.ms, delay: 500.ms),

                const SizedBox(height: 28),

                // ── Dev Options Section ──
                _buildSectionHeader('Developer'),
                const SizedBox(height: 12),

                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.cardDark,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: settings.devMode 
                          ? AppTheme.errorRed.withOpacity(0.4) 
                          : Colors.white.withOpacity(0.05),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.errorRed.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.developer_mode_rounded, color: AppTheme.errorRed, size: 22),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dev Mode',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Bypass 50m proximity check',
                              style: TextStyle(
                                color: AppTheme.errorRed,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: settings.devMode,
                        onChanged: settings.toggleDevMode,
                        activeColor: AppTheme.errorRed,
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 300.ms, delay: 600.ms),

                const SizedBox(height: 28),

                // ── About Section ──
                _buildSectionHeader('About'),
                const SizedBox(height: 12),

                _buildSettingsTile(
                  icon: Icons.info_outline_rounded,
                  title: 'CityQuest',
                  subtitle: 'Version 1.0.0 • Built for Hackathon',
                  trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                ).animate().fadeIn(duration: 300.ms, delay: 700.ms),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatRadius(double radius) {
    if (radius >= 1000) {
      return '${(radius / 1000).toStringAsFixed(1)}km';
    }
    return '${radius.toInt()}m';
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.montserrat(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppTheme.accentGold,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.primaryBlue, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _buildMapStyleSelector(SettingsProvider settings) {
    final styles = [
      {'id': 'normal', 'label': 'Normal', 'icon': Icons.map_rounded},
      {'id': 'satellite', 'label': 'Satellite', 'icon': Icons.satellite_alt_rounded},
      {'id': 'terrain', 'label': 'Terrain', 'icon': Icons.terrain_rounded},
      {'id': 'hybrid', 'label': 'Hybrid', 'icon': Icons.layers_rounded},
    ];

    return Row(
      children: styles.map((style) {
        final isSelected = settings.mapStyle == style['id'];
        return Expanded(
          child: GestureDetector(
            onTap: () => settings.setMapStyle(style['id'] as String),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.accentGold.withValues(alpha: 0.15) : AppTheme.cardDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppTheme.accentGold : Colors.white.withValues(alpha: 0.05),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    style['icon'] as IconData,
                    color: isSelected ? AppTheme.accentGold : AppTheme.textSecondary,
                    size: 24,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    style['label'] as String,
                    style: TextStyle(
                      color: isSelected ? AppTheme.accentGold : AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
