/// Shared WebRTC configuration. STUN-only is fine for a demo on a normal
/// home/office network; it will fail on strict corporate NATs or symmetric
/// NATs with no TURN fallback. Not a concern for "someone in Chrome testing
/// this" — just know that's the tradeoff being made here.
final Map<String, dynamic> kIceServers = {
  'iceServers': [
    {'urls': 'stun:stun.l.google.com:19302'},
  ],
};