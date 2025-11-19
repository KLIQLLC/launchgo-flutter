# LaunchGo - Main Product Requirements Document

## 1. Executive Summary

**Product Name:** LaunchGo  
**Version:** 1.0  
**Platform:** Flutter (iOS & Android)  
**Target Users:** Students, Mentors  

### Product Vision
LaunchGo is an educational support platform that facilitates seamless communication, scheduling, and progress tracking between students and their mentors through mobile applications.

### Key Value Propositions
- **For Students:** Centralized access to schedules, assignments, documents, and mentor communication
- **For Mentors:** Tools to track student progress, manage check-ins, submit recaps, and provide support

## 2. User Personas

### Primary Users

#### Student
- **Needs:** Access to schedule, assignments, documents, chat with mentors
- **Goals:** Stay organized, complete assignments, communicate with support team
- **Constraints:** Mobile-first usage, varying technical skills
- **Key Features:** Read-only schedule, document viewing, chat, notifications

#### Mentor
- **Needs:** Student progress tracking, check-in management, communication tools, recap submissions
- **Goals:** Support multiple students, track engagement, submit weekly reports
- **Constraints:** Manages multiple students, needs efficient workflows
- **Key Features:** Student selection, schedule management, document CRUD, weekly recaps

## 3. Core Features Overview

### Authentication & User Management
- Google Sign-In integration
- JWT token-based authentication
- Role-based access control (Student vs Mentor)
- Multi-environment support (stage/production)

### Scheduling & Events
- Weekly schedule view
- Event management (Mentors can create/edit)
- Location-based check-ins
- Deadline tracking

### Document Management
- File upload/download
- Role-based permissions (Students: read-only, Mentors: full CRUD)
- Category organization
- Search functionality

### Communication
- Real-time chat (Stream Chat)
- Presence management (Mentors connect selectively to students)
- Push notifications
- Offline message handling

### Weekly Recaps (Mentors Only)
- Weekly report submissions
- Local notification reminders
- Progress tracking

### Notifications
- FCM push notifications
- Local notifications (weekly recap reminders)
- Smart navigation to relevant screens
- Badge management

## 4. User Journey Flows

### Student Journey
1. **Login** → Google Sign-In → Dashboard
2. **Daily Use** → Check schedule → View assignments → Chat with mentor
3. **Notifications** → Receive updates → Navigate to relevant content

### Mentor Journey
1. **Login** → Select student from dropdown → Dashboard
2. **Daily Use** → Review student schedule → Check-in tracking → Document management
3. **Weekly** → Submit recap reports → Receive reminder notifications

## 5. Success Metrics

### User Engagement
- Daily active users by role
- Student-mentor message frequency
- Check-in completion rates

### Operational Efficiency
- Weekly recap submission rates
- Document access frequency
- Notification response rates

### Technical Performance
- App launch time < 3 seconds
- 99.9% uptime
- Crash rate < 0.1%

## 6. Technical Constraints

- **Platforms:** iOS and Android only (no web/desktop)
- **Connectivity:** Requires internet for real-time features
- **Compatibility:** iOS 12.0+, Android API 21+
- **Dependencies:** Firebase, Stream Chat, Google Services

## 7. Feature Priority Matrix

### Must Have (MVP)
- Authentication (Google Sign-In)
- Basic scheduling view
- Document access
- Chat functionality

### Should Have (V1.1)
- Push notifications
- Weekly recap system
- Location check-ins

### Could Have (V1.2)
- Advanced search
- Offline support
- Performance optimizations

### Won't Have (Current Scope)
- Web platform
- Case Manager features
- Advanced analytics

---

**Document Owner:** [Product Manager]  
**Last Updated:** [Date]  
**Review Cycle:** Monthly  
**Related Documents:** 
- [PRD_Authentication.md](features/PRD_Authentication.md)
- [PRD_Scheduling.md](features/PRD_Scheduling.md)
- [PRD_Chat.md](features/PRD_Chat.md)