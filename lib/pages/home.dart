import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uchat/pages/UserSelectionPage.dart';
import 'chatpage.dart';
import 'package:intl/intl.dart';

class UserAvatar extends StatelessWidget {
  final String userName;

  const UserAvatar({Key? key, required this.userName}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String firstLetter = userName.isNotEmpty ? userName[0].toUpperCase() : '?';

    return Container(
      width: 40.0,
      height: 40.0,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.purple,
      ),
      alignment: Alignment.center,
      child: Text(
        firstLetter,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 20.0,
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _chatHistory = [];
  List<Map<String, dynamic>> _filteredChatHistory = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchChatHistory();
    _startTimer();
  }

/*
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
*/
  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 10), (Timer timer) {
      _fetchChatHistory();
    });
  }

  void _fetchChatHistory() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId != null) {
      try {
        QuerySnapshot sentMessagesSnapshot = await FirebaseFirestore.instance
            .collection('messages')
            .where('senderId', isEqualTo: currentUserId)
            .get();

        QuerySnapshot receivedMessagesSnapshot = await FirebaseFirestore
            .instance
            .collection('messages')
            .where('receiverId', isEqualTo: currentUserId)
            .get();

        List<Map<String, dynamic>> messages = [];

        for (var doc in sentMessagesSnapshot.docs) {
          messages.add({
            'senderId': doc['senderId'],
            'receiverId': doc['receiverId'],
            'text': doc['text'],
            'timestamp': doc['createdAt'],
            'delivered': doc['delivered'] ?? false,
          });
        }

        for (var doc in receivedMessagesSnapshot.docs) {
          messages.add({
            'senderId': doc['senderId'],
            'receiverId': doc['receiverId'],
            'text': doc['text'],
            'timestamp': doc['createdAt'],
            'delivered': doc['delivered'] ?? false,
          });
        }

        Map<String, Map<String, dynamic>> latestMessages = {};
        for (var message in messages) {
          String otherUserId = message['senderId'] == currentUserId
              ? message['receiverId']
              : message['senderId'];

          DocumentSnapshot userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(otherUserId)
              .get();

          if (userDoc.exists) {
            String userName = userDoc['name'] ?? 'Unknown';

            int newMessagesCount = (message['receiverId'] == currentUserId &&
                    !message['delivered'])
                ? 1
                : 0;

            if (latestMessages.containsKey(otherUserId)) {
              newMessagesCount +=
                  (latestMessages[otherUserId]!['newMessagesCount'] ?? 0)
                      as int;
            }

            if (!latestMessages.containsKey(otherUserId) ||
                (message['timestamp'] as Timestamp)
                        .compareTo(latestMessages[otherUserId]!['timestamp']) >
                    0) {
              latestMessages[otherUserId] = {
                'lastMessage': message['text'],
                'timestamp': message['timestamp'],
                'userId': otherUserId,
                'userName': userName,
                'newMessagesCount': newMessagesCount,
                'delivered': message['delivered'],
              };
            }
          }
        }

        setState(() {
          _chatHistory = latestMessages.entries.map((entry) {
            return {
              'userId': entry.value['userId'],
              'userName': entry.value['userName'],
              'lastMessage': entry.value['lastMessage'],
              'time': entry.value['timestamp'],
              'newMessagesCount': entry.value['newMessagesCount'],
              'delivered': entry.value['delivered'],
            };
          }).toList()
            ..sort((a, b) => (b['time'] as Timestamp).compareTo(a['time']));
          _filteredChatHistory =
              List.from(_chatHistory); // Initialize filtered chat history
        });
      } catch (e) {
        print("Error fetching messages: $e");
      }
    }
  }

  String _formatTime(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();

    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return DateFormat.jm().format(date);
    } else if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1) {
      return "Yesterday";
    } else {
      return DateFormat('MMM dd, HH:mm').format(date);
    }
  }

  void _filterChatHistory(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredChatHistory = List.from(_chatHistory); // Reset filter
      } else {
        _filteredChatHistory = _chatHistory.where((chat) {
          return chat['lastMessage']
              .toString()
              .toLowerCase()
              .contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white70),
                ),
                style: TextStyle(color: Colors.white),
                onChanged: _filterChatHistory,
              )
            : const Text('ChatUp'),
        backgroundColor: Colors.purple,
        leading: IconButton(
          icon: const Icon(Icons.logout), // Logout button
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _filterChatHistory(''); // Reset the filtered chat history
                }
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _filteredChatHistory.isEmpty
                ? Center(child: Text("No chats found. Start chatting!"))
                : ListView.builder(
                    itemCount: _filteredChatHistory.length,
                    itemBuilder: (context, index) {
                      final chat = _filteredChatHistory[index];
                      return ListTile(
                        leading: UserAvatar(userName: chat['userName']),
                        title: Text(chat['userName']),
                        subtitle: Row(
                          children: [
                            Expanded(child: Text(chat['lastMessage'])),
                            if (chat['newMessagesCount'] > 0)
                              Container(
                                margin: const EdgeInsets.only(left: 8.0),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8.0, vertical: 4.0),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${chat['newMessagesCount']}',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                        trailing: Text(_formatTime(chat['time'] as Timestamp)),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatPage(
                                userId: chat['userId'],
                                userName: chat['userName'],
                              ),
                            ),
                          ).then((value) {
                            _fetchChatHistory();
                          });
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => UserSelectionPage()),
          ).then((value) {
            _fetchChatHistory();
          });
        },
        backgroundColor: Colors.purple,
        child: const Icon(Icons.chat),
      ),
    );
  }
}
