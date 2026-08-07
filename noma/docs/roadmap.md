# Roadmap Pengembangan Aplikasi Noma - Pencatatan Uang Berbasis AI

## Status Roadmap Saat Ini - 7 Agustus 2026

MVP utama sudah diimplementasikan di kode Flutter. Dokumen roadmap ini sekarang dipakai sebagai rujukan progres, bukan daftar task kosong. Status ringkas:

- Fase 1 Foundation: selesai. Struktur Flutter, Riverpod, Drift, routing, tema, asset, dan seeding kategori sudah ada.
- Fase 2 Core transaction: sebagian besar selesai. CRUD transaksi, kategori, dashboard, pencarian, dan filter sudah ada. Edit kategori kustom belum tersedia, baru tambah/hapus.
- Fase 3 AI text dan receipt scanner: sebagian besar selesai. Parsing teks, scan struk, kamera/galeri, loading state, dan penyimpanan hasil sudah ada. Koreksi hasil scan sebelum simpan masih perlu ditingkatkan.
- Fase 4 Chatbot dan notifikasi: sebagian selesai. Chatbot dan local notification scheduling sudah ada. `workmanager` belum dipakai dan tidak tercatat sebagai dependency aktif.
- Fase 5 Laporan dan polish: sebagian besar selesai. Laporan bar/pie chart, filter periode sederhana, pengaturan API key/notifikasi, dan UI polish sudah ada. Release APK belum diverifikasi dalam dokumen ini.

Prioritas teknis berikutnya:

1. Perbaiki flow AI text agar hasil parsing disimpan sebagai transaksi baru, bukan update `id: 0`.
2. Amankan `.env`: jangan bundle secret production ke asset Flutter, dan masukkan `.env` ke `.gitignore`.
3. Perluas konteks chatbot dengan ringkasan periode, kategori terbesar, dan transaksi terbaru.
4. Tambahkan form koreksi hasil scan struk sebelum simpan.
5. Sinkronkan dokumentasi dependency: hapus klaim `workmanager` jika tidak dipakai, atau tambahkan implementasinya jika memang diperlukan.

Aplikasi "Noma" adalah aplikasi pencatatan keuangan pribadi berbasis AI (Artificial Intelligence) untuk platform Android. Aplikasi ini dirancang untuk memudahkan pengguna dalam mencatat, melacak, dan menganalisis pengeluaran serta pemasukan menggunakan teknologi natural language processing dan computer vision.

Dokumen ini merinci roadmap pengembangan untuk Minimum Viable Product (MVP) dengan kerangka waktu 5 minggu untuk solo developer.

---

## Fase 1: Foundation & Setup (Minggu 1)

Fokus pada minggu pertama adalah meletakkan fondasi teknis, struktur arsitektur proyek, dan desain sistem visual yang akan digunakan di seluruh aplikasi.

**Daftar Task:**
- [ ] Inisialisasi proyek Flutter baru dengan nama `noma`.
- [ ] Konfigurasi `pubspec.yaml` untuk menambahkan dependensi utama: `flutter_riverpod`, `drift`, `sqlite3_flutter_libs`, `dio`, `go_router`, `google_fonts`, `image_picker`, `flutter_local_notifications`, `workmanager`, `freezed`, `fl_chart`, `flutter_dotenv`.
- [ ] Setup struktur folder proyek menggunakan prinsip Clean Architecture Lite (presentation, domain, data).
- [ ] Implementasi Design System: Konfigurasi tema Dark Mode dan elemen Glassmorphism (warna, border radius, blur effect, typography).
- [ ] Setup database lokal menggunakan Drift (SQLite).
- [ ] Buat file migrasi database awal dan fungsi *seeding* untuk memasukkan kategori pengeluaran/pemasukan default.
- [ ] Setup Riverpod providers dasar untuk state management (database provider, theme provider).
- [ ] Konfigurasi routing aplikasi menggunakan `go_router` dengan rute awal (Splash, Home, Add Transaction).

**Estimasi Effort:** Tinggi (3-4 hari)
**Dependencies antar Task:** Inisialisasi proyek harus selesai sebelum konfigurasi dependensi. Setup struktur folder mendasari pembuatan file lainnya. Setup database harus dilakukan sebelum seeding.
**Definition of Done (DoD):**
- Proyek dapat di-build dan berjalan di emulator/device tanpa error.
- Tampilan dasar menunjukkan tema gelap dengan efek glassmorphism.
- Database lokal berhasil diinisialisasi dan data kategori default tersimpan.
- Navigasi dasar menggunakan `go_router` berfungsi.

---

## Fase 2: Core Feature - Pencatatan Transaksi (Minggu 2)

Minggu kedua berfokus pada fitur inti aplikasi: kemampuan untuk mencatat, melihat, mengubah, dan menghapus transaksi secara manual.

**Daftar Task:**
- [ ] Pembuatan UI Halaman Dashboard/Home yang menampilkan ringkasan saldo, pengeluaran bulan ini, dan daftar transaksi terbaru.
- [ ] Pembuatan UI Halaman Tambah/Edit Transaksi Manual (input jumlah, deskripsi, tanggal, kategori, dan jenis transaksi).
- [ ] Implementasi logic CRUD (Create, Read, Update, Delete) untuk Transaksi dengan integrasi Drift database dan Riverpod.
- [ ] Pembuatan UI dan logic untuk manajemen kategori (tambah, edit, hapus kategori kustom).
- [ ] Implementasi fitur filter transaksi (berdasarkan bulan, jenis) dan pencarian transaksi.

**Estimasi Effort:** Sangat Tinggi (4-5 hari)
**Dependencies antar Task:** UI Halaman Tambah Transaksi dan CRUD logic harus selesai sebelum Halaman Dashboard dapat menampilkan data transaksi terbaru.
**Definition of Done (DoD):**
- Pengguna dapat menambah, mengedit, dan menghapus transaksi manual.
- Halaman Dashboard menampilkan total saldo yang akurat dan list transaksi yang di-update secara real-time.
- Pencarian dan filter transaksi berfungsi dengan baik.

---

## Fase 3: AI Integration - Text Parsing & Receipt Scanner (Minggu 3)

Fase ini mengintegrasikan kecerdasan buatan untuk mempercepat proses pencatatan melalui teks bahasa natural dan pemindaian struk.

**Daftar Task:**
- [ ] Setup layanan API (Dio) untuk berkomunikasi dengan Google Gemini API.
- [ ] Pembuatan fitur input teks natural: UI input, pengiriman prompt ke AI, parsing respon JSON dari AI, dan tampilan konfirmasi data transaksi.
- [ ] Pembuatan UI Scanner: Integrasi kamera menggunakan `image_picker`, tampilan preview foto, dan loading state saat memproses gambar.
- [ ] Pembuatan fitur Receipt Scanner: Pengiriman gambar ke Gemini Vision API, ekstraksi data (total, nama toko, tanggal), dan konfirmasi sebelum menyimpan ke database.

**Estimasi Effort:** Tinggi (3-4 hari)
**Dependencies antar Task:** Setup layanan API Gemini harus dilakukan sebelum implementasi fitur teks natural dan receipt scanner. Fitur CRUD transaksi dari Fase 2 harus sudah stabil.
**Definition of Done (DoD):**
- Pengguna dapat mengetikkan kalimat seperti "Makan siang 50 ribu" dan aplikasi mengenali jumlah, kategori, dan deskripsi dengan benar.
- Pengguna dapat memfoto struk dan aplikasi secara otomatis mengekstrak total biaya dan tanggal.
- Selalu ada layar konfirmasi sebelum data hasil parsing AI disimpan ke database.

---

## Fase 4: Chatbot & Notifikasi (Minggu 4)

Minggu keempat menghadirkan fitur interaktif berupa Chatbot AI untuk analisis keuangan kasual dan sistem pengingat otomatis.

**Daftar Task:**
- [ ] Pembuatan UI Halaman Chatbot (layout chat bubble, input teks, auto-scroll ke pesan terbaru, dan indikator *typing*).
- [ ] Implementasi logic Chatbot: Mengumpulkan konteks transaksi pengguna (misal: pengeluaran bulan ini) dan mengirimkannya bersama pertanyaan pengguna ke Gemini API, lalu menampilkan jawabannya.
- [ ] Konfigurasi inisialisasi `flutter_local_notifications` untuk Android.
- [ ] Setup `workmanager` untuk menjalankan task di latar belakang secara terjadwal.
- [ ] Implementasi logic untuk mengirimkan notifikasi rangkuman pengeluaran pada malam hari secara otomatis.

**Estimasi Effort:** Menengah (3 hari)
**Dependencies antar Task:** UI Chatbot bergantung pada API service yang dibuat di Fase 3. Setup notifikasi harus dilakukan sebelum konfigurasi Workmanager.
**Definition of Done (DoD):**
- Pengguna dapat berinteraksi dengan chatbot, bertanya tentang pengeluaran mereka, dan mendapatkan jawaban yang relevan.
- Notifikasi lokal dijadwalkan dan muncul pada jam yang telah ditentukan setiap malam tanpa aplikasi harus terbuka.

---

## Fase 5: Laporan & Polish (Minggu 5)

Minggu terakhir difokuskan pada penyempurnaan aplikasi, penambahan laporan sederhana, dan persiapan rilis.

**Daftar Task:**
- [ ] Pembuatan UI Halaman Laporan/Statistik sederhana (menampilkan grafik bar/pie sederhana untuk perbandingan pemasukan vs pengeluaran dan pengeluaran per kategori).
- [ ] Pembuatan Halaman Pengaturan (opsi mengubah jam notifikasi harian, mengganti API Key Gemini jika diperlukan).
- [ ] *Polishing* UI: Penambahan animasi transisi layar, *micro-interactions* (seperti efek ripple yang sesuai dengan gaya glassmorphism), dan validasi form yang lebih baik.
- [ ] Pengujian menyeluruh (manual testing) pada setiap alur pengguna dan perbaikan bug yang ditemukan (Bug fixing).
- [ ] Proses *build* aplikasi untuk menghasilkan file APK release (`flutter build apk --release`).

**Estimasi Effort:** Menengah-Tinggi (3-4 hari)
**Dependencies antar Task:** Halaman statistik bergantung pada data transaksi yang ada. Polishing dilakukan setelah semua fitur utama selesai dan berjalan dengan baik.
**Definition of Done (DoD):**
- Halaman laporan menampilkan data agregat yang akurat.
- Aplikasi terasa responsif, visual stabil, dan tidak ada bug *crash* (NullPointerException, dsb).
- File APK release berhasil dibuat dan siap untuk di-install pada perangkat nyata.

---

## Backlog (Future / Post-MVP)

Fitur-fitur ini direncanakan untuk pengembangan lebih lanjut setelah versi MVP dirilis:

- **Multi-dompet/akun:** Mendukung pencatatan terpisah (misal: Uang Tunai, Rekening Bank, e-Wallet).
- **Budgeting per kategori:** Menetapkan limit pengeluaran bulanan untuk setiap kategori dengan peringatan jika mendekati batas.
- **Target tabungan:** Fitur untuk melacak progress menabung untuk tujuan tertentu.
- **Cloud sync:** Sinkronisasi data ke cloud (misal: Firebase/Supabase) agar aman dan dapat diakses dari beberapa perangkat.
- **Ekspor CSV/PDF:** Mengunduh laporan transaksi ke format spreadsheet atau dokumen laporan.
- **Widget home screen Android:** Akses cepat untuk menambahkan transaksi atau melihat sisa saldo langsung dari *home screen*.
- **Recurring transactions:** Pencatatan otomatis untuk transaksi berulang (seperti langganan Netflix, bayar listrik).
- **Dark/Light mode toggle:** Opsi bagi pengguna untuk beralih antara tema gelap dan terang (saat ini terkunci di Dark Mode).
