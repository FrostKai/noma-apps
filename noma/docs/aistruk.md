# 🧾 AI Struk — Panduan Membangun AI Pembaca Struk Belanja

## Status Implementasi Noma Saat Ini - 7 Agustus 2026

Dokumen ini adalah panduan untuk opsi masa depan jika Noma ingin membangun AI pembaca struk sendiri. Implementasi aplikasi saat ini belum memakai model open-source self-hosted atau fine-tuning.

Yang berjalan di kode saat ini:

- Flutter mengambil gambar via `image_picker` dari kamera atau galeri.
- Gambar di-resize oleh `image_picker` dengan `maxWidth: 1200`, `maxHeight: 1600`, dan `imageQuality: 85`.
- Byte gambar dikirim langsung dari client ke Gemini Vision melalui `GeminiApiService.scanReceiptImage`.
- Response JSON divalidasi minimal: harus punya total lebih dari 0 atau total hasil penjumlahan item.
- Hasil ditampilkan dalam bottom sheet ringkasan lalu disimpan ke Drift sebagai transaksi `expense` dengan source `receipt_scan`.

Rekomendasi jangka pendek sebelum masuk fine-tuning:

1. Tambahkan form review/edit hasil scan: total, toko, tanggal, kategori, payment method, dan item utama.
2. Simpan confidence atau flag "perlu review" bila total diperoleh dari penjumlahan item, bukan field total eksplisit.
3. Batasi debug log agar tidak terlalu banyak mencetak payload/response saat production.
4. Gunakan backend proxy jika ingin melindungi API key dan mengontrol quota.

Gunakan sisa dokumen ini hanya bila arah produk berubah ke AI server milik sendiri atau model open-source yang di-host terpisah.

> Dokumen ini menjelaskan cara **membangun AI pembaca struk belanja** sendiri menggunakan model open-source yang sudah ada (fine-tuning), mulai dari pemilihan model, pengumpulan dataset, training, deployment, hingga integrasi ke aplikasi Flutter Noma.

---

## 📋 Daftar Isi

1. [Gambaran Umum](#1-gambaran-umum)
2. [Arsitektur Sistem AI Struk](#2-arsitektur-sistem-ai-struk)
3. [Pilihan Model Open-Source](#3-pilihan-model-open-source)
4. [Persiapan Dataset](#4-persiapan-dataset)
5. [Proses Training / Fine-Tuning](#5-proses-training--fine-tuning)
6. [Deployment ke Server](#6-deployment-ke-server)
7. [API Endpoint Spesifikasi](#7-api-endpoint-spesifikasi)
8. [Integrasi ke Flutter Noma](#8-integrasi-ke-flutter-noma)
9. [Estimasi Biaya & Resource](#9-estimasi-biaya--resource)
10. [Roadmap Pengembangan AI](#10-roadmap-pengembangan-ai)

---

## 1. Gambaran Umum

### Tujuan

Membangun AI yang mampu:
- Menerima **foto struk belanja** (dari kamera / galeri HP)
- **Mengekstrak informasi** secara otomatis:
  - Nama toko
  - Tanggal transaksi
  - Total belanja
  - Daftar item (opsional)
  - Saran kategori pengeluaran
- Mengembalikan hasil dalam format **JSON terstruktur**

### Pendekatan: Fine-Tuning Model yang Sudah Ada

Kita **tidak membuat model dari nol**. Kita mengambil model AI open-source yang sudah pintar membaca teks dalam gambar, lalu kita **latih ulang (fine-tune)** agar lebih akurat untuk membaca struk belanja Indonesia.

### Kenapa Fine-Tune?

| Aspek | Tanpa Fine-Tune (Zero-shot) | Dengan Fine-Tune |
|-------|----------------------------|-------------------|
| Akurasi struk Indonesia | 60-75% | 85-95% |
| Memahami format Rupiah | Kadang salah | Sangat akurat |
| Mengenali toko lokal | Kurang | Sangat baik |
| Kategorisasi otomatis | Generic | Sesuai kebutuhan kita |
| Waktu setup | 1 hari | 2-4 minggu |

---

## 2. Arsitektur Sistem AI Struk

```
┌─────────────────────────────────────────────────────────┐
│                    APLIKASI FLUTTER (NOMA)               │
│                                                          │
│  ┌──────────┐    ┌──────────────┐    ┌───────────────┐  │
│  │  Kamera / │───▶│  Preprocessing│───▶│  HTTP Request │  │
│  │  Galeri   │    │  (resize,     │    │  ke AI Server │  │
│  └──────────┘    │   compress)   │    └───────┬───────┘  │
│                  └──────────────┘            │           │
└─────────────────────────────────────────────┼───────────┘
                                              │
                                    ┌─────────▼─────────┐
                                    │   AI SERVER        │
                                    │   (Cloud/VPS)      │
                                    │                    │
                                    │  ┌──────────────┐  │
                                    │  │ Model AI      │  │
                                    │  │ (Fine-tuned)  │  │
                                    │  └──────┬───────┘  │
                                    │         │          │
                                    │  ┌──────▼───────┐  │
                                    │  │ Post-process  │  │
                                    │  │ & Validasi    │  │
                                    │  └──────┬───────┘  │
                                    │         │          │
                                    │  ┌──────▼───────┐  │
                                    │  │ JSON Response │  │
                                    │  └──────────────┘  │
                                    └────────────────────┘
```

### Aliran Data Detail

```
1. User foto struk di HP
       ↓
2. Flutter resize gambar ke max 1024px, compress JPEG quality 85%
       ↓
3. Gambar dikirim ke AI Server via HTTP POST (multipart/form-data)
       ↓
4. Server terima gambar → kirim ke model AI
       ↓
5. Model AI proses gambar → output teks terstruktur
       ↓
6. Server validasi & format ke JSON
       ↓
7. JSON dikirim balik ke Flutter
       ↓
8. Flutter tampilkan hasil → user konfirmasi → simpan ke database lokal
```

---

## 3. Pilihan Model Open-Source

### 3.1. 🏆 Rekomendasi Utama: Qwen2.5-VL (Vision-Language Model)

| Properti | Detail |
|----------|--------|
| **Nama Model** | `Qwen/Qwen2.5-VL-7B-Instruct` |
| **Pengembang** | Alibaba Cloud (Qwen Team) |
| **Tipe** | Vision-Language Model (VLM) — bisa baca gambar + teks |
| **Ukuran** | 7B parameter (~14GB VRAM untuk inference) |
| **Lisensi** | Apache 2.0 (bebas digunakan komersial) |
| **Keunggulan** | Sangat unggul dalam membaca dokumen, tabel, dan struk. Support bahasa Indonesia. |
| **Versi Kecil** | `Qwen2.5-VL-3B-Instruct` (~6GB VRAM, lebih ringan) |
| **Download** | [HuggingFace](https://huggingface.co/Qwen/Qwen2.5-VL-7B-Instruct) |

**Kenapa Qwen2.5-VL?**
- Multimodal: bisa langsung menerima gambar + instruksi teks
- Performa OCR terbaik di kelasnya untuk dokumen & struk
- Support fine-tuning dengan LoRA (hemat VRAM)
- Komunitas besar & dokumentasi lengkap

### 3.2. Alternatif Lain

| Model | Ukuran | Kelebihan | Kekurangan |
|-------|--------|-----------|------------|
| **Florence-2** (Microsoft) | 0.2B / 0.7B | Sangat ringan, bagus untuk OCR | Kurang pintar reasoning/kategorisasi |
| **PaddleOCR** (Baidu) | ~50MB | Ringan, OCR murni, cepat | Hanya ekstrak teks mentah, tidak bisa parsing struktur |
| **Donut** (Naver) | 200M | Dirancang khusus untuk dokumen | Kurang fleksibel, perlu fine-tune berat |
| **LayoutLMv3** (Microsoft) | 125M / 350M | Bagus untuk dokumen terstruktur | Perlu OCR terpisah sebagai input |
| **LLaVA-1.6** | 7B / 13B | Vision-Language yang bagus | Kurang akurat untuk OCR detail dibanding Qwen |

### 3.3. Pendekatan Pipeline vs End-to-End

#### Pendekatan A: End-to-End (Rekomendasi ✅)

Menggunakan **1 model VLM** (Qwen2.5-VL) yang langsung menerima gambar dan menghasilkan JSON.

```
Foto Struk → [Qwen2.5-VL] → JSON Output
```

- ✅ Lebih sederhana
- ✅ Lebih akurat (model memahami konteks visual + teks sekaligus)
- ✅ Lebih mudah di-maintain

#### Pendekatan B: Pipeline (2 Tahap)

Menggunakan **OCR dulu** untuk ekstrak teks, lalu **LLM** untuk parsing.

```
Foto Struk → [PaddleOCR] → Teks Mentah → [LLM kecil] → JSON Output
```

- ✅ Setiap komponen lebih kecil/ringan
- ❌ Lebih kompleks
- ❌ Error bisa berantai (OCR salah → LLM ikut salah)

---

## 4. Persiapan Dataset

### 4.1. Apa yang Dibutuhkan?

Untuk fine-tune model agar akurat membaca struk Indonesia, kamu butuh **dataset struk belanja** dengan **label/anotasi**.

| Komponen | Minimal | Ideal | Keterangan |
|----------|---------|-------|------------|
| Jumlah foto struk | 200 | 500-1000 | Semakin banyak semakin akurat |
| Variasi toko | 10+ | 30+ | Minimarket, restoran, toko online, pasar, dll |
| Kualitas foto | Campuran | Campuran | Sengaja campur foto bagus & sedikit blur |
| Anotasi per foto | Wajib | Wajib | Label JSON untuk setiap foto |

### 4.2. Cara Mengumpulkan Dataset

#### Sumber Foto Struk:
1. **Foto sendiri** — Kumpulkan struk belanja harianmu selama 1-2 bulan
2. **Minta ke teman/keluarga** — Minta mereka foto struk belanja mereka
3. **Dataset publik** — Beberapa dataset struk yang bisa dipakai:
   - [CORD Dataset](https://github.com/clovaai/cord) — 1000 struk (bahasa Inggris/Korea, tapi berguna untuk pretraining)
   - [SROIE Dataset](https://arxiv.org/abs/2103.10213) — 973 struk toko
4. **Synthetic data** — Generate struk palsu menggunakan template HTML/CSS

#### Tips Foto:
- Foto dari berbagai sudut (lurus, sedikit miring)
- Cahaya berbeda (terang, redup, flash)
- Resolusi berbeda (HP murah vs bagus)
- Struk yang sedikit kusut/terlipat
- Struk thermal yang sudah mulai pudar

### 4.3. Format Anotasi

Setiap foto struk harus memiliki pasangan file JSON sebagai labelnya:

**Nama file:**
```
dataset/
├── images/
│   ├── struk_001.jpg
│   ├── struk_002.jpg
│   └── ...
└── labels/
    ├── struk_001.json
    ├── struk_002.json
    └── ...
```

**Contoh label `struk_001.json`:**
```json
{
  "store_name": "Indomaret",
  "store_address": "Jl. Sudirman No. 45, Jakarta",
  "date": "2026-07-20",
  "time": "14:35",
  "items": [
    {
      "name": "Indomie Goreng",
      "quantity": 3,
      "unit_price": 3500,
      "total_price": 10500
    },
    {
      "name": "Aqua 600ml",
      "quantity": 2,
      "unit_price": 4000,
      "total_price": 8000
    },
    {
      "name": "Teh Pucuk 350ml",
      "quantity": 1,
      "unit_price": 5000,
      "total_price": 5000
    }
  ],
  "subtotal": 23500,
  "tax": 0,
  "discount": 0,
  "total": 23500,
  "payment_method": "Tunai",
  "category_suggestion": "Belanja Harian"
}
```

### 4.4. Tools untuk Anotasi

| Tool | Tipe | Keterangan |
|------|------|------------|
| **Label Studio** | Web-based | Open-source, sangat fleksibel, bisa untuk gambar + teks |
| **Manual JSON** | Text editor | Tulis JSON manual — cocok untuk dataset kecil (<200) |
| **Custom script** | Python | Buat script Python untuk mempercepat anotasi |

### 4.5. Shortcut: Gunakan AI Existing untuk Generate Label Awal

Trik cerdas untuk mempercepat proses anotasi:

```
1. Kirim foto struk ke Gemini API (gratis)
       ↓
2. Gemini generate JSON output
       ↓
3. Kamu review & koreksi JSON-nya secara manual
       ↓
4. Simpan sebagai label dataset
```

Ini jauh lebih cepat daripada menulis label dari nol! Proses ini disebut **"human-in-the-loop annotation"**.

---

## 5. Proses Training / Fine-Tuning

### 5.1. Persyaratan Hardware

| Komponen | Minimum | Rekomendasi |
|----------|---------|-------------|
| **GPU** | NVIDIA dengan 8GB VRAM (RTX 3060) | 16GB+ VRAM (RTX 4080, A100) |
| **RAM** | 16 GB | 32 GB |
| **Storage** | 50 GB SSD | 100 GB SSD |
| **OS** | Linux (Ubuntu 22.04+) | Linux |

> **Tidak punya GPU?** Gunakan layanan cloud gratis/murah:
> - **Google Colab** (gratis, GPU T4 16GB, terbatas waktu)
> - **Kaggle Notebooks** (gratis, GPU P100 16GB, 30 jam/minggu)
> - **Lambda Labs** (~$0.50/jam, GPU A10 24GB)
> - **RunPod** (~$0.40/jam, berbagai GPU)

### 5.2. Metode Fine-Tuning: LoRA / QLoRA

Kita menggunakan **LoRA (Low-Rank Adaptation)** agar fine-tuning bisa dilakukan dengan VRAM terbatas.

| Metode | VRAM Dibutuhkan | Kecepatan | Akurasi |
|--------|-----------------|-----------|---------|
| Full Fine-tune | 48GB+ | Lambat | Terbaik |
| **LoRA** | 16GB | Cepat | Sangat baik |
| **QLoRA** (4-bit) | **8GB** | Cepat | Baik |

### 5.3. Setup Environment

```bash
# 1. Buat virtual environment
python -m venv venv
source venv/bin/activate  # Linux/Mac
# atau: venv\Scripts\activate  # Windows

# 2. Install dependencies
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
pip install transformers accelerate peft bitsandbytes
pip install trl datasets pillow

# 3. (Opsional) Install unsloth untuk training 2x lebih cepat
pip install unsloth
```

### 5.4. Script Training (Contoh dengan Qwen2.5-VL + LoRA)

```python
"""
train_receipt_model.py
Fine-tune Qwen2.5-VL untuk membaca struk belanja Indonesia
"""

import json
import os
from datasets import Dataset
from transformers import (
    Qwen2_5_VLForConditionalGeneration,
    AutoProcessor,
    TrainingArguments,
)
from peft import LoraConfig, get_peft_model
from trl import SFTTrainer
from PIL import Image

# ============================================================
# 1. KONFIGURASI
# ============================================================

MODEL_NAME = "Qwen/Qwen2.5-VL-3B-Instruct"  # Pakai 3B agar ringan
DATASET_DIR = "./dataset"
OUTPUT_DIR = "./output/noma-receipt-model"
NUM_EPOCHS = 3
BATCH_SIZE = 2
LEARNING_RATE = 2e-4

# ============================================================
# 2. LOAD MODEL & PROCESSOR
# ============================================================

processor = AutoProcessor.from_pretrained(MODEL_NAME)

model = Qwen2_5_VLForConditionalGeneration.from_pretrained(
    MODEL_NAME,
    torch_dtype="auto",
    device_map="auto",
    load_in_4bit=True,  # QLoRA: hemat VRAM
)

# ============================================================
# 3. KONFIGURASI LoRA
# ============================================================

lora_config = LoraConfig(
    r=16,                      # Rank
    lora_alpha=32,             # Alpha
    lora_dropout=0.05,
    target_modules=[
        "q_proj", "k_proj", "v_proj", "o_proj",
        "gate_proj", "up_proj", "down_proj"
    ],
    task_type="CAUSAL_LM",
)

model = get_peft_model(model, lora_config)
model.print_trainable_parameters()
# Output: trainable params: ~25M / 3B total (~0.8%)

# ============================================================
# 4. PERSIAPAN DATASET
# ============================================================

SYSTEM_PROMPT = """Kamu adalah AI pembaca struk belanja Indonesia.
Tugas kamu adalah mengekstrak informasi dari foto struk belanja
dan mengembalikan hasilnya dalam format JSON yang valid.

Format output JSON:
{
  "store_name": "string",
  "date": "YYYY-MM-DD",
  "total": number,
  "items": [
    {"name": "string", "quantity": number, "total_price": number}
  ],
  "payment_method": "string atau null",
  "category_suggestion": "string"
}

Aturan:
- Semua nominal dalam Rupiah (tanpa simbol Rp atau titik pemisah ribuan)
- Jika tidak terbaca, isi dengan null
- Kategori yang tersedia: Makanan & Minuman, Belanja Harian, Transportasi,
  Hiburan, Kesehatan, Pendidikan, Tagihan & Utilitas, Fashion & Kecantikan,
  Rumah Tangga, Lainnya
"""

def load_dataset():
    """Load foto struk dan label JSON dari folder dataset."""
    data = []
    images_dir = os.path.join(DATASET_DIR, "images")
    labels_dir = os.path.join(DATASET_DIR, "labels")

    for filename in os.listdir(images_dir):
        name, ext = os.path.splitext(filename)
        if ext.lower() not in [".jpg", ".jpeg", ".png"]:
            continue

        label_path = os.path.join(labels_dir, f"{name}.json")
        if not os.path.exists(label_path):
            continue

        image_path = os.path.join(images_dir, filename)
        with open(label_path, "r", encoding="utf-8") as f:
            label = json.load(f)

        # Format sebagai conversation untuk VLM
        data.append({
            "image": image_path,
            "conversations": [
                {
                    "role": "system",
                    "content": SYSTEM_PROMPT
                },
                {
                    "role": "user",
                    "content": "Baca struk belanja pada foto ini dan ekstrak informasinya ke format JSON."
                },
                {
                    "role": "assistant",
                    "content": json.dumps(label, ensure_ascii=False, indent=2)
                }
            ]
        })

    return Dataset.from_list(data)

dataset = load_dataset()
print(f"Total dataset: {len(dataset)} sampel")

# Split: 90% train, 10% eval
split = dataset.train_test_split(test_size=0.1, seed=42)
train_dataset = split["train"]
eval_dataset = split["test"]

# ============================================================
# 5. TRAINING
# ============================================================

training_args = TrainingArguments(
    output_dir=OUTPUT_DIR,
    num_train_epochs=NUM_EPOCHS,
    per_device_train_batch_size=BATCH_SIZE,
    gradient_accumulation_steps=4,
    learning_rate=LEARNING_RATE,
    warmup_ratio=0.1,
    lr_scheduler_type="cosine",
    logging_steps=10,
    save_steps=50,
    eval_strategy="steps",
    eval_steps=50,
    save_total_limit=3,
    fp16=True,
    report_to="none",
    dataloader_num_workers=2,
)

trainer = SFTTrainer(
    model=model,
    args=training_args,
    train_dataset=train_dataset,
    eval_dataset=eval_dataset,
    processing_class=processor,
)

# Mulai training
trainer.train()

# Simpan model
trainer.save_model(OUTPUT_DIR)
processor.save_pretrained(OUTPUT_DIR)

print(f"✅ Model berhasil disimpan di: {OUTPUT_DIR}")
```

### 5.5. Evaluasi Model

Setelah training, evaluasi akurasi model:

```python
"""
evaluate_model.py
Evaluasi akurasi model pembaca struk
"""

import json
from PIL import Image

def evaluate(model, processor, test_dataset):
    correct = 0
    total = len(test_dataset)

    for sample in test_dataset:
        image = Image.open(sample["image"])
        expected = json.loads(sample["conversations"][2]["content"])

        # Inference
        predicted = run_inference(model, processor, image)

        # Cek akurasi field utama
        score = 0
        if predicted.get("store_name") == expected.get("store_name"):
            score += 1
        if predicted.get("total") == expected.get("total"):
            score += 1
        if predicted.get("date") == expected.get("date"):
            score += 1

        field_accuracy = score / 3
        correct += field_accuracy

    overall_accuracy = (correct / total) * 100
    print(f"📊 Akurasi keseluruhan: {overall_accuracy:.1f}%")
    return overall_accuracy
```

**Target akurasi:**
| Field | Target |
|-------|--------|
| Nama Toko | > 90% |
| Total Belanja | > 85% |
| Tanggal | > 90% |
| Kategori | > 80% |

---

## 6. Deployment ke Server

### 6.1. Opsi Hosting

| Platform | Biaya | GPU | Kemudahan | Cocok untuk |
|----------|-------|-----|-----------|-------------|
| **HuggingFace Inference Endpoints** | $0.60/jam (GPU) | T4/A10G | ⭐⭐⭐⭐⭐ | Paling mudah |
| **Google Cloud Run (GPU)** | $0.40/jam | L4 | ⭐⭐⭐⭐ | Scalable |
| **RunPod Serverless** | $0.00035/detik (GPU) | Berbagai | ⭐⭐⭐⭐ | Pay-per-use |
| **Railway** | $5-20/bulan (CPU) | CPU only | ⭐⭐⭐⭐⭐ | Model kecil |
| **VPS Sendiri** | $20-100/bulan | Tergantung | ⭐⭐ | Kontrol penuh |

### 6.2. Deployment dengan FastAPI (Rekomendasi)

Bungkus model dalam API server menggunakan FastAPI:

```python
"""
server.py
API Server untuk model pembaca struk Noma
"""

import io
import json
import torch
from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.responses import JSONResponse
from PIL import Image
from transformers import Qwen2_5_VLForConditionalGeneration, AutoProcessor
from peft import PeftModel

# ============================================================
# SETUP
# ============================================================

app = FastAPI(title="Noma Receipt AI", version="1.0.0")

MODEL_PATH = "./output/noma-receipt-model"
BASE_MODEL = "Qwen/Qwen2.5-VL-3B-Instruct"

# Load model saat server start
print("🔄 Loading model...")
processor = AutoProcessor.from_pretrained(MODEL_PATH)
base_model = Qwen2_5_VLForConditionalGeneration.from_pretrained(
    BASE_MODEL,
    torch_dtype=torch.float16,
    device_map="auto",
)
model = PeftModel.from_pretrained(base_model, MODEL_PATH)
model.eval()
print("✅ Model loaded!")

SYSTEM_PROMPT = """Kamu adalah AI pembaca struk belanja Indonesia.
Ekstrak informasi dari foto struk dan kembalikan dalam format JSON valid.

Format output:
{
  "store_name": "string",
  "date": "YYYY-MM-DD",
  "total": number,
  "items": [{"name": "string", "quantity": number, "total_price": number}],
  "payment_method": "string atau null",
  "category_suggestion": "string"
}
"""

# ============================================================
# ENDPOINT
# ============================================================

@app.post("/api/v1/scan-receipt")
async def scan_receipt(file: UploadFile = File(...)):
    """
    Terima foto struk, kembalikan data terstruktur.
    """
    # Validasi file
    if file.content_type not in ["image/jpeg", "image/png", "image/webp"]:
        raise HTTPException(400, "Format file harus JPEG, PNG, atau WebP")

    # Baca gambar
    contents = await file.read()
    if len(contents) > 10 * 1024 * 1024:  # Max 10MB
        raise HTTPException(400, "Ukuran file maksimal 10MB")

    image = Image.open(io.BytesIO(contents)).convert("RGB")

    # Resize jika terlalu besar
    max_size = 1024
    if max(image.size) > max_size:
        ratio = max_size / max(image.size)
        new_size = (int(image.size[0] * ratio), int(image.size[1] * ratio))
        image = image.resize(new_size, Image.LANCZOS)

    # Inference
    messages = [
        {"role": "system", "content": SYSTEM_PROMPT},
        {
            "role": "user",
            "content": [
                {"type": "image", "image": image},
                {"type": "text", "text": "Baca struk belanja ini dan ekstrak informasinya."}
            ]
        }
    ]

    text_input = processor.apply_chat_template(
        messages, tokenize=False, add_generation_prompt=True
    )

    inputs = processor(
        text=[text_input],
        images=[image],
        return_tensors="pt",
    ).to(model.device)

    with torch.no_grad():
        output_ids = model.generate(
            **inputs,
            max_new_tokens=1024,
            temperature=0.1,
            do_sample=False,
        )

    # Decode output
    output_text = processor.batch_decode(
        output_ids[:, inputs.input_ids.shape[1]:],
        skip_special_tokens=True
    )[0]

    # Parse JSON dari output
    try:
        # Cari JSON dalam output
        json_start = output_text.find("{")
        json_end = output_text.rfind("}") + 1
        if json_start == -1 or json_end == 0:
            raise ValueError("No JSON found")

        result = json.loads(output_text[json_start:json_end])
    except (json.JSONDecodeError, ValueError):
        return JSONResponse(
            status_code=422,
            content={
                "success": False,
                "error": "Gagal membaca struk. Pastikan foto jelas dan merupakan struk belanja.",
                "raw_output": output_text
            }
        )

    return JSONResponse(content={
        "success": True,
        "data": result
    })


@app.get("/health")
async def health_check():
    return {"status": "ok", "model": "noma-receipt-ai"}
```

### 6.3. Dockerfile

```dockerfile
FROM nvidia/cuda:12.1-runtime-ubuntu22.04

WORKDIR /app

# Install Python
RUN apt-get update && apt-get install -y python3 python3-pip && \
    rm -rf /var/lib/apt/lists/*

# Install dependencies
COPY requirements.txt .
RUN pip3 install --no-cache-dir -r requirements.txt

# Copy model & server
COPY output/noma-receipt-model ./output/noma-receipt-model
COPY server.py .

EXPOSE 8000

CMD ["uvicorn", "server:app", "--host", "0.0.0.0", "--port", "8000"]
```

**requirements.txt:**
```
fastapi==0.115.0
uvicorn==0.30.0
torch==2.4.0
transformers==4.45.0
peft==0.12.0
accelerate==0.34.0
pillow==10.4.0
python-multipart==0.0.9
```

### 6.4. Deploy ke HuggingFace (Paling Mudah)

```bash
# 1. Login ke HuggingFace
huggingface-cli login

# 2. Upload model ke HuggingFace Hub
python -c "
from huggingface_hub import HfApi
api = HfApi()
api.upload_folder(
    folder_path='./output/noma-receipt-model',
    repo_id='username-kamu/noma-receipt-model',
    repo_type='model',
)
"

# 3. Buat Inference Endpoint di https://ui.endpoints.huggingface.co/
#    - Pilih model: username-kamu/noma-receipt-model
#    - Pilih GPU: nvidia-t4
#    - Region: Asia Pacific (kalau ada)
#    - Klik Deploy
```

---

## 7. API Endpoint Spesifikasi

### Request

```
POST /api/v1/scan-receipt
Content-Type: multipart/form-data
Authorization: Bearer <API_KEY>
```

| Field | Tipe | Wajib | Keterangan |
|-------|------|-------|------------|
| `file` | File (image) | ✅ | Foto struk (JPEG/PNG/WebP, max 10MB) |

### Response (Sukses - 200)

```json
{
  "success": true,
  "data": {
    "store_name": "Indomaret",
    "date": "2026-07-20",
    "total": 23500,
    "items": [
      {
        "name": "Indomie Goreng",
        "quantity": 3,
        "total_price": 10500
      },
      {
        "name": "Aqua 600ml",
        "quantity": 2,
        "total_price": 8000
      }
    ],
    "payment_method": "Tunai",
    "category_suggestion": "Belanja Harian"
  }
}
```

### Response (Gagal Baca - 422)

```json
{
  "success": false,
  "error": "Gagal membaca struk. Pastikan foto jelas dan merupakan struk belanja.",
  "raw_output": "..."
}
```

### Response (Error - 400)

```json
{
  "detail": "Format file harus JPEG, PNG, atau WebP"
}
```

---

## 8. Integrasi ke Flutter Noma

### 8.1. Service Class

```dart
// lib/core/services/receipt_ai_service.dart

import 'dart:io';
import 'package:dio/dio.dart';

class ReceiptAiService {
  final Dio _dio;
  final String _baseUrl;

  ReceiptAiService({
    required String baseUrl,
    String? apiKey,
  })  : _baseUrl = baseUrl,
        _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 60),
          headers: {
            if (apiKey != null) 'Authorization': 'Bearer $apiKey',
          },
        ));

  /// Kirim foto struk ke AI server dan dapatkan hasil parsing.
  Future<ReceiptScanResult> scanReceipt(File imageFile) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          imageFile.path,
          filename: 'receipt.jpg',
        ),
      });

      final response = await _dio.post(
        '/api/v1/scan-receipt',
        data: formData,
      );

      if (response.data['success'] == true) {
        return ReceiptScanResult.fromJson(response.data['data']);
      } else {
        throw ReceiptScanException(
          response.data['error'] ?? 'Gagal membaca struk',
        );
      }
    } on DioException catch (e) {
      throw ReceiptScanException(
        'Gagal terhubung ke server AI: ${e.message}',
      );
    }
  }
}

class ReceiptScanResult {
  final String? storeName;
  final String? date;
  final double total;
  final List<ReceiptItem> items;
  final String? paymentMethod;
  final String? categorySuggestion;

  ReceiptScanResult({
    this.storeName,
    this.date,
    required this.total,
    required this.items,
    this.paymentMethod,
    this.categorySuggestion,
  });

  factory ReceiptScanResult.fromJson(Map<String, dynamic> json) {
    return ReceiptScanResult(
      storeName: json['store_name'],
      date: json['date'],
      total: (json['total'] as num).toDouble(),
      items: (json['items'] as List? ?? [])
          .map((e) => ReceiptItem.fromJson(e))
          .toList(),
      paymentMethod: json['payment_method'],
      categorySuggestion: json['category_suggestion'],
    );
  }
}

class ReceiptItem {
  final String name;
  final int quantity;
  final double totalPrice;

  ReceiptItem({
    required this.name,
    required this.quantity,
    required this.totalPrice,
  });

  factory ReceiptItem.fromJson(Map<String, dynamic> json) {
    return ReceiptItem(
      name: json['name'] ?? '',
      quantity: json['quantity'] ?? 1,
      totalPrice: (json['total_price'] as num).toDouble(),
    );
  }
}

class ReceiptScanException implements Exception {
  final String message;
  ReceiptScanException(this.message);

  @override
  String toString() => message;
}
```

### 8.2. Riverpod Provider

```dart
// lib/features/receipt_scanner/providers/receipt_scanner_provider.dart

import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Provider untuk ReceiptAiService
final receiptAiServiceProvider = Provider<ReceiptAiService>((ref) {
  return ReceiptAiService(
    baseUrl: 'https://your-ai-server.com',  // Ganti dengan URL server-mu
    apiKey: 'your-api-key',
  );
});

// State untuk hasil scan
final receiptScanProvider = StateNotifierProvider<ReceiptScanNotifier, AsyncValue<ReceiptScanResult?>>((ref) {
  return ReceiptScanNotifier(ref.read(receiptAiServiceProvider));
});

class ReceiptScanNotifier extends StateNotifier<AsyncValue<ReceiptScanResult?>> {
  final ReceiptAiService _service;

  ReceiptScanNotifier(this._service) : super(const AsyncData(null));

  Future<void> scanReceipt(File imageFile) async {
    state = const AsyncLoading();
    try {
      final result = await _service.scanReceipt(imageFile);
      state = AsyncData(result);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  void reset() {
    state = const AsyncData(null);
  }
}
```

---

## 9. Estimasi Biaya & Resource

### 9.1. Biaya Training

| Item | Estimasi Biaya |
|------|----------------|
| Google Colab Pro (GPU A100) | Gratis / $10/bulan |
| Kaggle GPU (gratis) | Gratis |
| RunPod A10G (4 jam training) | ~$2 |
| Lambda Labs A10 (4 jam) | ~$2 |
| **Total training** | **Gratis - $10** |

### 9.2. Biaya Hosting/Inference

| Platform | Biaya/Bulan | Model |
|----------|-------------|-------|
| HuggingFace Endpoint (T4) | ~$430/bulan (24/7) | Qwen2.5-VL-3B |
| RunPod Serverless | ~$5-15/bulan (pay-per-use) | Qwen2.5-VL-3B |
| VPS GPU (Vast.ai) | ~$50-100/bulan | Qwen2.5-VL-3B |
| Google Cloud Run (GPU) | ~$10-30/bulan (pay-per-use) | Qwen2.5-VL-3B |

> **💡 Tips Hemat**: Gunakan **RunPod Serverless** atau **Google Cloud Run** dengan mode pay-per-use (bayar hanya saat ada request). Ini paling hemat untuk aplikasi dengan traffic rendah-menengah.

### 9.3. Perbandingan dengan Gemini API

| Aspek | Custom Model | Gemini API |
|-------|-------------|------------|
| Biaya awal | Gratis - $10 (training) | Gratis |
| Biaya bulanan | $5-100/bulan (hosting) | Gratis (15 RPM) / $0.075 per 1M token |
| Akurasi struk Indonesia | 85-95% (setelah fine-tune) | 80-90% (zero-shot) |
| Kontrol penuh | ✅ Ya | ❌ Tidak |
| Maintenance | Kamu sendiri | Google yang urus |
| Waktu setup | 2-4 minggu | 1 hari |
| Offline capability | Bisa (jika self-hosted) | Tidak |

---

## 10. Roadmap Pengembangan AI

### Fase 1: Persiapan (Minggu 1-2)
- [ ] Kumpulkan 200+ foto struk belanja dari berbagai toko
- [ ] Setup environment Python + GPU (Colab/Kaggle)
- [ ] Buat script anotasi semi-otomatis (pakai Gemini untuk generate label awal)
- [ ] Review & koreksi semua label secara manual
- [ ] Split dataset: 180 train / 20 eval

### Fase 2: Training (Minggu 3)
- [ ] Download model Qwen2.5-VL-3B-Instruct
- [ ] Setup LoRA/QLoRA configuration
- [ ] Jalankan training (estimasi 2-4 jam di GPU T4)
- [ ] Evaluasi akurasi pada test set
- [ ] Iterasi: tambah data / adjust hyperparameter jika akurasi < 85%

### Fase 3: Deployment (Minggu 4)
- [ ] Buat API server dengan FastAPI
- [ ] Test endpoint secara lokal
- [ ] Deploy ke RunPod Serverless / Google Cloud Run
- [ ] Setup monitoring & logging
- [ ] Test dari aplikasi Flutter

### Fase 4: Iterasi & Peningkatan (Ongoing)
- [ ] Kumpulkan feedback dari user (struk yang gagal dibaca)
- [ ] Tambah data training dari struk yang gagal
- [ ] Re-training berkala untuk meningkatkan akurasi
- [ ] Ekspansi ke jenis struk baru (e-receipt, struk digital)

---

## 📌 Catatan Penting

1. **Mulai dari Gemini API dulu** — Untuk MVP aplikasi Noma, gunakan Gemini API terlebih dahulu agar aplikasi cepat jadi. Pengembangan custom model bisa berjalan paralel.

2. **Dataset adalah kunci** — Kualitas model sangat bergantung pada kualitas dan kuantitas dataset. Investasi waktu di pengumpulan & anotasi data akan sangat worth it.

3. **Iterasi bertahap** — Jangan langsung target 1000 data. Mulai dari 200, evaluasi, lalu tambah secara bertahap.

4. **Fallback mechanism** — Selalu siapkan fallback ke Gemini API jika custom model gagal/down. Ini menjaga pengalaman user tetap baik.

---

> **Dokumen ini akan di-update seiring perkembangan proyek.**
> 
> Terakhir diperbarui: 2026-07-26
