# Kopi Tycoon

Game incremental (idle clicker) bertema kedai kopi, dibuat dengan **Godot Engine 4.7.2** (GDScript) untuk mata kuliah Workshop Game.

Mulai dari menyeduh kopi secara manual, rekrut barista, beli mesin espresso, hingga punya perkebunan kopi sendiri. Kafe akan terus berkembang dan pelanggan berdatangan seiring bisnismu tumbuh.

## Main di Browser

**▶ https://dans-vsa.github.io/kopi-tycoon/**

Langsung main tanpa install. Progres tersimpan otomatis di browser.

## Download & Main (Windows)

Unduh `KopiTycoon.rar` dari halaman [Releases](../../releases), ekstrak, lalu jalankan `KopiTycoon.exe`.
File `KopiTycoon.exe` dan `KopiTycoon.pck` harus berada di folder yang sama.

## Fitur

- Klik cangkir kopi untuk mendapatkan koin.
- 6 generator otomatis: Barista, Mesin Espresso, Gerobak Kopi, Kedai Kopi, Pabrik Roasting, Perkebunan Kopi.
- Tampilan kafe hidup: pelanggan datang membeli kopi, dan dekorasi kafe bertambah sesuai generator yang dimiliki.
- Sistem unlock: generator dan fitur baru terbuka bertahap.
- Upgrade Seduhan (nilai klik ×2 per level) dan Prestige (Biji Emas, +10% penghasilan permanen).
- Save otomatis dan penghasilan offline (maks. 8 jam).
- Efek suara dan musik latar, dengan tombol Suara ON/OFF.
- Tombol Reset Data (dengan konfirmasi) untuk memulai dari awal.

## Mekanik

| Mekanik | Rumus |
|---|---|
| Nilai klik | 2^level × multiplier |
| Harga generator | harga dasar × 1,15^jumlah dimiliki |
| Harga upgrade klik | 50 × 3^level |
| Biji Emas (prestige) | ⌊√(total koin / 1.000.000)⌋ |

## Struktur Project

```
project.godot
scenes/
  main.tscn          # scene utama (UI)
  cafe_view.tscn     # tampilan interior kafe
scripts/
  game_state.gd      # data & logika game (autoload)
  main.gd            # UI, unlock, dan efek
  cafe_view.gd       # pelanggan dan dekorasi kafe
assets/
  icons/  cafe/  audio/
```

## Menjalankan dari Source

1. Install [Godot Engine 4.7](https://godotengine.org/download).
2. Import `project.godot`, lalu tekan **F5**.

## Aset

Seluruh gambar (SVG) dan suara (WAV hasil sintesis) dibuat khusus untuk project ini, tanpa aset pihak ketiga.

---

Danish Vesa Bintang Parikesit — 235410036
