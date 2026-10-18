CATATAN PRAKTIKUM 5: IMPLEMENTASI SAST DENGAN JENKINS DAN SONARQUBE

1. ENVIRONMENT DAN KONFIGURASI UTAMA

Praktikum menggunakan Fedora Linux sebagai sistem operasi utama. Jenkins dan SonarQube dijalankan menggunakan Docker container. Jenkins digunakan sebagai CI/CD pipeline runner, sedangkan SonarQube digunakan untuk melakukan Static Application Security Testing (SAST) terhadap source code aplikasi MiniSOC.

Repository GitHub:
https://github.com/NickyFajaelani525/devsecops-p5-0110223045

Branch: main
Jenkins Job: MiniSOC-Praktikum5-SAST
SonarQube Project Key: Pipeline_SAST

Akses Jenkins:
http://localhost:8080

Akses SonarQube:
http://localhost:9000

Nama container Jenkins: jenkins
Nama container SonarQube: sonarqube

2. KONFIGURASI CONTAINER DOCKER DAN DOCKER SOCKET

Jenkins dijalankan menggunakan custom image bernama jenkins-dockercli:lts. Image ini dilengkapi Docker CLI agar Jenkins dapat menjalankan perintah Docker dari dalam pipeline.

Docker socket host dipasang ke container Jenkins melalui /var/run/docker.sock. Dengan konfigurasi ini, proses Jenkins dapat berkomunikasi dengan Docker daemon host untuk menjalankan container seperti python:3.12-slim dan sonarsource/sonar-scanner-cli.

Perlu diperhatikan bahwa akses ke Docker socket memberikan hak yang sangat besar terhadap Docker daemon host, sehingga konfigurasi ini perlu dibatasi dan diamankan pada lingkungan production.

Jenkins dan SonarQube terhubung melalui Docker network bernama sonarqube-net. Network ini memungkinkan Jenkins mengakses SonarQube menggunakan hostname container, yaitu http://sonarqube:9000, tanpa harus menggunakan localhost dari dalam container Jenkins.

3. WORKSPACE DAN VOLUME JENKINS

Jenkins menggunakan named volume Docker bernama jenkins_home yang dipasang pada direktori /var/jenkins_home di dalam container Jenkins.

Workspace job MiniSOC-Praktikum5-SAST berada pada path:

/var/jenkins_home/workspace/MiniSOC-Praktikum5-SAST

Pipeline menggunakan environment variable $WORKSPACE untuk merujuk ke direktori workspace aktif.

Pada stage Build & Test dan SonarQube SAST, container Docker dijalankan dengan mount:

-v jenkins_home:/var/jenkins_home

Dengan mount tersebut, container Python dan SonarScanner dapat mengakses source code serta file workspace Jenkins yang sama. Working directory container ditentukan menggunakan:

-w "$WORKSPACE"

Konfigurasi ini memungkinkan scanner membaca source code dari workspace Jenkins dan menyimpan hasil analisis ke direktori workspace yang dapat diakses Jenkins.

4. KONFIGURASI GITHUB DAN JENKINS PIPELINE

Jenkins job dikonfigurasi menggunakan Pipeline script from SCM. Repository menggunakan URL HTTPS GitHub, branch */main, dan Script Path Jenkinsfile.

Jenkins mengambil Jenkinsfile dan source code dari repository melalui Git plugin. Repository dapat diakses tanpa kredensial khusus pada konfigurasi yang digunakan karena checkout melalui HTTPS berhasil dilakukan.

Pipeline dijalankan secara manual menggunakan Build Now. Saat build dimulai, Jenkins melakukan Declarative Checkout SCM sebelum mengeksekusi stage yang didefinisikan dalam Jenkinsfile.

5. KONFIGURASI SONARQUBE DAN CREDENTIAL

Plugin SonarQube Scanner for Jenkins digunakan untuk mengintegrasikan Jenkins dengan SonarQube.

Pada konfigurasi global Jenkins, SonarQube server didaftarkan dengan nama:

SonarQube

Server URL:

http://sonarqube:9000

Token autentikasi SonarQube disimpan pada Jenkins Credentials sebagai Secret Text dengan ID:

sonar-token

Token tersebut tidak ditulis langsung ke Jenkinsfile. Pipeline menggunakan withSonarQubeEnv('SonarQube') untuk menyediakan konfigurasi server dan token autentikasi bagi proses analisis.

Di dalam container SonarScanner, informasi autentikasi diteruskan melalui environment variable SONAR_TOKEN, sedangkan URL server diberikan melalui SONAR_HOST_URL.

6. KONFIGURASI SONAR-PROJECT.PROPERTIES

File sonar-project.properties berada di root repository dan digunakan untuk menentukan konfigurasi analisis SonarQube.

Konfigurasi yang digunakan:

sonar.projectKey=Pipeline_SAST
sonar.sources=backend,frontend
sonar.sourceEncoding=UTF-8
sonar.exclusions=**/__pycache__/**,**/*.db,**/.venv/**

Dengan konfigurasi tersebut, SonarQube menganalisis source code pada direktori backend dan frontend. File bytecode Python, database, serta virtual environment dikecualikan dari analisis sesuai pola exclusions yang ditentukan.

7. STRUKTUR STAGE PIPELINE

Pipeline terdiri dari lima stage:

A. Clean Workspace

Menggunakan deleteDir() untuk menghapus isi workspace job sebelum checkout source code. Tujuannya menghindari sisa file dari build sebelumnya agar tidak mengganggu proses berikutnya.

B. Checkout SCM

Menggunakan checkout scm untuk mengambil source code dari repository GitHub berdasarkan konfigurasi SCM pada Jenkins job.

C. Build & Test

Menjalankan container python:3.12-slim dengan mount volume jenkins_home. Dependency Python dipasang menggunakan pip berdasarkan backend/requirements.txt, kemudian sintaks seluruh modul Python diperiksa menggunakan:

python -m compileall -q backend

Stage ini memeriksa dependency dan sintaks Python. Perintah compileall bukan pengganti unit test atau pengujian fungsional aplikasi.

D. SonarQube SAST

Menjalankan image sonarsource/sonar-scanner-cli pada Docker network sonarqube-net. Scanner membaca konfigurasi sonar-project.properties, melakukan analisis source code, dan mengirim hasil analisis ke server SonarQube.

Properti metadata scanner diarahkan ke root workspace menggunakan:

-Dsonar.scanner.metadataFilePath="$WORKSPACE/report-task.txt"

Properti tersebut harus menjadi argumen dari perintah docker run, bukan perintah shell terpisah. File report-task.txt berisi metadata task analisis yang dibutuhkan integrasi Quality Gate Jenkins.

E. Quality Gate

Menggunakan waitForQualityGate abortPipeline: true dengan timeout 10 menit. Jenkins menunggu hasil Quality Gate dari SonarQube. Jika hasilnya gagal, pipeline dihentikan. Integrasi ini memerlukan metadata task analisis yang dapat dibaca plugin dan webhook SonarQube yang mengarah ke endpoint Jenkins.

8. KONFIGURASI WEBHOOK SONARQUBE

Webhook dibuat pada SonarQube dengan nama:

Jenkins-Quality-Gate

URL webhook:

http://jenkins:8080/sonarqube-webhook/

Secret webhook dibiarkan kosong pada konfigurasi praktikum ini.

Webhook digunakan untuk mengirimkan hasil pemrosesan analisis dari SonarQube ke Jenkins sehingga waitForQualityGate dapat menerima status Quality Gate tanpa melakukan polling terus-menerus.

9. HASIL ANALISIS DAN QUALITY GATE

SonarQube berhasil menjalankan analisis terhadap source code MiniSOC dan mengirimkan hasil analisis ke server. Hasil dapat dilihat pada project Pipeline_SAST di dashboard SonarQube.

Quality Gate yang digunakan adalah Sonar way. Gate ini berfokus pada kondisi yang ditentukan untuk New Code. Oleh karena itu, status Passed tidak berarti seluruh source code bebas dari kerentanan.

Pada hasil praktikum, Overall Code menunjukkan tujuh temuan, sedangkan New Code menunjukkan nol issue. Pipeline tetap lolos karena kondisi Quality Gate yang diterapkan terpenuhi.

Overall Code menunjukkan temuan pada keseluruhan cakupan analisis, sedangkan New Code menunjukkan temuan pada kode yang dianggap baru berdasarkan definisi New Code project. Keduanya bukan metode scanning yang berbeda.

10. MASALAH PERMISSION WORKSPACE

Selama praktikum ditemukan masalah permission pada file hasil kompilasi Python di:

backend/__pycache__/

Error yang muncul antara lain:

Operation not permitted
Unable to delete workspace

Masalah terjadi ketika stage Clean Workspace menjalankan deleteDir(), tetapi Jenkins tidak dapat menghapus file tertentu dalam workspace.

Penanganan sementara yang digunakan sebelum menjalankan build adalah:

docker exec -u root jenkins sh -c \
'chown -R jenkins:jenkins /var/jenkins_home/workspace/MiniSOC-Praktikum5-SAST'

Perintah tersebut mengubah kepemilikan file dan direktori workspace job menjadi jenkins:jenkins agar Jenkins dapat menghapus file saat proses pembersihan workspace.

Solusi ini masih bersifat sementara dan perlu diperbaiki secara permanen setelah praktikum selesai. Dugaan penyebabnya adalah file dibuat oleh container Python dengan kepemilikan yang tidak sesuai dengan user Jenkins. Penyebab tersebut perlu dikonfirmasi dan ditangani melalui pengaturan user atau permission container yang tepat.

11. STATUS AKHIR PRAKTIKUM

Pipeline MiniSOC-Praktikum5-SAST telah berhasil dijalankan sampai seluruh stage berstatus hijau, termasuk SonarQube SAST dan Quality Gate.

Integrasi Jenkins dengan GitHub, Docker, SonarQube, credential, metadata analisis, dan webhook telah digunakan dalam pipeline.

Quality Gate yang Passed hanya menunjukkan bahwa kondisi gate yang aktif terpenuhi. Hasil tersebut bukan bukti bahwa seluruh source code bebas dari vulnerability.

