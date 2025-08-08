import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:launchgo/widgets/schedule_item.dart';
import 'package:launchgo/widgets/study_guide_card.dart';
import 'package:launchgo/widgets/message_item.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Dashboard',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: Colors.grey[300],
            child: Icon(
              Icons.person,
              color: Colors.grey[600],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.settings,
              color: Colors.black87,
            ),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Today's Schedule",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              const ScheduleItem(
                title: 'Math 101',
                time: '8:00 AM - 9:00 AM',
              ),
              const ScheduleItem(
                title: 'History 202',
                time: '9:30 AM - 10:30 AM',
              ),
              const ScheduleItem(
                title: 'English 303',
                time: '11:00 AM - 12:00 PM',
              ),
              const SizedBox(height: 32),
              const Text(
                'Study Guides',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              const StudyGuideCard(
                title: 'Math 101 Study Guide',
                creator: 'Amelia',
              ),
              const StudyGuideCard(
                title: 'History 202 Study Guide',
                creator: 'Liam',
              ),
              const SizedBox(height: 32),
              const Text(
                'Messages',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              const MessageItem(
                name: 'Dr. Harper',
                message: 'Project update',
                isMentor: true,
              ),
              const MessageItem(
                name: 'Owen',
                message: 'Study group meeting',
                isMentor: false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}