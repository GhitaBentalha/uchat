import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatPage extends StatefulWidget {
  final String userId; // ID of the user you're chatting with
  final String userName; // Name of the user you're chatting with

  const ChatPage({super.key, required this.userId, required this.userName});

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> _messages = [];
  bool _isTyping = false;

  // Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String currentUserId =
      FirebaseAuth.instance.currentUser!.uid; // Get the current user's ID

  void _sendMessage() {
    if (_controller.text.isNotEmpty) {
      // Add message to Firestore
      _firestore.collection('messages').add({
        'text': _controller.text,
        'createdAt': Timestamp.now(),
        'senderId': currentUserId,
        'receiverId': widget.userId, // Store the ID of the receiver
      });

      _controller.clear();
      setState(() {
        _isTyping = false;
      });
    }
  }

  void _onTyping(String text) {
    setState(() {
      _isTyping = text.isNotEmpty;
    });
  }

  @override
  void initState() {
    super.initState();
    // Listen for messages for the current conversation
    _firestore
        .collection('messages')
        .where('senderId', whereIn: [currentUserId, widget.userId])
        .where('receiverId', whereIn: [currentUserId, widget.userId])
        .orderBy('createdAt')
        .snapshots()
        .listen((snapshot) {
          snapshot.docChanges.forEach((change) {
            if (change.type == DocumentChangeType.added) {
              setState(() {
                _messages.insert(0, {
                  'text': change.doc['text'],
                  'senderId': change.doc['senderId'],
                  'receiverId': change.doc['receiverId'],
                }); // Insert message at the top
              });
            }
          });
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.userName), // Display the user's name
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              // Handle logout functionality here
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                bool isSender = _messages[index]['senderId'] ==
                    currentUserId; // Check if the current user sent the message
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Align(
                    alignment:
                        isSender ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 18),
                      decoration: BoxDecoration(
                        color: isSender ? Colors.blueAccent : Colors.grey[200],
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            offset: const Offset(0, 2),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Text(
                        _messages[index]['text'],
                        style: TextStyle(
                          color: isSender ? Colors.white : Colors.black87,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onChanged: _onTyping,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      filled: true,
                      fillColor: Colors.grey[200],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _isTyping ? Icons.send : Icons.mic,
                    color: Colors.blueAccent,
                  ),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
