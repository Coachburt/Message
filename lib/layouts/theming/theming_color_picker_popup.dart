import 'package:bluebubbles/layouts/widgets/scroll_physics/custom_bouncing_scroll_physics.dart';
import 'package:bluebubbles/repository/models/theme_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class ThemingColorPickerPopup extends StatefulWidget {
  ThemingColorPickerPopup({Key key, this.onSet, this.entry}) : super(key: key);
  final ThemeEntry entry;
  final Function(Color color, {int fontSize}) onSet;

  @override
  _ThemingColorPickerPopupState createState() =>
      _ThemingColorPickerPopupState();
}

class _ThemingColorPickerPopupState extends State<ThemingColorPickerPopup> {
  Color currentColor;
  int currentFontSize;

  @override
  void initState() {
    super.initState();
    currentColor = widget.entry.color;
    if (widget.entry.isFont) currentFontSize = widget.entry.fontSize;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.black.withOpacity(0.8),
      title:
          Text("Choose a Color", style: Theme.of(context).textTheme.headline1.apply(color: Colors.white)),
      content: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(
            parent: CustomBouncingScrollPhysics()),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ColorPicker(
              pickerColor: widget.entry.color,
              onColorChanged: (Color color) => currentColor = color,
              showLabel: true,
              pickerAreaHeightPercent: 0.8,
              labelTextStyle: Theme.of(context).textTheme.bodyText1.apply(color: Colors.white)
            ),
            if (widget.entry.isFont)
              Text(
                "Font Size",
                style: Theme.of(context)
                    .textTheme
                    .bodyText1
                    .apply(color: Colors.white),
              ),
            if (widget.entry.isFont)
              Slider(
                onChanged: (double value) {
                  setState(() {
                    currentFontSize = value.floor();
                  });
                },
                value: currentFontSize.toDouble(),
                min: 5,
                max: 30,
                divisions: 25,
                label: currentFontSize.toString(),
              ),
          ],
        ),
      ),
      actions: <Widget>[
        FlatButton(
          child: Text("OK",
              style: Theme.of(context)
                  .textTheme
                  .bodyText1
                  .apply(color: Colors.white)),
          onPressed: () {
            widget.onSet(currentColor, fontSize: currentFontSize);
            Navigator.of(context).pop();
          },
        )
      ],
    );
  }
}
