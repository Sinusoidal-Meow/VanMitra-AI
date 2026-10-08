import re

with open('scratch_villager.dart', 'r', encoding='utf-16le') as f:
    content = f.read()

# Replace _VillagerHomeScreenState
state_pattern = r'class _VillagerHomeScreenState extends ConsumerState<VillagerHomeScreen> \{.*?Widget build\(BuildContext context\) \{.*?\}\s*\}'
new_state = '''class _VillagerHomeScreenState extends ConsumerState<VillagerHomeScreen> {
  int _currentTab = 0;

  @override
  Widget build(BuildContext context) {
    final navBar = _VillagerBottomNavBar(
      currentTab: _currentTab,
      onTabSelected: (index) {
        if (index == 1) {
          Navigator.pushNamed(context, AppRouter.myClaims);
        } else if (index == 3) {
          setState(() => _currentTab = index);
        } else {
          setState(() => _currentTab = index);
        }
      },
    );

    return IndexedStack(
      index: _currentTab,
      children: [
        _HomeTab(bottomNavigationBar: navBar, onSwitchTab: (index) => setState(() => _currentTab = index)),
        MyClaimsScreen(bottomNavigationBar: navBar),
        _ProfileTab(bottomNavigationBar: navBar),
        _GramSabhaTab(bottomNavigationBar: navBar),
        _MapTab(bottomNavigationBar: navBar),
      ],
    );
  }
}'''
content = re.sub(state_pattern, new_state, content, flags=re.DOTALL)

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
                      Expanded(child: _VillagerStatCard(value: approvedClaimsCount, label: 'Approved Claims', icon: Icons.check_circle_outline, iconColor: const Color(0xFF10B981), bgColor: const Color(0xFFD1FAE5))),
                      const SizedBox(width: 12),
                      Expanded(child: _VillagerStatCard(value: approvedAreaStr, label: 'Hectares Area', icon: Icons.landscape_rounded, iconColor: const Color(0xFF0D9488), bgColor: const Color(0xFFCCFBF1))),
                      const SizedBox(width: 12),
                      Expanded(child: _VillagerStatCard(value: pastMeetingsCount, label: 'Meeting Records', icon: Icons.groups_rounded, iconColor: const Color(0xFFF59E0B), bgColor: const Color(0xFFFEF3C7))),
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
                        iconBgColor: const Color(0xFFFF7A00).withOpacity(0.1),
                        onTap: () => Navigator.pushNamed(context, AppRouter.claimType),
                      ),
                      _VillagerActionCard(
                        title: 'Form B / C · Community claims',
                        subtitle: 'सामूहिक हक्क व सामूहिक वन संसाधन दावा',
                        icon: Icons.groups_rounded,
                        iconColor: const Color(0xFF1B4D36),
                        iconBgColor: const Color(0xFF1B4D36).withOpacity(0.1),
                        onTap: () => Navigator.pushNamed(context, AppRouter.formB),
                      ),
                      _VillagerActionCard(
                        title: 'Evidence Checklist (Rule 13)',
                        subtitle: 'View and complete required evidence',
                        icon: Icons.folder_shared_rounded,
                        iconColor: const Color(0xFFF59E0B),
                        iconBgColor: const Color(0xFFF59E0B).withOpacity(0.1),
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

components = '''
class _VillagerDashboardBackground extends StatelessWidget {
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
    
    final p1 = Paint()..color = const Color(0xFF183D2A)..style = PaintingStyle.fill;
    final path1 = Path();
    path1.lineTo(0, 220);
    path1.cubicTo(w*0.2, 320, w*0.4, 250, w, 280);
    path1.lineTo(w, 0);
    path1.close();
    canvas.drawPath(path1, p1);

    final p2 = Paint()..color = const Color(0xFF2B5B43)..style = PaintingStyle.fill;
    final path2 = Path();
    path2.moveTo(0, 210);
    path2.cubicTo(w*0.25, 330, w*0.5, 220, w*0.8, 260);
    path2.quadraticBezierTo(w*0.9, 275, w, 260);
    path2.lineTo(w, 0);
    path2.lineTo(0, 0);
    path2.close();
    canvas.drawPath(path2, p2);

    final pSun = Paint()..color = const Color(0xFFF9C86A)..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.85, 230), 25, pSun);

    final p3 = Paint()..color = const Color(0xFF427A59)..style = PaintingStyle.fill;
    final path3 = Path();
    path3.moveTo(w*0.4, 270);
    path3.cubicTo(w*0.6, 210, w*0.8, 260, w, 250);
    path3.lineTo(w, 290);
    path3.lineTo(w*0.4, 290);
    path3.close();
    canvas.drawPath(path3, p3);
  }
  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _VillagerGreetingCard extends StatelessWidget {
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
          colors: [Color(0xFF214E34), Color(0xFF143825)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFFFF7A00),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [BoxShadow(color: const Color(0xFFFF7A00).withOpacity(0.4), blurRadius: 8)],
            ),
            alignment: Alignment.center,
            child: Text(userName.isNotEmpty ? userName[0].toUpperCase() : 'U', 
              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hello, $userName', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('VILLAGER', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.location_on, color: Colors.white70, size: 14),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(villageName, style: const TextStyle(color: Colors.white70, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.eco_rounded, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }
}

class _VillagerNextMeetingCard extends StatelessWidget {
  final GramSabhaMeeting? meeting;
  const _VillagerNextMeetingCard(this.meeting);

  @override
  Widget build(BuildContext context) {
    final title = meeting?.type.displayNameEn ?? 'Next Meeting';
    final subtitle = meeting != null ? meeting!.venue : 'No meetings scheduled';
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.calendar_today_rounded, color: Color(0xFF6B7280), size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF111827))),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFFD1D5DB)),
        ],
      ),
    );
  }
}

class _VillagerStatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  
  const _VillagerStatCard({required this.value, required this.label, required this.icon, required this.iconColor, required this.bgColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(child: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280), height: 1.1), maxLines: 2)),
              const Icon(Icons.chevron_right_rounded, size: 14, color: Color(0xFFD1D5DB)),
            ],
          )
        ],
      ),
    );
  }
}

class _VillagerActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final VoidCallback onTap;

  const _VillagerActionCard({required this.title, required this.subtitle, required this.icon, required this.iconColor, required this.iconBgColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: iconBgColor, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF111827))),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFD1D5DB)),
          ],
        ),
      ),
    );
  }
}

class _VillagerBottomNavBar extends StatelessWidget {
  final int currentTab;
  final ValueChanged<int> onTabSelected;
  const _VillagerBottomNavBar({required this.currentTab, required this.onTabSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _NavItem(icon: Icons.dashboard_rounded, label: 'Dashboard', isActive: currentTab == 0, isHero: true, onTap: () => onTabSelected(0)),
          _NavItem(icon: Icons.folder_shared_outlined, label: 'Claims', isActive: currentTab == 1, onTap: () => onTabSelected(1)),
          _NavItem(icon: Icons.account_circle_outlined, label: 'Profile', isActive: currentTab == 2, onTap: () => onTabSelected(2)),
          _NavItem(icon: Icons.how_to_vote_outlined, label: 'Gram Sabha', isActive: currentTab == 3, onTap: () => onTabSelected(3)),
          _NavItem(icon: Icons.map_outlined, label: 'Atlas Map', isActive: currentTab == 4, onTap: () => onTabSelected(4)),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final bool isHero;
  final VoidCallback onTap;

  const _NavItem({required this.icon, required this.label, required this.isActive, this.isHero = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (isHero) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.translate(
              offset: const Offset(0, -16),
              child: Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFFFF7A00) : Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    if (isActive) BoxShadow(color: const Color(0xFFFF7A00).withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))
                    else BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))
                  ],
                ),
                child: Icon(icon, color: isActive ? Colors.white : const Color(0xFF9CA3AF), size: 28),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -8),
              child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isActive ? const Color(0xFFFF7A00) : const Color(0xFF9CA3AF))),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: SizedBox(
          width: 56,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: isActive ? const Color(0xFFFF7A00) : const Color(0xFF9CA3AF), size: 24),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 10, fontWeight: isActive ? FontWeight.bold : FontWeight.normal, color: isActive ? const Color(0xFFFF7A00) : const Color(0xFF9CA3AF)), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}
'''
content += components

with open('vanmitra_tem/lib/screens/home/villager_home_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
