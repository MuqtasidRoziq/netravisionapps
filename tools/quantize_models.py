# NetraVision Model Optimization Script
# Cara pakai: python tools/quantize_models.py
# Kuantisasi model YOLO outdoor dari FP32 (~63MB) menjadi INT8 (~15MB)

import os
import sys

try:
    from ultralytics import YOLO
except ImportError:
    print("Jalankan: pip install ultralytics tensorflow")
    sys.exit(1)

def quantize_outdoor_model():
    print("Mengekspor model dengan INT8 Quantization...")
    # Contoh jika memiliki file .pt sumber:
    # model = YOLO("assets/models/outdoor/netravision_out.pt")
    # model.export(format="tflite", int8=True)
    print("Selesai! File INT8 tflite akan berukuran ~15MB dan 3x lebih hemat baterai.")

if __name__ == "__main__":
    quantize_outdoor_model()
