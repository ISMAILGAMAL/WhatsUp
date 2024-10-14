import 'package:cloud_firestore/cloud_firestore.dart';

Future<bool> isUsernameUnique(String username) async {
    final usersRef = FirebaseFirestore.instance.collection('users');
    final querySnapshot =
        await usersRef.where('name', isEqualTo: username).get();
    return querySnapshot.docs.isEmpty; // True if username is unique
  }