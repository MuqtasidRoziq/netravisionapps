#!/usr/bin/env python3
"""Lokalkan `names` pada metadata Ultralytics di dalam file .tflite.

Plugin `ultralytics_yolo` membaca metadata dari ZIP yang ditempelkan di ekor
file .tflite (entry `metadata.json`). Model Ultralytics umumnya sudah membawa
metadata ini, tetapi `names`-nya berbahasa Inggris (mis. "car", "curb").
Aplikasi NetraVision bekerja dengan label Bahasa Indonesia (lihat
`labels.txt` dan `ObjectSpeechHelper`), jadi skrip ini mengganti `names`
dengan terjemahan dari `labels.txt` sambil MEMPERTAHANKAN field metadata lain
(description, task, stride, imgsz, channels, end2end, dll).

Sumber byte "bersih" diprioritaskan dari `<file>.orig` bila ada (cadangan
pristine tanpa ZIP tempelan); jika tidak ada, ZIP lama di ekor dilepas dulu.

Pemakaian:
    python3 tools/append_metadata.py
"""

from __future__ import annotations

import json
import zipfile
from io import BytesIO
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

# (file .tflite, file labels, task) — urutan baris labels.txt = urutan class index.
TARGETS = [
    (
        REPO_ROOT / "assets/models/rupiah/rupiah.tflite",
        REPO_ROOT / "assets/models/rupiah/labels.txt",
        "detect",
    ),
    (
        REPO_ROOT / "assets/models/outdoor/netravision_out.tflite",
        REPO_ROOT / "assets/models/outdoor/labels.txt",
        "segment",
    ),
    (
        REPO_ROOT / "assets/models/indoor/indoor_objects.tflite",
        REPO_ROOT / "assets/models/indoor/labels.txt",
        "detect",
    ),
]

METADATA_ENTRY = "metadata.json"
PK_HEADER = b"PK\x03\x04"
TAIL_SEARCH = 128 * 1024  # cukup lebar; plugin mencari 64KB+256 di ekor


def read_labels(labels_path: Path) -> list[str]:
    labels = [line.strip() for line in labels_path.read_text(encoding="utf-8").splitlines()]
    return [label for label in labels if label]


def split_appended_zip(data: bytes) -> tuple[bytes, dict | None]:
    """Pisahkan byte model bersih dari ZIP metadata di ekor.

    Mengembalikan (base_bytes, metadata_dict|None). Kandidat offset = kemunculan
    terakhir `PK\\x03\\x04` di ekor; hanya dianggap ZIP tempelan bila bisa dibuka
    dan memuat `metadata.json`, sehingga byte `PK` di dalam bobot tidak salah.
    """
    search_from = max(0, len(data) - TAIL_SEARCH)
    idx = data.rfind(PK_HEADER, search_from)
    while idx != -1:
        try:
            with zipfile.ZipFile(BytesIO(data[idx:])) as zf:
                if METADATA_ENTRY in zf.namelist():
                    metadata = json.loads(zf.read(METADATA_ENTRY))
                    return data[:idx], metadata
        except (zipfile.BadZipFile, json.JSONDecodeError):
            pass
        idx = data.rfind(PK_HEADER, search_from, idx)
    return data, None


def build_zip(base: bytes, metadata: dict) -> bytes:
    buf = BytesIO()
    buf.write(base)
    with zipfile.ZipFile(buf, mode="w", compression=zipfile.ZIP_DEFLATED) as zf:
        info = zipfile.ZipInfo(METADATA_ENTRY)
        info.date_time = (2026, 1, 1, 0, 0, 0)  # stempel tetap agar byte reproduksibel
        zf.writestr(info, json.dumps(metadata, ensure_ascii=False))
    return buf.getvalue()


def localize(tflite_path: Path, labels_path: Path, task: str) -> None:
    labels = read_labels(labels_path)
    if not labels:
        raise SystemExit(f"labels kosong: {labels_path}")

    # Sumber bersih: pakai .orig bila ada, jika tidak lepas ZIP dari file saat ini.
    orig_path = tflite_path.with_name(tflite_path.name + ".orig")
    source = orig_path if orig_path.exists() else tflite_path
    base, metadata = split_appended_zip(source.read_bytes())
    metadata = metadata or {}

    existing = metadata.get("names")
    existing_count = len(existing) if isinstance(existing, dict) else 0
    if existing_count and existing_count != len(labels):
        raise SystemExit(
            f"jumlah labels.txt ({len(labels)}) != names model ({existing_count}) "
            f"untuk {tflite_path.name}"
        )

    metadata["task"] = task
    metadata["names"] = {str(i): name for i, name in enumerate(labels)}

    tflite_path.write_bytes(build_zip(base, metadata))

    # Verifikasi: buka ulang ZIP di ekor dan baca metadata.json.
    with zipfile.ZipFile(BytesIO(tflite_path.read_bytes())) as zf:
        written = json.loads(zf.read(METADATA_ENTRY))
    assert written["names"] == metadata["names"], "names tidak konsisten setelah ditulis"

    src = "orig" if orig_path.exists() else "self"
    print(
        f"OK  {tflite_path.relative_to(REPO_ROOT)}  (sumber: {src})  "
        f"task={task}  kelas={len(labels)}  "
        f"[{labels[0]} .. {labels[-1]}]  "
        f"field={len(metadata)}"
    )


def main() -> None:
    for tflite_path, labels_path, task in TARGETS:
        if not tflite_path.exists():
            raise SystemExit(f"tidak ditemukan: {tflite_path}")
        localize(tflite_path, labels_path, task)


if __name__ == "__main__":
    main()
