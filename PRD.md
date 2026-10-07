# Product Requirements Document (PRD)

**Nama Proyek:** Smart Academic Assistant (SAA)
**Platform:** Mobile — Android (fokus MVP)
**Event Target:** IconFest, Universitas Siliwangi (UNSIL)
**Kategori:** Pendidikan
**Status Dokumen:** Versi 4.0 (revisi dari v3.0 — lebih detail, konsisten, dan realistis)

---

## 0. Ringkasan Perubahan dari v3.0

Bagian ini merangkum temuan hasil review v3.0 dan bagaimana setiap temuan diperbaiki di dokumen ini.

| # | Temuan di v3.0 | Dampak | Perbaikan di v4.0 |
|---|---|---|---|
| 1 | Tidak ada tujuan produk, target user/persona, metrik keberhasilan, non-goals | Sulit menilai "selesai" dan sulit dijelaskan ke juri | Bagian 1 (Goals, Persona, Metrik, Non-goals) |
| 2 | Semua fitur dianggap sama penting, tidak ada prioritas | Risiko semua fitur setengah jadi saat deadline | Bagian 2: prioritas P0/P1/P2 + garis potong (cut line) |
| 3 | Auto-tag menyebut "Tag" mata kuliah, tapi tabel `courses` tidak punya kolom keyword | Logika auto-tag tidak bisa diimplementasi | Kolom `keywords` di `courses` + algoritma skor + konfidensi (3.2.B, 6) |
| 4 | Tabel `schedules` mencampur kelas dan tugas; tidak ada hari/jam/ruang kelas mingguan | Perhitungan "Pertemuan 2 = +7 hari" tidak bisa tepat (UTS/UAS/libur, jam kelas) | Tabel baru `course_slots`; `schedules` punya `type` CLASS/TASK/EXAM + `meeting_number` |
| 5 | Contoh tanggal `2023-09-01T08:00:00Z` salah zona waktu (08:00Z = 15:00 WIB) dan sudah kedaluwarsa | Jadwal/reminder bergeser 7 jam | Aturan zona waktu: simpan UTC, hitung dengan `Asia/Jakarta`; contoh diperbarui |
| 6 | Auth: arsitektur menulis Firebase + JWT Custom, sprint menulis Register/Login | Dua jalur auth, membingungkan | Satu jalur: Google Sign-In (Firebase) → backend verifikasi ID token (Bagian 4.3) |
| 7 | Endpoint `/notes/transcribe` padahal transkripsi terjadi di perangkat; alur tag terjadi *setelah* simpan tetapi `course_id` NOT NULL | Alur tidak konsisten | Pisahkan `POST /notes/suggest-course` (stateless) dan `POST /notes`; `course_id` nullable ("Belum dikategorikan") |
| 8 | Penamaan field tidak konsisten (`suggestedCourseId` vs `suggested_course_id`, `pertemuan/topik` vs `meeting/title`) | Bug integrasi FE–BE | Standar: JSON `camelCase`, kolom DB `snake_case` (Bagian 7) |
| 9 | `speech_to_text` diasumsikan bisa merekam kuliah panjang | Di Android, recognizer berhenti saat jeda bicara; perlu restart loop | Spesifikasi restart loop, batas sesi, dan ekspektasi realistis (3.1.A) |
| 10 | Screen Pinning diasumsikan bisa aktif otomatis tanpa interaksi | Android meminta konfirmasi user; butuh platform channel native; perilaku beda antar perangkat | Spesifikasi onboarding, deteksi state, dan fallback DND (3.3) |
| 11 | Reminder tidak membahas izin Android 12/13/14, reboot, penghematan baterai | Reminder tidak muncul di sebagian perangkat | Bagian 3.2.B + 9 (daftar izin) |
| 12 | Regex RPS terlalu sederhana; RPS asli biasanya berbentuk tabel dan teks hasil `pdf-parse` berantakan | Akurasi rendah | Strategi parser bertingkat + data uji minimal 5 RPS + wajib layar review (3.2.A) |
| 13 | Skema DB kurang field penting (`updated_at`, `deleted_at`, `started_at`, alasan gagal, `user_id` di notes, indeks, ON DELETE) | Sulit sinkronisasi offline dan debugging | Skema diperluas + draft Prisma (Bagian 6) |
| 14 | Hanya 2 endpoint terdokumentasi | FE tidak punya kontrak lengkap | Daftar API lengkap + format error (Bagian 7) |
| 15 | Tidak ada keamanan, privasi, NFR, strategi offline-sync, testing | Rawan celah dan rawan ditanya juri | Bagian 8, 10 |
| 16 | Sprint 7 hari tidak memuat auto-reminder, share intent, auto-tag, deploy backend, build APK, buffer | Jadwal tidak realistis | Sprint plan baru (Bagian 11) + status progres saat ini |

---

## 1. Product Overview

### 1.1 Latar Belakang & Masalah

1. **Pencatatan tidak efisien.** Kecepatan bicara dosen tidak sebanding dengan kecepatan mencatat mahasiswa.
2. **Manajemen jadwal manual.** RPS (Rencana Pembelajaran Semester) dibagikan dalam format PDF; mahasiswa malas memindahkannya ke kalender/to-do list sehingga tugas dan ujian sering terlewat.
3. **Distraksi digital.** Notifikasi media sosial merusak konsentrasi saat belajar mandiri.
4. **Aplikasi terpisah-pisah.** Pencatat suara, kalender, dan timer fokus adalah aplikasi berbeda yang tidak saling terhubung dengan konteks mata kuliah.

### 1.2 Solusi (Value Proposition)

Aplikasi asisten akademik *all-in-one* yang mengotomatisasi tugas repetitif mahasiswa dan **semuanya terhubung ke konteks mata kuliah**:

- mengubah ucapan menjadi teks dan otomatis menyarankan mata kuliahnya,
- mengubah PDF RPS menjadi jadwal pertemuan lengkap dengan pengingat,
- membantu fokus dengan timer yang mengunci layar dari aplikasi lain.

**Pembeda utama (diferensiasi):** konteks akademik Indonesia (RPS, pertemuan, UTS/UAS) dan keterkaitan antarfitur — hasil ekstraksi RPS memperkaya kata kunci mata kuliah, sehingga auto-tag catatan menjadi lebih akurat.

Pembanding (contoh): aplikasi kalender/to-do umum tidak membaca RPS; aplikasi transkripsi umum tidak mengenal mata kuliah; aplikasi timer fokus umum tidak terhubung dengan jadwal dan tugas kuliah.

### 1.3 Goals

| ID | Goal | Cara mengukur (untuk demo/validasi) |
|---|---|---|
| G1 | Mengurangi waktu memasukkan jadwal satu mata kuliah | Dari RPS PDF ke jadwal tersimpan < 60 detik (vs input manual 16 pertemuan) |
| G2 | Catatan lisan tersimpan rapi per mata kuliah tanpa input manual | Akurasi saran auto-tag top-1 ≥ 70% pada ≥ 20 catatan uji |
| G3 | Ekstraksi RPS cukup akurat untuk dipakai | ≥ 80% baris pertemuan terekstrak benar pada ≥ 5 RPS uji (sisanya bisa diedit di layar review) |
| G4 | Sesi fokus tidak mudah terganggu | Pada pengujian, aplikasi lain/notifikasi tidak dapat diakses selama sesi berjalan (di ≥ 2 perangkat uji) |
| G5 | Pengingat andal | ≥ 95% reminder terjadwal muncul tepat waktu (±1 menit) pada perangkat uji |

### 1.4 Non-Goals (di luar MVP)

- iOS, web, dan versi tablet.
- OCR untuk RPS berupa gambar/scan.
- Rekaman audio mentah dan transkripsi berbasis server (Whisper/Google STT) — masuk roadmap.
- Ringkasan otomatis berbasis LLM, kuis otomatis, kolaborasi antar-user.
- Integrasi ke sistem akademik kampus (SIAKAD).
- Sinkronisasi multi-perangkat secara real-time (MVP cukup sinkron saat online).

### 1.5 Target Pengguna & Persona

**Target:** mahasiswa (utama) dan siswa SMA/SMK (sekunder), pengguna Android.

**Persona utama — "Rina", mahasiswa semester 3**
- Mengambil 6–8 mata kuliah, tiap mata kuliah punya RPS PDF dari dosen.
- Sulit mencatat saat dosen menjelaskan cepat; sering lupa deadline tugas.
- Sering membuka media sosial saat belajar mandiri.
- Kebutuhan: "Saya ingin sekali upload, jadwal dan pengingat langsung jadi; saya ingin rekam penjelasan dosen jadi catatan yang rapi; saya ingin dipaksa fokus 30 menit."

### 1.6 Prinsip Desain Produk

1. **Otomatis tapi bisa dikoreksi.** Setiap hasil otomatis (ekstraksi RPS, saran mata kuliah) selalu bisa diedit user sebelum final.
2. **Offline-first untuk fitur inti.** Catatan, reminder, dan timer tetap jalan tanpa internet.
3. **Satu langkah untuk aksi utama.** Rekam, mulai fokus, dan upload RPS maksimal 2 ketukan dari beranda.
4. **Jujur soal keterbatasan.** Transkripsi tidak sempurna; aplikasi menampilkan teks yang bisa diedit.

---

## 2. Scope & Prioritas

| Prioritas | Fitur | Keterangan |
|---|---|---|
| **P0 (wajib untuk demo)** | Login Google, kelola mata kuliah + jam kelas, upload RPS → review → jadwal, auto reminder, voice transcription → catatan, auto-tag mata kuliah, timer fokus + screen pinning, beranda ringkas | Alur utama yang akan didemokan |
| **P1 (sebaiknya ada)** | Share dokumen/notes dari aplikasi lain, daftar & pencarian catatan, tugas (TASK) manual, statistik fokus mingguan, fallback Do Not Disturb | Dikerjakan jika P0 sudah stabil |
| **P2 (nilai tambah / roadmap)** | Ringkasan catatan otomatis (LLM), LLM fallback untuk parser RPS, rekaman audio + STT server, widget Android, mode gelap | Hanya disebut di proposal sebagai rencana pengembangan, kecuali waktu tersisa |

**Cut line:** bila waktu kurang, P1 dipotong dahulu. P0 tidak boleh dipotong; yang boleh disederhanakan hanya tampilan UI.

---

## 3. User Flow & Daftar Layar

### 3.1 Alur Utama (End-to-End)

```
Login Google
   └─> Onboarding singkat (pilih universitas, izin notifikasi)
        └─> Tambah Mata Kuliah (nama, warna, hari/jam kelas, tanggal mulai kuliah)
             ├─> Upload RPS PDF ──> Review hasil ──> Simpan ──> Jadwal + Reminder terpasang
             ├─> Rekam (mic) ──> Transkrip ──> Stop ──> Saran mata kuliah ──> Simpan catatan
             └─> Mulai Fokus (pilih tugas/jadwal, durasi) ──> Pinned ──> Selesai/Gagal ──> Tercatat
```

### 3.2 Daftar Layar (MVP)

| Kode | Layar | Isi utama |
|---|---|---|
| S01 | Splash & Login | Tombol "Masuk dengan Google" |
| S02 | Onboarding | Universitas (opsional), minta izin notifikasi, penjelasan singkat fitur |
| S03 | Beranda (Dashboard) | Jadwal hari ini, deadline terdekat, tombol cepat Rekam / Mulai Fokus / Upload RPS, ringkasan fokus minggu ini |
| S04 | Daftar Mata Kuliah | Kartu per mata kuliah (warna, jumlah catatan, jadwal terdekat) |
| S05 | Form Mata Kuliah | Nama, kode (opsional), dosen (opsional), warna, tanggal mulai kuliah, slot hari/jam/ruang, kata kunci tambahan |
| S06 | Detail Mata Kuliah | Tab: Jadwal, Catatan, Dokumen |
| S07 | Upload RPS | Pilih file, tanggal mulai, tombol Proses |
| S08 | Review Hasil RPS | Daftar pertemuan (checkbox + text editable + tanggal editable), peringatan, tombol Simpan Jadwal |
| S09 | Jadwal / Kalender | Tampilan daftar per minggu; filter mata kuliah; tandai selesai |
| S10 | Rekam Catatan | Mic besar, teks streaming, status (Idle/Recording/Paused), Save/Discard |
| S11 | Bottom Sheet Saran Mata Kuliah | "Simpan ke {Mata Kuliah}? [Ya] [Pilih Lain]" |
| S12 | Daftar & Detail Catatan | Daftar, pencarian, edit judul/isi, pindah mata kuliah |
| S13 | Setup Fokus | Pilih tugas (opsional), durasi 10–120 menit (kelipatan 5) |
| S14 | Sesi Fokus (Running) | Lingkaran timer, tombol "Menyerah" |
| S15 | Hasil Fokus | Confetti (berhasil) atau pesan gagal + alasan, ringkasan waktu |
| S16 | Pengaturan | Izin, bahasa transkripsi (id-ID/en-US), reminder default, hapus data/akun |

---

## 4. Arsitektur & Teknologi

### 4.1 Diagram Arsitektur

```
┌──────────────────────────── Android (Flutter) ────────────────────────────┐
│  UI (Riverpod + go_router)                                                 │
│  ├─ speech_to_text  ──► teks (di perangkat)                                │
│  ├─ flutter_local_notifications ──► reminder terjadwal (di perangkat)      │
│  ├─ MethodChannel (Kotlin) ──► startLockTask / stopLockTask / state         │
│  └─ Local storage (Hive/SQLite) ──► draft catatan + antrean "Pending Sync" │
└───────────────┬────────────────────────────────────────────────────────────┘
                │ HTTPS (Authorization: Bearer <Firebase ID Token>)
┌───────────────▼────────────────────────────────────────────────────────────┐
│  NestJS (REST /api/v1)                                                     │
│  AuthGuard (firebase-admin) · ValidationPipe · Swagger · Throttler         │
│  Modules: Users · Courses · Schedules · Rps · Notes · Files · Focus        │
└───────────────┬───────────────────────────────┬────────────────────────────┘
                │ Prisma ORM                    │ Multer (file upload)
        ┌───────▼────────┐              ┌───────▼─────────┐
        │ PostgreSQL     │              │ Penyimpanan file │
        │ (DB: saa)      │              │ (disk / cloud)   │
        └────────────────┘              └─────────────────┘
```

### 4.2 Tech Stack

| Lapisan | Pilihan | Catatan |
|---|---|---|
| Frontend | Flutter (Dart), Android API 24+ | State management: Riverpod; routing: go_router; HTTP: dio |
| Backend | Node.js + NestJS (TypeScript) | REST, versi `/api/v1`, dokumentasi Swagger |
| Database | PostgreSQL + Prisma ORM | DB lokal bernama `saa` (sudah dibuat) |
| Auth | Firebase Authentication (Google Sign-In) | Backend memverifikasi ID token dengan `firebase-admin` |
| Speech-to-Text | `speech_to_text` (Google Speech Services bawaan Android) | Berjalan di perangkat; offline hanya jika paket bahasa sudah diunduh |
| PDF Parser | `pdf-parse` + parser bertingkat (regex + heuristik) | Hanya PDF berbasis teks |
| File upload | Multer | Batas ukuran dan validasi MIME |
| Notifikasi | `flutter_local_notifications` + `timezone` | Dijadwalkan lokal; tanpa cron di backend |

> Catatan versi: pastikan versi Prisma, NestJS, dan paket Flutter yang dipakai sesuai dokumentasi terbarunya (terutama konfigurasi Prisma yang berubah antar versi mayor). Cek di pub.dev / dokumentasi resmi sebelum mengunci versi.

### 4.3 Keputusan Teknis Penting

**a. Auth (satu jalur saja).**
1. Flutter melakukan Google Sign-In via Firebase → mendapat *Firebase ID Token*.
2. Setiap request membawa header `Authorization: Bearer <idToken>`.
3. Backend memverifikasi token dengan `firebase-admin`, lalu *upsert* user (berdasarkan `firebase_uid`) pada request pertama (`GET /me`).
4. Tidak ada JWT custom pada MVP (lebih sedikit kode dan celah). Tidak ada Register/Login email pada MVP.
5. Daftarkan SHA-1/SHA-256 *debug* dan *release* keystore di Firebase Console, jika tidak Google Sign-In akan gagal di APK.

**b. Offline-first & sinkronisasi (sederhana).**
- Catatan dibuat di perangkat dengan `id` UUID yang dibuat di client (`clientId`), sehingga `POST /notes` bersifat idempoten (kirim ulang tidak menggandakan data).
- Status lokal: `DRAFT` → `PENDING_SYNC` → `SYNCED`.
- Sinkronisasi dicoba saat: catatan disimpan, aplikasi dibuka, koneksi kembali. Retry dengan *exponential backoff* (mis. 5s, 30s, 2m, maks 5 kali), selebihnya menunggu pemicu berikutnya.
- Konflik: *last-write-wins* berdasarkan `updated_at` (cukup untuk MVP satu perangkat).
- Pilih **satu** penyimpanan lokal (rekomendasi: Hive/`hive_ce` untuk draft dan antrean sinkron). Jangan campur Hive dan SQLite.

**c. Zona waktu.**
- Semua timestamp di DB dan API disimpan dalam **UTC** (format ISO-8601 dengan `Z`).
- Perhitungan "hari/jam kelas" memakai zona `Asia/Jakarta` (field `users.timezone`, default `Asia/Jakarta`).
- Contoh: kuliah Senin 08:00 WIB = `01:00:00Z` pada hari yang sama.

**d. Penyimpanan file.**
- MVP: disk lokal server (`/uploads`), nama file di-*rename* (UUID), simpan path relatif di `file_url`.
- Validasi: MIME + ekstensi (`application/pdf`; untuk dokumen catatan boleh `pptx` hanya disimpan, **tidak** diekstrak teksnya), maksimal 5 MB (RPS) dan 10 MB (dokumen).
- Roadmap: pindah ke object storage (S3/Supabase/Firebase Storage).

**e. Konvensi API.**
- JSON memakai `camelCase`; kolom DB memakai `snake_case` (dipetakan via Prisma `@map`).
- Semua respons: `{ "status": "success" | "error", "data": ..., "error": ... }`.
- Setiap data milik user wajib difilter dengan `userId` dari token (tidak boleh dari body/parameter).

### 4.4 Struktur Backend yang Disarankan (NestJS)

```
src/
├─ main.ts                    # ValidationPipe(whitelist), Swagger, helmet, CORS
├─ app.module.ts
├─ prisma/                    # PrismaModule + PrismaService
├─ common/                    # guards, filters (exception), interceptors (response wrapper), dto
├─ auth/                      # FirebaseAuthGuard, @CurrentUser()
├─ users/                     # GET /me, PATCH /me, DELETE /me
├─ courses/                   # CRUD + slots
├─ schedules/                 # CRUD + bulk + complete
├─ rps/                       # extract (parser) — stateless
├─ notes/                     # CRUD + suggest-course + document upload
├─ files/                     # Multer config + serve file (auth)
└─ focus/                     # create session + stats
```

### 4.5 Paket Flutter yang Direncanakan

| Kebutuhan | Paket (contoh) | Catatan |
|---|---|---|
| Auth | `firebase_core`, `firebase_auth`, `google_sign_in` | |
| HTTP | `dio` | Interceptor menambahkan ID token |
| State & routing | `flutter_riverpod`, `go_router` | |
| Speech | `speech_to_text` | Lihat 5.1.A (restart loop) |
| Izin | `permission_handler` | Mic, notifikasi, exact alarm |
| Notifikasi | `flutter_local_notifications`, `timezone`, `flutter_timezone` | |
| File | `file_picker` | Pilih RPS/dokumen |
| Share intent | `receive_sharing_intent` | Cek status pemeliharaan paket; siapkan alternatif bila bermasalah |
| Wakelock | `wakelock_plus` | Menjaga layar saat sesi fokus bila diperlukan |
| Lokal | `hive_ce` (atau pilihan lain, **satu saja**) | |
| UI | `confetti`, `intl`, `table_calendar` (opsional) | |

---

## 5. Spesifikasi Fitur Detail

> Format: **FR** = Functional Requirement. **AC** = Acceptance Criteria (kondisi lulus uji).

### 5.0 Modul 0 — Fondasi (Auth, Mata Kuliah, Beranda)

*(Modul ini tidak ada di v3.0 padahal semua fitur bergantung padanya.)*

**FR-0.1 Login Google (P0)**
- User menekan "Masuk dengan Google" → login Firebase → panggil `GET /me`.
- AC: Setelah login pertama, record `users` terbentuk; login berikutnya tidak menggandakan record.
- AC: Bila gagal/dibatalkan, tampilkan pesan yang jelas dan tetap di layar login.

**FR-0.2 Kelola Mata Kuliah (P0)**
- Buat/ubah/hapus mata kuliah: nama (wajib), warna (pilihan palet), tanggal mulai kuliah, slot jadwal mingguan (hari, jam mulai, jam selesai, ruang), kata kunci tambahan (opsional).
- Kolom `keywords` otomatis terisi dari: token nama mata kuliah + kata kunci manual + topik hasil ekstraksi RPS (lihat 5.2.A).
- AC: Mata kuliah tanpa slot tetap bisa dibuat (jam default 08:00 WIB saat ekstraksi RPS).
- AC: Menghapus mata kuliah meminta konfirmasi dan menjelaskan dampaknya ke jadwal dan catatan (soft delete; catatan menjadi "Belum dikategorikan").

**FR-0.3 Beranda (P0)**
- Menampilkan: jadwal hari ini, 3 deadline terdekat, tombol cepat (Rekam, Mulai Fokus, Upload RPS), total menit fokus minggu ini.
- AC: Saat belum ada mata kuliah, tampilkan *empty state* yang mengarahkan ke "Tambah Mata Kuliah".

---

### 5.1 Modul 1 — Smart Capture (Voice Transcription & Auto-Tag)

#### A. Voice Transcription → Teks (P0)

**Deskripsi:** Perekaman suara *real-time* yang langsung dikonversi menjadi teks di perangkat.

**State UI:**
| State | Tampilan |
|---|---|
| Idle | Tombol mic besar di tengah bawah layar |
| Recording | Animasi *pulsing mic*/waveform, teks muncul bertahap (streaming), indikator durasi |
| Paused | Tombol Lanjut, Save, Discard |
| Stopped | Teks bisa diedit, tombol Save dan Discard |
| Error | Pesan penyebab (izin ditolak, layanan suara tidak tersedia, dsb.) + tombol coba lagi |

**Logika & Happy Path:**
1. User menekan tombol Mic.
2. Aplikasi meminta izin `RECORD_AUDIO` (bila belum diberikan).
3. Aplikasi mulai mendengarkan dengan locale pilihan (`id-ID` default, atau `en-US`) dan `partialResults = true`.
4. Hasil parsial ditampilkan sebagai teks sementara; hasil final dipindahkan ke teks tetap (*committed text*).
5. **Restart loop (wajib):** pada Android, recognizer berhenti sendiri saat user diam beberapa detik atau melewati batas waktu. Saat status berubah ke `done`/`notListening` dan user belum menekan Stop/Pause, aplikasi memulai ulang `listen()` setelah jeda singkat (±300 ms) dan menyambung hasilnya ke teks sebelumnya.
6. Auto-save draft ke penyimpanan lokal **setiap 15 detik** dan setiap kali ada hasil final.
7. User menekan Stop → teks bisa diedit → Save.
8. Setelah Save: catatan disimpan lokal (`PENDING_SYNC`), lalu alur Auto-Tag (5.1.B) dan sinkron ke backend.

**Batasan yang harus diterima (dan dijelaskan di proposal):**
- Kualitas bergantung mikrofon, jarak ke dosen, dan kebisingan kelas; hasil dapat memuat salah kata → teks harus bisa diedit.
- Di sebagian perangkat, restart recognizer dapat memunculkan bunyi "beep" sistem. Uji di perangkat nyata; jika mengganggu, catat sebagai known issue.
- Dirancang untuk penjelasan per topik (sesi beberapa menit berulang), bukan jaminan merekam kuliah 2 jam tanpa putus. Tampilkan tips: "Dekatkan HP ke sumber suara."
- Ucapan tidak menyimpan file audio (tidak ada rekaman mentah pada MVP).

**Edge Cases & Error Handling:**
| Kasus | Penanganan |
|---|---|
| Izin mic ditolak | Tampilkan penjelasan + tombol buka Pengaturan aplikasi |
| Izin ditolak permanen | Arahkan ke pengaturan sistem |
| Layanan speech tidak tersedia | Pesan: "Layanan pengenalan suara tidak tersedia di perangkat ini." |
| Internet putus | Bila paket bahasa offline tersedia, tetap jalan; bila tidak, tampilkan pesan dan simpan teks yang sudah ada |
| Aplikasi ditutup paksa / crash | Saat dibuka lagi, tampilkan dialog "Lanjutkan draft terakhir?" (maks draft 24 jam) |
| Panggilan masuk / aplikasi ke background | Otomatis *pause* dan simpan draft |
| Teks kosong saat Stop | Tombol Save dinonaktifkan |
| Sinkron gagal | Status "Pending Sync" + ikon; retry otomatis (lihat 4.3.b) |

**AC:**
- Teks muncul dalam < 2 detik setelah mulai bicara pada kondisi normal.
- Draft tidak hilang setelah force close (maks kehilangan 15 detik terakhir).
- Dua kali Save dengan `clientId` sama tidak membuat catatan ganda di server.

#### B. Auto-Tag Mata Kuliah (P0)

**Deskripsi:** Menyarankan mata kuliah dari isi catatan tanpa input manual.

**Sumber sinyal (dari terkuat ke terlemah):**
1. **Konteks waktu:** bila catatan dibuat pada rentang jam kelas suatu mata kuliah (jam mulai −15 menit s.d. jam selesai +30 menit, zona `Asia/Jakarta`), mata kuliah itu mendapat bonus skor.
2. **Kata kunci mata kuliah:** nama mata kuliah, `keywords` manual, dan topik hasil ekstraksi RPS.
3. **(Opsional/P2)** isi catatan sebelumnya yang sudah di-tag.

**Algoritma (MVP, tanpa ML):**
1. Normalisasi teks: huruf kecil, hapus tanda baca, tokenisasi, buang *stopword* bahasa Indonesia/Inggris sederhana.
2. Untuk setiap mata kuliah *c* milik user:
   - `skor(c) = Σ bobot(kata) × min(jumlah_kemunculan, 3)` untuk setiap kata kunci yang cocok.
   - Bobot: token nama mata kuliah = 3, kata kunci manual = 2, topik RPS = 2.
   - `skor(c) += bonusWaktu` bila catatan dibuat dalam jam kelas *c* (mis. +5).
3. `konfidensi = skor_tertinggi / Σ semua skor` (0–1). Bila total skor = 0 maka konfidensi = 0.
4. Keputusan:

| Konfidensi | Perilaku UI |
|---|---|
| ≥ 0.60 | Bottom sheet: "Simpan ke {Mata Kuliah}? [Ya] [Pilih Lain]" |
| 0.30 – 0.59 | Bottom sheet menampilkan 3 kandidat teratas untuk dipilih |
| < 0.30 | Tidak ada saran; catatan masuk "Belum dikategorikan" dan user bisa memilih manual |

**Contoh:** Teks mengandung "algoritma", "array", "coding". User punya mata kuliah "Struktur Data" dengan topik RPS "Array dan Linked List" → skor tertinggi → saran "Struktur Data", konfidensi 0.85.

**Edge Cases:**
- User belum punya mata kuliah → langsung arahkan ke "Tambah Mata Kuliah" (catatan tetap tersimpan).
- Offline → catatan disimpan sebagai "Belum dikategorikan (menunggu saran)"; saran dihitung saat sinkron berikutnya.
- Catatan sangat pendek (< 10 kata) → konfidensi dianggap rendah, tidak ada saran.

**AC:**
- Bottom sheet muncul < 1 detik setelah saran diterima.
- Pilihan user (Ya/Pilih Lain) menjadi sumber kebenaran; `confidence_score` disimpan untuk evaluasi akurasi.

#### C. Share Dokumen/Notes ke Aplikasi (P1)

**Deskripsi:** Menerima file PDF/PPT/teks dari WhatsApp atau File Manager langsung ke aplikasi.

**Logika:**
1. Gunakan `receive_sharing_intent` (atau alternatif bila paket bermasalah) + `intent-filter` `ACTION_SEND` untuk `application/pdf`, `application/vnd.ms-powerpoint`, `application/vnd.openxmlformats-officedocument.presentationml.presentation`, dan `text/plain`.
2. Saat user membagikan file, aplikasi muncul di menu Share Android.
3. Aplikasi terbuka dengan URI file → tampil dialog "Simpan dokumen ke mata kuliah apa?" (daftar mata kuliah + opsi "Belum dikategorikan").
4. File diunggah ke `POST /notes/document` dan dibuat sebagai catatan bertipe `DOCUMENT`.

**Batasan MVP:** file hanya disimpan dan dapat dibuka; **tidak ada ekstraksi teks** dari PPT/PDF dokumen (kecuali RPS di Modul 2).

**Edge Cases:** file > 10 MB → ditolak dengan pesan; tipe tidak didukung → pesan; URI tidak bisa dibaca (izin) → salin dulu ke cache aplikasi; user belum login → simpan sementara, lanjutkan setelah login.

**AC:** Dokumen terbuka kembali dari detail mata kuliah setelah diunggah; tidak ada duplikat bila user menekan tombol dua kali.

---

### 5.2 Modul 2 — Intelligent Planning (RPS & Jadwal)

#### A. Ambil Data RPS → Auto Jadwal (P0)

**Deskripsi:** Ekstraksi PDF RPS menjadi daftar pertemuan mingguan yang bisa direview dan disimpan sebagai jadwal.

**State UI:**
| State | Tampilan |
|---|---|
| Upload | Tombol "Pilih File PDF", pilih tanggal mulai kuliah (default dari data mata kuliah) |
| Loading | Animasi *scanning* (target 2–5 detik) |
| Review | Daftar hasil ekstraksi: checkbox, judul editable, tanggal editable, penanda tipe (Kelas/UTS/UAS), peringatan |
| Success | Ringkasan "N jadwal tersimpan, reminder aktif" |
| Error | Pesan sesuai kode error (lihat tabel) + opsi input manual |

**Logika & Happy Path:**
1. User memilih mata kuliah → Upload RPS (PDF, maks 5 MB) → mengisi/konfirmasi `startDate` (tanggal pertemuan 1).
2. Frontend mengirim `multipart/form-data` ke `POST /courses/:courseId/rps/extract` (hanya ekstraksi, **belum menyimpan**).
3. Backend membaca teks dengan `pdf-parse` dan menjalankan **parser bertingkat**:
   - **Tingkat 1 — penanda eksplisit:** baris yang diawali pola seperti `Minggu ke-X`, `Minggu X`, `Pertemuan ke-X`, `Pertemuan X`, `Week X` → topik adalah teks setelahnya.
   - **Tingkat 2 — tabel RPS:** baris yang diawali angka 1–16 sendiri diikuti teks (karena `pdf-parse` meratakan tabel). Terapkan hanya jika Tingkat 1 menghasilkan < 4 baris.
   - **Penyambungan baris:** teks lanjutan sampai penanda berikutnya digabung (maks ±200 karakter, rapikan spasi).
   - **Deteksi ujian:** judul memuat `UTS`, `Ujian Tengah Semester`, `UAS`, `Ujian Akhir Semester`, `Evaluasi` → `type = EXAM`.
   - **Validasi:** nomor 1–16, hapus duplikat, urutkan; nomor yang hilang dicatat di `warnings` (mis. "Pertemuan 5 tidak ditemukan").
4. Backend menghitung tanggal tiap pertemuan:
   - Hari & jam dari slot pertama mata kuliah (`course_slots`); bila tidak ada, pakai hari dari `startDate` dan jam 08:00 `Asia/Jakarta`.
   - Pertemuan *n* = tanggal pertemuan 1 + 7 × (n − 1) hari.
   - Hasil dikonversi ke UTC.
5. Backend mengembalikan `items[]` + `warnings[]` (contoh di Bagian 7).
6. Frontend menampilkan layar Review; user dapat mengedit judul/tanggal, menghapus baris, atau menambah baris manual (mis. menggeser tanggal karena libur).
7. User menekan "Simpan Jadwal" → `POST /schedules/bulk` → backend membuat record `schedules`, lalu **menambahkan topik ke `courses.keywords`** (untuk auto-tag).
8. Frontend memasang reminder lokal untuk setiap jadwal (5.2.B).

**Kode error & pesan:**
| Kode | Kondisi | Pesan ke user |
|---|---|---|
| `RPS_NOT_TEXT_PDF` | Teks hasil ekstraksi kosong / hampir kosong (PDF scan/gambar) | "Format RPS tidak didukung. Gunakan PDF berbasis teks (bukan hasil scan)." |
| `RPS_NO_PATTERN` | Tidak ada pola pertemuan ditemukan | "Gagal mengekstrak otomatis. Silakan input jadwal secara manual." |
| `FILE_TOO_LARGE` | > 5 MB | "Ukuran file maksimal 5 MB." |
| `UNSUPPORTED_MIME` | Bukan PDF | "Hanya file PDF yang didukung." |
| `PDF_CORRUPT` | PDF tidak bisa dibaca / terproteksi | "File PDF tidak dapat dibaca." |

**Kebutuhan data uji (wajib sebelum fitur dianggap selesai):** kumpulkan **minimal 5 RPS asli** dari berbagai dosen/prodi, simpan sebagai data uji (tanpa data pribadi), dan ukur akurasi (Goal G3). Sesuaikan pola regex berdasarkan sampel ini, bukan hanya tebakan format.

**AC:**
- Dari menekan "Proses" hingga layar Review muncul ≤ 5 detik untuk PDF ≤ 5 MB.
- Layar Review selalu ditampilkan sebelum data disimpan (tidak ada simpan otomatis tanpa konfirmasi).
- Tanggal pertemuan jatuh pada hari dan jam yang sama dengan slot kelas (WIB).
- Menyimpan ulang RPS untuk mata kuliah yang sama menampilkan konfirmasi "Ganti jadwal yang ada?" agar tidak terjadi duplikasi.

**Roadmap (P2):** fallback LLM untuk RPS dengan format tidak standar; OCR untuk PDF scan.

#### B. Auto Reminder (P0)

**Deskripsi:** Notifikasi sebelum jadwal kelas, ujian, atau tugas.

**Logika:**
1. Menggunakan `flutter_local_notifications` dengan `zonedSchedule` dan paket `timezone` (set lokasi `Asia/Jakarta`).
2. Saat jadwal disimpan/diubah/dihapus, frontend menjadwalkan/menjadwalkan ulang/membatalkan notifikasi. ID notifikasi = fungsi *hash* stabil dari `schedule.id` (integer 32-bit).
3. Default pengingat: kelas = 60 menit sebelum; tugas/ujian = H-1 pukul 19:00 dan 60 menit sebelum. Bisa diubah di Pengaturan (`reminderMinutes`).
4. Tidak ada cron di backend (hemat resource, bekerja offline).
5. Setelah login di perangkat baru atau data sinkron, jadwalkan ulang semua reminder mendatang.

**Izin & kompatibilitas Android (wajib ditangani):**
- Android 13+: izin runtime `POST_NOTIFICATIONS`.
- Android 12+: alarm tepat waktu memerlukan izin *exact alarm*; jika tidak diberikan, gunakan mode tidak-eksak dan beri tahu user bahwa waktu bisa meleset beberapa menit.
- Reminder hilang setelah reboot → pastikan receiver boot dari paket notifikasi terpasang di `AndroidManifest.xml` (`RECEIVE_BOOT_COMPLETED`).
- Sebagian merek (mis. Xiaomi, Oppo, Vivo) membatasi aplikasi latar belakang → sediakan layar bantuan "Agar pengingat tidak terlewat" yang menjelaskan pengecualian optimasi baterai.

**Edge Cases:** jadwal sudah lewat → jangan jadwalkan; zona waktu perangkat berubah → jadwalkan ulang saat aplikasi dibuka; notifikasi ditekan → buka detail jadwal terkait.

**AC:** Reminder muncul pada waktu yang benar (±1 menit) di minimal 2 perangkat uji, termasuk setelah aplikasi ditutup dan setelah reboot.

#### C. Jadwal Manual & Tugas (P1)

- User dapat menambah tugas (`type = TASK`) dengan judul, mata kuliah, tenggat, dan menandai selesai.
- AC: Tugas muncul di Beranda sebagai deadline terdekat dan memicu reminder.

---

### 5.3 Modul 3 — Deep Focus (Produktivitas)

#### A. Timer Fokus & Block Distraksi (P0)

**Deskripsi:** Timer fokus (gaya Pomodoro) yang mengunci layar pada aplikasi SAA agar tidak berpindah ke aplikasi lain.

**State UI:**
| State | Tampilan |
|---|---|
| Setup | Pemilih durasi 10–120 menit (kelipatan 5), pilihan tugas/jadwal (opsional), tombol "Mulai Fokus" |
| Pre-flight | Panduan sekali jalan: aktifkan Screen Pinning bila perlu (lihat di bawah) |
| Running | Lingkaran timer besar, sisa waktu, tombol "Menyerah"; tanpa navigasi lain |
| Finished | Confetti, ringkasan waktu fokus, tombol selesai |
| Failed | Pesan gagal + alasan, opsi coba lagi |

**Logika & Happy Path:**
1. User memilih durasi (dan opsional tugas) → "Mulai Fokus".
2. Aplikasi memanggil fitur **Android Screen Pinning** lewat *MethodChannel* ke kode Kotlin (`startLockTask()`). Tidak ada paket Flutter resmi untuk ini; perlu kode native kecil.
3. **Konfirmasi dari sistem:** pada aplikasi biasa (bukan device owner), Android menampilkan dialog konfirmasi pinning; pada sebagian perangkat fitur "Screen pinning/App pinning" harus diaktifkan dulu di Pengaturan sistem. Aplikasi mendeteksi status dengan `ActivityManager.getLockTaskModeState()` dan menampilkan panduan bila belum aktif.
4. Saat pinned, tombol Home/Recent diblokir oleh sistem dan notifikasi tidak ditampilkan.
5. Timer berjalan berdasarkan **waktu selesai absolut** (`endsAt = startedAt + durasi`); sisa waktu dihitung `endsAt − sekarang` pada setiap *tick* — bukan menghitung mundur manual — agar tahan terhadap layar mati dan *throttling*.
6. Jadwalkan juga satu notifikasi lokal pada `endsAt` sebagai cadangan ("Sesi fokus selesai").
7. Waktu habis → `stopLockTask()` otomatis → hasil dicatat (`COMPLETED`) → kirim ke `POST /focus-sessions`.

**Pembatasan penting (dijelaskan jujur di proposal):** Screen Pinning dapat dilepas user secara sengaja (tahan tombol Back + Recents / gestur sistem). Aplikasi tidak bisa mencegahnya; yang bisa dilakukan adalah mendeteksi dan mencatat sebagai gagal.

**Edge Cases & Error Handling:**
| Kasus | Penanganan |
|---|---|
| User melepas pin lewat OS / aplikasi pindah ke background | Deteksi lewat *lifecycle* (`paused`) + status lock task → sesi dicatat `FAILED`, `failReason = UNPINNED` atau `APP_BACKGROUNDED` |
| User menekan "Menyerah" | Dialog konfirmasi → `FAILED`, `failReason = USER_GAVE_UP`, pin dilepas |
| Layar mati | Timer tetap benar karena berbasis `endsAt`; gunakan `wakelock_plus` atau foreground service bila diperlukan agar proses tidak dimatikan |
| Aplikasi dimatikan sistem saat sesi | Saat dibuka lagi: bila `endsAt` sudah lewat → catat `COMPLETED` (atau `FAILED` bila ditandai gangguan); bila belum → lanjutkan |
| Pinning tidak tersedia/ditolak | Tampilkan pilihan: lanjut tanpa kunci (mode "sukarela") atau batal; opsi P1: fallback *Do Not Disturb* |
| Telepon masuk | Dibiarkan sistem; tidak menggagalkan sesi selama aplikasi kembali ke foreground dalam 10 detik |
| Baterai lemah (< 10%) | Tampilkan peringatan sebelum mulai |

**Fallback P1 — Do Not Disturb:** minta akses kebijakan notifikasi (Notification Policy Access) lalu aktifkan mode DND selama sesi dan kembalikan setelahnya. Ini menangani masalah inti "notifikasi mengganggu" meskipun pinning tidak aktif.

**AC:**
- Selama sesi berjalan di perangkat uji, user tidak dapat membuka aplikasi lain tanpa melepas pin secara sengaja.
- Selisih timer vs jam sebenarnya ≤ 2 detik setelah sesi 10 menit dengan layar sempat mati.
- Setiap sesi (berhasil/gagal) tercatat di server, atau di antrean *Pending Sync* bila offline.

#### B. Statistik Fokus (P1)
- Ringkasan: total menit fokus minggu ini, jumlah sesi berhasil vs gagal, per mata kuliah (jika terhubung ke jadwal).
- Endpoint: `GET /focus-sessions/stats?range=week`.

---

## 6. Skema Database (PostgreSQL)

### 6.1 Prinsip

- Primary key `UUID`; kolom `snake_case`; timestamp UTC (`TIMESTAMPTZ`).
- Soft delete (`deleted_at`) untuk `courses` dan `notes`.
- `ON DELETE`: hapus user → cascade ke semua data user; hapus course → `schedules` cascade, `notes.course_id` → `SET NULL`.
- Indeks pada kolom yang sering difilter (`user_id`, `course_id`, `due_date`).

### 6.2 Tabel

#### `users`
| Kolom | Tipe | Constraint | Keterangan |
|---|---|---|---|
| `id` | UUID | PK | |
| `firebase_uid` | VARCHAR | UNIQUE, NOT NULL | UID dari Firebase |
| `email` | VARCHAR | UNIQUE, NOT NULL | |
| `name` | VARCHAR | NOT NULL | |
| `photo_url` | VARCHAR | NULL | |
| `university` | VARCHAR | NULL | |
| `timezone` | VARCHAR | NOT NULL, DEFAULT 'Asia/Jakarta' | |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() | |
| `updated_at` | TIMESTAMPTZ | NOT NULL | |

#### `courses` (Mata Kuliah)
| Kolom | Tipe | Constraint | Keterangan |
|---|---|---|---|
| `id` | UUID | PK | |
| `user_id` | UUID | FK → users(id), NOT NULL, INDEX | |
| `name` | VARCHAR | NOT NULL | Contoh: "Pemrograman Web" |
| `code` | VARCHAR | NULL | Kode mata kuliah |
| `lecturer` | VARCHAR | NULL | |
| `color_code` | VARCHAR(7) | NOT NULL | Hex, contoh "#FF5733" |
| `start_date` | DATE | NULL | Tanggal pertemuan 1 |
| `keywords` | TEXT[] | NOT NULL, DEFAULT '{}' | Untuk auto-tag (nama + manual + topik RPS) |
| `created_at` / `updated_at` | TIMESTAMPTZ | | |
| `deleted_at` | TIMESTAMPTZ | NULL | Soft delete |

#### `course_slots` (Jadwal kelas mingguan) — **baru**
| Kolom | Tipe | Constraint | Keterangan |
|---|---|---|---|
| `id` | UUID | PK | |
| `course_id` | UUID | FK → courses(id) ON DELETE CASCADE | |
| `day_of_week` | SMALLINT | NOT NULL, CHECK 1–7 | 1 = Senin … 7 = Minggu (ISO) |
| `start_time` | VARCHAR(5) | NOT NULL | "08:00" (WIB) |
| `end_time` | VARCHAR(5) | NOT NULL | "09:40" (WIB) |
| `room` | VARCHAR | NULL | |

#### `schedules` (Jadwal & Tugas)
| Kolom | Tipe | Constraint | Keterangan |
|---|---|---|---|
| `id` | UUID | PK | |
| `course_id` | UUID | FK → courses(id) ON DELETE CASCADE, INDEX | |
| `title` | VARCHAR | NOT NULL | Contoh: "Pertemuan 1: HTML" |
| `type` | ENUM | NOT NULL | `CLASS`, `TASK`, `EXAM` |
| `meeting_number` | SMALLINT | NULL | Untuk CLASS/EXAM dari RPS |
| `due_date` | TIMESTAMPTZ | NOT NULL, INDEX | Waktu kelas/tugas (UTC) |
| `is_completed` | BOOLEAN | DEFAULT FALSE | |
| `reminder_minutes` | INT | NOT NULL, DEFAULT 60 | Menit sebelum `due_date` |
| `source` | VARCHAR | NOT NULL, DEFAULT 'MANUAL' | `MANUAL` atau `RPS` |
| `created_at` / `updated_at` | TIMESTAMPTZ | | |

#### `notes` (Catatan & Transkripsi)
| Kolom | Tipe | Constraint | Keterangan |
|---|---|---|---|
| `id` | UUID | PK | Dibuat di client (`clientId`) → idempoten |
| `user_id` | UUID | FK → users(id), NOT NULL, INDEX | Memudahkan cek kepemilikan |
| `course_id` | UUID | FK → courses(id) ON DELETE SET NULL, NULL | NULL = Belum dikategorikan |
| `title` | VARCHAR | NOT NULL | |
| `content` | TEXT | NULL | Hasil transkripsi |
| `type` | ENUM | NOT NULL | `VOICE`, `DOCUMENT` |
| `language` | VARCHAR(5) | NULL | `id-ID` / `en-US` |
| `duration_seconds` | INT | NULL | Lama perekaman (VOICE) |
| `file_url` | VARCHAR | NULL | Path file bila `DOCUMENT` |
| `file_name` | VARCHAR | NULL | Nama asli |
| `mime_type` | VARCHAR | NULL | |
| `file_size` | INT | NULL | Byte |
| `suggested_course_id` | UUID | NULL | Saran sistem (untuk evaluasi akurasi) |
| `confidence_score` | REAL | NULL | 0–1 |
| `created_at` / `updated_at` | TIMESTAMPTZ | | |
| `deleted_at` | TIMESTAMPTZ | NULL | Soft delete |

#### `focus_sessions` (Riwayat Fokus)
| Kolom | Tipe | Constraint | Keterangan |
|---|---|---|---|
| `id` | UUID | PK | Dibuat di client (idempoten) |
| `user_id` | UUID | FK → users(id), NOT NULL, INDEX | |
| `schedule_id` | UUID | FK → schedules(id) ON DELETE SET NULL, NULL | Boleh fokus tanpa tugas |
| `planned_seconds` | INT | NOT NULL | Durasi rencana |
| `actual_seconds` | INT | NOT NULL | Durasi nyata |
| `status` | ENUM | NOT NULL | `COMPLETED`, `FAILED` |
| `fail_reason` | ENUM | NULL | `USER_GAVE_UP`, `UNPINNED`, `APP_BACKGROUNDED`, `SYSTEM_KILLED` |
| `started_at` | TIMESTAMPTZ | NOT NULL | |
| `ended_at` | TIMESTAMPTZ | NOT NULL | |

### 6.3 Draft Prisma Schema

> Draft ini disesuaikan dengan tabel di atas. Konfigurasi `generator`/`datasource` mengikuti versi Prisma yang kamu pakai (cek dokumentasi resmi), bagian `model` dan `enum` relatif sama.

```prisma
enum ScheduleType { CLASS TASK EXAM }
enum NoteType { VOICE DOCUMENT }
enum FocusStatus { COMPLETED FAILED }
enum FailReason { USER_GAVE_UP UNPINNED APP_BACKGROUNDED SYSTEM_KILLED }

model User {
  id          String   @id @default(uuid()) @db.Uuid
  firebaseUid String   @unique @map("firebase_uid")
  email       String   @unique
  name        String
  photoUrl    String?  @map("photo_url")
  university  String?
  timezone    String   @default("Asia/Jakarta")
  createdAt   DateTime @default(now()) @map("created_at") @db.Timestamptz
  updatedAt   DateTime @updatedAt @map("updated_at") @db.Timestamptz

  courses       Course[]
  notes         Note[]
  focusSessions FocusSession[]

  @@map("users")
}

model Course {
  id        String    @id @default(uuid()) @db.Uuid
  userId    String    @map("user_id") @db.Uuid
  name      String
  code      String?
  lecturer  String?
  colorCode String    @map("color_code") @db.VarChar(7)
  startDate DateTime? @map("start_date") @db.Date
  keywords  String[]  @default([])
  createdAt DateTime  @default(now()) @map("created_at") @db.Timestamptz
  updatedAt DateTime  @updatedAt @map("updated_at") @db.Timestamptz
  deletedAt DateTime? @map("deleted_at") @db.Timestamptz

  user      User         @relation(fields: [userId], references: [id], onDelete: Cascade)
  slots     CourseSlot[]
  schedules Schedule[]
  notes     Note[]

  @@index([userId])
  @@map("courses")
}

model CourseSlot {
  id        String @id @default(uuid()) @db.Uuid
  courseId  String @map("course_id") @db.Uuid
  dayOfWeek Int    @map("day_of_week") @db.SmallInt
  startTime String @map("start_time") @db.VarChar(5)
  endTime   String @map("end_time") @db.VarChar(5)
  room      String?

  course Course @relation(fields: [courseId], references: [id], onDelete: Cascade)

  @@index([courseId])
  @@map("course_slots")
}

model Schedule {
  id              String       @id @default(uuid()) @db.Uuid
  courseId        String       @map("course_id") @db.Uuid
  title           String
  type            ScheduleType
  meetingNumber   Int?         @map("meeting_number") @db.SmallInt
  dueDate         DateTime     @map("due_date") @db.Timestamptz
  isCompleted     Boolean      @default(false) @map("is_completed")
  reminderMinutes Int          @default(60) @map("reminder_minutes")
  source          String       @default("MANUAL")
  createdAt       DateTime     @default(now()) @map("created_at") @db.Timestamptz
  updatedAt       DateTime     @updatedAt @map("updated_at") @db.Timestamptz

  course        Course         @relation(fields: [courseId], references: [id], onDelete: Cascade)
  focusSessions FocusSession[]

  @@index([courseId])
  @@index([dueDate])
  @@map("schedules")
}

model Note {
  id                String    @id @db.Uuid // dibuat di client (idempoten)
  userId            String    @map("user_id") @db.Uuid
  courseId          String?   @map("course_id") @db.Uuid
  title             String
  content           String?
  type              NoteType
  language          String?   @db.VarChar(5)
  durationSeconds   Int?      @map("duration_seconds")
  fileUrl           String?   @map("file_url")
  fileName          String?   @map("file_name")
  mimeType          String?   @map("mime_type")
  fileSize          Int?      @map("file_size")
  suggestedCourseId String?   @map("suggested_course_id") @db.Uuid
  confidenceScore   Float?    @map("confidence_score")
  createdAt         DateTime  @default(now()) @map("created_at") @db.Timestamptz
  updatedAt         DateTime  @updatedAt @map("updated_at") @db.Timestamptz
  deletedAt         DateTime? @map("deleted_at") @db.Timestamptz

  user   User    @relation(fields: [userId], references: [id], onDelete: Cascade)
  course Course? @relation(fields: [courseId], references: [id], onDelete: SetNull)

  @@index([userId])
  @@index([courseId])
  @@map("notes")
}

model FocusSession {
  id             String      @id @db.Uuid // dibuat di client (idempoten)
  userId         String      @map("user_id") @db.Uuid
  scheduleId     String?     @map("schedule_id") @db.Uuid
  plannedSeconds Int         @map("planned_seconds")
  actualSeconds  Int         @map("actual_seconds")
  status         FocusStatus
  failReason     FailReason? @map("fail_reason")
  startedAt      DateTime    @map("started_at") @db.Timestamptz
  endedAt        DateTime    @map("ended_at") @db.Timestamptz

  user     User      @relation(fields: [userId], references: [id], onDelete: Cascade)
  schedule Schedule? @relation(fields: [scheduleId], references: [id], onDelete: SetNull)

  @@index([userId, startedAt])
  @@map("focus_sessions")
}
```

---

## 7. Spesifikasi API

### 7.1 Konvensi

- Base URL: `/api/v1`
- Auth: header `Authorization: Bearer <Firebase ID Token>` (semua endpoint kecuali health check).
- Format JSON `camelCase`. Tanggal/waktu: ISO-8601 UTC (`2026-09-07T01:00:00Z`). Tanggal murni: `YYYY-MM-DD`.
- Paginasi daftar: `?limit=20&cursor=<id>`; respons menyertakan `nextCursor`.
- Sukses: `{ "status": "success", "data": { ... } }`
- Gagal: `{ "status": "error", "error": { "code": "RPS_NO_PATTERN", "message": "…", "details": [] } }`

**Kode status:** 200/201 sukses; 400 validasi; 401 token tidak valid; 403 bukan pemilik; 404 tidak ditemukan; 413 file terlalu besar; 415 tipe tidak didukung; 422 isi file tidak dapat diproses; 429 terlalu banyak request.

### 7.2 Daftar Endpoint

| Grup | Method & Path | Fungsi | Prioritas |
|---|---|---|---|
| Health | `GET /health` | Cek server hidup | P0 |
| User | `GET /me` | Ambil profil (upsert saat pertama kali) | P0 |
| User | `PATCH /me` | Ubah nama/universitas/timezone | P1 |
| User | `DELETE /me` | Hapus akun & seluruh data | P1 |
| Course | `GET /courses` | Daftar mata kuliah (+slots) | P0 |
| Course | `POST /courses` | Buat mata kuliah (boleh sekaligus `slots`) | P0 |
| Course | `GET /courses/:id` | Detail | P0 |
| Course | `PATCH /courses/:id` | Ubah (termasuk `slots`, `keywords`) | P0 |
| Course | `DELETE /courses/:id` | Soft delete | P0 |
| RPS | `POST /courses/:courseId/rps/extract` | Ekstrak PDF → daftar pertemuan (tanpa simpan) | P0 |
| Schedule | `GET /schedules` | Filter: `from`, `to`, `courseId`, `type`, `isCompleted` | P0 |
| Schedule | `POST /schedules` | Tambah satu jadwal/tugas | P1 |
| Schedule | `POST /schedules/bulk` | Simpan hasil review RPS | P0 |
| Schedule | `PATCH /schedules/:id` | Ubah | P0 |
| Schedule | `PATCH /schedules/:id/complete` | Tandai selesai/belum | P1 |
| Schedule | `DELETE /schedules/:id` | Hapus | P0 |
| Note | `POST /notes/suggest-course` | Saran mata kuliah dari teks (stateless) | P0 |
| Note | `POST /notes` | Simpan catatan suara (idempoten dengan `id`) | P0 |
| Note | `GET /notes` | Filter: `courseId`, `q`, `type`, paginasi | P0 |
| Note | `GET /notes/:id` | Detail | P0 |
| Note | `PATCH /notes/:id` | Ubah judul/isi/`courseId` | P0 |
| Note | `DELETE /notes/:id` | Soft delete | P1 |
| Note | `POST /notes/document` | Unggah dokumen (multipart) | P1 |
| Focus | `POST /focus-sessions` | Simpan hasil sesi (idempoten dengan `id`) | P0 |
| Focus | `GET /focus-sessions` | Riwayat (`from`, `to`) | P1 |
| Focus | `GET /focus-sessions/stats` | Statistik (`range=week`) | P1 |

### 7.3 Contoh Detail

#### `POST /courses/:courseId/rps/extract`
- Content-Type: `multipart/form-data`
- Body: `file` (PDF, maks 5 MB), `startDate` (`YYYY-MM-DD`, tanggal pertemuan 1)

Respons sukses (200) — contoh kuliah Senin 08:00 WIB:
```json
{
  "status": "success",
  "data": {
    "courseId": "7b1f3c4e-0000-0000-0000-000000000001",
    "startDate": "2026-09-07",
    "timezone": "Asia/Jakarta",
    "items": [
      { "meeting": 1, "title": "Pengenalan Sistem", "type": "CLASS", "dueDate": "2026-09-07T01:00:00Z" },
      { "meeting": 2, "title": "Arsitektur Dasar", "type": "CLASS", "dueDate": "2026-09-14T01:00:00Z" },
      { "meeting": 8, "title": "Ujian Tengah Semester", "type": "EXAM", "dueDate": "2026-10-26T01:00:00Z" }
    ],
    "warnings": ["Pertemuan 5 tidak ditemukan"]
  }
}
```

Respons error (422):
```json
{
  "status": "error",
  "error": {
    "code": "RPS_NOT_TEXT_PDF",
    "message": "Format RPS tidak didukung. Gunakan PDF berbasis teks (bukan hasil scan).",
    "details": []
  }
}
```

#### `POST /schedules/bulk`
```json
{
  "courseId": "7b1f3c4e-0000-0000-0000-000000000001",
  "replaceExistingFromRps": true,
  "items": [
    { "meeting": 1, "title": "Pengenalan Sistem", "type": "CLASS", "dueDate": "2026-09-07T01:00:00Z" },
    { "meeting": 2, "title": "Arsitektur Dasar", "type": "CLASS", "dueDate": "2026-09-14T01:00:00Z" }
  ]
}
```
Respons: `data.created` (jumlah), `data.schedules[]` (dengan `id`, untuk dipakai menjadwalkan reminder), `data.keywordsAdded[]`.

#### `POST /notes/suggest-course`
Request:
```json
{
  "content": "Hari ini kita belajar tentang algoritma sorting dan array...",
  "createdAt": "2026-10-12T01:20:00Z"
}
```
Respons:
```json
{
  "status": "success",
  "data": {
    "suggestions": [
      { "courseId": "uuid-course-5678", "name": "Struktur Data", "confidenceScore": 0.85 },
      { "courseId": "uuid-course-9012", "name": "Algoritma Pemrograman", "confidenceScore": 0.10 }
    ],
    "decision": "SUGGEST_ONE"
  }
}
```
`decision`: `SUGGEST_ONE` (≥ 0.60), `SUGGEST_MANY` (0.30–0.59), `NONE` (< 0.30).

#### `POST /notes`
```json
{
  "id": "b5c1f0a2-0000-0000-0000-000000000010",
  "title": "Catatan 12 Okt",
  "content": "Hari ini kita belajar tentang algoritma sorting...",
  "type": "VOICE",
  "language": "id-ID",
  "durationSeconds": 420,
  "courseId": "uuid-course-5678",
  "suggestedCourseId": "uuid-course-5678",
  "confidenceScore": 0.85
}
```
Respons 201 berisi catatan lengkap. Bila `id` sudah ada milik user yang sama → kembalikan 200 dengan data yang ada (idempoten).

#### `POST /focus-sessions`
```json
{
  "id": "e9a0c0de-0000-0000-0000-000000000020",
  "scheduleId": null,
  "plannedSeconds": 1800,
  "actualSeconds": 1800,
  "status": "COMPLETED",
  "failReason": null,
  "startedAt": "2026-10-12T02:00:00Z",
  "endedAt": "2026-10-12T02:30:00Z"
}
```

### 7.4 Aturan Validasi Utama

| Field | Aturan |
|---|---|
| `courses.name` | 1–100 karakter |
| `courses.colorCode` | Regex `^#[0-9A-Fa-f]{6}$` |
| `slots[].dayOfWeek` | Integer 1–7; `startTime` < `endTime`, format `HH:mm` |
| `notes.title` | 1–150 karakter |
| `notes.content` | Maks 100.000 karakter |
| `focus.plannedSeconds` | 600–7200 |
| File RPS | PDF, ≤ 5 MB; dokumen: PDF/PPT/PPTX/TXT, ≤ 10 MB |

---

## 8. Kebutuhan Non-Fungsional

### 8.1 Performa
- Cold start aplikasi ≤ 3 detik pada perangkat menengah.
- Ekstraksi RPS ≤ 5 detik (PDF ≤ 5 MB); respons API umum ≤ 500 ms (tidak termasuk upload).
- Teks transkripsi muncul ≤ 2 detik setelah bicara.

### 8.2 Keamanan
- Verifikasi Firebase ID token di setiap request; kepemilikan data diverifikasi lewat `userId` dari token.
- `ValidationPipe` dengan `whitelist` dan `forbidNonWhitelisted`; DTO dengan `class-validator`.
- Rate limiting (`@nestjs/throttler`), terutama endpoint upload dan ekstraksi.
- `helmet`, CORS dibatasi, rahasia di `.env` (jangan di-commit), `firebase-admin` service account tidak masuk repositori.
- File upload: cek MIME + ekstensi + ukuran, nama file di-*rename* UUID, tidak dieksekusi, akses file butuh auth.
- HTTPS untuk lingkungan demo/produksi.

### 8.3 Privasi & Etika
- Transkrip suara adalah data pribadi: tampilkan penjelasan singkat penggunaan data saat pertama kali menyalakan mic.
- Ingatkan user untuk **meminta izin dosen** sebelum merekam kelas.
- Tidak menyimpan audio mentah pada MVP.
- Sediakan "Hapus akun & data" (selaras prinsip pelindungan data pribadi, mis. UU PDP No. 27/2022).

### 8.4 Keandalan & Offline
- Fitur inti (rekam, simpan draft, reminder, timer) berjalan tanpa internet.
- Tidak ada kehilangan data pada force close (draft tiap 15 detik).
- Semua operasi tulis dari client bersifat idempoten.

### 8.5 Kompatibilitas & Aksesibilitas
- Android 7.0 (API 24) ke atas; diuji minimal pada 2 perangkat (satu Android ≤ 12, satu Android ≥ 13).
- Ukuran teks mengikuti pengaturan sistem; kontras warna memadai; target sentuh ≥ 48 dp.
- Bahasa antarmuka: Indonesia (default); bahasa transkripsi: `id-ID` / `en-US`.

---

## 9. Izin & Konfigurasi Android

| Kebutuhan | Detail |
|---|---|
| `INTERNET` | Akses backend |
| `RECORD_AUDIO` | Voice transcription (izin runtime) |
| `POST_NOTIFICATIONS` | Android 13+ (izin runtime) |
| Exact alarm | `SCHEDULE_EXACT_ALARM` (Android 12–13, bisa dicabut user) / sesuaikan dengan kebijakan Android 14+ dan kebijakan distribusi yang dipakai |
| `RECEIVE_BOOT_COMPLETED` | Menjadwalkan ulang reminder setelah reboot |
| `WAKE_LOCK` / Foreground service | Menjaga timer fokus; di Android 14+ foreground service wajib mendeklarasikan tipe |
| `<queries>` untuk `android.speech.RecognitionService` | Agar `speech_to_text` dapat menemukan layanan suara (Android 11+) |
| Intent filter `ACTION_SEND` | Menerima share PDF/PPT/teks (P1) |
| Firebase | `google-services.json`, SHA-1/SHA-256 debug & release terdaftar |
| Screen Pinning | Kode Kotlin lewat MethodChannel (`startLockTask`, `stopLockTask`, `getLockTaskModeState`) |

---

## 10. Rencana Pengujian

### 10.1 Unit & Integrasi (Backend)
- **Parser RPS:** uji dengan ≥ 5 PDF RPS asli + beberapa kasus buatan (PDF kosong, scan, format berbeda) — target akurasi G3.
- **Auto-tag:** uji ≥ 20 teks contoh dengan label benar — target akurasi G2; sertakan kasus tanpa mata kuliah dan teks sangat pendek.
- **Perhitungan tanggal:** uji konversi WIB↔UTC, pergantian bulan, dan 16 pertemuan.
- **API e2e** (`supertest`): auth (token valid/tidak), kepemilikan data (user A tidak bisa membaca data user B), idempotensi `POST /notes`, batas ukuran file.

### 10.2 Uji di Perangkat (Manual)
| Skenario | Hasil yang diharapkan |
|---|---|
| Rekam 5 menit dengan jeda bicara | Teks tersambung, tidak hilang saat recognizer restart |
| Force close saat merekam | Draft dapat dilanjutkan |
| Mode pesawat → simpan catatan → online | Status Pending Sync → tersinkron, tidak ganda |
| Reminder 5 menit ke depan, aplikasi ditutup | Muncul tepat waktu |
| Reminder setelah reboot | Tetap muncul |
| Sesi fokus 10 menit, layar dimatikan di tengah | Timer akurat, sesi tercatat |
| Lepas pin di tengah sesi | Sesi `FAILED` dengan alasan benar |
| Share PDF dari WhatsApp (P1) | Aplikasi muncul di menu Share, dokumen tersimpan |

### 10.3 Uji Pengguna (Validasi untuk Juri)
- 5–10 mahasiswa mencoba skenario utama; catat waktu penyelesaian dan skor kepuasan singkat (skala 1–5).
- Bandingkan waktu input jadwal manual vs menggunakan RPS (Goal G1).
- Kumpulkan kutipan/umpan balik singkat untuk proposal.

---

## 11. Rencana Eksekusi (Sprint)

> **Status saat ini:** project backend NestJS sudah dibuat dan database PostgreSQL `saa` sudah dibuat di pgAdmin. ✅

Rencana lama (7 hari) tidak memuat auto-reminder, auto-tag, share intent, deploy backend, build APK, dan buffer. Berikut usulan baru (7 hari kerja + 2 hari aset lomba/cadangan). **Sesuaikan dengan tanggal deadline sebenarnya**; jika deadline lebih pendek, potong P1 lebih dulu.

| Hari | Fokus | Output |
|---|---|---|
| **0 (selesai)** | Inisialisasi backend NestJS & DB `saa` | ✅ |
| **1** | Backend: Prisma schema (Bagian 6.3) + migrasi, PrismaModule, Firebase AuthGuard, `GET /me`, CRUD Courses + slots, Swagger, `GET /health`, global filter/response wrapper | Auth + Courses berjalan di Swagger |
| **2** | Backend: Schedules (CRUD + bulk), Notes (CRUD + `suggest-course`), Focus sessions, Multer; **Parser RPS + unit test dengan sampel RPS**; algoritma auto-tag | Semua endpoint P0 lulus uji |
| **3** | Frontend: setup Flutter, Firebase Google Sign-In, API client (dio + interceptor token), Beranda, daftar & form Mata Kuliah (+ slot jam) | Login → buat mata kuliah dari aplikasi |
| **4** | Frontend: Upload RPS, layar Review, simpan jadwal, daftar jadwal, **Auto Reminder** (izin + penjadwalan) | RPS → jadwal → reminder muncul |
| **5** | Frontend: Voice transcription (restart loop), auto-save draft, simpan catatan, bottom sheet Auto-Tag, daftar catatan | Rekam → saran mata kuliah → catatan tersimpan |
| **6** | Frontend: Timer Fokus + Screen Pinning (Kotlin) + panduan pre-flight, kirim sesi ke API; (P1) Share intent bila waktu ada | Sesi fokus end-to-end |
| **7** | **Deploy backend** (hosting dengan URL HTTPS), build APK release, E2E di perangkat nyata (2 perangkat), perbaiki bug fatal, data demo (mata kuliah + RPS siap pakai) | APK + backend publik stabil |
| **8** | Rekam demo (screen recording), voice over & editing video, uji pengguna singkat | Video demo |
| **9 (buffer)** | Proposal final, perbaikan terakhir, submit proposal & tautan video | Pengumpulan |

**Aturan kerja:** hentikan penambahan fitur pada Hari 7; Hari 8–9 hanya perbaikan bug dan aset lomba.

---

## 12. Risiko & Mitigasi

| Risiko | Kemungkinan | Dampak | Mitigasi |
|---|---|---|---|
| Format RPS beragam → regex gagal | Tinggi | Tinggi | Parser bertingkat, uji ≥ 5 RPS, layar review wajib, input manual sebagai jalan keluar; LLM fallback (P2) |
| Speech recognizer berhenti saat jeda bicara / bunyi beep | Tinggi | Sedang | Restart loop, auto-save, ekspektasi sesi pendek, uji di perangkat nyata |
| Screen Pinning berbeda antar perangkat/OEM | Sedang | Tinggi | Pre-flight check, deteksi state, fallback DND/mode sukarela, uji ≥ 2 perangkat |
| Reminder tidak muncul di OEM tertentu | Sedang | Sedang | Panduan optimasi baterai, exact alarm, uji reboot |
| Google Sign-In gagal di APK release (SHA-1) | Sedang | Tinggi | Daftarkan SHA release di Firebase sejak awal; uji APK release di Hari 7 |
| Backend demo tidak bisa diakses juri | Sedang | Tinggi | Deploy publik lebih awal (Hari 7), siapkan akun demo dan data demo, siapkan video sebagai cadangan |
| Terlalu banyak fitur, waktu habis | Tinggi | Tinggi | Prioritas P0/P1/P2 dan cut line (Bagian 2) |
| Isu privasi saat merekam kelas | Rendah | Sedang | Notifikasi izin dosen, tanpa audio mentah, fitur hapus data |
| Paket Flutter tidak terawat (mis. share intent) | Sedang | Rendah | Cek pub.dev sebelum dipakai; siapkan alternatif; fitur P1 |

---

## 13. Skenario Demo & Aset Lomba

### 13.1 Skenario Demo (target 3–4 menit)
1. **Masalah (20 dtk):** dosen cepat, RPS PDF, notifikasi mengganggu.
2. **Login & tambah mata kuliah (20 dtk).**
3. **Upload RPS → review → simpan jadwal (45 dtk)** — tunjukkan 16 pertemuan terbentuk dan reminder terpasang.
4. **Rekam penjelasan → saran mata kuliah → simpan (60 dtk).**
5. **Mulai fokus → layar terkunci → selesai/gagal (45 dtk).**
6. **Penutup (20 dtk):** hasil validasi pengguna (waktu hemat, kepuasan), roadmap (ringkasan AI, OCR).

### 13.2 Aset yang Perlu Disiapkan
> Sesuaikan dengan panduan resmi (guidebook) IconFest — format proposal, batas durasi video, dan kriteria penilaian.

- Proposal (masalah, solusi, arsitektur, hasil uji, rencana pengembangan).
- Video demo + voice over.
- APK dan/atau tautan repositori sesuai ketentuan.
- Data demo: akun, mata kuliah, dan 1–2 RPS contoh yang terbukti terekstrak baik.

---

## 14. Pertanyaan Terbuka (Perlu Dikonfirmasi)

1. Tanggal pasti deadline dan tahapan lomba (proposal, video, final/presentasi)?
2. Apa kriteria penilaian di guidebook (inovasi, kelayakan teknis, dampak, UI)? Apakah ada unsur AI yang dinilai khusus?
3. Berapa anggota tim dan pembagian peran (backend / Flutter / desain / video)?
4. Perangkat Android apa saja yang tersedia untuk uji (merek dan versi Android)?
5. Di mana backend akan di-host untuk demo (VPS, Railway, Render, dsb.)?
6. Sumber RPS contoh: dari prodi/kampus mana, dan apakah boleh dipakai sebagai data uji?
7. Apakah aplikasi hanya untuk mahasiswa UNSIL/Polindra atau lintas kampus (menentukan fitur "universitas" dan format RPS yang harus didukung)?

---

## 15. Riwayat Perubahan

| Versi | Perubahan |
|---|---|
| 3.0 | Spesifikasi awal (fitur, skema dasar, 2 endpoint, sprint 7 hari) |
| 4.0 | Tambah goals/persona/metrik, prioritas, Modul 0, algoritma auto-tag, parser RPS bertingkat, `course_slots`, aturan zona waktu, strategi offline-sync, spesifikasi screen pinning & reminder Android, skema DB lengkap + Prisma, daftar API lengkap, NFR, rencana uji, risiko, sprint baru, skenario demo |