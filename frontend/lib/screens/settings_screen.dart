import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:provider/provider.dart';
import 'package:stardylog/routes/app_router.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/image_with_fallback.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final settingsProvider = context.watch<SettingsProvider>();
    final firebaseUser = authProvider.firebaseUser;
    final userDetails = authProvider.userDetails;

    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 프로필 섹션
          if (firebaseUser != null && userDetails != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ListTile(
                  leading: firebaseUser.photoURL != null
                      ? ClipOval(
                          child: ImageWithFallback(
                            imageUrl: firebaseUser.photoURL!,
                            width: 50,
                            height: 50,
                          ),
                        )
                      : const CircleAvatar(child: Icon(LucideIcons.user)),
                  title: Text(userDetails['displayName'] ?? '이름 없음', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(firebaseUser.email ?? '이메일 정보 없음'),
                  trailing: IconButton(
                    icon: const Icon(LucideIcons.logOut),
                    onPressed: () {
                      Provider.of<AuthProvider>(context, listen: false).signOut();
                      Navigator.of(context).pushNamedAndRemoveUntil(Routes.login, (route) => false);
                    },
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          // 공부 설정
          SettingCard(
            title: '공부 설정',
            icon: LucideIcons.clock,
            children: [
              ListTile(
                title: const Text('일일 목표 시간'),
                subtitle: const Text('하루에 공부할 목표 시간을 설정하세요'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 60,
                      child: TextField(
                        controller: TextEditingController(text: settingsProvider.dailyGoal.toInt().toString()),
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        onSubmitted: (value) {
                          settingsProvider.updateDailyGoal(double.tryParse(value) ?? 4.0);
                        },
                      ),
                    ),
                    const Text(' 시간'),
                  ],
                ),
              ),
              const Divider(),
              SwitchListTile(
                title: const Text('타이머 완료 소리'),
                subtitle: const Text('타이머가 끝날 때 알림음을 재생합니다'),
                value: settingsProvider.soundEnabled,
                onChanged: (value) {
                  settingsProvider.updateSoundEnabled(value);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 알림 설정
          SettingCard(
            title: '알림 설정',
            icon: LucideIcons.bell,
            children: [
              SwitchListTile(
                title: const Text('푸시 알림'),
                subtitle: const Text('공부 리마인더와 목표 달성 알림을 받습니다'),
                value: settingsProvider.notifications,
                onChanged: (value) {
                  settingsProvider.updateNotifications(value);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 테마 설정
          SettingCard(
            title: '테마 설정',
            icon: LucideIcons.palette,
            children: [
              SwitchListTile(
                title: const Text('다크 모드'),
                subtitle: const Text('어두운 테마로 변경합니다'),
                value: settingsProvider.isDarkMode,
                onChanged: (value) {
                  settingsProvider.updateDarkMode(value);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SettingCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const SettingCard({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(icon),
            title: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          ...children,
        ],
      ),
    );
  }
}