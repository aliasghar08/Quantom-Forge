part of 'reaction_animation_widget.dart';

class _SpinBox extends StatefulWidget {
  const _SpinBox({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.label,
    this.suffix,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  /// Accessible name; also the tooltip subject.
  final String label;

  /// Optional trailing text drawn beside the field, e.g. `/25`.
  final String? suffix;

  @override
  State<_SpinBox> createState() => _SpinBoxState();
}

class _SpinBoxState extends State<_SpinBox> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.value}');
    _focusNode = FocusNode(debugLabel: widget.label);
    // Commit on blur as well as on submit, so clicking away does not silently
    // discard an edit.
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(covariant _SpinBox old) {
    super.didUpdateWidget(old);
    // Only overwrite the field when it is not being typed into, or the caret
    // would jump on every rebuild.
    if (!_focusNode.hasFocus && widget.value != old.value) {
      _controller.text = '${widget.value}';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _commit() {
    final parsed = int.tryParse(_controller.text.trim());
    final clamped = (parsed ?? widget.value).clamp(widget.min, widget.max);
    _controller.text = '$clamped';
    if (clamped != widget.value) widget.onChanged(clamped);
  }

  void _step(int delta) {
    final next = (widget.value + delta).clamp(widget.min, widget.max);
    _controller.text = '$next';
    if (next != widget.value) widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 46,
          height: 26,
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onSubmitted: (_) => _commit(),
            style: const TextStyle(
              color: Color(0xFF4FC3F7),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 6,
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFF4FC3F7)),
              ),
            ),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _caret(Icons.arrow_drop_up, 'Increase ${widget.label}', 1),
            _caret(Icons.arrow_drop_down, 'Decrease ${widget.label}', -1),
          ],
        ),
        if (widget.suffix != null)
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Text(
              widget.suffix!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 10,
              ),
            ),
          ),
      ],
    );
  }

  Widget _caret(IconData icon, String tooltip, int delta) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () => _step(delta),
        child: SizedBox(
          width: 15,
          height: 13,
          child: Icon(
            icon,
            size: 15,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}
