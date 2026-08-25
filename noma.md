# Noma

Noma adalah aplikasi pencatatan keuangan pribadi yang dibuat untuk membantu pengguna mencatat pemasukan, pengeluaran, struk belanja, dan melihat laporan keuangan secara praktis. Aplikasi ini dirancang agar data utama tetap tersimpan secara lokal dan tetap bisa diakses secara offline.

## Tujuan Aplikasi

Noma membantu pengguna memahami kondisi keuangan pribadi dari transaksi sehari-hari. Pengguna bisa mencatat pemasukan, mencatat pengeluaran, memindai struk belanja, melihat ringkasan bulanan, dan membaca insight dari data transaksi yang sudah tersimpan.

## Fitur Utama

### Dashboard Keuangan

Dashboard menampilkan ringkasan kondisi keuangan pengguna, seperti:

- Total saldo bersih.
- Total pemasukan.
- Total pengeluaran.
- Ringkasan bulan berjalan.
- Grafik pemasukan dan pengeluaran.
- Tren transaksi 7 hari terakhir.
- Riwayat transaksi terbaru.

Riwayat transaksi dibuat dengan pagination, sehingga aplikasi tidak memuat seluruh histori sekaligus ketika data sudah banyak.

### Catat Transaksi Manual

Pengguna bisa menambahkan transaksi secara manual dengan informasi seperti:

- Jenis transaksi: pemasukan atau pengeluaran.
- Nominal.
- Kategori.
- Catatan.
- Metode pembayaran.
- Tanggal transaksi.

Fitur ini cocok untuk mencatat transaksi yang tidak berasal dari struk.

### Input dengan Nomi AI

Noma memiliki fitur AI untuk membantu membaca input transaksi dari teks. Pengguna bisa menulis kalimat sederhana, lalu AI membantu mengubahnya menjadi data transaksi yang lebih terstruktur.

Contoh:

```text
Beli makan siang 25000 pakai QRIS
```

Aplikasi dapat membantu mengenali nominal, kategori, dan detail transaksi sebelum disimpan.

### Scan Struk

Noma bisa memindai struk belanja dan mendeteksi informasi penting dari gambar struk, seperti:

- Merchant atau nama toko.
- Tanggal transaksi.
- Total belanja.
- Nama barang.
- Harga barang.
- Jumlah barang jika terdeteksi.

Detail item struk disimpan sebagai data lokal, sehingga informasi barang yang sudah terbaca tidak terbuang.

### Detail Item Struk

Jika transaksi berasal dari scan struk, Noma dapat menyimpan daftar barang yang dibeli. Data ini berguna untuk insight seperti barang apa yang paling sering atau paling banyak menghabiskan uang.

Contoh data item:

- Beras.
- Telur.
- Kopi.
- Sabun.
- Roti.

Setiap item dapat memiliki jumlah, harga satuan, dan total harga.

### Laporan dan Statistik

Halaman laporan menampilkan analisis dari transaksi pengguna, seperti:

- Total pemasukan berdasarkan periode.
- Total pengeluaran berdasarkan periode.
- Grafik perbandingan pemasukan dan pengeluaran.
- Pengeluaran berdasarkan kategori.
- Barang yang paling banyak menghabiskan uang.
- Merchant atau toko dengan pengeluaran terbesar.

Laporan dapat dilihat berdasarkan periode seperti bulan ini, bulan lalu, atau semua waktu.

### Chatbot Keuangan

Noma memiliki chatbot AI yang dapat membantu pengguna bertanya tentang kondisi keuangan. Chatbot menggunakan ringkasan data transaksi lokal sebagai konteks, seperti total saldo, pemasukan, pengeluaran, kategori terbesar, dan transaksi terakhir.

Data yang digunakan untuk konteks chatbot diambil secukupnya agar aplikasi tetap ringan.

### Kategori Transaksi

Noma menyediakan kategori bawaan untuk pemasukan dan pengeluaran, seperti:

- Makanan & Minuman.
- Belanja Harian.
- Transportasi.
- Tagihan & Utilitas.
- Hiburan.
- Kesehatan.
- Pendidikan.
- Gaji.
- Bonus & THR.
- Usaha & Freelance.

Kategori membantu laporan menjadi lebih mudah dibaca.

### Mode Gelap dan Glassmorphism

Tampilan Noma menggunakan desain modern dengan dark mode dan gaya glassmorphism. Desain ini membuat aplikasi terlihat lebih elegan, tetapi tetap dijaga agar tidak terlalu berat ketika data transaksi bertambah banyak.

## Penyimpanan Offline

Noma dirancang dengan prinsip offline-first untuk data utama. Transaksi, kategori, detail item struk, pengaturan, dan histori penting disimpan di database lokal.

Artinya:

- Data transaksi tidak hilang hanya karena pergantian bulan.
- Histori lama tetap tersimpan.
- Bulan hanya digunakan sebagai filter laporan atau dashboard.
- Aplikasi tidak menghapus data lama secara otomatis.

Konsep penyimpanan data:

```text
SQLite lokal
├── Transaksi bulan ini
├── Transaksi bulan lalu
├── Transaksi bulan sebelumnya
└── Seluruh histori pengguna
```

Aplikasi hanya mengambil data yang dibutuhkan saat layar dibuka, bukan memuat seluruh histori sekaligus.

## Optimasi Performa

Noma sudah disiapkan agar tetap nyaman digunakan ketika jumlah transaksi bertambah banyak.

Optimasi yang digunakan:

- Query transaksi dibatasi dengan pagination.
- Ringkasan bulanan dihitung langsung oleh SQLite.
- Laporan memakai query agregasi seperti `SUM`, `COUNT`, dan `GROUP BY`.
- Dashboard tidak memuat seluruh histori transaksi.
- Chart 7 hari memakai agregasi harian dari database.
- Search memakai debounce agar tidak terlalu sering query.
- Detail item struk tidak dimuat untuk semua transaksi sekaligus.
- Index database ditambahkan untuk mempercepat query tanggal, tipe, kategori, dan relasi item struk.

Target desain performa:

- 10.000+ transaksi tetap nyaman digunakan.
- 50.000+ transaksi tidak membuat seluruh histori dimuat ke memory.
- Histori lama tetap tersimpan.

## Teknologi yang Digunakan

Noma dibuat menggunakan:

- Flutter untuk aplikasi mobile.
- Riverpod untuk state management.
- Drift sebagai wrapper SQLite.
- SQLite sebagai database lokal.
- Gemini atau Groq untuk fitur AI.
- Receipt scanner untuk membaca struk.
- Local storage untuk menjaga data tetap tersedia secara offline.

## Data yang Disimpan

Beberapa jenis data yang disimpan di Noma:

- Transaksi pemasukan.
- Transaksi pengeluaran.
- Kategori transaksi.
- Detail item struk.
- Path gambar struk.
- Pengaturan aplikasi.
- Histori chatbot.

Data transaksi dan detail item struk disimpan secara lokal agar tetap bisa digunakan untuk laporan dan insight.

## Alur Penggunaan Singkat

1. Pengguna membuka dashboard untuk melihat saldo dan ringkasan.
2. Pengguna menambahkan transaksi manual, input AI, atau scan struk.
3. Data transaksi disimpan ke database lokal.
4. Jika transaksi berasal dari struk, item barang juga disimpan.
5. Dashboard dan laporan membaca data sesuai periode yang dipilih.
6. Pengguna bisa melihat insight kategori, merchant, dan barang.
7. Pengguna bisa bertanya ke Nomi AI untuk membaca kondisi keuangan.

## Nilai Utama Noma

Noma bukan hanya aplikasi catatan uang biasa. Noma membantu pengguna mengubah transaksi harian menjadi informasi yang lebih berguna:

- Ke mana uang paling banyak keluar.
- Barang apa yang sering dibeli.
- Toko mana yang paling banyak menyerap pengeluaran.
- Bagaimana kondisi pemasukan dan pengeluaran bulan ini.
- Apakah saldo masih sehat atau perlu lebih hemat.

## Status Aplikasi

Noma saat ini sudah memiliki fondasi utama:

- Pencatatan transaksi.
- Scan struk.
- Penyimpanan detail item struk.
- Dashboard.
- Laporan.
- Chatbot AI.
- Database lokal offline.
- Optimasi performa untuk histori transaksi besar.

Aplikasi masih bisa terus dikembangkan, misalnya dengan fitur budget bulanan, export laporan, backup lokal, atau sinkronisasi opsional jika suatu hari dibutuhkan.
