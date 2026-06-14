import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/env.dart';

class SignalingService {
  late io.Socket _socket;
  final StreamController<Map<String, dynamic>> _eventController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get events => _eventController.stream;

  bool get isConnected => _socket.connected;

  /// Connect to the signaling server
  void connect(String userId) {
    _socket = io.io(
      Env.apiBaseUrl.replaceAll('/api', ''),
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(1000)
          .setReconnectionAttempts(10)
          .build(),
    );

    _socket.onConnect((_) {
      debugPrint('Signaling connected');
      _socket.emit('register', userId);
    });

    _socket.onDisconnect((_) {
      debugPrint('Signaling disconnected');
    });

    _socket.onReconnect((_) {
      debugPrint('Signaling reconnected');
      _socket.emit('register', userId);
    });

    // Listen for call events
    _socket.on('incoming_call', (data) {
      _eventController.add({'type': 'incoming_call', 'data': data});
    });

    _socket.on('call_accepted', (data) {
      _eventController.add({'type': 'call_accepted', 'data': data});
    });

    _socket.on('call_rejected', (data) {
      _eventController.add({'type': 'call_rejected', 'data': data});
    });

    _socket.on('call_ended', (data) {
      _eventController.add({'type': 'call_ended', 'data': data});
    });

    _socket.on('signal', (data) {
      _eventController.add({'type': 'signal', 'data': data});
    });
  }

  /// Initiate a call to another user
  void callUser({
    required String callerId,
    required String callerName,
    required String targetId,
    required String callType, // 'audio' or 'video'
  }) {
    _socket.emit('call_user', {
      'callerId': callerId,
      'callerName': callerName,
      'targetId': targetId,
      'callType': callType,
    });
  }

  /// Accept an incoming call
  void acceptCall({
    required String callerId,
    required String targetId,
  }) {
    _socket.emit('accept_call', {
      'callerId': callerId,
      'targetId': targetId,
    });
  }

  /// Reject an incoming call
  void rejectCall({
    required String callerId,
    required String targetId,
  }) {
    _socket.emit('reject_call', {
      'callerId': callerId,
      'targetId': targetId,
    });
  }

  /// End an active call
  void endCall({
    required String callerId,
    required String targetId,
  }) {
    _socket.emit('end_call', {
      'callerId': callerId,
      'targetId': targetId,
    });
  }

  /// Send SDP signal (offer/answer)
  void sendSignal({
    required String targetId,
    required Map<String, dynamic> signal,
  }) {
    _socket.emit('signal', {
      'to': targetId,
      'signal': signal,
    });
  }

  /// Disconnect from signaling server
  void disconnect() {
    _socket.disconnect();
    _socket.dispose();
    _eventController.close();
  }
}
