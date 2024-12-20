import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uchat/pages/UserSelectionPage.dart';
import 'chatpage.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isSearching = false;
  TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _chatHistory = [];

  @override
  void initState() {
    super.initState();
    _fetchChatHistory(); // Récupérer l'historique des discussions lors de l'initialisation
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
          });
        }

        for (var doc in receivedMessagesSnapshot.docs) {
          messages.add({
            'senderId': doc['senderId'],
            'receiverId': doc['receiverId'],
            'text': doc['text'],
            'timestamp': doc['createdAt'],
          });
        }

        print("Messages récupérés : $messages"); // Ajout d'un log

        Map<String, Map<String, dynamic>> latestMessages = {};
        for (var message in messages) {
          String otherUserId = message['senderId'] == currentUserId
              ? message['receiverId']
              : message['senderId'];

          // Récupérez les informations de l'utilisateur depuis la collection 'users'
          DocumentSnapshot userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(otherUserId)
              .get();

          if (userDoc.exists) {
            String userName = userDoc['name'] ??
                'Nom inconnu'; // Récupérez le nom de l'utilisateur, utilisez 'Nom inconnu' si non disponible
            if (!latestMessages.containsKey(otherUserId) ||
                (message['timestamp'] as Timestamp)
                        .compareTo(latestMessages[otherUserId]!['timestamp']) >
                    0) {
              latestMessages[otherUserId] = {
                'lastMessage': message['text'],
                'timestamp': message['timestamp'],
                'userId': otherUserId,
                'userName': userName, // Ajoutez le nom ici
              };
            }
          } else {
            print("Utilisateur non trouvé pour ID: $otherUserId");
          }
        }

        setState(() {
          _chatHistory = latestMessages.entries.map((entry) {
            return {
              'userId': entry.value['userId'],
              'userName': entry.value['userName'], // Ajoutez le nom ici
              'lastMessage': entry.value['lastMessage'],
              'time': entry.value['timestamp'],
            };
          }).toList();
        });

        print(
            "Historique de chat : $_chatHistory"); // Log pour vérifier l'historique
      } catch (e) {
        print("Erreur lors de la récupération des messages : $e");
      }
    } else {
      print("Aucun utilisateur connecté.");
    }
  }

  void _onSearchTextChanged(String query) {
    // Vous pouvez implémenter une recherche ici si nécessaire
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
          ? Center(
              child: Text("Aucune discussion trouvée. Commencez à discuter!"))
          : ListView.builder(
              itemCount: _chatHistory.length,
              itemBuilder: (context, index) {
                final chat = _chatHistory[index];
                return ListTile(
                  title:
                      Text(chat['userName']), // Affiche le nom de l'utilisateur
                  subtitle: Text(chat['lastMessage']),
                  trailing: Text(
                    (chat['time'] as Timestamp)
                        .toDate()
                        .toString(), // Formatez la date ici
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatPage(
                          userId: chat['userId'],
                          userName: chat['userName'], // Utilisez le nom ici
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
        child: const Icon(Icons.message),
        backgroundColor: Colors.purple,
      ),
    );
  }
}
