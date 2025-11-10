import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
import 'federated/admin_dashboard.dart';
import 'district/district_admin_dashboard.dart';
import 'LGU/lgu_dashboard.dart';

/// AuthWrapper checks if a user is already logged in and routes them
/// to the appropriate dashboard based on their role.
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  Future<Widget> _determineHomePage(User user) async {
    try {
      // Get user document from Firestore
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        // Check if user is in station_owners as district president
        QuerySnapshot stationOwnerQuery = await FirebaseFirestore.instance
            .collection('station_owners')
            .where('userId', isEqualTo: user.uid)
            .where('district_president', isEqualTo: true)
            .where('status', isEqualTo: 'approved')
            .limit(1)
            .get();

        if (stationOwnerQuery.docs.isNotEmpty) {
          return const DistrictAdminDashboard();
        }

        // User not found in either collection, logout
        await FirebaseAuth.instance.signOut();
        return const LoginScreen();
      }

      final userData = userDoc.data() as Map<String, dynamic>? ?? {};

      // Check for federated president
      if (userData['federated_president'] == true && userData['role'] == 'admin') {
        return const AdminDashboard();
      }

      // Check for district president
      if (userData['role'] == 'admin' && userData['district_president'] == true) {
        return const DistrictAdminDashboard();
      }

      // Check for CHO/LGU role
      if (userData['role'] == 'cho_lgu') {
        return const LguDashboard();
      }

      // If role not recognized, logout
      await FirebaseAuth.instance.signOut();
      return const LoginScreen();
    } catch (e) {
      print('Error determining home page: $e');
      await FirebaseAuth.instance.signOut();
      return const LoginScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading spinner while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // If user is logged in, determine their dashboard
        if (snapshot.hasData && snapshot.data != null) {
          return FutureBuilder<Widget>(
            future: _determineHomePage(snapshot.data!),
            builder: (context, futureSnapshot) {
              if (futureSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (futureSnapshot.hasData) {
                return futureSnapshot.data!;
              }

              return const LoginScreen();
            },
          );
        }

        // No user logged in, show login screen
        return const LoginScreen();
      },
    );
  }
}
