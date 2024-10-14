import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:whatsup/synchronization.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.chat});
  final Map<String, dynamic> chat;

  @override
  State<ChatScreen> createState() {
    return _ChatScreenState();
  }
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final User? currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    markMessagesAsRead(widget.chat['id'], context);
  }

  Future<void> sendMessage(String content) async {
    if (content.isEmpty) return;
    final senderId = currentUser!.uid, recipientId = widget.chat['uid'];

    Map<String, dynamic> message = {
      'id': uuid.v4(),
      'chatId': widget.chat['id'],
      'content': content,
      'senderId': senderId,
      'recipientId': recipientId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'status': 'pending',
    };

    final messageProvider =
        Provider.of<MessageProvider>(context, listen: false);
    messageProvider.addMessage(message);

    sendPendingMessagesToFirestore(widget.chat);
    _messageController.clear();
  }

  Widget buildMessage(Map<String, dynamic> message) {
    bool isCurrentUser = message['senderId'] == currentUser!.uid;

    return Align(
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth:
              MediaQuery.of(context).size.width * 0.7, // Limit width to 70%
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isCurrentUser
                ? const Color.fromARGB(255, 89, 203, 122)
                : const Color.fromARGB(255, 119, 230, 255),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                message['content'],
                style: TextStyle(
                    color: isCurrentUser ? Colors.white : Colors.black),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message['timestamp'] != null)
                  Text(
                    formatTimestamp(message['timestamp']),
                    style: TextStyle(
                      fontSize: 10,
                      color: isCurrentUser ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(width: 5),
                  if (isCurrentUser) ...[
                    Icon(
                      (message['status'] == 'pending')
                          ? Icons.access_time_sharp
                          : (message['status'] == 'read' || message['status'] == 'received')
                          ? Icons.done_all
                          : Icons.check,
                      size: 16,
                      color: message['status'] == 'read'
                          ? const Color.fromARGB(255, 0, 251, 255)
                          : Colors.white70,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String formatTimestamp(int timestamp) {
    DateTime date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    int hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    return "$hour:${date.minute.toString().padLeft(2, '0')} ${date.hour < 12 ? 'AM' : 'PM'}";
  }

  @override
  Widget build(BuildContext context) {
    final messageProvider = Provider.of<MessageProvider>(context);
    messageProvider.loadMessages(widget.chat['id']);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            widget.chat['profileUrl'] != null
                ? CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.grey,
                    backgroundImage: NetworkImage(widget.chat['profileUrl']),
                  )
                : const CircleAvatar(
                    backgroundColor: Colors.grey,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
            const SizedBox(width: 8),
            Text(
              widget.chat['name'],
              style: const TextStyle(fontSize: 20),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        backgroundColor: Colors.teal,
        elevation: 0,
      ),
      body: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    reverse: true,
                    itemCount: min(messageProvider.messages.length, 50),
                    itemBuilder: (context, index) {
                      final message = messageProvider.messages[index];
                      return buildMessage(message);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: TextField(
                            controller: _messageController,
                            decoration: const InputDecoration(
                              hintText: 'Type a message...',
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FloatingActionButton(
                        onPressed: () {
                          sendMessage(_messageController.text.trim());
                        },
                        mini: true,
                        backgroundColor: Colors.teal,
                        child: const Icon(Icons.send, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
