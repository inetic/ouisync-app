import 'package:flutter/material.dart';

import '../../utils/extensions.dart';

class CustomAdaptiveSwitch extends StatelessWidget {
  const CustomAdaptiveSwitch({
    super.key,
    required this.value,
    required this.title,
    required this.contentPadding,
    required this.onChanged,
  });

  final bool value;
  final String title;
  final EdgeInsets contentPadding;
  final void Function(bool)? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: contentPadding,
      child: InkWell(
        onTap: onChanged?.let((onChanged) => () => onChanged(!value)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(
              child: Text(
                title,
                textAlign: TextAlign.end,
                softWrap: true,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: context.theme.appTextStyle.titleMedium.fontSize,
                ),
              ),
            ),
            SizedBox(
              width: 12.0,
            ),
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
