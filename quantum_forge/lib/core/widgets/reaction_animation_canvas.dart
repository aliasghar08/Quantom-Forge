// ignore_for_file: invalid_use_of_protected_member
part of 'reaction_animation_widget.dart';

extension _ReactionAnimationCanvasExt on _ReactionAnimationWidgetState {
  Widget _buildCanvasSlotUnbounded(BoxConstraints constraints) {
      // Unbounded (e.g. Dashboard): dynamically give the canvas a reasonable height.
      final screenH = MediaQuery.of(context).size.height;
      final screenW = MediaQuery.of(context).size.width;
      final height = (screenW < 600) ? screenH * 0.40 : screenH * 0.75;
      return SizedBox(
        height: height,
        child: GestureDetector(
          onTap: () {
            _claimKeyboard();
            _togglePlay();
          },
          child: _buildCanvas(),
        ),
      );
    }

  Widget _buildCanvasSlotBounded(BoxConstraints constraints) {
      // Bounded (e.g. Analytics page): use a responsive ratio so it fits cleanly
      // inside the bounded space without forcing a massive fixed height.
      final maxH = MediaQuery.of(context).size.height * 0.50;
      final byRatio = constraints.maxWidth.isFinite
          ? constraints.maxWidth / 1.2
          : maxH;
      final height = byRatio.clamp(220.0, maxH);
      return SizedBox(
        height: height,
        child: GestureDetector(
          onTap: () {
            _claimKeyboard();
            _togglePlay();
          },
          child: _buildCanvas(),
        ),
      );
    }

  Widget _buildCanvas() {
      return NglViewer(
        key: _viewerKey,
        width: double.infinity,
        height: double.infinity,
      );
    }

}
