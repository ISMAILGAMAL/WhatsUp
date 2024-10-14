import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:whatsup/synchronization.dart';

class Chatlistener {
  Chatlistener._internal();

  static final Chatlistener _instance = Chatlistener._internal();

  factory Chatlistener() => _instance;

  final List<StreamSubscription> _listeners = [];

  void addListener(StreamSubscription listener) {
    _listeners.add(listener);
  }

  void cancelListeners() {
    for (final listener in _listeners) {
      listener.cancel();
    }
    _listeners.clear();
  }

  Future<void> listenForIncomingMessages(BuildContext context) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final messageProvider =
        Provider.of<MessageProvider>(context, listen: false);

    StreamSubscription incomingMessagesListener = FirebaseFirestore.instance
        .collection('messages')
        .where('recipientId', isEqualTo: currentUser!.uid)
        .snapshots()
        .listen(
      (snapshot) async {
        WriteBatch batch = FirebaseFirestore.instance.batch();

        for (final change in snapshot.docChanges) {
          Map<String, dynamic> message =
              change.doc.data() as Map<String, dynamic>;

          if (change.type == DocumentChangeType.added) {
            if (messageProvider.currentChat.isEmpty) {
              message['status'] = 'received';
              batch.update(change.doc.reference, {'status': 'received'});
              messageProvider.loadChats();
            } else {
              message['status'] = 'read';
              batch.update(change.doc.reference, {'status': 'read'});
            }
            messageProvider.addMessage(message);
          } else if (change.type == DocumentChangeType.modified) {
            messageProvider.updateMessage(message);
          }
        }

        await batch.commit().then((_) {
          print("Status updated to 'received'");
        }).catchError((error) {
          print("Error updating message status: $error");
        });
      },
    );

    addListener(incomingMessagesListener);
  }

  Future<void> listenForSentMessagesUpdates(BuildContext context) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final messageProvider =
        Provider.of<MessageProvider>(context, listen: false);

    StreamSubscription sentMessagesListener = FirebaseFirestore.instance
        .collection('messages')
        .where('senderId', isEqualTo: currentUser!.uid)
        .snapshots()
        .listen(
      (snapshot) {
        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            messageProvider
                .addMessage(change.doc.data() as Map<String, dynamic>);
          }
          if (change.type == DocumentChangeType.modified) {
            messageProvider
                .updateMessage(change.doc.data() as Map<String, dynamic>);
          }
        }
      },
    );

    addListener(sentMessagesListener);
  }
}
