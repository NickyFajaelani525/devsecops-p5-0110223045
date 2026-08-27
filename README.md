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


