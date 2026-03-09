import 'dart:typed_data';
import 'dart:convert';

/// OWASP-compliant in-memory container for sensitive data (passwords, PINs).
///
/// Unlike Dart [String], which is immutable and cannot be zeroed after use,
/// [SecureBytes] wraps a [Uint8List] that is explicitly overwritten with zeros
/// when [dispose] is called, minimising the window during which plaintext
/// credentials reside in the process heap.
///
/// Usage pattern:
/// ```dart
/// final secret = SecureBytes.fromString(_controller.text);
/// _controller.clear(); // remove from TextField state immediately
/// try {
///   await sendToNetwork(secret.toUtf8String());
/// } finally {
///   secret.dispose(); // zero out heap memory
/// }
/// ```
class SecureBytes {
  Uint8List _bytes;
  bool _disposed = false;

  SecureBytes._(this._bytes);

  /// Wraps an existing [Uint8List]. The list is copied so the caller's buffer
  /// can be independently zeroed.
  factory SecureBytes(Uint8List bytes) {
    return SecureBytes._(Uint8List.fromList(bytes));
  }

  /// Encodes [s] as UTF-8 and stores the raw bytes.
  /// The original [String] may remain in the Dart heap (strings are immutable),
  /// but this at least prevents further copies being made from a [String] field.
  factory SecureBytes.fromString(String s) {
    return SecureBytes._(Uint8List.fromList(utf8.encode(s)));
  }

  /// Returns the raw bytes. Throws if already disposed.
  Uint8List get bytes {
    _assertAlive();
    return _bytes;
  }

  int get length => _disposed ? 0 : _bytes.length;
  bool get isEmpty => _disposed || _bytes.isEmpty;
  bool get isNotEmpty => !isEmpty;
  bool get isDisposed => _disposed;

  /// Decodes bytes as UTF-8 and returns a Dart [String].
  ///
  /// Use **only** at the last possible moment (e.g., building an HTTP body)
  /// and do not store the result in a variable longer than necessary.
  String toUtf8String() {
    _assertAlive();
    return utf8.decode(_bytes);
  }

  /// Overwrites every byte with 0x00 and marks this instance as disposed.
  /// Safe to call multiple times.
  void dispose() {
    if (!_disposed) {
      _bytes.fillRange(0, _bytes.length, 0);
      _disposed = true;
    }
  }

  void _assertAlive() {
    if (_disposed) throw StateError('SecureBytes has already been disposed');
  }
}
