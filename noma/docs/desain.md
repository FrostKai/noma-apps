# Desain Sistem Aplikasi Noma

Aplikasi Noma - Aplikasi Pencatatan Uang Berbasis AI untuk Android.

## 1. Design Principles & Philosophy
**Modern Dark Mode dengan Glassmorphism**
Noma mengusung filosofi desain modern, futuristik, dan clean. Menggunakan perpaduan Dark Mode sebagai kanvas utama untuk memberikan kesan premium dan nyaman di mata (eye-straining reduction), dipadukan dengan efek Glassmorphism untuk menciptakan ilusi kedalaman (depth), transparansi, dan hierarki visual yang kuat. Aplikasi keuangan seringkali terasa kaku; Noma hadir dengan pendekatan visual yang dinamis, interaktif, dan "hidup" untuk membuat pencatatan keuangan menjadi pengalaman yang menyenangkan.

## 2. Color System
Sistem warna Noma dirancang untuk visibilitas tinggi pada latar belakang gelap, dengan aksen neon untuk penekanan.

| Kategori | Nama Warna | Kode Hex | Penggunaan Utama |
| :--- | :--- | :--- | :--- |
| **Background Utama** | Deep Dark Slate | `#0A0E1A` / `#0F172A` | Background dasar aplikasi (Scaffold background). |
| **Surface/Card** | Glassy Slate | `#1E293B` | Background untuk card, bottom sheet, dialog (dengan opacity 0.4-0.8). |
| **Aksen Primer** | Emerald Glowing | `#10B981` | Indikator pemasukan (income), tombol sukses, saldo positif, grafik naik. |
| **Aksen Sekunder** | Neon Cyan | `#06B6D4` | Tombol aksi utama (FAB, submit), highlight tab aktif, interaksi AI. |
| **Aksen Bahaya** | Soft Red/Rose | `#F43F5E` | Indikator pengeluaran (expense), error, peringatan over-budget, grafik turun. |
| **Aksen Warning** | Amber | `#F59E0B` | Peringatan mendekati batas budget, notifikasi penting, status pending. |
| **Teks Utama** | Off-White | `#F1F5F9` | Teks utama, judul, nominal uang utama, paragraf penting. |
| **Teks Sekunder**| Slate Gray | `#94A3B8` | Teks pendukung, caption, placeholder, tanggal, kategori ringan. |
| **Border Glass** | Glass Border | `rgba(255, 255, 255, 0.08)` | Garis batas (border) untuk elemen glassmorphism agar batasnya terlihat tegas tanpa mengganggu transparansi. |

## 3. Typography Scale
Noma menggunakan dua jenis font dari Google Fonts untuk membedakan hierarki informasi numerik dan tekstual.

*   **Heading & Angka Keuangan:** **Outfit** (Geometris, modern, mudah dibaca untuk angka besar).
*   **Body & UI Text:** **Inter** (Sangat terbaca, netral, cocok untuk paragraf dan teks antarmuka kecil).

**Skala Tipografi:**
*   **Display / Total Balance:** Outfit, Bold, 40sp / 48sp, Letter-spacing: -1px (Warna: Off-White)
*   **H1 (App Bar / Judul Halaman):** Outfit, SemiBold, 24sp / 28sp (Warna: Off-White)
*   **H2 (Judul Section):** Outfit, Medium, 20sp (Warna: Off-White)
*   **Subtitle (Sub-judul / Nama Kategori):** Inter, Medium, 16sp (Warna: Off-White)
*   **Body 1 (Teks Paragraf / Input):** Inter, Regular, 14sp (Warna: Off-White / Slate Gray)
*   **Caption (Tanggal / Info Tambahan):** Inter, Regular, 12sp (Warna: Slate Gray)
*   **Micro (Badge / Tag):** Inter, SemiBold, 10sp (Uppercase, Spacing: 1px)

## 4. Spacing & Layout Grid
Noma menggunakan grid 4px/8px standar Material Design untuk menjaga konsistensi.

*   **Base Unit:** 8dp
*   **Screen Margin:** 24dp (kiri dan kanan)
*   **Gap (Antar Elemen Kecil):** 8dp
*   **Gap (Antar Section):** 24dp - 32dp
*   **Border Radius:**
    *   Kecil (Tombol, Chip): 8dp - 12dp
    *   Menengah (Card Standar, Input): 16dp
    *   Besar (Glass Card Utama, Bottom Sheet): 24dp - 32dp

## 5. Komponen UI

*   **Card Transaksi:** Menggunakan efek Glassmorphism. Memuat Ikon Kategori (kiri), Nama Kategori & Deskripsi (tengah), Nominal & Tanggal (kanan). Warna nominal mengikuti jenis (Primer untuk pemasukan, Bahaya untuk pengeluaran).
*   **Input Field:** Background transparan dengan border `rgba(255,255,255,0.12)`. Saat fokus, border menjadi aksen Neon Cyan. Teks input Off-White, placeholder Slate Gray.
*   **Bottom Navigation Bar:** Floating navbar dengan efek glassmorphism, terpisah (margin bottom 16dp) dari tepi bawah layar. Ikon tab aktif menyala (Neon Cyan) dengan indikator titik di bawahnya.
*   **Floating Action Button (FAB):** Menonjol dengan warna Neon Cyan (gradient dari cyan ke biru) dengan glow shadow. Digunakan khusus untuk "Tambah Transaksi" atau memanggil "AI Scanner".
*   **Chat Bubble (AI Assistant):**
    *   User: Bubble solid Surface color (`#1E293B`) di sisi kanan.
    *   AI: Bubble Glassmorphism dengan border tipis Neon Cyan di sisi kiri, menyertakan ikon robot kecil.
*   **Notification Card:** Mirip dengan Card Transaksi namun dengan strip aksen (Amber/Red) di sisi kiri untuk menunjukkan urgensi.

## 6. Glassmorphism Guidelines (Flutter)
Efek Glassmorphism di Noma mengandalkan kombinasi `BackdropFilter` (untuk blur latar belakang), `Container` semi-transparan, border tipis yang subtle, dan bayangan lembut.

**Parameter Standar:**
*   **Blur X/Y:** 20px - 30px
*   **Background:** `Color(0xFF1E293B).withOpacity(0.6)`
*   **Border:** `Border.all(color: Colors.white.withOpacity(0.08), width: 1.0)`
*   **Shadow:** `BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 32, spreadRadius: 0, offset: Offset(0, 8))`

**Contoh Kode Flutter Snippet:**

```dart
import 'dart:ui';
import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final double width;
  final double height;
  final BorderRadius borderRadius;

  const GlassCard({
    Key? key,
    required this.child,
    this.width = double.infinity,
    this.height = double.infinity,
    this.borderRadius = const BorderRadius.all(Radius.circular(24.0)),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 32.0,
            spreadRadius: 0.0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withOpacity(0.6), // Surface Color
              borderRadius: borderRadius,
              border: Border.all(
                color: Colors.white.withOpacity(0.08), // Subtle white border
                width: 1.0,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.1),
                  Colors.white.withOpacity(0.02),
                ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
```

## 7. Animasi & Micro-interactions
*   **Hero Transitions:** Transisi smooth saat berpindah dari Card di Home ke halaman Detail Transaksi.
*   **Scale Hover/Tap:** Tombol dan Card Transaksi mengecil (scale 0.95) saat ditekan (tap down) dan memantul kembali (spring) saat dilepas (tap up).
*   **Shimmer Effect:** Digunakan sebagai placeholder saat loading data AI atau fetching transaksi. Warna shimmer menggunakan gradiasi abu-abu gelap ke `rgba(255,255,255,0.1)`.
*   **Number Counting Animation:** Total Saldo dan grafik teranimasi dari 0 ke nominal akhir saat halaman Home di-load.

## 8. Ikonografi
*   **Library:** Lucide Icons (memberikan kesan garis yang bersih dan konsisten) atau Material Symbols (Rounded & Outlined).
*   **Stroke Width:** 2px.
*   **Gaya:** Minimalis, rounded corners. Hindari ikon filled (kecuali untuk indikator tab yang sedang aktif).

## 9. Halaman-halaman Aplikasi (Wireframe Deskriptif)

### 1. Splash Screen
*   Latar belakang gradient Deep Dark Slate (`#0A0E1A`).
*   Logo Noma (kombinasi huruf N dengan aksen dompet/grafik) dengan efek Neon Cyan glow di tengah.
*   Teks Noma dengan font Outfit.

### 2. Home / Dashboard
*   **Header:** Profil pengguna (foto sirkular) di kiri, Ikon Notifikasi di kanan.
*   **Balance Card (Glassmorphism Besar):** Menampilkan Total Saldo di tengah dengan font Outfit 48sp (Off-White). Di bawahnya terdapat informasi In/Out ringkas bulan ini menggunakan aksen Emerald/Rose.
*   **Quick Actions:** Deretan ikon bulat/glass-chip (Pindai Struk, Laporan, Chat AI).
*   **Recent Transactions:** List vertikal ke bawah berupa deretan GlassCard untuk tiap transaksi terbaru.

### 3. Tambah Transaksi (Manual & AI Text)
*   Formulir input nominal besar (Outfit) di bagian atas.
*   Toggle "Pemasukan / Pengeluaran" berbentuk pill (hijau/merah).
*   **AI Smart Input:** Kotak teks khusus di atas form manual: *"Ketik 'Beli kopi Starbucks 50 ribu pakai Gopay'"*. Noma AI akan otomatis mengisi form kategori, nominal, dan metode pembayaran.

### 4. Scanner Struk (AI Receipt OCR)
*   **Camera Viewfinder:** Layar penuh kamera dengan kotak pemindai (corner brackets).
*   **Overlays:** Tombol ambil gambar, panduan teks "Posisikan struk dalam kotak".
*   **Preview Mode:** Menampilkan foto struk yang diambil, disusul loading spinner (animasi scan AI). Muncul bottom sheet berisi hasil ekstraksi otomatis untuk dikonfirmasi.

### 5. Chatbot AI (Noma Assistant)
*   Tampilan mirip aplikasi chat modern.
*   **User Message:** Bubble abu-abu gelap, sejajar kanan.
*   **AI Message:** Glass bubble dengan border tipis cyan, sejajar kiri. Bisa menampilkan elemen kaya seperti Card Transaksi atau Mini-Chart langsung di dalam obrolan jika pengguna bertanya (misal: "Berapa total pengeluaran makan saya bulan ini?").

### 6. Laporan / Statistik
*   **Chart Area:** Bar chart atau Line chart interaktif di atas (menggunakan fl_chart atau yang serupa). Warna bar merepresentasikan Pemasukan/Pengeluaran.
*   **Donut Chart Kategori:** Ringkasan persentase kategori pengeluaran terbesar dengan legend interaktif.

### 7. Pengaturan
*   List menu standard (Akun, Notifikasi, Data, Integrasi AI, Tema).
*   Toggle switches dengan gaya iOS atau Material 3 beraksen Neon Cyan.

### 8. Manajemen Kategori
*   Diakses dari Halaman Pengaturan atau saat menambah transaksi (tombol "+" di samping dropdown kategori).
*   **Daftar Kategori:** List vertikal dengan GlassCard per kategori — menampilkan ikon, nama, warna, dan tipe (Pemasukan/Pengeluaran/Keduanya). Kategori bawaan ditandai dengan badge "Default".
*   **Tambah/Edit Kategori:** Bottom sheet dengan input nama, pilihan ikon (grid ikon Material), color picker (palet warna preset), dan toggle tipe.
*   **Hapus Kategori:** Swipe-to-delete dengan konfirmasi dialog. Kategori bawaan tidak bisa dihapus (tombol hapus di-disable dengan tooltip penjelasan).

## 10. Responsivitas & Adaptasi Layar
*   **Mobile Phone:** Menggunakan orientasi Portrait utama. Elemen ditata vertikal, Scrollable list. Bottom Navigation Bar untuk navigasi utama.
*   **Tablet/Foldables:** Menggunakan Layout adaptif. Navigasi beralih ke Navigation Rail di sisi kiri. Home dashboard akan menampilkan grafik/laporan di panel kanan dan list transaksi di panel kiri (Split View). Modals (Bottom Sheet) akan berubah menjadi Dialog di tengah layar. Menggunakan `LayoutBuilder` di Flutter untuk mendeteksi breakpoint (misal: > 600px).
