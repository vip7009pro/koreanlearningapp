/// Generates prompts for external LLM use, matching the backend prompt quality.
/// These prompts include Course → Section → Lesson context for accurate content.
class PromptGenerator {
  /// Generate vocabulary prompt
  static String vocabulary({
    required String courseTitle,
    required String sectionTitle,
    required String lessonTitle,
    List<String> existingKorean = const [],
  }) {
    final existingBlock = existingKorean.isNotEmpty
        ? '\nKHÔNG ĐƯỢC tạo trùng (korean) với các từ đã tồn tại sau:\n${existingKorean.map((x) => '- $x').join('\n')}\n'
        : '';

    return '''Bạn là trợ lý tạo nội dung học tiếng Hàn cho người Việt. Chỉ trả về JSON hợp lệ, không giải thích, không markdown.

Hãy tạo danh sách 10-20 từ vựng MỚI cho bài học tiếng Hàn.

Ngữ cảnh:
- Course: "$courseTitle"
- Section: "$sectionTitle"
- Lesson: "$lessonTitle"
$existingBlock
YÊU CẦU JSON:
[
  {
    "korean": "안녕하세요",
    "vietnamese": "Xin chào",
    "pronunciation": "an-nyeong-ha-se-yo",
    "exampleSentence": "안녕하세요! 만나서 반갑습니다.",
    "exampleMeaning": "Xin chào! Rất vui được gặp bạn.",
    "difficulty": "EASY"
  }
]

Lưu ý: ví dụ câu nên ngắn, tự nhiên, liên quan chủ đề. difficulty: EASY/MEDIUM/HARD.
Chỉ trả về JSON array, không có text nào khác.''';
  }

  /// Generate grammar prompt
  static String grammar({
    required String courseTitle,
    required String sectionTitle,
    required String lessonTitle,
  }) {
    return '''Bạn là trợ lý tạo ngữ pháp tiếng Hàn cho người Việt. Chỉ trả về JSON hợp lệ, không giải thích, không markdown.

Hãy tạo 3-8 mục ngữ pháp cho bài học.

Ngữ cảnh:
- Course: "$courseTitle"
- Section: "$sectionTitle"
- Lesson: "$lessonTitle"

YÊU CẦU JSON:
[
  {
    "pattern": "N + 입니다",
    "explanationVN": "Là N (dùng để giới thiệu danh từ, thể lịch sự)",
    "example": "저는 학생입니다. (Tôi là học sinh.)"
  }
]

Chỉ trả về JSON array, không có text nào khác.''';
  }

  /// Generate dialogues prompt
  static String dialogues({
    required String courseTitle,
    required String sectionTitle,
    required String lessonTitle,
  }) {
    return '''Bạn là trợ lý tạo hội thoại tiếng Hàn cho người Việt. Chỉ trả về JSON hợp lệ, không giải thích, không markdown.

Hãy tạo hội thoại gồm 6-10 câu (lines) cho bài học.

Ngữ cảnh:
- Course: "$courseTitle"
- Section: "$sectionTitle"
- Lesson: "$lessonTitle"

YÊU CẦU JSON:
[
  {
    "speaker": "A",
    "koreanText": "안녕하세요!",
    "vietnameseText": "Xin chào!",
    "orderIndex": 0
  }
]

Lưu ý: orderIndex tăng dần từ 0. Hội thoại phải tự nhiên, phù hợp ngữ cảnh.
Chỉ trả về JSON array, không có text nào khác.''';
  }

  /// Generate quiz prompt
  static String quiz({
    required String courseTitle,
    required String sectionTitle,
    required String lessonTitle,
  }) {
    return '''Bạn là trợ lý tạo quiz tiếng Hàn cho người Việt. Chỉ trả về JSON hợp lệ, không giải thích, không markdown.

Hãy tạo 1 quiz cho bài học.

Ngữ cảnh:
- Course: "$courseTitle"
- Section: "$sectionTitle"
- Lesson: "$lessonTitle"

YÊU CẦU JSON:
[
  {
    "title": "Quiz: $lessonTitle",
    "quizType": "MULTIPLE_CHOICE",
    "questions": [
      {
        "questionType": "MULTIPLE_CHOICE",
        "questionText": "Câu hỏi?",
        "correctAnswer": "Đáp án đúng",
        "options": [
          {"text": "Đáp án đúng", "isCorrect": true},
          {"text": "Sai 1", "isCorrect": false},
          {"text": "Sai 2", "isCorrect": false},
          {"text": "Sai 3", "isCorrect": false}
        ]
      }
    ]
  }
]

Lưu ý: mỗi quiz nên có 5-10 câu hỏi, options tối thiểu 4 lựa chọn.
Chỉ trả về JSON array, không có text nào khác.''';
  }

  /// Generate TOPIK exam prompt
  static String topikExam({
    required String topikLevel,
    required int year,
    required String examTitle,
    required String status,
  }) {
    final lvl = topikLevel == 'TOPIK_I'
        ? 'TOPIK I (sơ cấp, 1-2급)'
        : 'TOPIK II (trung-cao cấp, 3-6급)';

    final isI = topikLevel == 'TOPIK_I';
    final totalQ = isI ? 70 : 104;
    final dur = isI ? 100 : 180;
    final sections = isI
        ? 'LISTENING (30 câu, 40 phút), READING (40 câu, 60 phút)'
        : 'LISTENING (50 câu, 60 phút), WRITING (4 câu, 50 phút), READING (50 câu, 70 phút)';

    final writingSection = isI
        ? ''
        : ''',
    {
      "type": "WRITING",
      "orderIndex": 2,
      "durationMinutes": 50,
      "maxScore": 100,
      "questions": [
        {
          "questionType": "SHORT_TEXT",
          "orderIndex": 1,
          "contentHtml": "Đề viết ngắn",
          "correctTextAnswer": "Đáp án mẫu",
          "scoreWeight": 1
        },
        {
          "questionType": "ESSAY",
          "orderIndex": 4,
          "contentHtml": "Hãy viết bài luận 200-300 chữ về chủ đề...",
          "scoreWeight": 4
        }
      ]
    }''';

    return '''Bạn là chuyên gia ra đề thi TOPIK (Kỳ thi năng lực tiếng Hàn). Bạn phải tạo nội dung giống đề TOPIK thật: tự nhiên, chuẩn phong cách thi, có bẫy hợp lý nhưng không mơ hồ.

QUY TẮC BẮT BUỘC:
1) Chỉ trả về JSON hợp lệ, KHÔNG markdown, KHÔNG giải thích.
2) contentHtml có thể là text thuần, nhưng phải là chuỗi (không được null).
3) Với câu MCQ: phải có đúng 4 lựa chọn, orderIndex tăng dần từ 1..4, đúng 1 lựa chọn isCorrect=true.
4) Với LISTENING: luôn tạo listeningScript bằng tiếng Hàn (có thể 1-3 câu) phù hợp với câu hỏi. audioUrl = null.
5) Với WRITING:
   - SHORT_TEXT: có correctTextAnswer (một đáp án mẫu ngắn).
   - ESSAY: không cần correctTextAnswer.
6) Ngôn ngữ: tiếng Hàn cho câu hỏi/nội dung nghe; có thể thêm tiếng Việt cho hướng dẫn.

Hãy tạo đề thi $lvl năm $year.
Cấu trúc: $sections
Tổng: $totalQ câu, $dur phút.

Trả về JSON theo format sau:

{
  "exam": {
    "title": "$examTitle",
    "topikLevel": "$topikLevel",
    "year": $year,
    "totalQuestions": $totalQ,
    "durationMinutes": $dur,
    "status": "$status"
  },
  "sections": [
    {
      "type": "LISTENING",
      "orderIndex": 1,
      "durationMinutes": ${isI ? 40 : 60},
      "maxScore": 100,
      "questions": [
        {
          "questionType": "MCQ",
          "orderIndex": 1,
          "contentHtml": "Nội dung câu hỏi",
          "audioUrl": null,
          "listeningScript": "대화/음성 내용 (tiếng Hàn)",
          "correctTextAnswer": null,
          "scoreWeight": 1,
          "explanation": "Giải thích đáp án",
          "choices": [
            {"orderIndex": 1, "content": "Đáp án 1", "isCorrect": false},
            {"orderIndex": 2, "content": "Đáp án 2", "isCorrect": true},
            {"orderIndex": 3, "content": "Đáp án 3", "isCorrect": false},
            {"orderIndex": 4, "content": "Đáp án 4", "isCorrect": false}
          ]
        }
      ]
    },
    {
      "type": "READING",
      "orderIndex": ${isI ? 2 : 3},
      "durationMinutes": ${isI ? 60 : 70},
      "maxScore": 100,
      "questions": [ ... tương tự MCQ ... ]
    }$writingSection
  ]
}

Hãy tạo đầy đủ số lượng câu hỏi theo quy định mỗi section. Chỉ trả về JSON, không có text nào khác.''';
  }
}
