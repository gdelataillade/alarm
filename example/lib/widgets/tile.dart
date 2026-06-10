import 'package:flutter/material.dart';

class ExampleAlarmTile extends StatelessWidget {
  const ExampleAlarmTile({
    required this.title,
    required this.onPressed,
    super.key,
    this.subtitle,
    this.isStopped = false,
    this.onDismissed,
  });

  final String title;
  final String? subtitle;
  final bool isStopped;
  final void Function() onPressed;
  final void Function()? onDismissed;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: key!,
      direction: onDismissed != null
          ? DismissDirection.endToStart
          : DismissDirection.none,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 30),
        child: const Icon(
          Icons.delete,
          size: 30,
          color: Colors.white,
        ),
      ),
      onDismissed: (_) => onDismissed?.call(),
      child: RawMaterialButton(
        onPressed: onPressed,
        child: Container(
          height: subtitle != null ? 120 : 100,
          padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                      color: isStopped ? Colors.grey[400] : Colors.black,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      isStopped ? 'Stopped · $subtitle' : subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        color: isStopped ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                ],
              ),
              Icon(
                Icons.keyboard_arrow_right_rounded,
                size: 35,
                color: isStopped ? Colors.grey[400] : Colors.black,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
