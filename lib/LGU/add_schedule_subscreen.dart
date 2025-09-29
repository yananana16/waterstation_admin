import 'package:flutter/material.dart';

// AddScheduleSubscreen: use responsive label width.
class AddScheduleSubscreen extends StatelessWidget {
  final VoidCallback? onClose;
  const AddScheduleSubscreen({super.key, this.onClose});

  Widget _fieldRow(String label, Widget right, double labelWidth, double scale) {
    return Container(
      margin: EdgeInsets.only(bottom: 12 * scale),
      child: Row(
        children: [
          Container(
            width: labelWidth,
            padding: EdgeInsets.symmetric(vertical: 12 * scale, horizontal: 16 * scale),
            color: const Color(0xFFF2F6FA),
            child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: const Color(0xFF0B63B7), fontSize: 14 * scale)),
          ),
          SizedBox(width: 12 * scale),
          Expanded(child: right),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final scale = (w / 1200).clamp(0.75, 1.2);
    final labelWidth = (w * 0.18).clamp(120.0, 300.0);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8 * scale),
      child: Column(
        children: [
          // header inside subscreen
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 12 * scale),
            decoration: const BoxDecoration(
              color: Color(0xFFEAF6FF),
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: const Color(0xFF0B63B7), size: 20 * scale),
                  onPressed: () {
                    if (onClose != null) onClose!();
                  },
                ),
                SizedBox(width: 8 * scale),
                Text('Add Schedule', style: TextStyle(color: const Color(0xFF0B63B7), fontSize: 18 * scale, fontWeight: FontWeight.bold)),
                const Spacer(),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(20 * scale),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _fieldRow(
                      'Inspection number:',
                      Container(
                        padding: EdgeInsets.symmetric(vertical: 12 * scale, horizontal: 14 * scale),
                        color: const Color(0xFFF2F6FA),
                        child: Text('0168', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14 * scale)),
                      ),
                      labelWidth,
                      scale,
                    ),
                    _fieldRow(
                      'Station:',
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 12 * scale, horizontal: 14 * scale),
                              color: const Color(0xFFF2F6FA),
                              child: Text('PureFlow Water Station', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14 * scale)),
                            ),
                          ),
                          SizedBox(width: 8 * scale),
                          IconButton(onPressed: () {}, icon: Icon(Icons.edit, color: const Color(0xFF0B63B7), size: 20 * scale)),
                        ],
                      ),
                      labelWidth,
                      scale,
                    ),
                    _fieldRow(
                      'Location',
                      Container(
                        padding: EdgeInsets.symmetric(vertical: 4 * scale, horizontal: 8 * scale),
                        color: const Color(0xFFF2F6FA),
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: 'Mandurriao',
                          underline: const SizedBox.shrink(),
                          items: const [
                            DropdownMenuItem(value: 'Mandurriao', child: Text('Mandurriao')),
                            DropdownMenuItem(value: 'La Paz', child: Text('La Paz')),
                          ],
                          onChanged: (_) {},
                        ),
                      ),
                      labelWidth,
                      scale,
                    ),
                    _fieldRow(
                      'Date',
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 12 * scale, horizontal: 14 * scale),
                              color: const Color(0xFFF2F6FA),
                              child: Text('May 8, 2025', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14 * scale)),
                            ),
                          ),
                          SizedBox(width: 8 * scale),
                          IconButton(onPressed: () { /* pick date */ }, icon: Icon(Icons.calendar_today, color: const Color(0xFF0B63B7), size: 20 * scale)),
                        ],
                      ),
                      labelWidth,
                      scale,
                    ),
                    _fieldRow(
                      'Officer:',
                      Container(
                        padding: EdgeInsets.symmetric(vertical: 4 * scale, horizontal: 8 * scale),
                        color: const Color(0xFFF2F6FA),
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: 'T. Andres',
                          underline: const SizedBox.shrink(),
                          items: const [
                            DropdownMenuItem(value: 'T. Andres', child: Text('T. Andres')),
                            DropdownMenuItem(value: 'J. Alonzo', child: Text('J. Alonzo')),
                          ],
                          onChanged: (_) {},
                        ),
                      ),
                      labelWidth,
                      scale,
                    ),
                    SizedBox(height: 18 * scale),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: () {
                          // perform add schedule action
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B63B7)),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24 * scale, vertical: 12 * scale),
                          child: Text('Add Schedule', style: TextStyle(fontSize: 14 * scale)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
