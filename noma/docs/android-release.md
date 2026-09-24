# Rilis Android Noma

Rilis ini memakai package ID `com.noma.app`, versi `1.1.1`, dan minimum Android 7.0 (API 24). Semua transaksi tetap tersimpan lokal. APK baru **tidak** membaca data instalasi lama dengan package ID `com.example.noma` secara otomatis.

## APK untuk dibagikan

- `build/app/outputs/flutter-apk/noma-arm64.apk`: HP Android 64-bit (umumnya perangkat baru).
- `build/app/outputs/flutter-apk/noma-arm32.apk`: HP Android 32-bit.
- `build/app/outputs/flutter-apk/noma-universal.apk`: fallback bila pengguna tidak tahu tipe CPU HP-nya.

APK ditandatangani dengan sertifikat rilis yang sama. Jangan membagikan `app-debug.apk`, `app-release.apk`, `noma.apk`, `noma-compres.apk`, atau APK x86_64 lama di folder output; file-file itu bukan hasil rilis ini. Jika tidak yakin ABI HP, gunakan `noma-universal.apk`. Jika ingin ukuran lebih kecil, coba ARM64 terlebih dahulu; bila Android menolak instalasi karena arsitektur, gunakan ARM32. Android di bawah 7.0 tidak didukung.

## Pindah dari instalasi lama

1. Di aplikasi lama, buka Pengaturan > Data & Backup > Buat Backup dan simpan JSON di luar HP.
2. Pastikan file backup dapat ditemukan sebelum menghapus aplikasi lama.
3. Copot instalasi lama, lalu instal APK yang sesuai. Android dapat meminta izin untuk menginstal dari sumber tersebut.
4. Di Noma baru, buka Pengaturan > Data & Backup > Import Backup dan pilih JSON tadi.

Backup JSON berisi transaksi, kategori, dan item struk. Foto struk, API key, chat, dan preferensi tidak ikut. Jangan menghapus backup sebelum isi aplikasi baru diperiksa. Karena package ID berubah, instalasi lama dan baru dapat muncul berdampingan; mencopot yang lama bukan syarat teknis, tetapi hindari mencatat transaksi di dua aplikasi sekaligus.

## Build ulang

Simpan `C:/Users/jaki/keystores/noma-release.jks` dan `android/key.properties` di tempat aman terpisah. Keduanya diperlukan untuk menandatangani update dengan identitas yang sama. Jangan commit atau bagikan file tersebut. `android/key.properties` harus berisi `storeFile`, `storePassword`, `keyAlias`, dan `keyPassword`.

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --release --split-per-abi --target-platform android-arm,android-arm64
flutter build apk --release --target-platform android-arm,android-arm64
```

Setelah build, verifikasi package ID, minimum SDK, ABI, signature, alignment, dan checksum menggunakan Android SDK `aapt`, `apksigner`, `zipalign`, dan `Get-FileHash`. Naikkan `version` di `pubspec.yaml` untuk rilis berikutnya. Uji instalasi, backup/restore, transaksi, laporan, notifikasi, dan scroll histori pada HP 32-bit serta 64-bit sebelum distribusi luas. Belum ada pengujian perangkat fisik untuk rilis ini.
