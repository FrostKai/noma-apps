# Product Requirements Document (PRD) - Noma

## Status Implementasi Saat Ini - 7 Agustus 2026

Dokumen ini tetap menjadi rujukan produk, tetapi kondisi kode saat ini sudah melewati scaffold awal dan berada pada fase MVP fungsional. Implementasi yang sudah tersedia:

- Pencatatan transaksi manual: tambah, edit, hapus, tanggal, kategori, metode pembayaran.
- Dashboard: saldo bersih, total pemasukan, total pengeluaran, grafik ringkas, pencarian, dan filter jenis transaksi.
- Kategori: daftar kategori default, tambah kategori kustom, hapus kategori kustom.
- AI text input: parsing teks natural memakai Cloud AI atau fallback rule-based lokal, lalu membuka layar konfirmasi transaksi.
- Receipt scanner: ambil gambar kamera/galeri, kirim ke Gemini Vision, tampilkan hasil ekstraksi, lalu simpan sebagai pengeluaran.
- Chatbot Nomi AI: riwayat chat lokal, konteks saldo/pemasukan/pengeluaran, fallback lokal saat AI gagal.
- Laporan: filter periode sederhana, bar chart pemasukan vs pengeluaran, donut chart pengeluaran per kategori.
- Pengaturan: API key Groq/Gemini, notifikasi harian lokal, manajemen kategori.

Gap produk yang masih perlu diselesaikan:

- Review hasil AI text saat ini memakai mode edit transaksi dengan `id: 0`; secara teknis ini perlu diperbaiki agar menyimpan sebagai transaksi baru.
- Receipt scanner belum punya form koreksi rinci sebelum simpan; pengguna baru bisa scan ulang, input manual, atau simpan hasil.
- Chatbot belum menerima konteks kategori, transaksi terbaru, atau periode spesifik, sehingga analisis seperti "kategori terbesar bulan ini" masih terbatas.
- Tidak ada cloud sync, multi-dompet, budget per kategori, export CSV/PDF, atau backup data.
- API key di client Flutter tetap berisiko untuk produksi; pendekatan production sebaiknya memakai backend proxy.

## 1. Ringkasan Eksekutif
**Noma** adalah aplikasi pencatatan keuangan pribadi berbasis Android yang dirancang untuk mempermudah pengguna dalam melacak pemasukan dan pengeluaran sehari-hari. Berbeda dengan aplikasi pencatatan tradisional yang membutuhkan input manual yang kaku, Noma mengintegrasikan kecerdasan buatan (AI) berbasis cloud (Google Gemini Flash) untuk memungkinkan input melalui teks natural, pemindaian struk belanja, dan asisten pintar untuk menganalisis keuangan. Produk ini dibangun menggunakan Flutter dengan arsitektur Riverpod dan penyimpanan lokal SQLite, mengusung antarmuka modern Dark Mode dan efek Glassmorphism.

## 2. Latar Belakang & Masalah
Mencatat keuangan pribadi seringkali dianggap sebagai tugas yang membosankan dan menyita waktu. Banyak pengguna merasa kesulitan konsisten mencatat pengeluaran karena:
- Proses input manual pada aplikasi konvensional membutuhkan banyak langkah (memilih kategori, tanggal, memasukkan nominal).
- Sering lupa mencatat pengeluaran kecil.
- Kesulitan membaca pola pengeluaran dari data mentah tanpa analisis.
- Menyimpan tumpukan struk belanja yang mudah hilang atau pudar, dan malas memindahkannya ke catatan digital.

## 3. Tujuan Produk
Menciptakan pengalaman mencatat keuangan yang **cepat, minim gesekan (frictionless), dan pintar**.
- Mengurangi waktu yang dibutuhkan untuk mencatat satu transaksi.
- Meningkatkan retensi dan kebiasaan pengguna dalam mencatat pengeluaran.
- Memberikan wawasan (insights) keuangan yang mudah dipahami melalui percakapan alami.

## 4. Target Pengguna
- **Demografi:** Dewasa muda, mahasiswa, pekerja awal (usia 18 - 35 tahun).
- **Perilaku:** Terbiasa menggunakan smartphone, menyukai antarmuka aplikasi yang modern (dark mode), sibuk dan menginginkan efisiensi.
- **Pain Point:** Sering merasa uang cepat habis tapi tidak tahu ke mana perginya, malas repot mencatat satu per satu.

## 5. Fitur & User Stories

### 5.1. Pencatatan Transaksi Manual
Pengguna tetap memiliki opsi untuk mencatat transaksi dengan formulir standar jika mereka menginginkannya.
- **US-1.1:** Sebagai pengguna, saya dapat memasukkan nominal transaksi menggunakan keypad angka, agar angka yang dimasukkan akurat.
- **US-1.2:** Sebagai pengguna, saya dapat memilih apakah transaksi tersebut Pemasukan atau Pengeluaran.
- **US-1.3:** Sebagai pengguna, saya dapat memilih kategori transaksi dari daftar yang sudah disediakan.
- **US-1.4:** Sebagai pengguna, saya dapat menambahkan catatan singkat pada transaksi.
- **US-1.5:** Sebagai pengguna, saya dapat menambah, mengedit, dan menghapus kategori kustom sesuai kebutuhan saya, selain kategori bawaan yang sudah disediakan.
- **US-1.6:** Sebagai pengguna, saya dapat memilih metode pembayaran (Tunai, Gopay, OVO, Transfer Bank, dll) saat mencatat transaksi.

### 5.2. Pencatatan via Teks Natural (AI)
Mencatat transaksi seolah-olah mengirim pesan teks ke asisten.
- **US-2.1:** Sebagai pengguna, saya dapat mengetik kalimat seperti "Beli kopi senilai 35 ribu" pada kolom teks.
- **US-2.2:** Sebagai sistem, saya dapat memparsing teks tersebut menggunakan AI untuk mengekstrak: Nominal (35.000), Tipe (Pengeluaran), Kategori (Makanan/Minuman), dan Catatan (Beli kopi).
- **US-2.3:** Sebagai pengguna, saya dapat meninjau dan mengedit hasil ekstraksi AI sebelum menyimpannya ke database.

### 5.3. Pemindaian Struk Belanja (Receipt Scanner AI)
- **US-3.1:** Sebagai pengguna, saya dapat mengambil foto struk belanja menggunakan kamera aplikasi atau mengunggah dari galeri.
- **US-3.2:** Sebagai sistem, saya akan mengirim gambar ke Cloud AI untuk membaca dan mengekstrak informasi penting.
- **US-3.3:** Sebagai sistem, saya akan menampilkan hasil ekstraksi (Total belanja, Nama Toko, Tanggal, dan rekomendasi kategori) kepada pengguna.
- **US-3.4:** Sebagai pengguna, saya dapat mengkonfirmasi atau memperbaiki data hasil pindaian sebelum menyimpannya.

### 5.4. Chatbot Keuangan AI
Asisten pintar yang memahami data transaksi pengguna.
- **US-4.1:** Sebagai pengguna, saya dapat membuka halaman chat untuk bertanya kepada asisten AI.
- **US-4.2:** Sebagai pengguna, saya dapat mengajukan pertanyaan seperti "Berapa total pengeluaranku minggu ini?" atau "Apa pengeluaran terbesarku bulan ini?".
- **US-4.3:** Sebagai sistem, saya akan mengambil rangkuman data lokal yang relevan, mengirimkannya secara aman (anonim) sebagai konteks ke Cloud AI, dan mengembalikan jawaban yang mudah dimengerti.

### 5.5. Notifikasi Laporan Malam
- **US-5.1:** Sebagai sistem, saya akan mengirimkan push notification lokal pada waktu yang ditentukan (default: 20:00).
- **US-5.2:** Sebagai pengguna, saya akan melihat notifikasi berisi ringkasan pengeluaran hari ini (misal: "Pengeluaranmu hari ini Rp150.000. Jangan lupa catat semua transaksimu!").
- **US-5.3:** Sebagai pengguna, saya dapat mengubah jam pengiriman notifikasi ini di halaman pengaturan.

### 5.6. Laporan Sederhana
- **US-6.1:** Sebagai pengguna, saya dapat melihat total saldo, total pemasukan, dan total pengeluaran untuk periode berjalan (Harian/Mingguan/Bulanan) di halaman beranda.
- **US-6.2:** Sebagai pengguna, saya dapat melihat daftar transaksi terbaru yang diurutkan dari yang paling baru.
- **US-6.3:** Sebagai pengguna, saya dapat melihat grafik donat (donut chart) sederhana yang menunjukkan porsi pengeluaran berdasarkan kategori.

## 6. Non-Functional Requirements
- **Performa:** Waktu respons dari AI (parsing teks/struk dan chatbot) tidak boleh lebih dari 3-5 detik pada koneksi internet stabil (4G/WiFi).
- **Ketersediaan & Offline:** Aplikasi (kecuali fitur AI) harus sepenuhnya berfungsi secara offline. Data disimpan 100% lokal di perangkat (SQLite).
- **Keamanan & Privasi:** Data transaksi sensitif tidak diunggah secara persisten ke server manapun. Saat menggunakan AI, data hanya dikirim sebagai konteks sementara ke API Google Gemini Flash dan tidak disimpan oleh pihak Noma.
- **Ukuran Aplikasi:** Ukuran APK yang diunduh (download size) harus di bawah 30 MB untuk mendukung perangkat kelas menengah ke bawah.
- **UI/UX:** Aplikasi wajib menggunakan Dark Mode secara default dengan elemen desain Glassmorphism (efek blur transparan pada card/modal) agar terlihat modern dan elegan.

## 7. Batasan & Asumsi
- **Ketergantungan API:** Fitur parsing teks, pemindaian struk, dan chatbot bergantung pada ketersediaan dan stabilitas API Google Gemini Flash.
- **Tanpa Cloud Sync:** Di versi MVP ini, jika perangkat pengguna hilang atau aplikasi dihapus (tanpa backup Android), maka data transaksi akan hilang.
- **Sistem Operasi:** MVP hanya ditargetkan untuk platform Android.
- **Satu Dompet:** Tidak ada pemisahan sumber dana (misal: Kas, Rekening Bank, E-Wallet). Semua dicatat dalam satu "Dompet" virtual yang sama.

## 8. Metrik Keberhasilan (MVP)
- **Tingkat Akurasi AI:** 85% hasil parsing teks dan ekstraksi struk belanja dikonfirmasi pengguna tanpa perubahan manual.
- **Waktu Input:** Rata-rata waktu pencatatan menggunakan teks natural atau struk lebih cepat 40% dibandingkan input manual.
- **Retensi Hari ke-7 (D7 Retention):** Minimal 25% dari pengguna aktif mengaktifkan notifikasi malam dan melakukan pencatatan di hari ke-7 setelah instalasi.

## 9. Risiko & Mitigasi
- **Risiko:** Biaya operasional API AI membengkak seiring bertambahnya pengguna.
  - **Mitigasi:** Menggunakan model "Flash" yang lebih ekonomis, menerapkan rate limiting (batas penggunaan AI harian per pengguna), dan membatasi ukuran konteks data yang dikirim ke AI pada fitur chatbot.
- **Risiko:** Privasi pengguna terganggu karena pengiriman data ke Cloud AI.
  - **Mitigasi:** Menyertakan halaman persetujuan (consent) yang jelas saat onboarding bahwa fitur pintar memerlukan pemrosesan cloud, dan memastikan data dikirim secara anonim tanpa identitas personal (PII).
- **Risiko:** Pemindaian struk gagal karena kualitas foto buruk.
  - **Mitigasi:** Memberikan panduan on-screen saat mode kamera aktif (misal: "Pastikan teks struk terbaca jelas dan cukup cahaya") dan memperbolehkan fallback ke input manual jika AI gagal mengenali.

## 10. Glosarium
- **PRD:** Product Requirements Document, dokumen rujukan kebutuhan produk.
- **MVP:** Minimum Viable Product, versi produk dengan fitur minimum yang cukup untuk dirilis ke pengguna awal guna mendapatkan umpan balik.
- **Riverpod:** Framework state management modern untuk aplikasi Flutter.
- **Drift:** Pustaka (library) *type-safe* dan reaktif untuk mengelola database SQLite di Flutter. Dipilih sebagai satu-satunya ORM/wrapper SQLite untuk proyek ini.
- **Google Gemini Flash:** Varian model AI dari Google yang dioptimalkan untuk kecepatan dan efisiensi biaya.
- **Glassmorphism:** Gaya desain antarmuka pengguna yang menonjolkan efek seperti kaca berembun (frosted glass) dengan tingkat transparansi dan keburaman (blur) tertentu.
