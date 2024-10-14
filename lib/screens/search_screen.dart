import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:whatsup/database.dart';
import 'package:whatsup/synchronization.dart';
import 'package:whatsup/widgets/empty_creens.dart';
import 'package:whatsup/widgets/user_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() {
    return _SearchScreenState();
  }
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final int querySizeLimit = 20;
  String _searchBy = 'Name';
  Timer? _debounce;
  List<Map<String, dynamic>> searchResults = [];
  Widget? content;
  DocumentSnapshot? lastDocument;

  @override
  void initState() {
    super.initState();
    content = const EmptySearchScreenText();
    _scrollController.addListener(onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    super.dispose();
  }

  void _showAddUserDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add Friend'),
          content: Text('Do you want to add ${user['name']} to your contacts?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Add'),
              onPressed: () {
                final currentUser = FirebaseAuth.instance.currentUser;
                final db = DatabaseHelper();
                final messageProvider = Provider.of<MessageProvider>(context, listen:  false);

                Map<String, dynamic> chat = {
                  'id': db.generateChatId(user['uid'], currentUser!.uid),
                  'uid': user['uid'],
                  'name': user['name'],
                  'email': user['email'],
                  'profileUrl': user['profileUrl'],
                  'unreadCount': 0,
                };

                messageProvider.addChat(chat);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget get resultsList {
    return ListView.builder(
      controller: _scrollController,
      itemCount: searchResults.length,
      itemBuilder: (context, index) {
        final user = searchResults[index];
        return UserCard(user: user, onTap: () => _showAddUserDialog(user));
      },
    );
  }

  void onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      addSearchResults(_searchController.text.trim());
    }
  }

  void onSearchChange() {
    // Cancel timer if not null and timer is active.
    if ((_debounce?.isActive ?? false)) _debounce!.cancel();

    if (_searchController.text.trim().length >= 4) {
      _debounce = Timer(const Duration(milliseconds: 1000), () {
        searchForUser(_searchController.text.trim());
      });
    } else if (_searchController.text.trim().isEmpty) {
      searchResults = [];
      setState(() {
        content = const EmptySearchScreenText();
      });
    } else {
      searchResults = [];
      setState(() {
        content =
            const Center(child: Text('Please type at least 4 characters.'));
      });
    }
  }

  void searchForUser(String searchTerm) async {
    try {
      final usersRef = FirebaseFirestore.instance.collection('users');
      QuerySnapshot querySnapshot;

      if (_searchBy == 'Name') {
        searchTerm = searchTerm.toLowerCase();
        querySnapshot = await usersRef
            .where('nameLower', isGreaterThanOrEqualTo: searchTerm)
            .where('nameLower', isLessThanOrEqualTo: '$searchTerm\uf8ff')
            .orderBy('nameLower')
            .limit(querySizeLimit)
            .get();
      } else {
        querySnapshot = await usersRef
            .where('email', isGreaterThanOrEqualTo: searchTerm)
            .where('email', isLessThanOrEqualTo: '$searchTerm\uf8ff')
            .limit(querySizeLimit)
            .get();
      }

      if (querySnapshot.docs.isEmpty) {
        setState(() {
          content = const Center(child: Text('No results.'));
        });
        return;
      }

      lastDocument = querySnapshot.docs.last;

      List<Map<String, dynamic>> results = querySnapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();

      setState(() {
        searchResults = results;
        content = resultsList;
      });
    } catch (e) {
      // Display error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load more results: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void addSearchResults(String searchTerm) async {
    try {
      final usersRef = FirebaseFirestore.instance.collection('users');
      QuerySnapshot querySnapshot;
      Query query;
      if (_searchBy == 'Name') {
        searchTerm = searchTerm.toLowerCase();
        query = usersRef
            .where('nameLower', isGreaterThanOrEqualTo: searchTerm)
            .where('nameLower', isLessThanOrEqualTo: '$searchTerm\uf8ff')
            .orderBy('nameLower');
      } else {
        query = usersRef
            .where('email', isGreaterThanOrEqualTo: searchTerm)
            .where('email', isLessThanOrEqualTo: '$searchTerm\uf8ff')
            .orderBy('email');
      }

      query = query.limit(querySizeLimit).startAfterDocument(lastDocument!);

      querySnapshot = await query.get();

      if (querySnapshot.docs.isEmpty) {
        // No more results to load
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No more results.'),
            backgroundColor: Colors.grey,
          ),
        );
        return;
      }

      lastDocument = querySnapshot.docs.last;

      List<Map<String, dynamic>> results = querySnapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();

      setState(() {
        searchResults.addAll(results);
        content = resultsList;
      });
    } catch (e) {
      // Display error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load more results: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search For Your Friends'),
        backgroundColor: Colors.teal,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    maxLength: 50,
                    controller: _searchController,
                    decoration: InputDecoration(
                      counterText: '',
                      filled: true,
                      fillColor: Colors.white,
                      hintText: 'Search...',
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20.0),
                        borderSide:
                            const BorderSide(color: Colors.teal, width: 2),
                      ),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20.0),
                          borderSide: BorderSide(color: Colors.teal[300]!)),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
                    ),
                    onChanged: (value) {
                      onSearchChange();
                    },
                  ),
                ),
                const SizedBox(width: 16),
                DropdownButton<String>(
                  value: _searchBy,
                  onChanged: (String? newValue) {
                    setState(() {
                      _searchBy = newValue!;
                      onSearchChange();
                    });
                  },
                  items: <String>['Name', 'Email']
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  underline: const SizedBox(),
                ),
              ],
            ),
          ),
          Expanded(
            child: content!,
          ),
        ],
      ),
    );
  }
}
