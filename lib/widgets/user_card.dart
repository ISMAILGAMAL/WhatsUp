import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class UserCard extends StatelessWidget {
  const UserCard({super.key, required this.user, required this.onTap});
  final Map<String, dynamic> user;
  final void Function() onTap;

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 1.0),
      elevation: 2,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          radius: 30,
          backgroundImage: user['profileUrl'] != null
              ? NetworkImage(user['profileUrl'])
              : null,
          child: user['profileUrl'] == null
              ? const Icon(Icons.person, size: 30, color: Colors.grey)
              : null,
        ),
        title: Text(
          user['uid'] == currentUser!.uid
              ? '${user['name']} (You)'
              : user['name'],
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          user['email'],
          style: const TextStyle(color: Colors.grey),
        ),
        trailing: (user['unreadCount'] ?? 0) > 0
            ? CircleAvatar(
                radius: 12,
                backgroundColor: Colors.red,
                child: Text(
                  user['unreadCount'].toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              )
            : null, // Show the badge only if there are unread messages
      ),
    );
  }
}
