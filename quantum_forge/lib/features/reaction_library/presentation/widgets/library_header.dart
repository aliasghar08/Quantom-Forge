import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class LibraryHeader extends StatelessWidget {
  final int totalCount;
  final ValueChanged<String> onSearchChanged;

  const LibraryHeader({
    super.key, 
    required this.totalCount,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Container(
            constraints: const BoxConstraints(minWidth: 200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Reaction Library',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  '$totalCount systematic variants & templates derived from literature',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          // Search field
          Container(
            width: 320,
            constraints: const BoxConstraints(maxWidth: 320),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: (kIsWeb && defaultTargetPlatform == TargetPlatform.iOS)
                  ? Colors.black.withValues(alpha: 0.3)
                  : Colors.transparent,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: (!(kIsWeb && defaultTargetPlatform == TargetPlatform.iOS))
                  ? BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: _buildTextField(),
                    )
                  : _buildTextField(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField() {
    return TextField(
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'Search reactions, tags...',
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
        prefixIcon: Icon(Icons.search,
            color: Colors.white.withValues(alpha: 0.4)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: Colors.white.withValues(alpha: 0.3)),
        ),
      ),
      onChanged: onSearchChanged,
    );
  }
}
