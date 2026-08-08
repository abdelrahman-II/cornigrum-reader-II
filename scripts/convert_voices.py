# لتحويل الاصوات الى ملف واحد كبير غير موصى به بسبب الحجم

# import os
# import json
# import numpy as np

# BIN_PATH = "assets/voices/voices-v1.0.bin"
# OUTPUT_JSON_PATH = "assets/voices/voices.json"

# def convert():
#     if not os.path.exists(BIN_PATH):
#         print(f"Error: {BIN_PATH} not found!")
#         exit(1)

#     print(f"Loading {BIN_PATH}...")
#     data = np.load(BIN_PATH)

#     # تحويل كافة الأصوات إلى Dictionary
#     all_voices = {k: v.tolist() for k, v in data.items()}

#     # إنشاء المجلد إذا لم يكن موجوداً
#     os.makedirs(os.path.dirname(OUTPUT_JSON_PATH), exist_ok=True)

#     print(f"Writing to {OUTPUT_JSON_PATH}...")
#     with open(OUTPUT_JSON_PATH, "w") as f:
#         json.dump(all_voices, f)

#     print("Conversion completed successfully!")

# if __name__ == "__main__":
#     convert()




import os
import json
import numpy as np

BIN_PATH = "assets/voices/voices-v1.0.bin"
OUTPUT_DIR = "assets/voices"
INDEX_PATH = os.path.join(OUTPUT_DIR, "index.json")

def convert_all_voices_separately():
    # 1. التأكد من وجود الملف المصدر
    if not os.path.exists(BIN_PATH):
        print(f"Error: {BIN_PATH} not found at {BIN_PATH}")
        return

    # 2. إنشاء مجلد المخرجات إن لم يكن موجوداً
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    print(f"Loading {BIN_PATH}...")
    data = np.load(BIN_PATH)

    index_data = []
    extracted_count = 0

    index_data.append({
        "id": "us_gold",
        "name": "us_gold",
        "file": "us_gold.json"
    })

    index_data.append({
        "id": "us_silver",
        "name": "us_silver",
        "file": "us_silver.json"
    })

    index_data.append({
        "id": "lexicon",
        "name": "lexicon",
        "file": "lexicon.json"
    })

    LIMIT = 3
    items_to_process = list(data.items())[:LIMIT]

    for key, value in items_to_process:
        voice_filename = f"{key}.json"
        output_path = os.path.join(OUTPUT_DIR, voice_filename)
        
        # التعديل هنا: جعل بيانات الصوت على شكل قاموس { "اسم_الصوت": [المصفوفة] }
        # ليناسب تماماً ما تتوقعه المكتبة عند قراءة أي ملف صوتي منفرد
        voice_data = {key: value.tolist()}
        
        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(voice_data, f)
            
        # إضافة عنصر الصوت إلى الفهرس
        index_data.append({
            "id": key,
            "name": key,
            "file": voice_filename
        })

        extracted_count += 1
        print(f"Extracted: {voice_filename}")

    # 4. إنشاء وتنسيق ملف index.json
    with open(INDEX_PATH, "w", encoding="utf-8") as f:
        json.dump(index_data, f, ensure_ascii=False, indent=2)

    print(f"\nIndex file generated successfully at: {INDEX_PATH}")
    print(f"Success! Total {extracted_count} voices extracted to '{OUTPUT_DIR}' directory.")

    if os.path.exists(BIN_PATH):
        os.remove(BIN_PATH)
        print(f"{BIN_PATH} Deleted.")
    else:
        print("الملف غير موجود.")

if __name__ == "__main__":
    convert_all_voices_separately()