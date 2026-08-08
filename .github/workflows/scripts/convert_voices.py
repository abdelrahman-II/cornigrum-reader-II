import os
import json
import numpy as np

BIN_PATH = "assets/voices/voices-v1.0.bin"
OUTPUT_JSON_PATH = "assets/voices/voices.json"

def convert():
    if not os.path.exists(BIN_PATH):
        print(f"Error: {BIN_PATH} not found!")
        exit(1)

    print(f"Loading {BIN_PATH}...")
    data = np.load(BIN_PATH)

    # تحويل كافة الأصوات إلى Dictionary
    all_voices = {k: v.tolist() for k, v in data.items()}

    # إنشاء المجلد إذا لم يكن موجوداً
    os.makedirs(os.path.dirname(OUTPUT_JSON_PATH), exist_ok=True)

    print(f"Writing to {OUTPUT_JSON_PATH}...")
    with open(OUTPUT_JSON_PATH, "w") as f:
        json.dump(all_voices, f)

    print("Conversion completed successfully!")

if __name__ == "__main__":
    convert()