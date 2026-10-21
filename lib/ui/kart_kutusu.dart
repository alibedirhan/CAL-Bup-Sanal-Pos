import 'package:flutter/material.dart';
import '../domain/modeller.dart';
import 'tema.dart';

class KartKutusu extends StatelessWidget {
  const KartKutusu({
    super.key,
    required this.kart,
    required this.secili,
    required this.gecmis,
    required this.onSec,
  });
  final KartOzeti kart;
  final bool secili, gecmis;
  final VoidCallback? onSec;
  @override
  Widget build(BuildContext context) {
    final renk = secili ? PosRenk.beyaz : PosRenk.metin;
    return Semantics(
      button: true,
      selected: secili,
      enabled: !gecmis && onSec != null,
      label:
          '${kart.ad}, son dört hane ${kart.sonDort}, son kullanma ${kart.tarih}${gecmis ? ', süresi dolmuş' : ''}',
      excludeSemantics: true,
      onTap: gecmis ? null : onSec,
      child: Material(
        color: secili ? PosRenk.koyu : PosRenk.beyaz,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: secili ? PosRenk.vurgu : PosRenk.cizgi,
            width: secili ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: gecmis ? null : onSec,
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.credit_card_rounded, color: renk, size: 26),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        kart.ad,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: renk,
                        ),
                      ),
                    ),
                    Icon(
                      secili
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: secili ? const Color(0xFF8AD7C1) : PosRenk.ikincil,
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                Text(
                  '••••  ••••  ••••  ${kart.sonDort}',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1,
                    color: renk,
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 20,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    Text(
                      kart.tarih,
                      style: TextStyle(color: renk, fontSize: 14),
                    ),
                    Text(
                      gecmis
                          ? 'Süresi dolmuş'
                          : secili
                          ? 'Seçili kart'
                          : 'Seçmek için dokun',
                      style: TextStyle(
                        color: gecmis
                            ? PosRenk.uyari
                            : secili
                            ? const Color(0xFFBDE5D8)
                            : PosRenk.ikincil,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
