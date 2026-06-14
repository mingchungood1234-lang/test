import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../models/user.dart';
import 'webrtc_call_screen.dart';

class CallScreen extends StatefulWidget {
  const CallScreen({super.key});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final _phoneController = TextEditingController();
  final List<String> _recentCalls = [];
  final List<User> _contacts = [];
  bool _isLoadingContacts = false;
  bool _showDialer = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() => _isLoadingContacts = true);
    try {
      final token = await AuthService.getToken();
      if (token != null) {
        final result = await ApiService.getProfile(token);
        if (result['success'] && result['user'] != null) {
          // For demo, show the current user as a contact
          // In production, you'd have a contacts/friends API
          setState(() {
            _contacts.add(result['user']);
          });
        }
      }
    } catch (e) {
      // Silent fail
    }
    setState(() => _isLoadingContacts = false);
  }

  Future<void> _makeNativeCall(String number) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
      setState(() {
        _recentCalls.remove(number);
        _recentCalls.insert(0, number);
      });
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not launch phone dialer'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _startVoipCall(User targetUser, {required bool video}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WebRTCCallScreen(
          targetUserId: targetUser.id,
          targetUserName: targetUser.name,
          isVideo: video,
        ),
      ),
    );
  }

  void _onDigitPressed(String digit) {
    setState(() {
      _phoneController.text += digit;
    });
  }

  void _onBackspace() {
    if (_phoneController.text.isNotEmpty) {
      setState(() {
        _phoneController.text =
            _phoneController.text.substring(0, _phoneController.text.length - 1);
      });
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // Toggle between Dialer and Contacts
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _showDialer = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _showDialer
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.dialpad,
                            size: 20,
                            color: _showDialer ? Colors.white : Colors.grey[600],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Dialer',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _showDialer ? Colors.white : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _showDialer = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: !_showDialer
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.wifi_calling,
                            size: 20,
                            color: !_showDialer ? Colors.white : Colors.grey[600],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'VoIP Calls',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: !_showDialer ? Colors.white : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_showDialer) _buildDialerView() else _buildContactsView(),
        ],
      ),
    );
  }

  Widget _buildDialerView() {
    return Column(
      children: [
        const SizedBox(height: 20),
        // Phone number display
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: TextField(
            controller: _phoneController,
            textAlign: TextAlign.center,
            readOnly: true,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w300,
              letterSpacing: 2,
            ),
            decoration: InputDecoration(
              hintText: 'Enter number',
              hintStyle: TextStyle(
                fontSize: 24,
                color: Colors.grey[400],
                fontWeight: FontWeight.w300,
              ),
              border: InputBorder.none,
              suffixIcon: _phoneController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.backspace_outlined),
                      onPressed: _onBackspace,
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Dial pad
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            children: [
              _buildDialRow(['1', '2', '3']),
              const SizedBox(height: 12),
              _buildDialRow(['4', '5', '6']),
              const SizedBox(height: 12),
              _buildDialRow(['7', '8', '9']),
              const SizedBox(height: 12),
              _buildDialRow(['*', '0', '#']),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Native call button
        SizedBox(
          width: 80,
          height: 80,
          child: FloatingActionButton(
            onPressed: () {
              if (_phoneController.text.isNotEmpty) {
                _makeNativeCall(_phoneController.text);
              }
            },
            backgroundColor: Colors.green,
            elevation: 4,
            child: const Icon(Icons.phone, size: 36, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildContactsView() {
    return Expanded(
      child: _isLoadingContacts
          ? const Center(child: CircularProgressIndicator())
          : _contacts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'No contacts yet',
                        style: TextStyle(fontSize: 18, color: Colors.grey[500]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Register another user to start calling',
                        style: TextStyle(color: Colors.grey[400], fontSize: 13),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _contacts.length,
                  itemBuilder: (context, index) {
                    final contact = _contacts[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary.withAlpha(30),
                          child: Text(
                            contact.name.isNotEmpty
                                ? contact.name[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                        title: Text(
                          contact.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          contact.email,
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.phone, color: Colors.green),
                              onPressed: () => _startVoipCall(contact, video: false),
                              tooltip: 'Audio Call',
                            ),
                            IconButton(
                              icon: const Icon(Icons.videocam, color: Colors.blue),
                              onPressed: () => _startVoipCall(contact, video: true),
                              tooltip: 'Video Call',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildDialRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((digit) {
        return GestureDetector(
          onTap: () => _onDigitPressed(digit),
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[100],
            ),
            alignment: Alignment.center,
            child: Text(
              digit,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w300),
            ),
          ),
        );
      }).toList(),
    );
  }
}
