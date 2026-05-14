// ============================================================
// truth-dare-data.js — DATA TRUTH OR DARE
// Edit file ini untuk menambah/mengubah pertanyaan dan tantangan
// ============================================================

const TRUTH_QUESTIONS = [
  // 🧠 Tentang Diri
  "Apa hal paling memalukan yang pernah kamu lakukan di depan umum?",
  "Apa kebohongan terbesar yang pernah kamu katakan?",
  "Apa hal yang paling kamu takuti dalam hidup?",
  "Siapa orang yang paling kamu kagumi dan mengapa?",
  "Apa rahasia terbesar yang belum pernah kamu ceritakan ke siapapun?",
  "Apa pencapaian terbesar yang kamu banggakan sejauh ini?",
  "Kalau bisa mengubah satu hal dari masa lalumu, apa itu?",
  "Apa kebiasaan buruk yang ingin kamu hilangkan?",
  "Hal apa yang selalu kamu tunda-tunda?",
  "Apa mimpi terbesar yang ingin kamu capai?",

  // 👥 Tentang Hubungan
  "Siapa orang di ruangan ini yang paling kamu kagumi?",
  "Pernah punya crush ke teman sendiri?",
  "Apa yang paling kamu tidak suka dari dirimu sendiri?",
  "Apakah kamu pernah membicarakan teman di belakang mereka?",
  "Apa yang akan kamu lakukan kalau punya superpower selama 1 hari?",
  "Siapa satu orang yang paling ingin kamu minta maaf?",
  "Apa hal konyol yang masih kamu percaya waktu kecil?",
  "Pernah pura-pura sakit untuk bolos? Ceritakan!",
  "Apa aplikasi yang paling banyak kamu pakai tapi malu diakui?",
  "Kalau hidupmu jadi film, judulnya apa?",

  // 🎭 Seru & Ringan
  "Kalau bisa tukar tubuh dengan seseorang selama sehari, siapa?",
  "Apa lagu yang sering kamu nyanyikan saat sendirian?",
  "Pernah jatuh cinta sama karakter fiksi? Siapa?",
  "Apa makanan yang kamu bilang tidak suka tapi sebetulnya suka?",
  "Kalau bisa tinggal di era mana, kapan kamu pilih?",
  "Apa hal paling konyol yang pernah kamu googling?",
  "Berapa lama rekor kamu tidak mandi?",
  "Pernah nangis gara-gara film/drakor/anime? Film apa?",
  "Apa talent tersembunyi yang jarang orang tahu?",
  "Kalau besok adalah hari terakhir hidupmu, kamu mau ngapain?",

  // 🤔 Filosofis
  "Apa definisi bahagia menurutmu?",
  "Apakah uang bisa membeli kebahagiaan? Jelaskan!",
  "Pilih: sukses tapi kesepian, atau biasa-biasa tapi banyak teman?",
  "Apa yang lebih penting: jujur atau baik hati?",
  "Kalau bisa ketemu versi dirimu 10 tahun lagi, apa yang mau kamu tanyakan?",
];

const DARE_CHALLENGES = [
  // 🎤 Perform
  "Nyanyikan chorus lagu favorit kamu dengan penuh semangat!",
  "Lakukan stand-up comedy 1 menit dengan tema bebas.",
  "Tiru gaya bicara dan gerakan karakter film favoritmu.",
  "Ceritakan lelucon, semua orang harus tertawa atau kamu ulangi!",
  "Nyanyikan lagu anak-anak dengan serius dan penuh penghayatan.",
  "Buat rap singkat tentang orang di sebelah kanan kamu.",
  "Tirukan iklan TV yang kamu ingat dengan totalitas.",
  "Berikan pidato singkat tentang kenapa kamu adalah orang paling keren.",

  // 🤸 Fisik & Aksi
  "Lakukan 15 jumping jack sekarang juga!",
  "Berjalan keliling ruangan dengan gaya model catwalk.",
  "Lakukan pose yoga selama 30 detik.",
  "Makan apapun yang ada di depanmu tanpa menggunakan tangan.",
  "Tukar sepatu dengan orang di sebelahmu selama 3 menit.",
  "Berdiri di atas satu kaki selama 1 menit penuh.",
  "Lakukan gerakan tarian bebas selama 1 menit tanpa berhenti.",
  "Coba sentuh ujung hidungmu dengan lidah!",

  // 💬 Sosial & Komunikasi
  "Kirim pesan ke orang di kontakmu yang jarang dihubungi.",
  "Bilang 'aku sayang kamu' ke semua orang di ruangan ini.",
  "Ceritakan sesuatu yang lucu yang pernah terjadi padamu.",
  "Buat status WA/IG yang ditentukan orang lain.",
  "Hubungi seseorang secara acak dan ucapkan 'kamu luar biasa!'",
  "Minta nomor HP seseorang di ruangan ini dengan cara paling kreatif.",
  "Buat kalimat puisi tentang orang yang ada di sebelahmu.",
  "Kirim voice note nyanyian ke salah satu kontakmu.",

  // 😄 Konyol & Lucu
  "Berbicara dengan aksen daerah yang beda selama 3 menit.",
  "Minum air putih tapi tidak boleh tertawa selama 1 menit.",
  "Jelaskan cara membuat mie instan seolah kamu chef bintang 5.",
  "Selfie dengan ekspresi paling aneh dan jadikan foto profil 5 menit.",
  "Peragakan bagaimana caramu berjalan waktu ngantuk.",
  "Tirukan suara 3 hewan berbeda berturut-turut.",
  "Buat jingle iklan untuk produk yang ada di sekitarmu.",
  "Makan makanan yang ada seperti sedang di restoran mewah.",

  // 🎯 Tantangan
  "Tebak pikiran orang di sebelahmu sekarang, ungkapkan dengan lantang!",
  "Berikan pujian tulus kepada setiap orang di ruangan satu per satu.",
  "Ceritakan hari pertamamu bertemu teman-teman di sini.",
  "Ungkapkan satu hal yang selama ini ingin kamu katakan ke seseorang.",
  "Buat resolusi hidup 1 tahun ke depan dan ucapkan keras-keras.",
  "Berikan motivasi ke semua orang di sini dalam 60 detik.",
];
