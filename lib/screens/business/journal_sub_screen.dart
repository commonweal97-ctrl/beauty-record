import 'package:flutter/material.dart';
import 'analytics_screen.dart';
import 'month_view_screen.dart';
import 'list_view_screen.dart';
import 'schedule_view_screen.dart';
import 'clients_screen.dart';
import 'business_reviews_screen.dart';
import 'business_project_profile_screen.dart';
import 'employees_screen.dart';
import 'access_screen.dart';
import 'services_screen.dart';
import 'access_screen.dart';
import 'online_booking_screen.dart';
import 'notifications_screen.dart';
import 'push_settings_screen.dart';
import 'resources_screen.dart';

class JournalSubScreen extends StatelessWidget {
  final int projectId;
  final String page;
  final String title;
  const JournalSubScreen({super.key, required this.projectId, required this.page, required this.title});

  @override
  Widget build(BuildContext context) {
    if (page == 'analytics') {
      return AnalyticsScreen(projectId: projectId);
    }
    
    if (page == 'schedule') {
      return ScheduleViewScreen(projectId: projectId);
    }

    if (page == 'clients') {
      return ClientsScreen(projectId: projectId);
    }

    if (page == 'reviews') {
      return BusinessReviewsScreen(projectId: projectId);
    }

    if (page == 'profile') {
      return BusinessProjectProfileScreen(projectId: projectId);
    }

    if (page == 'employees') {
      return EmployeesScreen(projectId: projectId);
    }

    if (page == 'access') {
      return AccessScreen(projectId: projectId);
    }

    if (page == 'services') {
      return ServicesScreen(projectId: projectId);
    }

    if (page == 'resources') {
      return ResourcesScreen(projectId: projectId);
    }

    if (page == 'online') {
      return OnlineBookingScreen(projectId: projectId);
    }

    if (page == 'notifications') {
      return NotificationsScreen(projectId: projectId);
    }

    if (page == 'push_settings') {
      return PushSettingsScreen(projectId: projectId);
    }

    return Container(
      color: const Color(0xFFF5F5F5),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_pageIcon(), size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
            const SizedBox(height: 8),
            const Text('Раздел в разработке', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  IconData _pageIcon() {
    switch (page) {
      case 'analytics': return Icons.grid_view;
      case 'schedule': return Icons.schedule;
      case 'clients': return Icons.people;
      case 'reviews': return Icons.star_border;
      case 'profile': return Icons.business;
      case 'employees': return Icons.person_add;
      case 'services': return Icons.content_copy;
      case 'access': return Icons.lock;
      case 'online': return Icons.language;
      case 'notifications': return Icons.notifications;
      case 'push_settings': return Icons.notifications_active;
      default: return Icons.info;
    }
  }
}