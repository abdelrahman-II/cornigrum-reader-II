import 'dart:typed_data';

class Voice {
  final String id;
  final String name;
  final List<Float32List> styleVectors;
  final String languageCode;
  final String gender;
  
  // متغير مؤقت لحفظ المتوسط المحسوب مرة واحدة
  Float32List? _cachedMeanVector;

  Voice({
    required this.id,
    required this.name,
    required this.styleVectors,
    required this.languageCode,
    this.gender = 'neutral',
  });

  Float32List getStyleVectorForTokens(int tokenLength) {
    // تجاهل tokenLength تماماً، واستخدم المتوسط الثابت
    _cachedMeanVector ??= _computeMeanVector();
    return _cachedMeanVector!;
  }

  Float32List _computeMeanVector() {
    const int requiredDimension = 256;
    final result = Float32List(requiredDimension);
    
    if (styleVectors.isEmpty) return result;

    // جمع جميع المتجهات عنصراً عنصراً
    for (final vec in styleVectors) {
      for (int i = 0; i < requiredDimension && i < vec.length; i++) {
        result[i] += vec[i];
      }
    }

    // قسمة الناتج على عدد المتجهات (حساب المتوسط)
    for (int i = 0; i < requiredDimension; i++) {
      result[i] = result[i] / styleVectors.length;
    }

    // (اختياري) يمكنك إضافة تطبيع L2 هنا إذا كان النموذج يتوقع ذلك،
    // لكن في Kokoro الأصلي لا تحتاج إليه عادةً لأن المتجهات مُجهزة مسبقاً.
    return result;
  }

  @override
  String toString() => 'Voice(id: $id, name: $name, lang: $languageCode, styles: ${styleVectors.length})';
}