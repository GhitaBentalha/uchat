import 'dart:async'; // Importer le package dart:async pour le Timer
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uchat/pages/UserSelectionPage.dart';
import 'chatpage.dart';
import 'package:intl/intl.dart'; // Import the intl package for DateFormat

// UserAvatar widget to display the first letter of the username
class UserAvatar extends StatelessWidget {
  final String userName;

  const UserAvatar({Key? key, required this.userName}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Get the first letter of the username
    String firstLetter = userName.isNotEmpty ? userName[0].toUpperCase() : '?';

    return Container(
      width: 40.0, // Width of the avatar
      height: 40.0, // Height of the avatar
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.purple, // Background color of the avatar
      ),
      alignment: Alignment.center,
      child: Text(
        firstLetter,
        style: TextStyle(
          color: Colors.white, // Text color
          fontWeight: FontWeight.bold,
          fontSize: 20.0, // Font size
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
  Timer? _timer; // Timer pour mettre à jour les discussions

  @override
  void initState() {
    super.initState();
    _fetchChatHistory(); // Fetch chat history on initialization
    _startTimer(); // Start the timer to refresh chat history
  }

  @override
  void dispose() {
    _timer?.cancel(); // Cancel the timer when the widget is disposed
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (Timer timer) {
      _fetchChatHistory(); // Refresh chat history every second
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

        print("Messages fetched: $messages");

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

            // Vérifiez si le message est reçu et n'a pas été lu
            int newMessagesCount = (message['receiverId'] == currentUserId &&
                    !message['delivered'])
                ? 1
                : 0;

            if (!latestMessages.containsKey(otherUserId) ||
                (message['timestamp'] as Timestamp)
                        .compareTo(latestMessages[otherUserId]!['timestamp']) >
                    0) {
              latestMessages[otherUserId] = {
                'lastMessage': message['text'],
                'timestamp': message['timestamp'],
                'userId': otherUserId,
                'userName': userName,
                'newMessagesCount': newMessagesCount, // Count of new messages
                'delivered': message['delivered'], // Add delivered status
              };
            }
          } else {
            print("User not found for ID: $otherUserId");
          }
        }

        // Convert the latest messages map to a list and sort it by timestamp (latest first)
        setState(() {
          _chatHistory = latestMessages.entries.map((entry) {
            return {
              'userId': entry.value['userId'],
              'userName': entry.value['userName'],
              'lastMessage': entry.value['lastMessage'],
              'time': entry.value['timestamp'],
              'newMessagesCount':
                  entry.value['newMessagesCount'], // New messages count
              'delivered': entry
                  .value['delivered'], // Add delivered status to chat history
            };
          }).toList()
            ..sort((a, b) =>
                (b['time'] as Timestamp).compareTo(a['time'])); // Sort by time
        });

        print("Chat history: $_chatHistory");
      } catch (e) {
        print("Error fetching messages: $e");
      }
    } else {
      print("No user logged in.");
    }
  }

  String _formatTime(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();

    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return DateFormat.jm().format(date); // "HH:mm"
    } else if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1) {
      return "Yesterday";
    } else {
      return DateFormat('MMM dd, HH:mm').format(date); // "Jan 01, HH:mm"
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ChatUp'),
        backgroundColor: Colors.purple,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pop(context);
            },
          ),
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                }
              });
            },
          ),
        ],
      ),
      body: _chatHistory.isEmpty
          ? Center(child: Text("No chats found. Start chatting!"))
          : ListView.builder(
              itemCount: _chatHistory.length,
              itemBuilder: (context, index) {
                final chat = _chatHistory[index];
                return ListTile(
                  leading: UserAvatar(userName: chat['userName']),
                  title: Text(chat['userName']),
                  subtitle: Row(
                    children: [
                      Expanded(child: Text(chat['lastMessage'])),
                      // Affiche la bulle rouge uniquement si c'est un message reçu et non lu
                      if (chat['newMessagesCount'] > 0 &&
                          chat['delivered'] == false)
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
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserSelectionPage(),
            ),
          );
        },
        backgroundColor: Colors.purple,
        child: const Icon(Icons.message),
      ),
    );
  }
}
