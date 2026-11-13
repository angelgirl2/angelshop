import 'dart:async';
import 'package:flutter/material.dart';

class AngelNotice {
  static OverlayEntry? _entry;
  static Timer? _timer;

  static void show(BuildContext context, String message, {bool error = false}) {
    final overlay = Overlay.of(context, rootOverlay: true);
    _timer?.cancel();
    _entry?.remove();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.paddingOf(context).top + 12,
        left: 14,
        right: 14,
        child: SafeArea(
          bottom: false,
          child: Material(
            color: Colors.transparent,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, -16 * (1 - value)),
                  child: child,
                ),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: error
                        ? const [Color(0xFF54213F), Color(0xFF24132F)]
                        : const [Color(0xFF7138A5), Color(0xFF281640)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withValues(alpha: .22)),
                  boxShadow: [
                    BoxShadow(
                      color: (error ? Colors.redAccent : Colors.purpleAccent).withValues(alpha: .24),
                      blurRadius: 24,
                      offset: const Offset(0, 9),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      error ? Icons.error_outline_rounded : Icons.auto_awesome_rounded,
                      color: error ? const Color(0xFFFFB6C4) : const Color(0xFFE8C8FF),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        message,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, height: 1.4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.notifications_active_outlined, color: Colors.white.withValues(alpha: .6), size: 18),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    _entry = entry;
    overlay.insert(entry);
    _timer = Timer(const Duration(seconds: 3), () {
      if (entry.mounted) entry.remove();
      if (identical(_entry, entry)) _entry = null;
    });
  }
}
