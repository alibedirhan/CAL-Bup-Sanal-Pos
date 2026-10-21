import 'package:flutter/material.dart';
import '../domain/modeller.dart';
import 'oturum_modeli.dart';

Future<void> kartSilmeOnayi(
  BuildContext context,
  OturumModeli model,
  KartOzeti kart,
) async {
  final onay = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Kart silinsin mi?'),
      content: Text(
        '${kart.ad} · ${kart.maske} kaydı ve bu cihazdaki tam bilgileri kaldırılacak.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Vazgeç'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Sil'),
        ),
      ],
    ),
  );
  if (onay == true) await model.kartSil(kart.id);
}
