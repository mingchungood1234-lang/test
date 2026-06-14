import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class CallScreen extends StatefulWidget {
  const CallScreen({super.key});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final _phoneController = TextEditingController();
  final List<String> _recentCalls = [];

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _makeCall(String number) async {
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
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
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
          Expanded(
            child: Padding(
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
          ),

          // Call button
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: SizedBox(
              width: 80,
              height: 80,
              child: FloatingActionButton(
                onPressed: () {
                  if (_phoneController.text.isNotEmpty) {
                    _makeCall(_phoneController.text);
                  }
                },
                backgroundColor: Colors.green,
                elevation: 4,
                child: const Icon(
                  Icons.phone,
                  size: 36,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          // Recent calls section
          if (_recentCalls.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Recent',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _recentCalls.length,
                itemBuilder: (context, index) {
                  final number = _recentCalls[index];
                  return GestureDetector(
                    onTap: () => _makeCall(number),
                    child: Container(
                      width: 80,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor:
                                Theme.of(context).colorScheme.primary.withAlpha(30),
                            child: Icon(
                              Icons.phone,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            number.length > 10
                                ? '${number.substring(0, 10)}...'
                                : number,
                            style: const TextStyle(fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildDialRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((digit) {
        return GestureDetector(
          onTap: () => _onDigitPressed(digit),
          onTapDown: (_) => setState(() {}),
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
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
