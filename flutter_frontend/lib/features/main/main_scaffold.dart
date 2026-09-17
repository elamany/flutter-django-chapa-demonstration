import 'package:flutter/material.dart';

import '../campaigns/screens/create_campaign_screen.dart';
import '../campaigns/screens/home_screen.dart';
import '../campaigns/screens/more_screen.dart';
import '../campaigns/screens/my_campaigns_screen.dart';
import '../auth/screens/profile_screen.dart';


/// The app shell shown to authenticated users.
///
/// Bottom nav with 4 tabs and a centered "add campaign" button.
/// Pages are built lazily on first visit and then kept alive.
class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  static const _tabCount = 4;

  int _currentIndex = 0;

  /// Lazy loading:
  ///   - _visited tracks which tabs have ever been shown.
  ///   - _pageCache holds the widget for a tab *after* first visit.
  ///
  /// A tab that hasn't been visited renders a zero-size placeholder
  /// inside the IndexedStack, so its build() and any initState() work
  /// don't run until the user actually taps it.
  final Set<int> _visited = {0};
  final Map<int, Widget> _pageCache = {};

  Widget _pageFor(int index) {
    if (!_visited.contains(index)) return const SizedBox.shrink();
    return _pageCache.putIfAbsent(index, () => _buildPage(index));
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return HomeScreen(
          onProfileTap: () => _onTabTapped(2),
        );
      case 1:
        return const MyCampaignsScreen();
      case 2:
        return const ProfileScreen();
      case 3:
        return const MoreScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  void _onTabTapped(int index) {
    if (index == _currentIndex && _visited.contains(index)) return;
    setState(() {
      _visited.add(index);
      _currentIndex = index;
    });
  }

  void _onAddPressed() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreateCampaignScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: List.generate(_tabCount, _pageFor),
      ),
      bottomNavigationBar: _BottomNavBar(
        currentIndex: _currentIndex,
        onTabTapped: _onTabTapped,
        onAddPressed: _onAddPressed,
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Bottom bar
// -----------------------------------------------------------------------------
class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({
    required this.currentIndex,
    required this.onTabTapped,
    required this.onAddPressed,
  });

  final int currentIndex;
  final ValueChanged<int> onTabTapped;
  final VoidCallback onAddPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant.withOpacity(0.5)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            children: [
              _NavItem(
                index: 0,
                currentIndex: currentIndex,
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'Home',
                onTap: onTabTapped,
              ),
              _NavItem(
                index: 1,
                currentIndex: currentIndex,
                icon: Icons.dashboard_outlined,
                activeIcon: Icons.dashboard,
                label: 'Mine',
                onTap: onTabTapped,
              ),
              _AddButton(onPressed: onAddPressed),
              _NavItem(
                index: 2,
                currentIndex: currentIndex,
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'Profile',
                onTap: onTabTapped,
              ),
              _NavItem(
                index: 3,
                currentIndex: currentIndex,
                icon: Icons.more_horiz,
                activeIcon: Icons.more_horiz,
                label: 'More',
                onTap: onTabTapped,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.index,
    required this.currentIndex,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.onTap,
  });

  final int index;
  final int currentIndex;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isActive = index == currentIndex;
    final color = isActive ? scheme.primary : scheme.onSurfaceVariant;

    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isActive ? activeIcon : icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Expanded(
      child: Center(
        child: SizedBox(
          width: 52,
          height: 52,
          child: Material(
            color: scheme.primary,
            shape: const CircleBorder(),
            elevation: 3,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: Icon(Icons.add, color: scheme.onPrimary, size: 28),
            ),
          ),
        ),
      ),
    );
  }
}