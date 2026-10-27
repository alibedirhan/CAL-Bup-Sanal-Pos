// Android uçtan uca testi için emülatörü yapay kullanıcılarla sıfırlar
// (tools/android_test.sh). Yalnız demo-bup-pos emülatörüne bağlanır.
import { fixture } from './fixture.mjs';
await fixture();
console.log('Yapay kullanıcılar hazır.');
process.exit(0);
