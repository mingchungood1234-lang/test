import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class WebRTCService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  bool _isCleanedUp = false;

  final StreamController<MediaStream?> _remoteStreamController =
      StreamController<MediaStream?>.broadcast();
  final StreamController<RTCVideoRenderer?> _remoteRendererController =
      StreamController<RTCVideoRenderer?>.broadcast();
  final StreamController<RTCVideoRenderer?> _localRendererController =
      StreamController<RTCVideoRenderer?>.broadcast();
  final StreamController<bool> _callConnectedController =
      StreamController<bool>.broadcast();

  Stream<MediaStream?> get remoteStream => _remoteStreamController.stream;
  Stream<RTCVideoRenderer?> get remoteRenderer => _remoteRendererController.stream;
  Stream<RTCVideoRenderer?> get localRenderer => _localRendererController.stream;
  Stream<bool> get callConnected => _callConnectedController.stream;

  RTCVideoRenderer? _remoteRenderer;
  RTCVideoRenderer? _localRenderer;

  RTCVideoRenderer? get remoteVideoRenderer => _remoteRenderer;
  RTCVideoRenderer? get localVideoRenderer => _localRenderer;

  /// ICE servers configuration (Google STUN servers for NAT traversal)
  static final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'url': 'stun:stun.l.google.com:19302'},
      {'url': 'stun:stun1.l.google.com:19302'},
      {'url': 'stun:stun2.l.google.com:19302'},
    ],
  };

  /// Initialize the local media stream
  Future<MediaStream> initLocalStream({required bool video}) async {
    final Map<String, dynamic> constraints = {
      'audio': true,
      'video': video
          ? {
              'mandatory': {
                'minWidth': '640',
                'minHeight': '480',
                'minFrameRate': '30',
              },
              'facingMode': 'user',
            }
          : false,
    };

    _localStream = await navigator.mediaDevices.getUserMedia(constraints);

    // Initialize local renderer for video calls
    if (video) {
      _localRenderer = RTCVideoRenderer();
      await _localRenderer!.initialize();
      _localRenderer!.srcObject = _localStream;
      _localRendererController.add(_localRenderer);
    }

    return _localStream!;
  }

  /// Create a peer connection
  Future<RTCPeerConnection> createPeerConnection() async {
    _peerConnection = await createPeerConnection_(_iceServers);

    // Add local stream tracks to peer connection
    if (_localStream != null) {
      for (var track in _localStream!.getTracks()) {
        await _peerConnection!.addTrack(track, _localStream!);
      }
    }

    // Handle remote stream
    _peerConnection!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        _remoteStreamController.add(_remoteStream);

        // Create and initialize remote renderer
        _remoteRenderer = RTCVideoRenderer();
        _remoteRenderer!.initialize().then((_) {
          _remoteRenderer!.srcObject = _remoteStream;
          _remoteRendererController.add(_remoteRenderer);
        });
      }
    };

    // Handle ICE candidates
    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      debugPrint('ICE candidate: ${candidate.candidate}');
    };

    // Handle connection state changes
    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      debugPrint('Connection state: $state');
      _callConnectedController.add(
        state == RTCPeerConnectionState.RTCPeerConnectionStateConnected,
      );
    };

    _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
      debugPrint('ICE connection state: $state');
    };

    return _peerConnection!;
  }

  /// Create an SDP offer
  Future<RTCSessionDescription> createOffer() async {
    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    return offer;
  }

  /// Create an SDP answer
  Future<RTCSessionDescription> createAnswer() async {
    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);
    return answer;
  }

  /// Set remote description (offer or answer)
  Future<void> setRemoteDescription(RTCSessionDescription desc) async {
    await _peerConnection!.setRemoteDescription(desc);
  }

  /// Add a remote ICE candidate
  Future<void> addIceCandidate(RTCIceCandidate candidate) async {
    await _peerConnection!.addCandidate(candidate);
  }

  /// Toggle audio mute
  Future<void> toggleMute() async {
    if (_localStream != null) {
      for (var track in _localStream!.getAudioTracks()) {
        track.enabled = !track.enabled;
      }
    }
  }

  /// Toggle video (for video calls)
  Future<void> toggleVideo() async {
    if (_localStream != null) {
      for (var track in _localStream!.getVideoTracks()) {
        track.enabled = !track.enabled;
      }
    }
  }

  /// Switch between front and back camera
  Future<void> switchCamera() async {
    if (_localStream != null) {
      final videoTrack = _localStream!.getVideoTracks().first;
      await Helper.switchCamera(videoTrack);
    }
  }

  /// Get current mute state
  bool get isMuted {
    if (_localStream == null) return false;
    final audioTracks = _localStream!.getAudioTracks();
    if (audioTracks.isEmpty) return false;
    return !audioTracks.first.enabled;
  }

  /// Get current video state
  bool get isVideoOff {
    if (_localStream == null) return true;
    final videoTracks = _localStream!.getVideoTracks();
    if (videoTracks.isEmpty) return true;
    return !videoTracks.first.enabled;
  }

  /// Clean up resources
  Future<void> hangup() async {
    if (_isCleanedUp) return;
    _isCleanedUp = true;

    _callConnectedController.add(false);

    // Stop local stream tracks
    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream = null;

    // Dispose local renderer
    await _localRenderer?.dispose();
    _localRenderer = null;
    _localRendererController.add(null);

    // Close remote renderer
    await _remoteRenderer?.dispose();
    _remoteRenderer = null;
    _remoteStreamController.add(null);
    _remoteRendererController.add(null);

    // Close peer connection
    await _peerConnection?.close();
    _peerConnection = null;
    _remoteStream = null;
  }

  void dispose() {
    hangup();
    _remoteStreamController.close();
    _localRendererController.close();
    _remoteRendererController.close();
    _callConnectedController.close();
  }
}

/// Helper to create peer connection with config
Future<RTCPeerConnection> createPeerConnection_(
    Map<String, dynamic> configuration) async {
  return await createPeerConnection(configuration);
}
