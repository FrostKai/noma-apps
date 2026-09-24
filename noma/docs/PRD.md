# Product Requirements Document (PRD) - Noma

## Status Implementasi Saat Ini - 25 Agustus 2026

Noma sudah berada pada fase MVP fungsional. Aplikasi utama sudah berjalan dengan pencatatan transaksi, scan struk, detail item barang, dashboard, laporan, chatbot AI, database lokal offline, dan optimasi performa untuk histori besar.

Status teknis terakhir:

- `flutter analyze`: PASS, no issues found.
- `flutter test`: PASS.
- Perf smoke SQLite in-memory tersedia di `tool/perf_smoke.dart`.
- Target 100.000 transaksi sudah diuji lewat query smoke tanpa memuat seluruh histori ke memory.
- Histori transaksi sudah memakai pemilih bulan, filter range `transaction_date >= startMonth AND transaction_date < nextMonth`, dan pagination `LIMIT/OFFSET` per halaman.
- UI histori sudah dipindah ke `CustomScrollView` + `SliverList.builder`, sehingga transaction card dibangun secara lazy.
- Dashboard sudah disederhanakan menjadi snapshot cepat: saldo bersih, periode aktif, ringkasan bulan ini, dan 5 transaksi terbaru.
- Analisis kategori, merchant, item struk, dan statistik detail dipusatkan di halaman Laporan.

## 1. Ringkasan Produk

Noma adalah aplikasi pencatatan keuangan pribadi berbasis Flutter untuk membantu pengguna mencatat pemasukan, pengeluaran, struk belanja, dan membaca laporan keuangan. Data utama disimpan lokal menggunakan SQLite melalui Drift, sehingga transaksi dan detail struk tetap tersedia secara offline.

Noma menggabungkan input manual, input teks AI, scan struk, laporan keuangan, dan chatbot Nomi AI dalam satu aplikasi.

## 2. Tujuan Produk

Tujuan utama Noma:

- Membuat pencatatan keuangan lebih cepat dan ringan.
- Menyimpan histori transaksi secara lokal dan tidak menghapus data saat bulan berganti.
- Membantu pengguna memahami pola pengeluaran dari kategori, merchant, dan item barang.
- Menyediakan dashboard dan laporan yang tetap responsif meskipun data bertambah besar.

## 3. Target Pengguna

Target pengguna Noma:

- Mahasiswa.
- Pekerja awal.
- Pengguna yang ingin mencatat uang harian tanpa proses rumit.
- Pengguna yang sering belanja dengan struk dan ingin tahu barang apa yang paling banyak menghabiskan uang.
- Pengguna yang ingin aplikasi keuangan pribadi offline-first.

## 4. Fitur yang Sudah Ada

### 4.1 Dashboard

Dashboard menampilkan:

- Total saldo bersih.
- Periode saat ini.
- Ringkasan bulan ini.
- Pemasukan bulan ini.
- Pengeluaran bulan ini.
- 5 transaksi terbaru.
- Tombol `Lihat semua` menuju halaman Transaksi penuh.

Catatan performa:

- Dashboard tidak memuat seluruh histori transaksi, `transaction_items`, atau gambar struk.
- Transaksi terbaru memakai query `ORDER BY transaction_date DESC, id DESC LIMIT 5`.
- Dashboard tidak menampilkan grafik, breakdown kategori, top merchant, atau top receipt item; analisis tersebut berada di halaman Laporan.

### 4.1.1 Halaman Transaksi

Halaman Transaksi adalah tempat melihat histori transaksi lengkap.

Fitur:

- Navigasi bulan histori transaksi.
- Search transaksi dengan debounce 300ms.
- Filter transaksi berdasarkan semua, pemasukan, atau pengeluaran.
- Tombol `Muat Lagi` untuk pagination histori.
- List virtualized menggunakan `CustomScrollView` + `SliverList.builder`.

Catatan performa:

- Riwayat transaksi aktif dibatasi per bulan dengan date range.
- Tombol `Muat Lagi` mengambil halaman berikutnya dengan `LIMIT 50 OFFSET n`, bukan menaikkan limit lama.
- Histori tidak memuat `transaction_items` atau gambar struk untuk setiap card.

### 4.2 Pencatatan Manual

Pengguna dapat mencatat transaksi manual dengan data:

- Jenis transaksi: pemasukan atau pengeluaran.
- Nominal.
- Kategori.
- Catatan.
- Metode pembayaran.
- Tanggal transaksi.

Transaksi manual dapat ditambah, diedit, dan dihapus.

### 4.3 Input Teks AI

Pengguna dapat mencatat transaksi dari kalimat natural. AI membantu membaca:

- Nominal.
- Jenis transaksi.
- Kategori.
- Catatan.
- Metode pembayaran jika terdeteksi.

Hasil AI tetap dapat ditinjau dan diedit sebelum disimpan.

### 4.4 Scan Struk

Pengguna dapat mengambil foto struk dari kamera atau galeri. Sistem mencoba membaca:

- Nama toko atau merchant.
- Tanggal transaksi.
- Total belanja.
- Kategori rekomendasi.
- Nama item barang.
- Jumlah item.
- Harga item.

Sebelum disimpan, pengguna dapat mengoreksi daftar item hasil scan.

Catatan:

- OCR struk saat ini masih menggunakan AI cloud.
- Data hasil scan disimpan lokal setelah pengguna menyimpan transaksi.
- Gambar struk disimpan sebagai path file, bukan BLOB besar di SQLite.

### 4.5 Detail Item Struk

Noma menyimpan detail item struk pada tabel terpisah yang terhubung ke transaksi.

Data item mencakup:

- Nama barang.
- Jumlah.
- Harga satuan jika tersedia.
- Total harga item.
- Relasi ke transaksi utama.

Detail item dipakai untuk insight barang paling boros di laporan.

### 4.6 Laporan dan Statistik

Halaman laporan menampilkan:

- Total pemasukan berdasarkan periode.
- Total pengeluaran berdasarkan periode.
- Selisih atau net cash flow berdasarkan periode.
- Jumlah transaksi berdasarkan periode.
- Grafik pemasukan vs pengeluaran.
- Pengeluaran berdasarkan kategori.
- Barang yang paling banyak menghabiskan uang.
- Merchant atau toko terbesar.

Periode laporan:

- Bulan ini.
- Bulan lalu.
- 3 bulan terakhir.
- 6 bulan terakhir.
- Tahun ini.
- Semua waktu.

Catatan performa:

- Laporan memakai query agregasi SQLite seperti `SUM`, `COUNT`, `GROUP BY`, `ORDER BY`, dan `LIMIT`.
- Laporan tidak mengambil semua transaksi dan semua receipt item ke memory.

### 4.7 Chatbot Nomi AI

Nomi AI adalah chatbot keuangan yang dapat menjawab pertanyaan berdasarkan ringkasan data lokal.

Konteks yang dikirim ke AI dibatasi pada data yang relevan:

- Total saldo.
- Total pemasukan.
- Total pengeluaran.
- Ringkasan bulan ini.
- Kategori pengeluaran terbesar.
- 5 transaksi terakhir.

Catatan performa:

- Chatbot tidak membaca seluruh histori transaksi.
- Ringkasan dihitung dengan query agregasi.

### 4.8 Kategori

Noma menyediakan kategori bawaan untuk pemasukan dan pengeluaran.

Contoh kategori pengeluaran:

- Makanan & Minuman.
- Belanja Harian.
- Transportasi.
- Tagihan & Utilitas.
- Hiburan.
- Kesehatan.
- Pendidikan.

Contoh kategori pemasukan:

- Gaji.
- Bonus & THR.
- Investasi.
- Usaha & Freelance.
- Pemasukan Lainnya.

Pengguna dapat menambah dan menghapus kategori kustom.

### 4.9 Pengaturan

Halaman pengaturan mencakup:

- API key Gemini.
- API key Groq.
- Pengaturan notifikasi harian.
- Manajemen kategori.
- Pengaturan tampilan aplikasi.

## 5. Offline-First dan Penyimpanan Data

Noma memakai SQLite lokal sebagai penyimpanan utama.

Prinsip data:

- Transaksi tidak dihapus saat bulan berganti.
- Pergantian bulan hanya mengubah filter query.
- Histori lama tetap tersimpan.
- Dashboard dan laporan hanya mengambil data yang dibutuhkan.
- Data transaksi dan detail item struk tetap tersedia secara offline.

Struktur konsep:

```text
SQLite lokal
|-- Transaksi
|-- Detail item struk
|-- Kategori
|-- Pengaturan
`-- Histori chatbot
```

Catatan batasan:

- Fitur AI cloud tetap membutuhkan internet.
- Jika aplikasi dihapus tanpa backup perangkat, data lokal dapat hilang.
- Belum ada cloud sync atau backup otomatis.

## 6. Database dan Performa

Database memakai Drift sebagai wrapper SQLite.

Tabel utama:

- `transactions`
- `transaction_items`
- `categories`
- `chat_messages`
- `app_settings`

Index performa yang digunakan:

- `transactions(transaction_date DESC, id DESC)`
- `transactions(type, transaction_date)`
- `transactions(category, transaction_date)`
- `transaction_items(transaction_id)`

Optimasi yang sudah diterapkan:

- Pagination histori transaksi.
- Query berdasarkan periode.
- Aggregate query untuk summary.
- Aggregate query untuk laporan.
- Query terbatas `LIMIT 5` untuk transaksi terbaru Dashboard.
- Search debounce.
- Detail item struk tidak dimuat massal di dashboard.
- Chatbot memakai konteks terbatas.

Target performa:

- 10.000+ transaksi tetap nyaman digunakan.
- 50.000+ transaksi tidak membuat seluruh histori dimuat ke memory.
- 100.000 transaksi dapat diuji dengan perf smoke query.

## 7. Non-Functional Requirements

### 7.1 Performa

- Dashboard harus memakai query terbatas dan agregasi database.
- Laporan harus memakai agregasi database.
- Histori transaksi harus memakai pagination.
- Dashboard hanya boleh menjadi snapshot cepat, bukan halaman analisis lengkap.
- Search tidak boleh query terlalu agresif pada setiap karakter.

### 7.2 Offline

- Transaksi, kategori, pengaturan, detail item struk, dan histori penting disimpan lokal.
- AI cloud boleh gagal tanpa menghapus data lokal.
- Pengguna tetap dapat melihat data yang sudah tersimpan tanpa internet.

### 7.3 Privasi

- Data utama tersimpan lokal.
- Data hanya dikirim ke AI cloud saat pengguna memakai fitur AI.
- API key disimpan di perangkat pengguna.

### 7.4 UI/UX

- Tampilan utama menggunakan dark mode dan glassmorphism.
- Efek visual tidak boleh membuat list transaksi berat.
- List besar harus tetap memakai pembatasan query atau pagination.

## 8. Batasan Saat Ini

- OCR struk belum 100% offline.
- Backup JSON manual tersedia di Pengaturan > Data & Backup; file perlu disimpan pengguna di luar aplikasi.
- Export laporan PDF dan XLSX mengikuti periode laporan aktif. XLSX dibatasi 10.000 transaksi per export.
- Foto struk, API key, chat, dan preferensi aplikasi tidak termasuk backup JSON.
- Belum ada cloud sync.
- Belum ada multi-wallet.
- Belum ada budget per kategori.
- API key masih berada di sisi client, sehingga untuk produksi publik lebih aman memakai backend proxy.
- Migrasi penuh Drift web ke Wasm belum dilakukan karena target MVP adalah Android dan storage web tidak boleh diubah sembarangan.

## 9. Risiko dan Mitigasi

### Risiko: Biaya AI meningkat

Mitigasi:

- Gunakan model AI yang ekonomis.
- Batasi konteks chatbot.
- Gunakan fallback lokal untuk input teks jika memungkinkan.

### Risiko: AI salah membaca struk

Mitigasi:

- Tampilkan hasil scan sebelum disimpan.
- Izinkan koreksi item barang.
- Sediakan fallback input manual.

### Risiko: Data lokal hilang jika aplikasi dihapus

Mitigasi:

- Buat backup JSON secara berkala dan simpan di luar perangkat; restore menggabungkan transaksi berdasarkan UUID tanpa menggandakan data.
- Backup tidak otomatis dan foto struk belum ikut dipulihkan.

### Risiko: Histori besar membuat aplikasi lambat

Mitigasi:

- Gunakan pagination.
- Gunakan query periode.
- Gunakan index SQLite.
- Gunakan agregasi database.
- Hindari load seluruh histori ke memory.

## 10. Roadmap Berikutnya

Prioritas berikutnya:

1. Budget bulanan per kategori.
2. Detail transaksi struk yang lebih lengkap.
3. Filter laporan custom range.
4. Backup foto struk opsional jika kebutuhan dan kapasitas perangkat memungkinkan.
5. Optimasi tampilan list dengan lazy sliver jika dashboard mulai terasa berat.
6. Backend proxy opsional untuk AI jika aplikasi dirilis publik.

## 11. Metrik Keberhasilan

Metrik MVP:

- Pengguna dapat mencatat transaksi manual dalam kurang dari 15 detik.
- Pengguna dapat menyimpan hasil scan struk setelah koreksi.
- Dashboard tetap responsif pada histori besar.
- Laporan tetap memakai agregasi database.
- Halaman Transaksi tetap bisa membuka histori bulan-bulan lama tanpa menghapus data.
- Tidak ada error analyzer atau test pada build utama.

## 12. Glosarium

- **Noma:** Aplikasi pencatatan keuangan pribadi.
- **Nomi AI:** Asisten AI di dalam Noma.
- **SQLite:** Database lokal yang menyimpan data pengguna di perangkat.
- **Drift:** Library Flutter untuk mengakses SQLite secara type-safe.
- **Riverpod:** State management yang digunakan aplikasi.
- **Receipt Scanner:** Fitur membaca struk belanja dari gambar.
- **Glassmorphism:** Gaya tampilan seperti kaca transparan dengan blur.
- **Pagination:** Teknik memuat data sedikit demi sedikit, bukan seluruh histori sekaligus.
- **Aggregate Query:** Query database seperti `SUM`, `COUNT`, dan `GROUP BY` untuk menghitung data langsung di SQLite.
