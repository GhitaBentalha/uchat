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
  final TextEditingController _controller = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

  // Mark messages as read
  void _markMessagesAsReadOnInit(String chatUserId) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId != null) {
      QuerySnapshot unreadMessages = await FirebaseFirestore.instance
          .collection('messages')
          .where('senderId', isEqualTo: chatUserId)
          .where('receiverId', isEqualTo: currentUserId)
          .where('isRead', isEqualTo: false)
          .get();

      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (var doc in unreadMessages.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    }
  }

  @override
  void initState() {
    super.initState();
    _markMessagesAsReadOnInit(
        widget.userId); // Mark messages as read when accessing the chat
  }

  // Send a message
  void _sendMessage() async {
    if (_controller.text.isNotEmpty) {
      await _firestore.collection('messages').add({
        'text': _controller.text,
        'createdAt': FieldValue.serverTimestamp(),
        'senderId': currentUserId,
        'receiverId': widget.userId,
        'isRead': false, // By default, the message is marked as unread
        'delivered': false, // By default, the message is marked as undelivered
      });

      _controller.clear();
    }
  }

  // Delete a message
  void _deleteMessage(String messageId) async {
    await _firestore.collection('messages').doc(messageId).delete();
  }

  // Show a confirmation dialog for deletion
  void _showDeleteConfirmation(String messageId, bool isSender) {
    if (isSender) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Message'),
          content: const Text('Are you sure you want to delete this message?'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(ctx).pop();
              },
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () {
                _deleteMessage(messageId);
                Navigator.of(ctx).pop();
              },
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.grey[300],
              child: Text(
                widget.userName[0].toUpperCase(),
                style: const TextStyle(color: Colors.black),
              ),
            ),
            const SizedBox(width: 8),
            Text(widget.userName),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () {
                // Handle logout
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('messages')
                  .where('senderId', whereIn: [currentUserId, widget.userId])
                  .where('receiverId', whereIn: [currentUserId, widget.userId])
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                      child: Text('Error: ${snapshot.error.toString()}'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No messages yet.'));
                }

                final messages = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isSender = message['senderId'] == currentUserId;

                    return GestureDetector(
                      onLongPress: () {
                        _showDeleteConfirmation(message.id, isSender);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 16),
                        child: Row(
                          mainAxisAlignment: isSender
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                          children: [
                            if (!isSender) const SizedBox(width: 8),
                            Flexible(
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 250),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10, horizontal: 14),
                                  decoration: BoxDecoration(
                                    color: isSender
                                        ? Color.fromARGB(144, 248, 74, 248)
                                        : Colors.grey[200],
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(15),
                                      topRight: const Radius.circular(15),
                                      bottomLeft: isSender
                                          ? const Radius.circular(15)
                                          : const Radius.circular(0),
                                      bottomRight: isSender
                                          ? const Radius.circular(0)
                                          : const Radius.circular(15),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        message['text'],
                                        style: TextStyle(
                                          color: isSender
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      if (isSender) // Show checkmarks only for sent messages
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            if (!message['delivered'])
                                              Icon(
                                                Icons.check,
                                                size: 16,
                                                color: Colors.grey,
                                              ),
                                            if (message['delivered'] &&
                                                !message['isRead'])
                                              Icon(
                                                Icons.check,
                                                size: 16,
                                                color: Colors.grey,
                                              ),
                                            if (message['isRead'])
                                              Icon(
                                                Icons.check,
                                                size: 16,
                                                color: Colors.blue,
                                              ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (isSender) const SizedBox(width: 8),
                          ],
                        ),
                      ),
                    );
                  },
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
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      filled: true,
                      fillColor:
                          isDarkMode ? Colors.grey[800] : Colors.grey[200],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
                    ),
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
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
