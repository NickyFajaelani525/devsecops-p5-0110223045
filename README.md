# MiniSOC — Incident Ticketing API

Aplikasi kecil untuk mencatat dan mengelola tiket insiden keamanan. Dipakai sebagai aplikasi
sample konsisten di sepanjang roadmap belajar DevSecOps — dari Dockerize (Minggu 2), pipeline
CI/CD (Minggu 3-4), deploy ke Kubernetes (Minggu 5-6), scanning SAST/DAST (Minggu 7), sampai
integrasi automated incident response dengan n8n (Minggu 9).

## Struktur

```
minisoc/
├── backend/          # FastAPI + SQLAlchemy
│   ├── main.py        # routes/endpoint
│   ├── models.py       # model database (User, Ticket)
│   ├── schemas.py      # validasi request/response (Pydantic)
│   ├── auth.py          # logic JWT & password hashing
│   ├── database.py       # koneksi DB (SQLite lokal, Postgres di production)
│   ├── requirements.txt
│   └── Dockerfile         # multi-stage build, non-root user
└── frontend/          # HTML/JS sederhana, tanpa build tool
    ├── index.html
    ├── app.js
    └── style.css
```

## Cara jalanin lokal (sebelum masuk Docker/Kubernetes)

**Backend:**
```bash
cd backend
python -m venv venv
source venv/bin/activate        # Windows: venv\Scripts\activate
pip install -r requirements.txt
uvicorn main:app --reload
```
Backend jalan di `http://localhost:8000`. Dokumentasi API otomatis ada di `http://localhost:8000/docs`.

**Frontend:**
Cukup buka `frontend/index.html` langsung di browser (double-click atau `open index.html`),
atau serve pakai server statis sederhana:
```bash
cd frontend
python -m http.server 3000
```
Buka `http://localhost:3000`.

## Cara jalanin pakai Docker (Minggu 2)

```bash
cd backend
docker build -t minisoc-backend .
docker run -p 8000:8000 minisoc-backend
```

## Alur pemakaian aplikasi

1. Register akun baru lewat form di frontend (atau `POST /auth/register`)
2. Login, dapetin JWT token
3. Buat/lihat/hapus ticket insiden lewat dashboard
4. Endpoint `POST /tickets` ini yang nanti dipanggil otomatis oleh workflow n8n di Minggu 9

## Environment variables (dipakai mulai Minggu 4 saat provisioning infra beneran)

| Variable | Default | Keterangan |
|---|---|---|
| `DATABASE_URL` | `sqlite:///./minisoc.db` | Ganti ke `postgresql://...` saat pakai RDS/Postgres di production |
| `JWT_SECRET_KEY` | `dev-only-change-me-in-production` | WAJIB diganti dan disimpan di Vault/AWS Secrets Manager (Minggu 6), jangan pernah di-commit ke Git |

## Catatan keamanan yang disengaja untuk bahan latihan

- `JWT_SECRET_KEY` punya default value yang jelas-jelas "tidak aman" — ini disengaja supaya
  Gitleaks/secret scanning (Minggu 3) punya sesuatu yang relevan untuk dicek, dan supaya kamu
  terbiasa selalu override environment variable ini di setiap environment (jangan pernah pakai default-nya).
- CORS dibuka untuk semua origin (`allow_origins=["*"]`) — ini best practice yang BURUK
  untuk production, sengaja dibiarkan supaya bisa ditemukan sebagai temuan saat SAST/security
  review (Minggu 7), dan kamu praktik memperbaikinya sendiri.
