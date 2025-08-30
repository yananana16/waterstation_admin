import 'package:flutter/material.dart';

class LogoutDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: Colors.white,
      child: SizedBox(
        width: 340,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: Colors.blueAccent.withOpacity(0.1),
                child: const Icon(Icons.logout, color: Colors.blueAccent, size: 38),
              ),
              const SizedBox(height: 18),
              const Text(
                "Logout Confirmation",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  color: Colors.blueAccent,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Are you sure you want to logout?",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 44,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold),
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text("Logout"),
                    ),
                  ),
                  const SizedBox(width: 18),
                  SizedBox(
                    width: 120,
                    height: 44,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blueAccent,
                        side: const BorderSide(color: Colors.blueAccent, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text("Cancel"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
