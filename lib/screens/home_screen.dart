import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:whatsup/chat_listener.dart';
import 'package:whatsup/database.dart';
import 'package:whatsup/screens/chat_screen.dart';
import 'package:whatsup/screens/login.dart';
import 'package:whatsup/screens/search_screen.dart';
import 'package:whatsup/screens/settings_screen.dart';
import 'package:whatsup/widgets/empty_creens.dart';
import 'package:whatsup/synchronization.dart';
import 'package:whatsup/widgets/user_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() {
    return _HomeScreenState();
  }
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  Widget content = const Center(child: CircularProgressIndicator());
  DatabaseHelper? db;
  final Chatlistener chatListener = Chatlistener();
  List<Map<String, dynamic>>? chats;

  @override
  void initState() {
    super.initState();
    db = DatabaseHelper();
    syncMessages();
    chatListener.listenForIncomingMessages(context);
    chatListener.listenForSentMessagesUpdates(context);
  }

  @override
  void dispose() {
    db!.resetDatabase();
    chatListener.cancelListeners();
    super.dispose();
  }

  Future<void> signOut(MessageProvider messageProvider) async {
    await FirebaseAuth.instance.signOut();
    await Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
    messageProvider.clearChats();
  }

  Future<void> syncMessages() async {
    await syncMessagesToLocalDatabase(context);
    await syncChatsToLocalDatabase();

    if (mounted) {
      final messageProvider =
          Provider.of<MessageProvider>(context, listen: false);
      await messageProvider.loadChats();
    }
  }

  Future<void> enterChat(
      MessageProvider messageProvider, Map<String, dynamic> user) async {
    messageProvider.setCurrentChat(user['id']);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(chat: user),
      ),
    );
    messageProvider.removeCurrentChat();
    messageProvider.clearMessages();
  }

  Widget chatList(MessageProvider messageProvider) {
    return messageProvider.chats.isNotEmpty
        ? ListView.builder(
            controller: _scrollController,
            itemCount: messageProvider.chats.length,
            itemBuilder: (context, index) {
              final user = messageProvider.chats[index];

              return UserCard(
                user: user,
                onTap: () => enterChat(messageProvider, user),
              );
            },
          )
        : const EmptyHomeScreen();
  }

  @override
  Widget build(BuildContext context) {
    final messageProvider = Provider.of<MessageProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'lib/assets/cat_waving.png',
              height: 55,
            ),
            const Text(
              'WhatsUp',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 101, 249, 178),
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.teal,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (String item) async {
              if (item == 'signOut') {
                await signOut(messageProvider);
              } else if (item == 'settings') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (BuildContext ctx) => const SettingsScreen()),
                );
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'settings',
                child: Text('Settings'),
              ),
              const PopupMenuItem<String>(
                value: 'signOut',
                child: Text('Sign Out'),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SearchScreen(),
            ),
          );
        },
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.search),
      ),
      body: chatList(messageProvider),
    );
  }
}
