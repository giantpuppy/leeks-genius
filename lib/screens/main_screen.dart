import 'dart:ui';
import 'package:flutter/material.dart';
import 'calendar_screen.dart';
import 'gantt_screen.dart';
import 'profile_screen.dart';
import '../widgets/schedule_tab_icon.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  bool _calendarHasSelectedEvent = false;
  bool _is7Day = false;
  final _ganttKey = GlobalKey<GanttScreenState>();

  List<Widget> get _pages => [
        CalendarScreen(
          onSelectedDayHasEvent: (hasEvent) {
            setState(() => _calendarHasSelectedEvent = hasEvent);
          },
        ),
        GanttScreen(key: _ganttKey),
        const ProfileScreen(),
      ];

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final showReminderLight =
        _currentIndex == 0 && _calendarHasSelectedEvent;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: _pages[_currentIndex],
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 选中有剧目日期时，底部导航条上方的提醒光感分隔符
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            height: showReminderLight ? 2 : 0,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.transparent,
                  primaryColor.withValues(alpha: showReminderLight ? 1.0 : 0.0),
                  primaryColor.withValues(alpha: showReminderLight ? 0.6 : 0.0),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.45, 0.55, 1.0],
              ),
              boxShadow: showReminderLight
                  ? [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.55),
                        blurRadius: 18,
                        spreadRadius: 3,
                      ),
                    ]
                  : null,
            ),
          ),
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                color: const Color(0xFF121212).withValues(alpha: 0.65),
                child: BottomNavigationBar(
                  currentIndex: _currentIndex,
                  onTap: (index) {
                    if (index == 1 && _currentIndex == 1) {
                      // 重点击排期 tab → 切换三行/七行
                      _ganttKey.currentState?.toggleMode();
                      setState(() => _is7Day = !_is7Day);
                      return;
                    }
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  selectedItemColor: primaryColor,
                  unselectedItemColor: const Color(0xFF8A8F98),
                  selectedFontSize: 0,
                  unselectedFontSize: 0,
                  showSelectedLabels: false,
                  showUnselectedLabels: false,
                  type: BottomNavigationBarType.fixed,
                  items: [
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.calendar_month_outlined),
                      activeIcon: Icon(Icons.calendar_month),
                      label: '日历',
                    ),
                    BottomNavigationBarItem(
                      icon: ScheduleTabIcon(
                        mode: _is7Day
                            ? ScheduleTabIconMode.sevenDay
                            : ScheduleTabIconMode.threeDay,
                        key: ValueKey<bool>(_is7Day),
                      ),
                      label: '排期',
                    ),
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.person_outline),
                      activeIcon: Icon(Icons.person),
                      label: '我的',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
