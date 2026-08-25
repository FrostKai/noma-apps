# Noma Full Application Audit

Tanggal audit: 2026-08-25  
Status audit: PASS  
Scope: discovery arsitektur, fitur, database, offline-first, security, dan performa berdasarkan source code aktual.

Catatan penting:
- Audit ini tidak melakukan refactor fitur.
- Hasil benchmark adalah smoke benchmark query SQLite/Drift dari `tool/perf_smoke.dart`, bukan profiling frame rendering Android.
- API live request tidak dites karena audit tidak menggunakan secret/API key pengguna.

## Executive Summary

1. Noma adalah aplikasi Flutter offline-first untuk pencatatan keuangan pribadi.
2. Penyimpanan utama menggunakan Drift sebagai wrapper SQLite lokal.
3. Tidak ada backend server aplikasi; "backend" aktual adalah repository Drift + SQLite lokal.
4. Data transaksi tidak dihapus saat pergantian bulan. Periode digunakan sebagai filter query.
5. Fitur transaksi manual, edit transaksi utama, delete transaksi, histori, dashboard, laporan, kategori, scan struk, chatbot, API key setup, tema, dan notifikasi sudah terimplementasi.
6. Dashboard dan laporan sudah banyak memakai query agregasi SQLite, bukan load seluruh histori ke Dart.
7. Histori transaksi sudah memakai query `LIMIT`, tetapi UI masih memakai `SingleChildScrollView` + `Column`, sehingga belum virtualized.
8. Search sudah berjalan di database dan memakai debounce 300ms, tetapi pola `LIKE '%term%'` tetap tidak memanfaatkan index teks biasa.
9. `transaction_items` benar-benar digunakan: dibuat dari scan struk, disimpan ke SQLite, dan dipakai laporan insight barang.
10. Tidak ada layar detail transaksi khusus yang menampilkan item struk setelah transaksi disimpan.
11. Scan struk membutuhkan internet dan Gemini API key; OCR lokal belum ditemukan.
12. AI text parsing punya fallback lokal saat API key kosong, tetapi fallback tidak konsisten untuk semua provider cloud.
13. Chatbot memakai data agregasi dan recent transaction terbatas, bukan seluruh histori.
14. Glassmorphism masih berpotensi berat di list panjang karena card transaksi memakai `BackdropFilter`.
15. Receipt image dibaca sebagai bytes dan di-base64 di main isolate, berisiko jank untuk gambar besar.
16. API key disimpan di `SharedPreferences`, bukan secure storage.
17. `.env` terdeteksi sebagai tracked file dan ada di asset Flutter, sehingga harus diawasi agar tidak berisi secret produksi.
18. Debug log receipt scan mencetak response dan JSON struk; ini risiko privasi.
19. Backup/export tidak ditemukan implementasinya.
20. Validasi minimal terakhir: `flutter analyze` PASS dan `flutter test` PASS.

## Architecture Map

```text
Flutter UI
  -> Riverpod Provider / StateNotifier
    -> Repository / Service
      -> Drift
        -> SQLite lokal

AI path:
Flutter UI
  -> GeminiApiService
    -> Groq / OpenRouter / Gemini HTTP API
    -> LocalAiEngine fallback untuk sebagian fitur

Settings path:
Flutter UI
  -> SharedPreferences
  -> NotificationService
  -> ApiKeyService
```

Rute utama:
- `/splash` -> splash screen
- `/home` -> main shell
- `/add-transaction` -> tambah/edit transaksi
- `/scanner` -> scan struk
- `/chatbot` -> Nomi AI
- `/report` -> laporan
- `/settings` -> pengaturan
- `/categories` -> manajemen kategori

## Feature Inventory

| Feature | Status | Core Value | Complexity | Internet | Database |
| --- | --- | --- | --- | --- | --- |
| Dashboard | Implemented | Core | Medium | Tidak | `transactions` |
| Saldo/pemasukan/pengeluaran | Implemented | Core | Low | Tidak | `transactions` |
| Histori transaksi | Implemented, query scalable, UI belum ideal | Core | Medium | Tidak | `transactions` |
| Tambah manual | Implemented | Core | Low | Tidak | `transactions`, `categories` |
| Edit transaksi | Implemented sebagian | Core | Low | Tidak | `transactions` |
| Hapus transaksi | Implemented | Core | Low | Tidak | `transactions`, cascade `transaction_items` |
| Search | Implemented sebagian | Supporting | Medium | Tidak | `transactions` |
| Filter tipe | Implemented | Supporting | Low | Tidak | `transactions` |
| Filter/periode bulan histori | Belum khusus di histori | Supporting | Medium | Tidak | `transactions` |
| Laporan | Implemented | Core | Medium | Tidak | `transactions`, `transaction_items` |
| Grafik | Implemented | Supporting | Medium | Tidak | aggregate query |
| Kategori | Implemented sebagian | Core | Medium | Tidak | `categories` |
| Scan struk | Implemented | Core/Supporting | High | Ya | `transactions`, `transaction_items` |
| OCR lokal | Belum ada | Optional | High | Tidak berlaku | - |
| AI text parsing | Implemented + local fallback terbatas | Supporting | Medium | Ya/sebagian offline | `transactions` |
| Detail item struk | Disimpan dan report aggregate, belum ada detail UI | Supporting | Medium | Tidak | `transaction_items` |
| Chatbot Nomi AI | Implemented | Optional/Supporting | High | Ya/sebagian fallback | `chat_messages`, `transactions` |
| API key setup | Implemented | Supporting | Medium | Ya untuk validasi | SharedPreferences |
| Notifikasi | Implemented sebagian | Supporting | Medium | Tidak | SharedPreferences |
| Backup/export | Tidak ditemukan | Optional | Medium | Tidak berlaku | - |
| Product tour | Implemented | Optional | Medium | Tidak | SharedPreferences |
| Dark/light mode | Implemented | Supporting | Low | Tidak | SharedPreferences |
| Web database | Implemented deprecated path | Optional | Medium | Tidak | Drift web |

## User Flow Audit

### Launch

```text
main()
  -> init intl id_ID
  -> init local notifications non-web
  -> load .env best-effort
  -> ProviderScope
  -> NomaApp
  -> GoRouter
  -> SplashScreen
  -> MainShellScreen
```

### Transaksi Manual

```text
FAB Manual / empty-state Tambah
  -> AddTransactionScreen
  -> input nominal, kategori, metode pembayaran, tanggal, catatan
  -> validation nominal > 0 dan kategori wajib
  -> TransactionController.addTransaction
  -> TransactionRepository.addTransaction
  -> SQLite transactions
  -> stream provider update UI
```

Status: implemented.

### Edit Transaksi

```text
tap TransactionCard
  -> AddTransactionScreen(initialTransaction)
  -> update field utama
  -> TransactionController.updateTransaction
  -> TransactionRepository.updateTransaction
  -> SQLite transactions replace
```

Status: implemented sebagian. Edit tidak mengelola `transaction_items`.

### Delete Transaksi

```text
tap delete di TransactionCard
  -> confirmation dialog
  -> TransactionController.deleteTransaction
  -> TransactionRepository.deleteTransaction
  -> SQLite delete transactions
  -> transaction_items ikut cascade delete
```

Status: implemented.

### Scan Receipt

```text
ScannerScreen
  -> ImagePicker camera/gallery
  -> readAsBytes
  -> check Gemini API key
  -> GeminiApiService.scanReceiptImage
  -> base64 image
  -> Gemini Vision request
  -> parse JSON
  -> review bottom sheet
  -> add/edit/delete item sementara di bottom sheet
  -> save transaction + receipt items
  -> SQLite transactions + transaction_items
```

Status: implemented, membutuhkan internet.

### AI Text Input

```text
FAB AI Teks
  -> AiSmartInputCard
  -> GeminiApiService.parseNaturalText
  -> Groq/OpenRouter/Gemini atau LocalAiEngine fallback saat key kosong
  -> AddTransactionScreen prefilled
  -> save transaction source ai_text
```

Status: implemented dengan fallback terbatas.

### Chatbot

```text
ChatbotScreen
  -> send message
  -> get recent chat max 8
  -> save user message
  -> build financial context via aggregate/limited DB queries
  -> GeminiApiService.sendChatMessage
  -> save assistant message
  -> chat stream refresh
```

Status: implemented.

### Laporan

```text
ReportScreen
  -> select period this_month / last_month / all
  -> reportDataStreamProvider(range)
  -> aggregate summary, category totals, top receipt items, top merchants
  -> charts and insight UI
```

Status: implemented.

### Kategori

```text
Settings
  -> CategoryScreen
  -> categoriesStreamProvider
  -> add category via CategoryController
  -> delete non-default category via CategoryController
```

Status: add/delete implemented. Edit category repository ada, tetapi UI/controller update tidak terlihat.

### Settings

```text
SettingsScreen
  -> theme mode provider
  -> category management route
  -> notification settings via SharedPreferences + NotificationService
  -> API key modal
  -> product tour reset
```

Status: implemented.

## Database Inventory

| Table | Columns | PK/FK | Nullable/Default | Index | Purpose |
| --- | --- | --- | --- | --- | --- |
| `transactions` | `id`, `type`, `amount`, `category`, `description`, `source`, `payment_method`, `receipt_image_path`, `transaction_date`, `created_at`, `updated_at` | `id` PK | `description`, `payment_method`, `receipt_image_path` nullable | `idx_transactions_date_id`, `idx_transactions_type_date`, `idx_transactions_category_date` | transaksi utama |
| `transaction_items` | `id`, `transaction_id`, `name`, `quantity`, `unit_price`, `total_price`, `created_at` | `id` PK, `transaction_id` FK cascade | `unit_price` nullable, `quantity` default 1.0 | `idx_transaction_items_transaction_id` | item hasil scan struk |
| `categories` | `id`, `name`, `icon`, `color`, `type`, `is_default`, `created_at` | `id` PK, `name` unique | `icon`, `color` nullable, `is_default` default true | unique `name` | kategori income/expense |
| `chat_messages` | `id`, `role`, `content`, `created_at` | `id` PK | required fields | none | riwayat chat lokal 24 jam |
| `app_settings` | `key`, `value` | `key` PK | `value` nullable | PK | tersedia di schema, pemakaian aktif tidak terlihat |

Schema version: 3.

Migration:
- `from < 2`: create `transaction_items`
- `from < 3`: create performance indexes

## Performance Findings

| Severity | Issue | Location | Cause | Impact | Evidence |
| --- | --- | --- | --- | --- | --- |
| HIGH | Histori belum virtualized | `HomeScreen` | `SingleChildScrollView` + `Column` + map transaction cards | Semua card yang sudah dimuat dibuild ketika limit dinaikkan | source list rendering |
| HIGH | Blur per transaction card | `TransactionCard` -> `GlassCard` | `BackdropFilter` di setiap card | GPU/compositing berat pada list panjang | source rendering |
| HIGH | Receipt scan image processing di main isolate | `ScannerScreen`, `GeminiApiService` | `readAsBytes` + `base64Encode` | Potensi jank untuk image besar | source image flow |
| HIGH | Debug log struk terlalu detail | `GeminiApiService.scanReceiptImage` | raw AI response dan JSON struk dicetak | Risiko privacy leak | source debugPrint |
| MEDIUM | Search tidak memakai index teks | `TransactionRepository._transactionPredicate` | `LIKE '%query%'` | Ordered scan saat dataset besar | EXPLAIN query plan |
| MEDIUM | Balance memakai dua query | `TransactionRepository.watchTotalBalance` | income stream lalu expense query | Query ganda per update | source query |
| MEDIUM | Edit transaksi struk tidak edit item | `TransactionRepository.updateTransaction` | update hanya `transactions` | total/item bisa tidak sinkron | source update path |
| MEDIUM | Edit item review tidak update total transaksi | `ScannerScreen._showConfirmationBottomSheet` | `extractedTotal` tidak dihitung ulang setelah item berubah | total transaksi bisa beda dari item | source modal state |
| MEDIUM | Chat history order newest-first untuk AI | `ChatbotRepository.getRecentMessages` | order desc lalu dikirim langsung | konteks AI kurang natural | source chat flow |
| LOW | `app_settings` tidak terlihat dipakai | database schema | settings nyata memakai SharedPreferences | schema ekstra | source search |
| LOW | `workmanager` dependency tidak terlihat dipakai | `pubspec.yaml` | tidak ada import/pemanggil | dependency bloat | source search |
| LOW | Search hint menyebut nominal | `HomeScreen` | query tidak mencari amount | UX mismatch | source query vs UI text |

## SQLite Query Audit

### Dashboard Queries

- Latest page:

```sql
SELECT *
FROM transactions
WHERE ...
ORDER BY transaction_date DESC, id DESC
LIMIT ?
OFFSET ?
```

- Total income:

```sql
SELECT SUM(amount)
FROM transactions
WHERE type = 'income'
```

- Total expense:

```sql
SELECT SUM(amount)
FROM transactions
WHERE type = 'expense'
```

- Monthly summary:

```sql
SELECT type, SUM(amount), COUNT(id)
FROM transactions
WHERE transaction_date >= ? AND transaction_date < ?
GROUP BY type
```

- Daily totals:

```sql
SELECT strftime('%Y-%m-%d', transaction_date / 1000, 'unixepoch', 'localtime') AS day_key,
       type,
       SUM(amount) AS total
FROM transactions
WHERE transaction_date >= ? AND transaction_date < ?
GROUP BY day_key, type
ORDER BY day_key ASC
```

### Transaction List Queries

`watchTransactionsPage` uses type/search predicate, ordering by `transaction_date DESC, id DESC`, and `LIMIT/OFFSET`.

### Search Queries

```sql
WHERE category LIKE '%query%'
   OR description LIKE '%query%'
   OR payment_method LIKE '%query%'
```

This is database-level filtering with debounce, but not indexed full-text search.

### Report Queries

- Category totals:

```sql
SELECT category AS name, SUM(amount) AS total
FROM transactions
WHERE type = ? AND transaction_date >= ? AND transaction_date < ?
GROUP BY category
ORDER BY total DESC
LIMIT ?
```

- Top receipt items:

```sql
SELECT ti.name, SUM(ti.quantity), SUM(ti.total_price)
FROM transaction_items ti
INNER JOIN transactions t ON t.id = ti.transaction_id
WHERE ti.name <> ''
  AND t.transaction_date >= ?
  AND t.transaction_date < ?
GROUP BY ti.name
ORDER BY SUM(ti.total_price) DESC
LIMIT ?
```

- Top merchants:

```sql
SELECT TRIM(SUBSTR(description, 7)) AS name, SUM(amount) AS total
FROM transactions
WHERE type = ?
  AND description LIKE ?
  AND transaction_date >= ?
  AND transaction_date < ?
GROUP BY name
HAVING name <> ''
ORDER BY total DESC
LIMIT ?
```

### Receipt Queries

Receipt list card does not load `transaction_items`, so no N+1 query in transaction list. `transaction_items` are loaded only by aggregate report benchmark/detail test path.

### Chatbot Context Queries

Chatbot builds context with:
- total income
- total expense
- current month income
- current month expense
- top 5 expense categories
- recent 5 transactions

All are aggregate or limited queries.

## EXPLAIN QUERY PLAN Summary

Observed from SQLite in-memory schema with the same indexes:

| Query | Plan Summary |
| --- | --- |
| latest page | `SCAN transactions USING INDEX idx_transactions_date_id` |
| type-filtered page | `SEARCH transactions USING INDEX idx_transactions_type_date (type=?)` |
| monthly summary | `SEARCH transactions USING INDEX idx_transactions_date_id (transaction_date>? AND transaction_date<?)` plus temp B-tree for group |
| category report | `SEARCH transactions USING INDEX idx_transactions_type_date (type=? AND transaction_date>? AND transaction_date<?)` plus temp B-tree for group/order |
| daily totals | uses date index plus temp B-tree for group/order |
| top receipt items | uses transaction date index and `idx_transaction_items_transaction_id` |
| search | scan using date index; `%LIKE%` cannot use normal text index |

## Performance Benchmark

Command family:

```bash
dart run tool/perf_smoke.dart <rows>
```

Result:

| Rows | RSS MB | Dashboard Page | Monthly Summary | Report Categories | Daily Totals | Top Receipt Items | Search Page | Detail Items |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 100 | 225 | 6098us | 1419us | 343us | 146us | 264us | 436us | 298us |
| 1,000 | 227 | 6155us | 261us | 269us | 140us | 151us | 568us | 322us |
| 10,000 | 229 | 5352us | 339us | 306us | 223us | 395us | 456us | 273us |
| 50,000 | 241 | 4472us | 698us | 882us | 755us | 1308us | 355us | 243us |
| 100,000 | 257 | 5710us | 1306us | 1078us | 1462us | 3034us | 559us | 315us |

Interpretation:
- Query layer is acceptable for 100k simulated transactions in this smoke benchmark.
- Main remaining performance risk is Flutter rendering for long history lists, not SQLite query time.
- Search is fast in the benchmark, but structurally still limited by `%LIKE%`.

## Receipt Scanner Assessment

`transaction_items` is still worth keeping.

Evidence:
- Created from scan result items in `ScannerScreen`.
- Saved through `TransactionRepository.addTransaction` with batch insert.
- Deleted automatically through FK cascade when parent transaction is deleted.
- Used by report insight for "Barang Paling Banyak Menghabiskan Uang".

Limitations:
- No transaction detail screen to view saved items.
- Edit transaction does not edit receipt items.
- Receipt item edits in scan review do not recalculate transaction total.
- Items do not affect dashboard or chatbot context.

Conclusion:
- Do not remove `transaction_items`.
- Keep it as report/detail data.
- Future work should make receipt detail/edit behavior explicit.

## Offline Assessment

Works offline:
- Dashboard from local SQLite.
- Manual add transaction.
- Edit/delete transaction.
- Transaction history.
- Search/filter local data.
- Reports and charts from local aggregate queries.
- Category management.
- Theme settings.
- Local chat history.
- Scheduled local notification after setup.

Requires internet:
- Gemini Vision scan receipt.
- Groq/Gemini/OpenRouter AI calls.
- API key verification.
- Opening external API key pages.

Partially offline:
- AI text parsing has local fallback when API key is empty.
- Chatbot has local fallback for Gemini error path, but provider fallback behavior is not consistent for all cloud providers.
- Receipt scanner has no active local OCR fallback.

## Architecture Problems

### CRITICAL

- No critical data-loss or full-history deletion issue found in current source.

### HIGH

- Receipt scan debug logging exposes sensitive purchase details.
- `.env` is tracked and declared as Flutter asset; it must not contain production secrets.
- Transaction history UI is not virtualized.
- Glass blur per transaction card can become GPU-heavy.

### MEDIUM

- `transaction_items` has no saved-detail/edit flow.
- Search uses `%LIKE%` and is not true full-text search.
- Receipt image path persistence needs real-device validation.
- API keys are stored in SharedPreferences.
- Chatbot history sent newest-first.
- `app_settings` exists but settings are stored in SharedPreferences.

### LOW

- `workmanager` dependency appears unused.
- Category edit exists only at repository level, not UI/controller.
- Some strings show mojibake characters such as `â€”`, `â€¢`, `â†’`.
- Deprecated Drift web / ShowCaseWidget warnings are suppressed, not migrated.

## Recommended Direction

1. Keep SQLite/Drift as the local backend. No server backend is needed for the offline-first requirement.
2. Treat month changes as query range changes, not archive/delete operations.
3. Prioritize UI virtualization for transaction history.
4. Reduce heavy glass blur inside long lists while preserving the overall visual style.
5. Remove sensitive receipt scan debug logs before wider use.
6. Keep `transaction_items`, but define its product role as report/detail data.
7. Add a proper transaction detail path before expanding receipt item analytics further.
8. Consider SQLite FTS only when search becomes a measured bottleneck.
9. Move secret handling away from `.env` asset and SharedPreferences when security becomes a release requirement.

## Things That Should NOT Be Changed

- SQLite/Drift as local storage.
- Offline-first manual transaction flow.
- All-time transaction history.
- Range-based monthly queries.
- Existing aggregate query approach for dashboard/report.
- `transaction_items` table while receipt item insights remain in product scope.
- Riverpod split by page/summary/report/daily totals.
- Cascade delete from `transactions` to `transaction_items`.
- Glassmorphism visual identity, only its usage in long lists should be optimized.
- Local AI fallback behavior where already implemented.

## Unknowns

- Android frame performance was not profiled with DevTools.
- Real Gemini/Groq/OpenRouter network behavior was not tested.
- Actual `.env` secret value was not printed or validated.
- Receipt image path lifetime needs Android real-device verification.
- Database file growth with many receipt items/images was not measured.
- No dedicated tests were found for scan receipt, report aggregate correctness, or pagination UI.

## Validation

Latest validation before commit:

```text
flutter analyze
No issues found.

flutter test
All tests passed.
```

## Follow-up Implementation: Monthly Virtualized History

Tanggal implementasi: 2026-08-25

Perubahan yang sudah dilakukan setelah audit:
- Histori transaksi di dashboard sekarang memakai bulan aktif sebagai state UI.
- Query histori memakai date range: `transaction_date >= startMonth AND transaction_date < nextMonth`.
- Filter bulan, tipe transaksi, dan search dikombinasikan di database.
- Pagination histori memakai page-based `LIMIT 50 OFFSET n`.
- Perubahan bulan/filter/search membuat provider family baru, sehingga data bulan lama tidak tercampur dengan bulan baru.
- UI histori memakai `CustomScrollView` + `SliverList.builder`.
- Header tanggal seperti `25 AGUSTUS` dibuat sebagai row ringan di list, bukan dengan query item struk.
- `transaction_items` tetap tidak diload untuk transaction card.
- Schema database dan index tidak berubah.

Query histori utama:

```sql
SELECT *
FROM transactions
WHERE transaction_date >= ?
  AND transaction_date < ?
ORDER BY transaction_date DESC, id DESC
LIMIT 50 OFFSET ?
```

Query histori dengan filter tipe dan search:

```sql
SELECT *
FROM transactions
WHERE type = ?
  AND transaction_date >= ?
  AND transaction_date < ?
  AND (
    category LIKE ?
    OR description LIKE ?
    OR payment_method LIKE ?
  )
ORDER BY transaction_date DESC, id DESC
LIMIT 50 OFFSET ?
```

EXPLAIN query plan untuk histori bulanan:

```text
SEARCH transactions USING INDEX idx_transactions_date_id (transaction_date>? AND transaction_date<?)
```

Benchmark terbaru dari `dart run tool/perf_smoke.dart 1000 10000 50000 100000`:

| Rows | Monthly Page 1 | Monthly Page 2 | Month+Type+Search | EXPLAIN |
| ---: | ---: | ---: | ---: | --- |
| 1,000 | 713us | 208us | 271us | uses `idx_transactions_date_id` |
| 10,000 | 279us | 275us | 353us | uses `idx_transactions_date_id` |
| 50,000 | 269us | 333us | 422us | uses `idx_transactions_date_id` |
| 100,000 | 371us | 353us | 467us | uses `idx_transactions_date_id` |

Validation setelah implementasi:

```text
flutter analyze
No issues found.

flutter test
All tests passed.
```
