import re

with open('vanmitra_tem/lib/screens/home/villager_home_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace _HomeTab
tab_pattern = r'class _HomeTab extends ConsumerWidget \{.*?Widget _buildNextMeetingCard.*?\}\s*\}'
new_tab = '''class _HomeTab extends ConsumerWidget {
  final Widget bottomNavigationBar;
  final ValueChanged<int>? onSwitchTab;

  const _HomeTab({required this.bottomNavigationBar, this.onSwitchTab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final village = ref.watch(villageProvider);
    
    final villageId = village?.id ?? '';
    final claimsAsync = ref.watch(claimsStreamProvider(villageId));
    final meetingsAsync = ref.watch(meetingsStreamProvider(villageId));

    final approvedClaimsCount = claimsAsync.maybeWhen(
      data: (list) => list.where((c) => c.status.name == 'approved').length.toString(),
      orElse: () => '0',
    );

    final approvedAreaStr = claimsAsync.maybeWhen(
      data: (list) {
        final areaSqM = list
            .where((c) => c.status.name == 'approved')
            .fold<int>(0, (s, c) => s + (c.areaSqMeters?.toInt() ?? 0));
        return (areaSqM / 10000).toStringAsFixed(1);
      },
      orElse: () => '0.0',
    );

    final pastMeetingsCount = meetingsAsync.maybeWhen(
      data: (list) => list.where((m) => m.status.name == 'completed').length.toString(),
      orElse: () => '0',
    );

    final allMeetings = meetingsAsync.maybeWhen(
      data: (list) => list,
      orElse: () => <GramSabhaMeeting>[],
    );

    GramSabhaMeeting? todayMeeting;
    try {
      todayMeeting = allMeetings.firstWhere((m) => m.isToday && m.isAcceptingAttendance);
    } catch (_) {}
    
    final upcoming = allMeetings.where((m) => m.isUpcoming).toList()
      ..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
    final nextMeeting = todayMeeting ?? (upcoming.isNotEmpty ? upcoming.first : null);

    return PortalFrameScaffold(
      breadcrumbs: const [],
      bottomNavigationBar: null,
      body: Stack(
        children: [
          const Positioned.fill(child: VanMitraBackgroundWatermark()),
          const Positioned(top: 0, left: 0, right: 0, height: 400, child: _VillagerDashboardBackground()),
          
          Positioned.fill(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 120),
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Text('Dashboard', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1B4D36))),
                ),
                if (auth.currentUser != null)
                  _VillagerGreetingCard(userName: auth.currentUser!.name, villageName: village?.nameMarathi ?? auth.currentUser!.villageId),
                
                const SizedBox(height: 24),
                _VillagerNextMeetingCard(nextMeeting),
                
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      Expanded(child: _VillagerStatCard(value: approvedClaimsCount, label: 'Approved Claims', icon: Icons.check_circle_outline, iconColor: const Color(0xFF10B981), bgColor: const Color(0xFFD1FAE5), bgIcon: Icons.description)),
                      const SizedBox(width: 12),
                      Expanded(child: _VillagerStatCard(value: approvedAreaStr, label: 'Hectares Area', icon: Icons.landscape_rounded, iconColor: const Color(0xFF0D9488), bgColor: const Color(0xFFCCFBF1), bgIcon: Icons.landscape)),
                      const SizedBox(width: 12),
                      Expanded(child: _VillagerStatCard(value: pastMeetingsCount, label: 'Meeting Records', icon: Icons.groups_rounded, iconColor: const Color(0xFFF59E0B), bgColor: const Color(0xFFFEF3C7), bgIcon: Icons.groups)),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Claims', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Quick Actions', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                          const SizedBox(height: 4),
                          Container(width: 30, height: 3, color: const Color(0xFFFF7A00)),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    children: [
                      _VillagerActionCard(
                        title: 'File New Claim',
                        subtitle: 'Submit new individual or community claim',
                        icon: Icons.note_add_rounded,
                        iconColor: const Color(0xFFFF7A00),
                        iconBgColor: const Color(0xFFFF7A00).withValues(alpha: 0.1),
                        bgIcon: Icons.description,
                        onTap: () => Navigator.pushNamed(context, AppRouter.claimType),
                      ),
                      _VillagerActionCard(
                        title: 'Form B / C · Community claims',
                        subtitle: 'सामूहिक हक्क व सामूहिक वन संसाधन दावा',
                        icon: Icons.groups_rounded,
                        iconColor: const Color(0xFF1B4D36),
                        iconBgColor: const Color(0xFF1B4D36).withValues(alpha: 0.1),
                        bgIcon: Icons.groups,
                        onTap: () => Navigator.pushNamed(context, AppRouter.formB),
                      ),
                      _VillagerActionCard(
                        title: 'Evidence Checklist (Rule 13)',
                        subtitle: 'View and complete required evidence',
                        icon: Icons.folder_shared_rounded,
                        iconColor: const Color(0xFFF59E0B),
                        iconBgColor: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                        bgIcon: Icons.folder,
                        onTap: () => Navigator.pushNamed(context, AppRouter.rule13Evidence),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Satellite Monitoring', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF6B7280))),
                      const SizedBox(height: 12),
                      _ParcelStatusCard(
                        landownerId: int.tryParse(auth.currentUser?.id ?? '') ?? 6976,
                        onViewHistory: () => Navigator.pushNamed(context, AppRouter.alertHistory),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: bottomNavigationBar,
          ),
        ],
      ),
    );
  }
}'''
content = re.sub(tab_pattern, new_tab, content, flags=re.DOTALL)

# Now regex replace the specific bottom classes so we don't duplicate them
bg_pattern = r'class _VillagerDashboardBackground extends StatelessWidget \{.*?bool shouldRepaint\(covariant CustomPainter old\) => false;\n\}'
new_bg = '''class _VillagerDashboardBackground extends StatelessWidget {
  const _VillagerDashboardBackground();
  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _VillagerBgPainter());
  }
}

class _VillagerBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    
    // 1. Deepest dark forest green base (Header background area)
    final p1 = Paint()..color = const Color(0xFF123422)..style = PaintingStyle.fill;
    final path1 = Path();
    path1.lineTo(0, 200);
    path1.cubicTo(w*0.3, 300, w*0.7, 240, w, 290);
    path1.lineTo(w, 0);
    path1.close();
    canvas.drawPath(path1, p1);

    // 2. Middle forest layer
    final p2 = Paint()..color = const Color(0xFF1E4631)..style = PaintingStyle.fill;
    final path2 = Path();
    path2.moveTo(0, 190);
    path2.cubicTo(w*0.25, 320, w*0.6, 220, w*0.9, 270);
    path2.quadraticBezierTo(w*0.95, 278, w, 260);
    path2.lineTo(w, 0);
    path2.lineTo(0, 0);
    path2.close();
    canvas.drawPath(path2, p2);

    // 3. Sun
    final pSun = Paint()..color = const Color(0xFFF9C86A)..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.82, 235), 25, pSun);

    // Draw some stylized hills before white
    final pHill1 = Paint()..color = const Color(0xFF336346)..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.2, 290), 80, pHill1);
    canvas.drawCircle(Offset(w * 0.5, 300), 90, pHill1);
    final pHill2 = Paint()..color = const Color(0xFF5B8A6B)..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.75, 270), 70, pHill2);
    canvas.drawCircle(Offset(w * 0.9, 280), 80, pHill2);

    // White transition curve
    final pWhite = Paint()..color = const Color(0xFFFAFAFA)..style = PaintingStyle.fill;
    final pathWhite = Path();
    pathWhite.moveTo(0, 310);
    pathWhite.cubicTo(w*0.3, 290, w*0.5, 340, w, 265);
    pathWhite.lineTo(w, 400);
    pathWhite.lineTo(0, 400);
    pathWhite.close();
    
    canvas.drawPath(pathWhite, pWhite);
  }
  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}'''
content = re.sub(bg_pattern, new_bg, content, flags=re.DOTALL)

greeting_pattern = r'class _VillagerGreetingCard extends StatelessWidget \{.*?\]\,\n      \)\,\n    \)\;\n  \}\n\}'
new_greeting = '''class _VillagerGreetingCard extends StatelessWidget {
  final String userName;
  final String villageName;
  const _VillagerGreetingCard({required this.userName, required this.villageName});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF234B34), Color(0xFF143825)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.5),
        boxShadow: [
          BoxShadow(color: const Color(0xFF143825).withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFFF851B),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFFD1A8), width: 2),
              boxShadow: [
                BoxShadow(color: const Color(0xFFFF851B).withValues(alpha: 0.5), blurRadius: 15, spreadRadius: 2)
              ],
            ),
            alignment: Alignment.center,
            child: Text(userName.isNotEmpty ? userName[0].toUpperCase() : 'U', 
              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hello, $userName', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 0.2)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('VILLAGER', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.location_on, color: Color(0xFFA1E3C8), size: 16),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(villageName, style: const TextStyle(color: Color(0xFFA1E3C8), fontSize: 13, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.eco_rounded, color: Color(0xFFC7F0DF), size: 24),
          ),
        ],
      ),
    );
  }
}'''
content = re.sub(greeting_pattern, new_greeting, content, flags=re.DOTALL)

meeting_pattern = r'class _VillagerNextMeetingCard extends StatelessWidget \{.*?\]\,\n      \)\,\n    \)\;\n  \}\n\}'
new_meeting = '''class _VillagerNextMeetingCard extends StatelessWidget {
  final GramSabhaMeeting? meeting;
  const _VillagerNextMeetingCard(this.meeting);

  @override
  Widget build(BuildContext context) {
    final title = meeting?.type.displayNameEn ?? 'Next Meeting';
    final subtitle = meeting != null ? meeting!.venue : 'No meetings scheduled';
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: const Color(0xFF143825).withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 8))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60, height: 60,
            decoration: const BoxDecoration(
              color: Color(0xFFF4F7F6),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.calendar_today_rounded, color: Color(0xFF334155), size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF0F172A), letterSpacing: 0.2)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Color(0xFF64748B), fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Icon(Icons.edit_calendar_rounded, size: 40, color: const Color(0xFF10B981).withValues(alpha: 0.4)),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chevron_right_rounded, color: Color(0xFF475569), size: 20),
          ),
        ],
      ),
    );
  }
}'''
content = re.sub(meeting_pattern, new_meeting, content, flags=re.DOTALL)

stat_pattern = r'class _VillagerStatCard extends StatelessWidget \{.*?\]\,\n      \)\,\n    \)\;\n  \}\n\}'
new_stat = '''class _VillagerStatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final IconData bgIcon;
  
  const _VillagerStatCard({required this.value, required this.label, required this.icon, required this.iconColor, required this.bgColor, required this.bgIcon});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 125,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: const Color(0xFF143825).withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 8))
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -10,
            top: -10,
            child: Icon(bgIcon, size: 65, color: bgColor.withValues(alpha: 0.6)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const Spacer(),
              Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), height: 1.0)),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B), height: 1.1), maxLines: 2)),
                  const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF94A3B8)),
                ],
              )
            ],
          ),
        ],
      ),
    );
  }
}'''
content = re.sub(stat_pattern, new_stat, content, flags=re.DOTALL)

action_pattern = r'class _VillagerActionCard extends StatelessWidget \{.*?\]\,\n        \)\,\n      \)\,\n    \)\;\n  \}\n\}'
new_action = '''class _VillagerActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final VoidCallback onTap;
  final IconData bgIcon;

  const _VillagerActionCard({required this.title, required this.subtitle, required this.icon, required this.iconColor, required this.iconBgColor, required this.onTap, required this.bgIcon});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: const Color(0xFF143825).withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 8))
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              right: 10,
              top: -10,
              bottom: -10,
              child: Icon(bgIcon, size: 100, color: iconBgColor.withValues(alpha: 0.4)),
            ),
            Row(
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(color: iconBgColor, borderRadius: BorderRadius.circular(16)),
                  child: Icon(icon, color: iconColor, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Color(0xFF0F172A), letterSpacing: 0.1)),
                      const SizedBox(height: 6),
                      Text(subtitle, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chevron_right_rounded, color: Color(0xFF475569), size: 20),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}'''
content = re.sub(action_pattern, new_action, content, flags=re.DOTALL)


with open('vanmitra_tem/lib/screens/home/villager_home_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
