import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:whatsup/database.dart';

const uuid = Uuid();

Future<void> sendPendingMessagesToFirestore(Map<String, dynamic> chat) async {
  final db = DatabaseHelper();
  List<Map<String, dynamic>> unsynced =
      await db.allUnsyncedMessagesForChat(chat);

  if (unsynced.isNotEmpty) {
    WriteBatch batch = FirebaseFirestore.instance.batch();

    for (final message in unsynced) {
      final messageToSend = Map<String, dynamic>.from(message);
      messageToSend['status'] = 'sent';
      messageToSend['timestamp'] = FieldValue.serverTimestamp();

      // Use server timestamp
      DocumentReference docRef = FirebaseFirestore.instance
          .collection('messages')
          .doc(messageToSend['id']);
      batch.set(docRef, messageToSend);
    }

    // After that the listener should receive updates about the timestamp and status
    await batch.commit();
  }
}

Future<void> syncMessagesToLocalDatabase(BuildContext context) async {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  final db = DatabaseHelper();
  final messageProvider = Provider.of<MessageProvider>(context, listen: false);

  final recievedRef = FirebaseFirestore.instance
      .collection('messages')
      .where('recipientId', isEqualTo: uid);
  final sentRef = FirebaseFirestore.instance
      .collection('messages')
      .where('senderId', isEqualTo: uid);

  recievedRef.get().then((querySnapshot) async {
    if (querySnapshot.docs.isNotEmpty) {
      WriteBatch batch = FirebaseFirestore.instance.batch();

      Map<String, int> unreadCounter = {};

      for (final doc in querySnapshot.docs) {
        Map<String, dynamic> message = doc.data();
        if (message['status'] == 'sent') {
          message['status'] = 'received';

          unreadCounter[message['chatId']] =
              (unreadCounter[message['chatId']] ?? 0) + 1;

          messageProvider.addMessage(message);
          batch.update(doc.reference, {'status': 'received'});
        }
      }

      for (final chatId in unreadCounter.keys) {
        await messageProvider.updateChatUnreadCount(
            chatId, unreadCounter[chatId]!);
      }

      await batch.commit().then((_) {
        print("Received messages successfully updated to 'received'");
      }).catchError((error) {
        print("Error updating message status: $error");
      });
    }
  });

  // Record any changes to the messages i sent and then delete any read messages from Firestore
  sentRef.get().then((querySnapshot) async {
    if (querySnapshot.docs.isNotEmpty) {
      WriteBatch batch = FirebaseFirestore.instance.batch();
      List<Map<String, dynamic>> messagesSent = [];

      for (final doc in querySnapshot.docs) {
        messagesSent.add(doc.data());
      }

      List<Map<String, dynamic>> unsynced = await db.getDifferent(messagesSent);

      for (final message in unsynced) {
        await messageProvider.updateMessage(message);
        if (message['status'] == 'read') {
          final docRef = FirebaseFirestore.instance
              .collection('messages')
              .doc(message['id']);
          batch.delete(docRef);
        }
      }

      await batch.commit().then((_) {
        print("Read messages successfully deleted");
      }).catchError((error) {
        print("Error deleting messages: $error");
      });
    }
  });
}

Future<void> syncChatsToLocalDatabase() async {
  final db = DatabaseHelper();
  final chats = await db.allChats;

  List<Future<QuerySnapshot>> futures = [];

  for (final chat in chats) {
    futures.add(FirebaseFirestore.instance
        .collection('users')
        .where('uid', isEqualTo: chat['uid'])
        .get());
  }

  final results = await Future.wait(futures);

  for (final snapshot in results){
    for (final doc in snapshot.docs){
      Map<String, dynamic> chat = doc.data() as Map<String, dynamic>;
      await db.updateChat(chat);
    }
  }
}

Future<void> createChatIfNotExist(Map<String, dynamic> receivedMessage) async {
  final db = DatabaseHelper();
  bool chatExists = await db.searchChat(receivedMessage['chatId']);

  if (!chatExists) {
    DocumentSnapshot senderDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(receivedMessage['senderId'])
        .get();

    if (senderDoc.exists) {
      Map<String, dynamic> senderData =
          senderDoc.data() as Map<String, dynamic>;

      Map<String, dynamic> chat = {
        'id': receivedMessage['chatId'],
        'uid': senderData['uid'],
        'name': senderData['name'],
        'email': senderData['email'],
        'profileUrl': senderData['profileUrl'],
        'unreadCount': 1,
      };
      await db.createNewChat(chat);
    }
  }
}

Future<void> markMessagesAsRead(String chatId, BuildContext context) async {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  final db = DatabaseHelper();
  try {
    final unsynced = await db.allReceivedMessagesForChat(chatId, uid);
    List<Map<String, dynamic>> newMessages = [];
    WriteBatch batch = FirebaseFirestore.instance.batch();

    for (final message in unsynced) {
      final updatedMessage = Map<String, dynamic>.from(message);
      updatedMessage['status'] = 'read';
      newMessages.add(updatedMessage);

      final docRef = FirebaseFirestore.instance
          .collection('messages')
          .doc(updatedMessage['id']);
      batch.update(docRef, {'status': 'read'});
    }

    await batch.commit();
    print("Read messages successfully updated to 'read'");

    final messageProvider =
        Provider.of<MessageProvider>(context, listen: false);

    await db.updateMessages(newMessages);
    await db.updateUnreadCount(chatId, 0);
    await messageProvider.loadChats();
  } catch (e) {
    print('Error marking messages as read: $e');
  }
}

class MessageProvider with ChangeNotifier {
  final DatabaseHelper db = DatabaseHelper();

  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _chats = [];
  String _currentChat = '';

  List<Map<String, dynamic>> get messages => _messages;
  List<Map<String, dynamic>> get chats => _chats;

  // Used to mark messages as read only for the current chat in the listener
  String get currentChat => _currentChat;

  void setCurrentChat(String chatId) {
    _currentChat = chatId;
  }

  void removeCurrentChat() {
    _currentChat = '';
  }

  Future<void> loadChats() async {
    try {
      _chats = await db.allChats;
      notifyListeners();
    } catch (e) {
      print("Failed to load chats: $e");
    }
  }

  Future<void> addChat(Map<String, dynamic> chat) async {
    try {
      await db.createNewChat(chat);
      await loadChats();
    } catch (e) {
      print("Failed to add message: $e");
    }
  }

  Future<void> updateChatUnreadCount(String chatId, int unreadCount) async {
    try {
      await db.updateUnreadCount(chatId, unreadCount);
      await loadChats();
    } catch (e) {
      print("Failed to update message status: $e");
    }
  }

  Future<void> loadMessages(String chatId) async {
    try {
      _messages = await db.allMessagesForChat(chatId);
      notifyListeners();
    } catch (e) {
      print("Failed to load messages: $e");
    }
  }

  Future<void> addMessage(Map<String, dynamic> message) async {
    try {
      await db.createNewMessage(message);
      await createChatIfNotExist(message);
      await loadMessages(message['chatId']);
    } catch (e) {
      print("Failed to add message: $e");
    }
  }

  Future<void> updateMessage(Map<String, dynamic> message) async {
    try {
      await db.updateMessages([message]);
      await loadMessages(message['chatId']);
    } catch (e) {
      print("Failed to update message status: $e");
    }
  }

  void clearMessages() async {
    _messages = [];
  }

  void clearChats() async {
    _chats = [];
  }
}
