import 'package:flutter/material.dart';
import 'appColor.dart';

class PinDialog extends StatefulWidget {
  final Function(String) onConfirm;
  final String title;

  const PinDialog({
    super.key,
    required this.onConfirm,
    this.title = 'Enter PIN',
  });

  @override
  State<PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<PinDialog> {
  final List<TextEditingController> _controllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _onChanged(String value, int index) {
    if (value.length == 1 && index < 3) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    if (_controllers.every((c) => c.text.isNotEmpty)) {
      final pin = _controllers.map((c) => c.text).join();
      widget.onConfirm(pin);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        widget.title,
        textAlign: TextAlign.center,
        style: TextStyle(color: context.textColor, fontWeight: FontWeight.bold),
      ),
      content: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(4, (index) {
          return SizedBox(
            width: 50,
            child: TextField(
              controller: _controllers[index],
              focusNode: _focusNodes[index],
              onChanged: (v) => _onChanged(v, index),
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              obscureText: true,
              style: TextStyle(color: context.textColor, fontSize: 24, fontWeight: FontWeight.bold),
              maxLength: 1,
              decoration: InputDecoration(
                counterText: '',
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: kGold.withOpacity(0.5))),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: kGold, width: 2)),
              ),
            ),
          );
        }),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }
}
