# MiniSOC — Incident Ticketing API

Minisoc merupakan projek mandiri yang saya kerjakan dimana ini merupakan aplikasi ticketing sederhana untuk SOC, tapi yang saya fokuskan disini adalah proses dari DevSecOps nya sendiri karena memang itu tujuan pembelajarannya, minisoc hanya sebagai bahan yang akan saya deploy menggunakan pendekataan DevSecOps.
Environment yang digunakan disini lokal semi-cloud, cloud yang saya gunakan yaitu azzure dengan fitur free tier for student.

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

## Hasil minggu 3 

## Iterasi 1

Stage: checkout + secret scan gitleaks (filesystem & git history)

```
1. Custom Jenkins Image
   - Menggunakan custom image: jenkins-dockercli:lts
   - Base dari Jenkins LTS.
   - Menambahkan Docker CLI ke dalam image Jenkins.
   - Jenkins tetap berjalan menggunakan user non-root: jenkins.
   - Tujuan:
     Jenkins dapat menjalankan perintah Docker seperti:
     docker run
     docker ps
     docker pull
     tanpa perlu menjalankan Jenkins sebagai root.

2. Jenkins User + Docker Group
   - User jenkins dimasukkan ke group docker.
   - Docker socket pada host:
     /var/run/docker.sock
   - Permission Docker socket:
     root:docker
   - Dengan memasukkan jenkins ke group docker, user jenkins dapat berkomunikasi dengan Docker Engine melalui Docker socket.
   - Jenkins tetap menggunakan user jenkins, bukan root.

3. Docker Socket
   - Docker socket host di-mount ke container Jenkins:
     /var/run/docker.sock:/var/run/docker.sock
   - Dengan kombinasi:
     Docker CLI + Docker socket + permission docker group
     Jenkins dapat menjalankan Docker Engine milik host.

4. Persistent Jenkins Volume
   - Tetap menggunakan volume yang sudah ada:
     jenkins_home
   - Tidak membuat volume baru ketika mengganti image Jenkins.
   - Data Jenkins tetap tersimpan, termasuk:
     - user/admin
     - konfigurasi Jenkins
     - credentials
     - plugins
     - jobs
     - workspace
   - Container Jenkins lama diganti dengan container baru menggunakan image custom,
     tetapi jenkins_home tetap digunakan.

5. Gitleaks sebagai Container
   - Gitleaks tidak di-install langsung ke container Jenkins.
   - Jenkins menjalankan Gitleaks menggunakan:
     docker run
   - Pendekatan ini menjaga Jenkins image tetap immutable dan tools security scanner terisolasi.

6. Mount Jenkins Volume ke Gitleaks
   - Gitleaks container diberi akses ke volume:
     jenkins_home
   - Contoh:
     -v jenkins_home:/jenkins_home
   - Tujuannya agar container Gitleaks dapat membaca workspace Jenkins.

7. Filesystem Secret Scan
   - Gitleaks menggunakan command:
     gitleaks dir
   - Scan dilakukan terhadap filesystem repository yang sudah di-checkout oleh Jenkins.
   - Dengan demikian Gitleaks memeriksa file yang sedang ada di repository.
   - Contoh file saat awal:
     Jenkinsfile
     README.md
   - File source code yang ditambahkan kemudian juga otomatis ikut diperiksa.

8. Git History Secret Scan
   - Ditambahkan scan kedua menggunakan:
     gitleaks git
   - Scan dilakukan terhadap Git repository dan commit history.
   - Tujuannya mendeteksi secret yang pernah masuk ke commit walaupun pada commit berikutnya secret tersebut sudah dihapus dari source code.

9. Dua Report Terpisah
   - Filesystem scan menghasilkan:
     gitleaks-filesystem.json
   - Git history scan menghasilkan:
     gitleaks-history.json
   - Report dipisahkan agar hasil filesystem scan dan Git history scan dapat dibedakan.

10. Secret Redaction
    - Gitleaks menggunakan:
      --redact
    - Secret yang ditemukan tidak ditampilkan secara langsung di report.
    - Report tetap memberikan informasi seperti file/path dan rule yang terdeteksi.
    - Tujuannya mencegah artifact Jenkins menjadi tempat baru bocornya credential.

11. Exit Code Gitleaks
    - Menggunakan:
      --exit-code 1
    - Jika Gitleaks menemukan secret:
      exit code = 1
    - Jenkins kemudian menganggap scan tersebut gagal.

12. catchError
    - Kedua scan dibungkus dengan:
      catchError(
          buildResult: 'FAILURE',
          stageResult: 'FAILURE'
      )
    - Tujuannya agar failure pada Filesystem Scan tidak langsung menghentikan pipeline.
    - Dengan demikian Git History Scan tetap dijalankan.
    - Jika salah satu atau kedua scan menemukan secret, overall build tetap:
      FAILURE

13. Artifact Report
    - Report Gitleaks di-archive sebagai Jenkins artifact.
    - Pattern:
      gitleaks-*.json
    - Dengan demikian hasil scan dapat dilihat kembali dari Jenkins setelah build selesai.

14. Testing yang Sudah Dilakukan

    Positive test:
    - Repository tanpa secret.
    - Filesystem scan:
      no leaks found
    - Git history scan:
      no leaks found
    - Build:
      SUCCESS

    Negative test:
    - Secret/API key dummy dimasukkan ke repository.
    - Filesystem scan:
      leaks found
    - Git history scan:
      leaks found
    - Build:
      FAILURE

    History test:
    - Secret pernah dimasukkan ke commit.
    - Secret kemudian dihapus pada commit berikutnya.
    - Git history tetap mendeteksi secret tersebut.
    - Hal ini membuktikan fungsi Git history scanning.
    
    Cleaning History:
    - Git history rewrite
    - Secret replacement (text-replacement)
    - Tools : git-filter-repo

STRUKTUR PIPELINE SAAT INI:

GitHub Repository
        |
        v
Jenkins Checkout
        |
        +--------------------------+
        |                          |
        v                          v
Filesystem Scan              Git History Scan
gitleaks dir                 gitleaks git
        |                          |
        v                          v
gitleaks-filesystem.json     gitleaks-history.json
        |                          |
        +------------+-------------+
                     |
                     v
             Secret ditemukan?
                /         \
              YES          NO
               |            |
               v            v
          BUILD FAILURE  BUILD SUCCESS


```

## Iterasi 2 

Setup Azure identity & ACR : tambah stage Build Image + Push to ACR.

```
1. Azure Identity — Service Principal jenkins-ci
   - Dibuat via App Registration di Azure Entra ID.
   - Role: Contributor
   - Scope: dibatasi ke 1 resource group (rg-devsecops-journey), bukan
     seluruh subscription.
   - Prinsip least-privilege: kalau credential ini bocor, blast radius
     terbatas hanya ke resource group ini.
   - 3 nilai yang dihasilkan: Application (client) ID, Directory (tenant) ID,
     Client Secret.

2. Region Constraint — Azure for Students
   - Subscription Azure for Students dibatasi ke region tertentu via Azure
     Policy (allowed locations), berbeda dari region bebas pada subscription
     pay-as-you-go biasa.
   - Region yang diizinkan untuk akun ini: indonesiacentral, eastasia,
     malaysiawest, koreacentral, japaneast.
   - Semua resource (resource group, ACR) dibuat di region: indonesiacentral
     — selain memenuhi policy, juga region terdekat secara fisik.

3. Azure Container Registry (ACR)
   - Tier: Basic (cukup untuk kebutuhan project, tidak butuh replikasi
     multi-region).
   - Role Assignment Permissions Mode: RBAC Registry Permissions (bukan
     RBAC + ABAC) — dipilih karena role legacy seperti AcrPush tidak
     berlaku di mode ABAC-enabled, dan skala project ini tidak butuh
     permission per-repository.
   - Domain Name Label Scope: Tenant Reuse — DNS name registry mendapat
     hash unik berbasis tenant, mencegah subdomain takeover jika nama
     registry pernah dilepas di masa depan.

4. Role Assignment ke jenkins-ci
   - Contributor di level resource group SUDAH mencakup akses push/pull
     ke ACR yang ada di dalam resource group yang sama.
   - Assignment AcrPush terpisah di level ACR sempat ditambahkan tapi
     ternyata redundant — dihapus karena Contributor di resource group
     sudah cukup.
   - Pelajaran: cek dulu scope existing sebelum menambah role assignment
     baru, supaya tidak menambah permukaan izin tanpa manfaat nyata.

5. Kredensial Azure di Jenkins
   - Disimpan sebagai 3 Jenkins Secret text terpisah (bukan 1 credential
     tipe Azure Service Principal, karena tidak pakai plugin tambahan):
     azure-client-id
     azure-client-secret
     azure-tenant-id (belum dipakai di stage push, hanya client-id/secret
     yang dibutuhkan untuk docker login ke ACR)
   - ID credential Jenkins (azure-client-id, dst) adalah nama referensi
     yang direferensikan di Jenkinsfile lewat `credentialsId:` — bukan
     value UUID Azure asli. Value asli tersimpan di Jenkins Credentials
     Store, tidak pernah ditulis langsung di Jenkinsfile.

6. Masalah DooD (Docker-outside-of-Docker) — Path Translation untuk Build
   - Jenkins container mount docker.sock dari HOST, sehingga command
     "docker run -v <path>" (dipakai di stage Gitleaks) di-resolve oleh
     daemon HOST, bukan filesystem container Jenkins.
   - Solusi (dipakai juga di Iterasi 1): mount named volume jenkins_home
     langsung ke container terkait, translasi path manual:
     SCAN_PATH="${WORKSPACE#/var/jenkins_home}"
     GITLEAKS_PATH="/jenkins_home${SCAN_PATH}"

7. Koreksi Penting — docker build TIDAK Butuh Path Translation
   - Berbeda dari docker run -v, docker build TIDAK butuh translasi path.
   - CLI docker build berjalan LANGSUNG di dalam container Jenkins, dan
     membaca build context dari sudut pandang filesystem-nya sendiri
     ($WORKSPACE) sebelum dikirim ke daemon host — tidak ada container
     perantara yang butuh volume mount di-translate.
   - Memakai path hasil translasi (/jenkins_home/...) untuk build context
     menyebabkan error: "path not found".
   - Stage yang benar:
     sh 'docker build -t ${IMAGE_NAME}:${IMAGE_TAG} "${WORKSPACE}/backend"'

8. Image Tagging Strategy
   - IMAGE_TAG di-generate dari: git rev-parse --short HEAD
   - Tiap commit menghasilkan tag unik dan immutable — tidak pernah pakai
     tag "latest".
   - Konsekuensi: tiap pipeline run dengan commit baru akan menghasilkan
     image baru di ACR (menambah, bukan menimpa). Docker layer caching
     membuat build kedua dst lebih cepat dari build pertama, selama
     requirements.txt/base image tidak ikut berubah.

9. Push Stage
   - Login: docker login $ACR_NAME -u $AZ_CLIENT_ID --password-stdin
     (client-id sebagai username, client-secret sebagai password,
     --password-stdin dipakai agar secret tidak muncul di process list)
   - Lanjut: docker tag, lalu docker push

10. Hasil
    - Pipeline run terkonfirmasi SUCCESS.
    - Image berhasil di-build dan di-push ke login server:
      acrminisoc2026nick-e6cdh0h4dthegjg0.azurecr.io
    - Suffix random pada nama tersebut adalah bukti nyata dari pilihan
      Domain Name Label Scope: Tenant Reuse.

11. Catatan Forward-Looking (Belum Diimplementasi)
    - Image di ACR akan terus bertambah karena tiap commit baru
      menghasilkan tag baru yang immutable.
    - Retention policy adalah pertimbangan untuk direvisit sekitar
      Minggu 8 (policy as code) atau Minggu 10 (capstone) — belum
      diperlukan di skala project saat ini.

STRUKTUR PIPELINE SAAT INI (ITERASI 1 + 2):

Host (Fedora)
│
├── Docker Engine
│
├── Docker Socket
│      └── /var/run/docker.sock
│
└── Jenkins Container
       │
       ├── Image: jenkins-dockercli:lts
       ├── User: jenkins (non-root)
       ├── docker group
       ├── Docker CLI
       ├── Docker Socket
       │
       ├── Jenkins Credentials Store
       │      ├── github-minisoc        (PAT, Username with password)
       │      ├── azure-client-id       (Secret text)
       │      ├── azure-client-secret   (Secret text)
       │      └── azure-tenant-id       (Secret text)
       │
       └── jenkins_home
              │
              └── workspace/minisoc-pipeline
                     │
                     ├── .git
                     │    └── Git commit history
                     │
                     ├── Jenkinsfile
                     ├── README.md
                     │
                     ├── backend/
                     │    ├── Dockerfile        (multi-stage: builder → runtime)
                     │    ├── main.py, auth.py, dst
                     │    └── requirements.txt
                     │
                     └── gitleaks/
                          └── secret.txt        (dummy, sengaja dipertahankan)
                     │
                     ↓
              ┌──────────────┐
              │   Checkout   │
              └──────┬───────┘
                     │
                     ↓
              Gitleaks Container
              (docker run -v jenkins_home)
                     │
          ┌──────────┴──────────┐
          ↓                     ↓
   ┌──────────────┐     ┌──────────────┐
   │ Secret Scan  │     │ Secret Scan  │
   │ - Filesystem │     │ - Git History│
   │ (gitleaks dir)│    │ (gitleaks git)│
   └──────┬───────┘     └──────┬───────┘
          ↓                     ↓
  gitleaks-filesystem.json  gitleaks-history.json
          │                     │
          └──────────┬──────────┘
                      ↓
              Secret ditemukan?
                /          \
              YES           NO
               │             │
               ↓             │
         BUILD FAILURE       │
                              ↓
                       ┌──────────────┐
                       │ Build Image  │
                       │ (docker build│
                       │  di HOST via │
                       │  docker.sock)│
                       └──────┬───────┘
                              │
                              ↓
                       Image tagged:
                  minisoc-backend:<commit-hash>
                              │
                              ↓
                       ┌──────────────┐
                       │  Push to ACR │
                       └──────┬───────┘
                              │
              ═══════════════════════════════
              Keluar dari Host, masuk ke Azure
              ═══════════════════════════════
                              │
                              ↓
                Azure Container Registry (ACR)
             acrminisoc2026nick******************.io
                              │
                              ├── Region: indonesiacentral
                              ├── SKU: Basic
                              ├── Domain Name Label Scope: Tenant Reuse
                              ├── Role Assignment Mode: RBAC Registry Permissions
                              │
                              └── Repository: minisoc-backend
                                     └── Tag: <commit-hash> (immutable)
                              │
                              ↓
                       BUILD SUCCESS

```

