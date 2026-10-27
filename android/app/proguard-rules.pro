# ML Kit yazı tanıma eklentisi Çince/Devanagari/Japonca/Korece modellerine
# başvurur; yalnız Latin modeli eklidir (pubspec 0.12.0, APK boyutu). Diğerleri
# bilerek yoktur ve hiç seçilmez: R8 eksik sınıf uyarısı yalnız bu paketlerde kapalı.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
