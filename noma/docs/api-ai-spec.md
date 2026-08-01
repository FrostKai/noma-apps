# Spesifikasi API AI - Noma (Aplikasi Pencatatan Uang Berbasis AI)

Dokumen ini menjelaskan spesifikasi lengkap integrasi AI menggunakan **Google Gemini API** pada aplikasi Noma (Android/Flutter).

## 1. Gambaran Umum Integrasi AI

Noma memanfaatkan AI Generatif untuk mempermudah pencatatan dan pengelolaan keuangan pengguna. Terdapat tiga fitur utama yang ditenagai oleh AI:
1. **Pencatatan Cepat via Teks Natural**: Menerjemahkan bahasa sehari-hari pengguna menjadi data transaksi terstruktur.
2. **Pemindaian Struk (Receipt Scanner)**: Mengekstrak informasi dari foto struk belanja secara otomatis.
3. **Chatbot Asisten Keuangan**: Memberikan saran dan insight keuangan berbasis data transaksi pengguna secara interaktif.

- **AI Provider**: Google Gemini API
- **Base Endpoint**: `https://generativelanguage.googleapis.com/v1beta/`
- **Model yang digunakan**: `gemini-2.0-flash` (mendukung multimodal: teks dan gambar)
- **Klien**: Aplikasi Flutter menggunakan package `dio`

## 2. Konfigurasi & Authentication

Setiap request ke Gemini API harus menyertakan API Key.

- **Header Authentication**: Sebaiknya menggunakan header untuk mencegah API key tercatat di log URL.
  ```http
  x-goog-api-key: YOUR_API_KEY
  ```
- **Atau via Query Parameter**: (Alternatif, tapi kurang direkomendasikan untuk produksi)
  ```http
  ?key=YOUR_API_KEY
  ```
- **Content-Type**: `application/json`

---

## 3. Detail Per Use Case

### 3.1. Parsing Teks Natural ke Transaksi

Fitur ini mengubah input teks bebas menjadi objek JSON transaksi yang siap disimpan ke database.

**Model:** `gemini-2.0-flash`
**Endpoint:** `POST models/gemini-2.0-flash:generateContent`

#### System Prompt
```text
Kamu adalah asisten keuangan pintar untuk aplikasi pencatatan uang "Noma".
Tugasmu adalah mengekstrak data dari teks bebas yang diberikan oleh pengguna ke dalam format JSON yang valid.
Format JSON yang diharapkan:
{
  "type": "expense" | "income",
  "amount": angka (integer, hilangkan titik atau koma, misal: 45000),
  "category": string (pilih kategori paling cocok: Makanan, Transportasi, Belanja, Hiburan, Tagihan, Gaji, Transfer, Lainnya),
  "description": string (keterangan singkat transaksi),
  "payment_method": string (pilih salah satu jika disebutkan: Tunai, Transfer Bank, Gopay, OVO, Dana, ShopeePay, Kartu Kredit, Lainnya)
}
Hanya kembalikan objek JSON murni, tanpa markdown ```json atau teks tambahan apapun.
Jika input tidak dikenali sebagai transaksi, kembalikan objek JSON dengan field "error": "Input tidak valid".
```

#### Contoh Request (menggunakan `dio` format JSON)
```json
{
  "system_instruction": {
    "parts": [
      {
        "text": "[ISI SYSTEM PROMPT DI ATAS]"
      }
    ]
  },
  "contents": [
    {
      "role": "user",
      "parts": [
        {
          "text": "Beli kopi starbucks 45rb pake gopay"
        }
      ]
    }
  ],
  "generationConfig": {
    "responseMimeType": "application/json",
    "temperature": 0.1
  }
}
```

#### Contoh Response
```json
{
  "type": "expense",
  "amount": 45000,
  "category": "Makanan",
  "description": "Beli kopi starbucks",
  "payment_method": "Gopay"
}
```

#### Error Handling & Edge Cases
- **Input ambigu (misal "Kemarin 50 ribu")**: AI bisa diset untuk merespon default ke `expense` dan `Lainnya` dengan deskripsi "Kemarin". Jika pakai instruksi strict, kembalikan error.
- **Kesalahan format angka (misal "45k" atau "45.000")**: System prompt sudah diinstruksikan untuk mengembalikan angka integer (45000).
- **Penanganan Error**: Tangkap exception dari `dio` (misal 503 jika server overload) dan tampilkan snackbar "Gagal menganalisis teks, silakan coba lagi".

---

### 3.2. Pemindaian Struk Belanja (Receipt Scanner)

Fitur ini membaca teks pada gambar struk (OCR) dan menstrukturkannya menjadi data transaksi.

**Model:** `gemini-2.0-flash` (Multimodal)
**Endpoint:** `POST models/gemini-2.0-flash:generateContent`

#### System Prompt
```text
Kamu adalah sistem ekstraksi struk belanja untuk aplikasi keuangan "Noma".
Tugasmu adalah membaca gambar struk yang diberikan dan mengembalikan data dalam format JSON yang valid.
Format JSON yang diharapkan:
{
  "store_name": string (nama toko/merchant),
  "date": string (format YYYY-MM-DD, jika ada),
  "total": angka (integer, total belanja akhir),
  "category_suggestion": string (kategori yang paling sesuai: Makanan, Belanja Bulanan, Transportasi, Lainnya),
  "items": [
    {
      "name": string (nama barang),
      "total_price": angka (integer, harga total per item),
      "quantity": angka (integer, jika tersedia)
    }
  ]
}
Jika gambar bukan struk atau teks tidak terbaca, kembalikan:
{
  "error": "Gambar tidak dapat dibaca atau bukan struk belanja"
}
Hanya kembalikan objek JSON murni tanpa markdown.
```

#### Contoh Request (Multimodal)
```json
{
  "system_instruction": {
    "parts": [
      {
        "text": "[ISI SYSTEM PROMPT DI ATAS]"
      }
    ]
  },
  "contents": [
    {
      "role": "user",
      "parts": [
        {
          "inlineData": {
            "mimeType": "image/jpeg",
            "data": "BASE64_ENCODED_STRING_IMAGE_HERE"
          }
        },
        {
          "text": "Tolong ekstrak data struk ini."
        }
      ]
    }
  ],
  "generationConfig": {
    "responseMimeType": "application/json",
    "temperature": 0.0
  }
}
```

#### Contoh Response
```json
{
  "store_name": "Indomaret",
  "date": "2024-05-12",
  "total": 25500,
  "category_suggestion": "Belanja Bulanan",
  "items": [
    {
      "name": "Aqua Botol 600ml",
      "total_price": 7000,
      "quantity": 2
    },
    {
      "name": "Chitato Sapi Panggang",
      "total_price": 18500,
      "quantity": 1
    }
  ]
}
```

#### Tips & Error Handling
- **Kualitas Foto**: Berikan panduan UI agar pengguna mengambil foto di tempat terang, tidak blur, dan struk lurus. Kompresi gambar disarankan sebelum dikirim (misal lebar max 1024px, quality 80%) agar mempercepat upload dan mengurangi token.
- **Struk Blur/Gelap**: Jika AI mengembalikan pesan error (karena resolusi jelek), tampilkan popup "Struk tidak terbaca, mohon foto ulang dengan lebih jelas".
- **Timeout**: Gunakan timeout 15-20 detik pada `dio`, karena proses gambar bisa memakan waktu sedikit lebih lama.

---

### 3.3. Chatbot Keuangan

Asisten pintar interaktif untuk tanya jawab tentang kondisi keuangan pengguna.

**Model:** `gemini-2.0-flash`
**Endpoint:** `POST models/gemini-2.0-flash:generateContent`

#### System Prompt
```text
Kamu adalah "Nomi", asisten keuangan pribadi yang ramah, profesional, dan empatik untuk aplikasi "Noma".
Gunakan bahasa Indonesia yang santai tapi sopan (gunakan kata 'kamu' untuk pengguna).
Tugasmu adalah menjawab pertanyaan terkait keuangan pengguna berdasarkan data konteks yang diberikan.
Jangan memberikan saran investasi yang berisiko atau menjanjikan keuntungan pasti. Fokus pada budgeting, penghematan, dan kebiasaan sehat finansial.
Jika ditanya di luar topik keuangan, tolak dengan halus dan arahkan kembali ke pencatatan uang.
Jawablah dengan ringkas dan jelas (maksimal 3 paragraf pendek). Gunakan format poin jika perlu.
```

#### Contoh Request (dengan Context Window)
Aplikasi harus mengirim ulang konteks data user (ringkasan bulan ini) dan beberapa riwayat chat (misal 5-10 pesan terakhir) agar percakapan nyambung.

```json
{
  "system_instruction": {
    "parts": [
      {
        "text": "[ISI SYSTEM PROMPT DI ATAS]"
      }
    ]
  },
  "contents": [
    {
      "role": "user",
      "parts": [
        {
          "text": "Data keuangan bulan ini: Total Pemasukan Rp 5.000.000, Total Pengeluaran Rp 4.200.000. Pengeluaran terbesar: Makanan Rp 2.000.000.\nHalo Nomi, apakah pengeluaran saya bulan ini sudah berlebihan?"
        }
      ]
    },
    {
      "role": "model",
      "parts": [
        {
          "text": "Halo! Sisa uang kamu bulan ini Rp 800.000 ya. Mengingat pengeluaran terbesarmu ada di kategori Makanan (Rp 2.000.000), ini lumayan besar lho (40% dari pemasukan). Mungkin kamu bisa coba kurangi jajan di luar atau masak sendiri agar bisa lebih hemat. Ada target tabungan bulan ini?"
        }
      ]
    },
    {
      "role": "user",
      "parts": [
        {
          "text": "Targetku nabung 1 juta bulan ini, kira-kira nutup gak ya?"
        }
      ]
    }
  ],
  "generationConfig": {
    "temperature": 0.7
  }
}
```

#### Context Window Management
- Kirimkan ringkasan data transaksi (summary pemasukan, pengeluaran, sisa saldo, top kategori) secara tersembunyi pada prompt pertama dari user di setiap sesi.
- Pertahankan **maksimal 10 turn percakapan terakhir** (5 pasang user-model) untuk menghemat penggunaan token, hapus riwayat yang lebih lama dari array `contents`.

---

## 4. Rate Limiting & Quota Management

- **Free Tier Gemini**: Umumnya memiliki batasan (misal 15 RPM / 1 juta TPM / 1.500 RPD). Ini sangat cukup untuk development.
- **Production**:
  - Implementasikan *debounce* (misal 1 detik) di UI saat user mengetik.
  - Sediakan status indikator (loading spinner) saat menunggu response.
  - Tangkap status code `429 Too Many Requests`. Jika terjadi, tampilkan notifikasi: "Server sedang sibuk, silakan coba beberapa saat lagi."

## 5. Keamanan API Key

**SANGAT PENTING**: Jangan pernah menaruh API Key secara hardcode di dalam kode Flutter.
- Gunakan file `.env` (melalui package `flutter_dotenv`) untuk menyimpan `GEMINI_API_KEY`.
- Untuk keamanan yang lebih baik di production (skala menengah-besar), sangat disarankan agar aplikasi Flutter tidak langsung menembak API Gemini. Sebaiknya: `Flutter App` -> `Backend (Node.js/Go) milik Noma` -> `Gemini API`. Dengan begitu API Key tersimpan aman di server backend, bukan di aplikasi klien yang bisa di-reverse engineer.

## 6. Fallback & Offline Behavior

- **Koneksi Terputus**: API Gemini membutuhkan internet. Jika device offline, disable sementara fitur AI (tombol mic, input AI, scanner) dan beri indikator visual "Membutuhkan koneksi internet untuk fitur AI".
- **Fallback Pencatatan**: User harus tetap bisa mencatat transaksi secara manual lewat form standar jika fitur AI sedang error atau offline.

## 7. Cost Estimation (Estimasi Biaya)

Untuk `gemini-2.0-flash` (harga bisa berubah, mengacu pada struktur Google AI Studio saat tulisan ini dibuat):
- **Teks Natural**: ~150 input token + ~50 output token per request. Biaya sangat murah (bisa gratis pada tier tertentu).
- **Struk Scanner**: 1 gambar base64 biasanya dikalkulasi setara ~258 token + teks prompt. Output ~100 token.
- **Chatbot**: Token lebih banyak karena menyimpan riwayat (bisa 1000-2000 token per request).

**Estimasi Kasar (Gratis vs Berbayar):**
Jika menggunakan API Keys dari Google AI Studio dengan *free tier*, biayanya **Gratis** asalkan tidak melebihi limit. Jika masuk ke *Pay-as-you-go*, biayanya dihitung per 1 juta token. Model Flash sangat efisien, estimasi pemakaian oleh 1.000 DAU (Daily Active Users) dengan masing-masing 5 request/hari mungkin hanya memakan biaya < $1 per hari.
