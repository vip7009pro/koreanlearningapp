import { PrismaClient, UserRole, CourseLevel, Difficulty } from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Seeding database with MASSIVE data...');

  // Clean existing data
  await prisma.analyticsEvent.deleteMany();
  await prisma.userBadge.deleteMany();
  await prisma.dailyGoal.deleteMany();
  await prisma.userVocabularyReview.deleteMany();
  await prisma.aIWritingPractice.deleteMany();
  await prisma.userProgress.deleteMany();
  await prisma.option.deleteMany();
  await prisma.question.deleteMany();
  await prisma.quiz.deleteMany();
  await prisma.dialogue.deleteMany();
  await prisma.grammar.deleteMany();
  await prisma.vocabulary.deleteMany();
  await prisma.lesson.deleteMany();
  await prisma.section.deleteMany();
  await prisma.course.deleteMany();
  await prisma.subscription.deleteMany();
  await prisma.badge.deleteMany();
  await prisma.user.deleteMany();

  // Create badges
  await Promise.all([
    prisma.badge.create({ data: { name: 'Người mới bắt đầu', description: 'Đạt 100 XP', iconUrl: '🌱', requiredXP: 100 } }),
    prisma.badge.create({ data: { name: 'Học sinh chăm chỉ', description: 'Đạt 500 XP', iconUrl: '📚', requiredXP: 500 } }),
    prisma.badge.create({ data: { name: 'Siêu sao', description: 'Đạt 1000 XP', iconUrl: '⭐', requiredXP: 1000 } }),
    prisma.badge.create({ data: { name: 'Bậc thầy', description: 'Đạt 5000 XP', iconUrl: '🏆', requiredXP: 5000 } }),
    prisma.badge.create({ data: { name: 'Huyền thoại', description: 'Đạt 10000 XP', iconUrl: '👑', requiredXP: 10000 } }),
  ]);

  // Create admin
  const adminHash = await bcrypt.hash('Admin123!', 10);
  const admin = await prisma.user.create({
    data: {
      email: 'admin@koreanapp.com',
      passwordHash: adminHash,
      displayName: 'Admin',
      role: UserRole.ADMIN,
      totalXP: 0,
      streakDays: 0,
    },
  });

  // Create users
  const userHash = await bcrypt.hash('User123!', 10);
  const users = await Promise.all([
    prisma.user.create({
      data: { email: 'nguyen@example.com', passwordHash: userHash, displayName: 'Nguyễn Văn A', totalXP: 750, streakDays: 5 },
    }),
    prisma.user.create({
      data: { email: 'tran@example.com', passwordHash: userHash, displayName: 'Trần Thị B', totalXP: 1200, streakDays: 12 },
    }),
    prisma.user.create({
      data: { email: 'le@example.com', passwordHash: userHash, displayName: 'Lê Minh C', totalXP: 300, streakDays: 2 },
    }),
  ]);

  // Create subscriptions
  await prisma.subscription.create({ data: { userId: admin.id, planType: 'LIFETIME', status: 'ACTIVE' } });
  await prisma.subscription.create({ data: { userId: users[0].id, planType: 'FREE', status: 'ACTIVE' } });
  await prisma.subscription.create({
    data: {
      userId: users[1].id,
      planType: 'PREMIUM',
      status: 'ACTIVE',
      endDate: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
    },
  });
  await prisma.subscription.create({ data: { userId: users[2].id, planType: 'FREE', status: 'ACTIVE' } });

  // Create Courses
  const course1 = await prisma.course.create({
    data: {
      title: 'Tiếng Hàn Cơ Bản cho Người Việt',
      description: 'Khóa học tiếng Hàn toàn diện từ con số 0. Học bảng chữ cái, phát âm chuẩn, giao tiếp cơ bản và ngữ pháp nền tảng.',
      level: CourseLevel.BEGINNER,
      isPremium: false,
      published: true,
    },
  });

  const course2 = await prisma.course.create({
    data: {
      title: 'Tiếng Hàn Công Sở (Ad-free)',
      description: 'Giao tiếp chuyên nghiệp trong môi trường doanh nghiệp Hàn Quốc. Viết email, báo cáo, thuyết trình và văn hóa công ty.',
      level: CourseLevel.INTERMEDIATE,
      isPremium: true,
      published: true,
    },
  });

  const course3 = await prisma.course.create({
    data: {
      title: 'Tiếng Hàn K-POP & Idol',
      description: 'Dành riêng cho fan K-Pop! Học từ vựng qua bài hát, show thực tế, cách fanchant và giao tiếp khi đu idol, đi concert.',
      level: CourseLevel.BEGINNER,
      isPremium: false,
      published: true,
    },
  });

  // ==========================================
  // COURSE 1: BASIC KOREAN FOR VIETNAMESE
  // ==========================================
  const c1_sec1 = await prisma.section.create({ data: { courseId: course1.id, title: 'Bảng chữ cái Hangul', orderIndex: 0 } });
  const c1_sec2 = await prisma.section.create({ data: { courseId: course1.id, title: 'Chủ đề: Bản thân & Gia đình', orderIndex: 1 } });
  const c1_sec3 = await prisma.section.create({ data: { courseId: course1.id, title: 'Mua sắm & Ăn uống', orderIndex: 2 } });
  const c1_sec4 = await prisma.section.create({ data: { courseId: course1.id, title: 'Thời gian & Sinh hoạt', orderIndex: 3 } });

  const c1_s1_l1 = await prisma.lesson.create({ data: { sectionId: c1_sec1.id, title: 'Nguyên âm đơn & Kép', description: '21 Nguyên âm trong tiếng Hàn', orderIndex: 0, estimatedMinutes: 20 } });
  const c1_s1_l2 = await prisma.lesson.create({ data: { sectionId: c1_sec1.id, title: 'Phụ âm đơn & Kép', description: '19 Phụ âm tiếng Hàn', orderIndex: 1, estimatedMinutes: 20 } });
  await prisma.lesson.create({ data: { sectionId: c1_sec1.id, title: 'Patchim (Phụ âm dưới)', description: 'Quy tắc đọc phụ âm cuối', orderIndex: 2, estimatedMinutes: 25 } });

  const c1_s2_l1 = await prisma.lesson.create({ data: { sectionId: c1_sec2.id, title: 'Xin chào & Tên Quốc gia', description: 'Cách chào hỏi và giới thiệu quốc tịch', orderIndex: 0, estimatedMinutes: 15 } });
  const c1_s2_l2 = await prisma.lesson.create({ data: { sectionId: c1_sec2.id, title: 'Nghề nghiệp', description: 'Từ vựng các ngành nghề', orderIndex: 1, estimatedMinutes: 15 } });
  const c1_s2_l3 = await prisma.lesson.create({ data: { sectionId: c1_sec2.id, title: 'Gia đình', description: 'Cách gọi các thành viên trong gia đình', orderIndex: 2, estimatedMinutes: 15 } });

  const c1_s3_l1 = await prisma.lesson.create({ data: { sectionId: c1_sec3.id, title: 'Số đếm thuần Hàn & Hán Hàn', description: 'Phân biệt 2 hệ số đếm', orderIndex: 0, estimatedMinutes: 30 } });
  const c1_s3_l2 = await prisma.lesson.create({ data: { sectionId: c1_sec3.id, title: 'Tại nhà hàng', description: 'Gọi món, tính tiền', orderIndex: 1, estimatedMinutes: 20 } });
  const c1_s3_l3 = await prisma.lesson.create({ data: { sectionId: c1_sec3.id, title: 'Mua sắm & Trả giá', description: 'Mặc cả quần áo, đồ đạc', orderIndex: 2, estimatedMinutes: 20 } });

  const c1_s4_l1 = await prisma.lesson.create({ data: { sectionId: c1_sec4.id, title: 'Giờ giấc & Ngày tháng', description: 'Nói về thời gian', orderIndex: 0, estimatedMinutes: 20 } });
  const c1_s4_l2 = await prisma.lesson.create({ data: { sectionId: c1_sec4.id, title: 'Hoạt động hàng ngày', description: 'Động từ sinh hoạt', orderIndex: 1, estimatedMinutes: 20 } });
  await prisma.lesson.create({ data: { sectionId: c1_sec4.id, title: 'Thời tiết & Các mùa', description: 'Mô tả thời tiết', orderIndex: 2, estimatedMinutes: 15 } });

  // Basic Vocab (Spread across lessons)
  const basicVocabs = [
    // Alphabets
    { lessonId: c1_s1_l1.id, korean: 'ㅏ', vietnamese: 'a', pronunciation: 'a', difficulty: Difficulty.EASY, exampleSentence: '아이', exampleMeaning: 'Trẻ em' },
    { lessonId: c1_s1_l1.id, korean: 'ㅓ', vietnamese: 'eo', pronunciation: 'eo', difficulty: Difficulty.EASY, exampleSentence: '어머니', exampleMeaning: 'Mẹ' },
    { lessonId: c1_s1_l1.id, korean: 'ㅗ', vietnamese: 'o', pronunciation: 'o', difficulty: Difficulty.EASY, exampleSentence: '오빠', exampleMeaning: 'Anh trai' },
    { lessonId: c1_s1_l1.id, korean: 'ㅜ', vietnamese: 'u', pronunciation: 'u', difficulty: Difficulty.EASY, exampleSentence: '우리', exampleMeaning: 'Chúng tôi' },
    { lessonId: c1_s1_l1.id, korean: 'ㅡ', vietnamese: 'eu', pronunciation: 'ư', difficulty: Difficulty.EASY, exampleSentence: '그것', exampleMeaning: 'Cái đó' },
    { lessonId: c1_s1_l1.id, korean: 'ㅣ', vietnamese: 'i', pronunciation: 'i', difficulty: Difficulty.EASY, exampleSentence: '이것', exampleMeaning: 'Cái này' },
    { lessonId: c1_s1_l1.id, korean: 'ㅐ', vietnamese: 'ae', pronunciation: 'e', difficulty: Difficulty.MEDIUM, exampleSentence: '개', exampleMeaning: 'Con chó' },
    { lessonId: c1_s1_l1.id, korean: 'ㅔ', vietnamese: 'e', pronunciation: 'e', difficulty: Difficulty.MEDIUM, exampleSentence: '네', exampleMeaning: 'Vâng' },
    { lessonId: c1_s1_l1.id, korean: 'ㅘ', vietnamese: 'wa', pronunciation: 'oa', difficulty: Difficulty.HARD, exampleSentence: '과일', exampleMeaning: 'Hoa quả' },
    { lessonId: c1_s1_l1.id, korean: 'ㅝ', vietnamese: 'wo', pronunciation: 'uo', difficulty: Difficulty.HARD, exampleSentence: '병원', exampleMeaning: 'Bệnh viện' },
    
    // Consonants
    { lessonId: c1_s1_l2.id, korean: 'ㄱ', vietnamese: 'g/k', pronunciation: 'giyeok', difficulty: Difficulty.EASY, exampleSentence: '가다', exampleMeaning: 'Đi' },
    { lessonId: c1_s1_l2.id, korean: 'ㄴ', vietnamese: 'n', pronunciation: 'nieun', difficulty: Difficulty.EASY, exampleSentence: '나', exampleMeaning: 'Tôi' },
    { lessonId: c1_s1_l2.id, korean: 'ㄷ', vietnamese: 'd/t', pronunciation: 'digeut', difficulty: Difficulty.EASY, exampleSentence: '다', exampleMeaning: 'Tất cả' },
    { lessonId: c1_s1_l2.id, korean: 'ㄹ', vietnamese: 'r/l', pronunciation: 'rieul', difficulty: Difficulty.MEDIUM, exampleSentence: '라면', exampleMeaning: 'Mì ramen' },
    { lessonId: c1_s1_l2.id, korean: 'ㅁ', vietnamese: 'm', pronunciation: 'mieum', difficulty: Difficulty.EASY, exampleSentence: '마음', exampleMeaning: 'Tâm trí' },
    { lessonId: c1_s1_l2.id, korean: 'ㅂ', vietnamese: 'b/p', pronunciation: 'bieup', difficulty: Difficulty.EASY, exampleSentence: '바다', exampleMeaning: 'Biển' },
    { lessonId: c1_s1_l2.id, korean: 'ㅅ', vietnamese: 's', pronunciation: 'siot', difficulty: Difficulty.EASY, exampleSentence: '사람', exampleMeaning: 'Con người' },
    { lessonId: c1_s1_l2.id, korean: 'ㅇ', vietnamese: 'ng/không', pronunciation: 'ieung', difficulty: Difficulty.MEDIUM, exampleSentence: '아이', exampleMeaning: 'Trẻ em' },
    { lessonId: c1_s1_l2.id, korean: 'ㅈ', vietnamese: 'j/ch', pronunciation: 'jieut', difficulty: Difficulty.EASY, exampleSentence: '자다', exampleMeaning: 'Ngủ' },
    { lessonId: c1_s1_l2.id, korean: 'ㅊ', vietnamese: 'ch', pronunciation: 'chieut', difficulty: Difficulty.MEDIUM, exampleSentence: '차', exampleMeaning: 'Xe / Trà' },
    { lessonId: c1_s1_l2.id, korean: 'ㅋ', vietnamese: 'kh', pronunciation: 'kieuk', difficulty: Difficulty.HARD, exampleSentence: '코', exampleMeaning: 'Mũi' },
    { lessonId: c1_s1_l2.id, korean: 'ㅌ', vietnamese: 'th', pronunciation: 'tieut', difficulty: Difficulty.HARD, exampleSentence: '타조', exampleMeaning: 'Đà điểu' },
    { lessonId: c1_s1_l2.id, korean: 'ㅍ', vietnamese: 'ph', pronunciation: 'pieup', difficulty: Difficulty.HARD, exampleSentence: '파도', exampleMeaning: 'Sóng biển' },
    { lessonId: c1_s1_l2.id, korean: 'ㅎ', vietnamese: 'h', pronunciation: 'hieut', difficulty: Difficulty.EASY, exampleSentence: '하늘', exampleMeaning: 'Bầu trời' },

    // Greetings
    { lessonId: c1_s2_l1.id, korean: '안녕하세요', vietnamese: 'Xin chào', pronunciation: 'an-nyeong-ha-se-yo', difficulty: Difficulty.EASY, exampleSentence: '안녕하세요, 잘 지내세요?', exampleMeaning: 'Xin chào, bạn khỏe không?' },
    { lessonId: c1_s2_l1.id, korean: '감사합니다', vietnamese: 'Cảm ơn', pronunciation: 'gam-sa-ham-ni-da', difficulty: Difficulty.EASY, exampleSentence: '도와주셔서 감사합니다', exampleMeaning: 'Cảm ơn vì đã giúp đỡ' },
    { lessonId: c1_s2_l1.id, korean: '죄송합니다', vietnamese: 'Xin lỗi', pronunciation: 'joe-song-ham-ni-da', difficulty: Difficulty.EASY, exampleSentence: '늦어서 죄송합니다', exampleMeaning: 'Xin lỗi vì đến muộn' },
    { lessonId: c1_s2_l1.id, korean: '베트남', vietnamese: 'Việt Nam', pronunciation: 'be-teu-nam', difficulty: Difficulty.EASY, exampleSentence: '저는 베트남 사람입니다', exampleMeaning: 'Tôi là người Việt Nam' },
    { lessonId: c1_s2_l1.id, korean: '한국', vietnamese: 'Hàn Quốc', pronunciation: 'han-guk', difficulty: Difficulty.EASY, exampleSentence: '한국에 가고 싶어요', exampleMeaning: 'Tôi muốn đi Hàn Quốc' },
    { lessonId: c1_s2_l1.id, korean: '미국', vietnamese: 'Mỹ', pronunciation: 'mi-guk', difficulty: Difficulty.EASY, exampleSentence: '미국 사람입니다', exampleMeaning: 'Là người Mỹ' },
    { lessonId: c1_s2_l1.id, korean: '이름', vietnamese: 'Tên', pronunciation: 'i-reum', difficulty: Difficulty.EASY, exampleSentence: '이름이 뭐예요?', exampleMeaning: 'Tên bạn là gì?' },

    // Jobs
    { lessonId: c1_s2_l2.id, korean: '학생', vietnamese: 'Học sinh', pronunciation: 'hak-saeng', difficulty: Difficulty.EASY, exampleSentence: '저는 학생입니다', exampleMeaning: 'Tôi là học sinh' },
    { lessonId: c1_s2_l2.id, korean: '선생님', vietnamese: 'Giáo viên', pronunciation: 'seon-saeng-nim', difficulty: Difficulty.EASY, exampleSentence: '우리 선생님입니다', exampleMeaning: 'Đây là giáo viên của chúng tôi' },
    { lessonId: c1_s2_l2.id, korean: '회사원', vietnamese: 'Nhân viên văn phòng', pronunciation: 'hoe-sa-won', difficulty: Difficulty.EASY, exampleSentence: '제 직업은 회사원이에요', exampleMeaning: 'Nghề của tôi là nhân viên văn phòng' },
    { lessonId: c1_s2_l2.id, korean: '의사', vietnamese: 'Bác sĩ', pronunciation: 'ui-sa', difficulty: Difficulty.MEDIUM, exampleSentence: '형은 의사입니다', exampleMeaning: 'Anh trai tôi là bác sĩ' },
    { lessonId: c1_s2_l2.id, korean: '요리사', vietnamese: 'Đầu bếp', pronunciation: 'yo-ri-sa', difficulty: Difficulty.MEDIUM, exampleSentence: '요리사가 꿈이에요', exampleMeaning: 'Ước mơ là đầu bếp' },

    // Family
    { lessonId: c1_s2_l3.id, korean: '가족', vietnamese: 'Gia đình', pronunciation: 'ga-jok', difficulty: Difficulty.EASY, exampleSentence: '가족이 몇 명이에요?', exampleMeaning: 'Gia đình có bao nhiêu người?' },
    { lessonId: c1_s2_l3.id, korean: '아버지', vietnamese: 'Bố', pronunciation: 'a-beo-ji', difficulty: Difficulty.EASY, exampleSentence: '아버지는 회사원입니다', exampleMeaning: 'Bố là nhân viên công ty' },
    { lessonId: c1_s2_l3.id, korean: '어머니', vietnamese: 'Mẹ', pronunciation: 'eo-meo-ni', difficulty: Difficulty.EASY, exampleSentence: '어머니는 요리를 잘해요', exampleMeaning: 'Mẹ nấu ăn ngon' },
    { lessonId: c1_s2_l3.id, korean: '오빠', vietnamese: 'Anh trai (em gái gọi)', pronunciation: 'o-ppa', difficulty: Difficulty.EASY, exampleSentence: '오빠가 한 명 있어요', exampleMeaning: 'Tôi có một anh trai' },
    { lessonId: c1_s2_l3.id, korean: '형', vietnamese: 'Anh trai (em trai gọi)', pronunciation: 'hyeong', difficulty: Difficulty.EASY, exampleSentence: '형은 대학생입니다', exampleMeaning: 'Anh tôi là sinh viên' },
    { lessonId: c1_s2_l3.id, korean: '언니', vietnamese: 'Chị gái (em gái gọi)', pronunciation: 'eon-ni', difficulty: Difficulty.EASY, exampleSentence: '언니는 예뻐요', exampleMeaning: 'Chị tôi xinh' },
    { lessonId: c1_s2_l3.id, korean: '누나', vietnamese: 'Chị gái (em trai gọi)', pronunciation: 'nu-na', difficulty: Difficulty.EASY, exampleSentence: '누나가 있어요', exampleMeaning: 'Tôi có chị gái' },
    { lessonId: c1_s2_l3.id, korean: '동생', vietnamese: 'Em', pronunciation: 'dong-saeng', difficulty: Difficulty.EASY, exampleSentence: '여동생 1명', exampleMeaning: '1 em gái' },

    // Numbers
    { lessonId: c1_s3_l1.id, korean: '하나', vietnamese: 'Một (thuần Hàn)', pronunciation: 'ha-na', difficulty: Difficulty.EASY, exampleSentence: '사과 하나 주세요', exampleMeaning: 'Cho tôi một quả táo' },
    { lessonId: c1_s3_l1.id, korean: '둘', vietnamese: 'Hai (thuần Hàn)', pronunciation: 'dul', difficulty: Difficulty.EASY, exampleSentence: '사람 둘이에요', exampleMeaning: 'Có hai người' },
    { lessonId: c1_s3_l1.id, korean: '셋', vietnamese: 'Ba (thuần Hàn)', pronunciation: 'set', difficulty: Difficulty.EASY, exampleSentence: '셋까지 세세요', exampleMeaning: 'Hãy đếm đến ba' },
    { lessonId: c1_s3_l1.id, korean: '일', vietnamese: 'Một (Hán-Hàn)', pronunciation: 'il', difficulty: Difficulty.EASY, exampleSentence: '일월', exampleMeaning: 'Tháng Một' },
    { lessonId: c1_s3_l1.id, korean: '이', vietnamese: 'Hai (Hán-Hàn)', pronunciation: 'i', difficulty: Difficulty.EASY, exampleSentence: '이번 주', exampleMeaning: 'Tuần này' },
    { lessonId: c1_s3_l1.id, korean: '삼', vietnamese: 'Ba (Hán-Hàn)', pronunciation: 'sam', difficulty: Difficulty.EASY, exampleSentence: '삼월', exampleMeaning: 'Tháng Ba' },

    // Restaurant
    { lessonId: c1_s3_l2.id, korean: '식당', vietnamese: 'Nhà hàng', pronunciation: 'sik-dang', difficulty: Difficulty.EASY, exampleSentence: '식당에 가요', exampleMeaning: 'Đi đến nhà hàng' },
    { lessonId: c1_s3_l2.id, korean: '메뉴', vietnamese: 'Thực đơn', pronunciation: 'me-nyu', difficulty: Difficulty.EASY, exampleSentence: '메뉴판 주세요', exampleMeaning: 'Cho tôi xem thực đơn' },
    { lessonId: c1_s3_l2.id, korean: '물', vietnamese: 'Nước', pronunciation: 'mul', difficulty: Difficulty.EASY, exampleSentence: '물 좀 주세요', exampleMeaning: 'Cho tôi xin chút nước' },
    { lessonId: c1_s3_l2.id, korean: '밥', vietnamese: 'Cơm', pronunciation: 'bap', difficulty: Difficulty.EASY, exampleSentence: '밥을 먹어요', exampleMeaning: 'Ăn cơm' },
    { lessonId: c1_s3_l2.id, korean: '김치', vietnamese: 'Kim chi', pronunciation: 'gim-chi', difficulty: Difficulty.EASY, exampleSentence: '김치가 매워요', exampleMeaning: 'Kim chi cay' },
    { lessonId: c1_s3_l2.id, korean: '맛있다', vietnamese: 'Ngon', pronunciation: 'ma-sit-da', difficulty: Difficulty.MEDIUM, exampleSentence: '음식이 맛있어요', exampleMeaning: 'Đồ ăn ngon' },

    // Shopping
    { lessonId: c1_s3_l3.id, korean: '옷', vietnamese: 'Quần áo', pronunciation: 'ot', difficulty: Difficulty.EASY, exampleSentence: '옷을 사요', exampleMeaning: 'Mua quần áo' },
    { lessonId: c1_s3_l3.id, korean: '얼마예요', vietnamese: 'Bao nhiêu tiền?', pronunciation: 'eol-ma-ye-yo', difficulty: Difficulty.EASY, exampleSentence: '이거 얼마예요?', exampleMeaning: 'Cái này bao nhiêu tiền?' },
    { lessonId: c1_s3_l3.id, korean: '비싸다', vietnamese: 'Đắt', pronunciation: 'bi-ssa-da', difficulty: Difficulty.MEDIUM, exampleSentence: '너무 비싸요', exampleMeaning: 'Đắt quá' },
    { lessonId: c1_s3_l3.id, korean: '싸다', vietnamese: 'Rẻ', pronunciation: 'ssa-da', difficulty: Difficulty.MEDIUM, exampleSentence: '정말 싸요', exampleMeaning: 'Rẻ thật' },
    { lessonId: c1_s3_l3.id, korean: '깎아주세요', vietnamese: 'Giảm giá cho tôi đi', pronunciation: 'kka-kka-ju-se-yo', difficulty: Difficulty.HARD, exampleSentence: '좀 깎아주세요', exampleMeaning: 'Giảm giá một chút đi ạ' },

    // Daily Life
    { lessonId: c1_s4_l2.id, korean: '일어나다', vietnamese: 'Thức dậy', pronunciation: 'i-reo-na-da', difficulty: Difficulty.MEDIUM, exampleSentence: '아침 7시에 일어나요', exampleMeaning: 'Tôi dậy lúc 7h sáng' },
    { lessonId: c1_s4_l2.id, korean: '자다', vietnamese: 'Ngủ', pronunciation: 'ja-da', difficulty: Difficulty.EASY, exampleSentence: '밤 11시에 자요', exampleMeaning: 'Ngủ lúc 11h đêm' },
    { lessonId: c1_s4_l2.id, korean: '먹다', vietnamese: 'Ăn', pronunciation: 'meok-da', difficulty: Difficulty.EASY, exampleSentence: '밥을 먹어요', exampleMeaning: 'Tôi đang ăn cơm' },
    { lessonId: c1_s4_l2.id, korean: '마시다', vietnamese: 'Uống', pronunciation: 'ma-si-da', difficulty: Difficulty.EASY, exampleSentence: '커피를 마셔요', exampleMeaning: 'Uống cà phê' },
    { lessonId: c1_s4_l2.id, korean: '일하다', vietnamese: 'Làm việc', pronunciation: 'il-ha-da', difficulty: Difficulty.EASY, exampleSentence: '회사에서 일해요', exampleMeaning: 'Làm việc ở công ty' },
    { lessonId: c1_s4_l2.id, korean: '공부하다', vietnamese: 'Học', pronunciation: 'gong-bu-ha-da', difficulty: Difficulty.EASY, exampleSentence: '한국어를 공부해요', exampleMeaning: 'Tôi học tiếng Hàn' },
  ];
  await prisma.vocabulary.createMany({ data: basicVocabs });

  const basicGrammar = [
    { lessonId: c1_s2_l1.id, pattern: 'N + 입니다 (Im-ni-da)', explanationVN: 'Là... (thể trang trọng). Đuôi câu cơ bản nhất.', example: '저는 베트남 사람입니다. (Tôi là người Việt Nam.)' },
    { lessonId: c1_s2_l1.id, pattern: 'N + 입니까? (Im-ni-kka?)', explanationVN: 'Là... phải không? Cấu trúc hỏi.', example: '학생입니까? (Bạn là học sinh phải không?)' },
    { lessonId: c1_s2_l2.id, pattern: 'N + 은/는', explanationVN: 'Trợ từ chủ đề. Dùng để nhấn mạnh chủ ngữ hoặc so sánh.', example: '저는 학생입니다. (TÔI là học sinh.)' },
    { lessonId: c1_s3_l2.id, pattern: 'V + ㅂ/습니다 (B/sum-ni-da)', explanationVN: 'Đuôi câu kết thúc thể kính ngữ trang trọng cho động từ/tính từ.', example: '감사합니다. (Cảm ơn.)' },
    { lessonId: c1_s4_l2.id, pattern: 'V + 아/어요 (A/eo-yo)', explanationVN: 'Đuôi câu thân mật, lịch sự. Dùng chủ yếu trong giao tiếp hàng ngày.', example: '밥을 먹어요. (Tôi ăn cơm.)' },
    { lessonId: c1_s3_l2.id, pattern: 'N + 을/를 (Eul/reul)', explanationVN: 'Trợ từ tân ngữ. Gắn sau danh từ chỉ đối tượng chịu tác động của hành động.', example: '사과를 먹어요. (Tôi ăn TÁO.)' },
    { lessonId: c1_s4_l1.id, pattern: 'N (thời gian) + 에', explanationVN: 'Trợ từ thời gian: vào lúc...', example: '아침 7시에 일어나요. (Tôi dậy VÀO LÚC 7h.)' },
    { lessonId: c1_s4_l1.id, pattern: 'N (địa điểm) + 에 가다', explanationVN: 'Đi đến (địa điểm).', example: '학교에 가요. (Tôi đi đến trường.)' },
    { lessonId: c1_s4_l2.id, pattern: 'N (địa điểm) + 에서', explanationVN: 'Làm gì đó TẠI (địa điểm).', example: '식당에서 밥을 먹어요. (Ăn cơm TẠI nhà hàng.)' },
  ];
  await prisma.grammar.createMany({ data: basicGrammar });

  const basicDialogues = [
    { lessonId: c1_s2_l1.id, speaker: '민수', koreanText: '안녕하세요!', vietnameseText: 'Xin chào!', orderIndex: 0 },
    { lessonId: c1_s2_l1.id, speaker: '하이', koreanText: '안녕하세요! 저는 하이입니다.', vietnameseText: 'Xin chào! Tôi là Hải.', orderIndex: 1 },
    { lessonId: c1_s2_l1.id, speaker: '민수', koreanText: '어느 나라 사람입니까?', vietnameseText: 'Bạn là người nước nào?', orderIndex: 2 },
    { lessonId: c1_s2_l1.id, speaker: '하이', koreanText: '저는 베트남 사람입니다.', vietnameseText: 'Tôi là người Việt Nam.', orderIndex: 3 },
    { lessonId: c1_s2_l1.id, speaker: '민수', koreanText: '만나서 반갑습니다.', vietnameseText: 'Rất vui được gặp bạn.', orderIndex: 4 },
    { lessonId: c1_s3_l2.id, speaker: '하이', koreanText: '저기요! 주문할게요.', vietnameseText: 'Xin lỗi (gọi phục vụ)! Cho tôi gọi món.', orderIndex: 0 },
    { lessonId: c1_s3_l2.id, speaker: '직원', koreanText: '네, 뭐 드릴까요?', vietnameseText: 'Vâng, quý khách dùng gì ạ?', orderIndex: 1 },
    { lessonId: c1_s3_l2.id, speaker: '하이', koreanText: '비빔밥 하나 하고 콜라 하나 주세요.', vietnameseText: 'Cho tôi 1 bibimbap và 1 cola.', orderIndex: 2 },
    { lessonId: c1_s3_l2.id, speaker: '직원', koreanText: '네, 알겠습니다. 잠깐만 기다리세요.', vietnameseText: 'Vâng, tôi hiểu rồi. Xin đợi một chút.', orderIndex: 3 },
  ];
  await prisma.dialogue.createMany({ data: basicDialogues });


  // ==========================================
  // COURSE 2: OFFICE KOREAN (AD-FREE)
  // ==========================================
  const c2_sec1 = await prisma.section.create({ data: { courseId: course2.id, title: 'Ngày đầu tiên đi làm', orderIndex: 0 } });
  const c2_sec2 = await prisma.section.create({ data: { courseId: course2.id, title: 'Giao tiếp nội bộ', orderIndex: 1 } });
  const c2_sec3 = await prisma.section.create({ data: { courseId: course2.id, title: 'Email & Điện thoại', orderIndex: 2 } });
  await prisma.section.create({ data: { courseId: course2.id, title: 'Hội họp & Báo cáo', orderIndex: 3 } });

  const c2_s1_l1 = await prisma.lesson.create({ data: { sectionId: c2_sec1.id, title: 'Tự giới thiệu bản thân', description: 'Giới thiệu ấn tượng với đồng nghiệp mới', orderIndex: 0, estimatedMinutes: 20 } });
  const c2_s1_l2 = await prisma.lesson.create({ data: { sectionId: c2_sec1.id, title: 'Chức danh công ty', description: 'Từ vựng về các cấp bậc (Giám đốc, Trưởng phòng...)', orderIndex: 1, estimatedMinutes: 15 } });
  const c2_s1_l3 = await prisma.lesson.create({ data: { sectionId: c2_sec1.id, title: 'Các phòng ban', description: 'Nhân sự, Marketing, Kế toán...', orderIndex: 2, estimatedMinutes: 15 } });

  const c2_s2_l1 = await prisma.lesson.create({ data: { sectionId: c2_sec2.id, title: 'Chào hỏi & Xin phép', description: 'Văn hóa chào hỏi tại nơi làm việc', orderIndex: 0, estimatedMinutes: 20 } });
  const c2_s2_l2 = await prisma.lesson.create({ data: { sectionId: c2_sec2.id, title: 'Nhờ vả đồng nghiệp', description: 'Cách nhờ giúp đỡ một cách lịch sự', orderIndex: 1, estimatedMinutes: 25 } });
  const c2_s2_l3 = await prisma.lesson.create({ data: { sectionId: c2_sec2.id, title: 'Xin lỗi & Báo cáo lỗi', description: 'Xử lý khi làm sai', orderIndex: 2, estimatedMinutes: 25 } });

  const c2_s3_l1 = await prisma.lesson.create({ data: { sectionId: c2_sec3.id, title: 'Chào hỏi qua Email', description: 'Mở đầu và kết thúc Email chuẩn', orderIndex: 0, estimatedMinutes: 30 } });
  await prisma.lesson.create({ data: { sectionId: c2_sec3.id, title: 'Nghe điện thoại', description: 'Cách trả lời điện thoại công ty', orderIndex: 1, estimatedMinutes: 25 } });

  const officeVocabs = [
    // Ranks & Titles
    { lessonId: c2_s1_l2.id, korean: '사장님', vietnamese: 'Giám đốc', pronunciation: 'sa-jang-nim', difficulty: Difficulty.EASY, exampleSentence: '사장님께서 안 계십니다', exampleMeaning: 'Giám đốc không có ở đây' },
    { lessonId: c2_s1_l2.id, korean: '부장님', vietnamese: 'Trưởng phòng / Quản lý bộ phận', pronunciation: 'bu-jang-nim', difficulty: Difficulty.EASY, exampleSentence: '부장님, 보고서 결재 부탁드립니다', exampleMeaning: 'Trưởng phòng, xin hãy ký duyệt báo cáo' },
    { lessonId: c2_s1_l2.id, korean: '과장님', vietnamese: 'Trưởng nhóm / Trưởng phòng nhỏ', pronunciation: 'gwa-jang-nim', difficulty: Difficulty.EASY, exampleSentence: '오늘 과장님 휴가예요', exampleMeaning: 'Hôm nay trưởng nhóm nghỉ phép' },
    { lessonId: c2_s1_l2.id, korean: '대리님', vietnamese: 'Trợ lý / Phó phòng', pronunciation: 'dae-ri-nim', difficulty: Difficulty.MEDIUM, exampleSentence: '대리님이 도와주셨어요', exampleMeaning: 'Phó phòng đã giúp tôi' },
    { lessonId: c2_s1_l2.id, korean: '사원', vietnamese: 'Nhân viên', pronunciation: 'sa-won', difficulty: Difficulty.EASY, exampleSentence: '저는 신입 사원입니다', exampleMeaning: 'Tôi là nhân viên mới' },
    { lessonId: c2_s1_l2.id, korean: '회장님', vietnamese: 'Chủ tịch', pronunciation: 'hoe-jang-nim', difficulty: Difficulty.EASY, exampleSentence: '회장님이 오셨습니다', exampleMeaning: 'Chủ tịch đã đến' },
    
    // Departments
    { lessonId: c2_s1_l3.id, korean: '인사부', vietnamese: 'Phòng nhân sự', pronunciation: 'in-sa-bu', difficulty: Difficulty.MEDIUM, exampleSentence: '인사부에 물어보세요', exampleMeaning: 'Hãy thử hỏi phòng nhân sự' },
    { lessonId: c2_s1_l3.id, korean: '총무부', vietnamese: 'Phòng hành chính tổng hợp', pronunciation: 'chong-mu-bu', difficulty: Difficulty.MEDIUM, exampleSentence: '명함은 총무부에서 줍니다', exampleMeaning: 'Phòng hành chính phát danh thiếp' },
    { lessonId: c2_s1_l3.id, korean: '영업부', vietnamese: 'Phòng kinh doanh', pronunciation: 'yeong-eop-bu', difficulty: Difficulty.MEDIUM, exampleSentence: '저는 영업부에서 일합니다', exampleMeaning: 'Tôi làm việc ở phòng kinh doanh' },
    { lessonId: c2_s1_l3.id, korean: '재무부', vietnamese: 'Phòng tài chính kế toán', pronunciation: 'jae-mu-bu', difficulty: Difficulty.HARD, exampleSentence: '재무부로 서류를 보내세요', exampleMeaning: 'Hãy gửi tài liệu đến phòng tài chính' },
    { lessonId: c2_s1_l3.id, korean: '개발팀', vietnamese: 'Đội phát triển (Dev)', pronunciation: 'gae-bal-tim', difficulty: Difficulty.EASY, exampleSentence: '개발팀 회의가 있습니다', exampleMeaning: 'Có cuộc họp đội phát triển' },

    // Daily Office Actions
    { lessonId: c2_s2_l1.id, korean: '출근', vietnamese: 'Đi làm / Có mặt tại cty', pronunciation: 'chul-geun', difficulty: Difficulty.EASY, exampleSentence: '아침 9시에 출근합니다', exampleMeaning: 'Tôi đi làm lúc 9 giờ sáng' },
    { lessonId: c2_s2_l1.id, korean: '퇴근', vietnamese: 'Tan làm / Rời cty', pronunciation: 'toe-geun', difficulty: Difficulty.EASY, exampleSentence: '오늘은 일찍 퇴근할게요', exampleMeaning: 'Hôm nay tôi sẽ tan làm sớm' },
    { lessonId: c2_s2_l1.id, korean: '결재', vietnamese: 'Ký duyệt', pronunciation: 'gyeol-jae', difficulty: Difficulty.HARD, exampleSentence: '결재를 올려주세요', exampleMeaning: 'Xin hãy đệ trình để ký duyệt' },
    { lessonId: c2_s2_l1.id, korean: '야근', vietnamese: 'Làm thêm giờ', pronunciation: 'ya-geun', difficulty: Difficulty.MEDIUM, exampleSentence: '요즘 매일 야근해요', exampleMeaning: 'Dạo này ngày nào cũng làm thêm giờ' },
    { lessonId: c2_s2_l1.id, korean: '외근', vietnamese: 'Làm việc bên ngoài', pronunciation: 'oe-geun', difficulty: Difficulty.MEDIUM, exampleSentence: '오후에는 외근이 있어요', exampleMeaning: 'Buổi chiều có việc bên ngoài' },
    { lessonId: c2_s2_l1.id, korean: '회의', vietnamese: 'Cuộc họp', pronunciation: 'hoe-ui', difficulty: Difficulty.EASY, exampleSentence: '회의실을 예약해 주세요', exampleMeaning: 'Hãy đặt trước phòng họp' },
    { lessonId: c2_s2_l1.id, korean: '의견', vietnamese: 'Ý kiến', pronunciation: 'ui-gyeon', difficulty: Difficulty.MEDIUM, exampleSentence: '다른 의견 있습니까?', exampleMeaning: 'Có ý kiến nào khác không?' },

    // Office Tools & Terms
    { lessonId: c2_s3_l1.id, korean: '서류', vietnamese: 'Tài liệu / Hồ sơ', pronunciation: 'seo-ryu', difficulty: Difficulty.EASY, exampleSentence: '서류를 검토해 주세요', exampleMeaning: 'Hãy xem xét tài liệu' },
    { lessonId: c2_s3_l1.id, korean: '피드백', vietnamese: 'Phản hồi', pronunciation: 'pi-deu-baek', difficulty: Difficulty.MEDIUM, exampleSentence: '빠른 피드백 부탁드립니다', exampleMeaning: 'Xin vui lòng phản hồi sớm' },
    { lessonId: c2_s3_l1.id, korean: '참조', vietnamese: 'CC (Email) / Tham chiếu', pronunciation: 'cham-jo', difficulty: Difficulty.HARD, exampleSentence: '부장님을 참조로 넣으세요', exampleMeaning: 'Hãy cho trưởng phòng vào mục CC' },
    { lessonId: c2_s3_l1.id, korean: '첨부파일', vietnamese: 'File đính kèm', pronunciation: 'cheom-bu-pa-il', difficulty: Difficulty.HARD, exampleSentence: '첨부파일을 확인해 주세요', exampleMeaning: 'Vui lòng kiểm tra file đính kèm' },
    { lessonId: c2_s3_l1.id, korean: '명함', vietnamese: 'Danh thiếp', pronunciation: 'myeong-ham', difficulty: Difficulty.MEDIUM, exampleSentence: '제 명함입니다', exampleMeaning: 'Đây là danh thiếp của tôi' },
    { lessonId: c2_s3_l1.id, korean: '휴가', vietnamese: 'Kỳ nghỉ / Nghỉ phép', pronunciation: 'hyu-ga', difficulty: Difficulty.EASY, exampleSentence: '내일 휴가를 내고 싶습니다', exampleMeaning: 'Ngày mai tôi muốn xin nghỉ phép' },
  ];
  await prisma.vocabulary.createMany({ data: officeVocabs });

  const officeGrammar = [
    { lessonId: c2_s1_l1.id, pattern: 'N(이/가) 어떻게 되십니까?', explanationVN: 'Hỏi một cách rất trang trọng (Tên, tuổi, liên lạc...).', example: '성함이 어떻게 되십니까? (Xin hỏi quý danh của anh/chị là gì?)' },
    { lessonId: c2_s2_l2.id, pattern: 'V + 아/어 주시겠어요?', explanationVN: 'Yêu cầu, nhờ vả một cách vô cùng lịch sự trong công sở.', example: '이 서류를 확인해 주시겠어요? (Xin vui lòng kiểm tra giúp tài liệu này được không ạ?)' },
    { lessonId: c2_s2_l3.id, pattern: 'V + (으)ㄹ 예정입니다', explanationVN: 'Dự định, kế hoạch sẽ làm gì (Trang trọng).', example: '회의는 2시에 시작할 예정입니다. (Cuộc họp dự kiến sẽ bắt đầu lúc 2h.)' },
    { lessonId: c2_s3_l1.id, pattern: 'V + (으)시기 바랍니다', explanationVN: 'Mong, yêu cầu (lịch sự) thường dùng trong thông báo, email.', example: '내일까지 회신해 주시기 바랍니다. (Mong anh/chị phản hồi trước ngày mai.)' },
  ];
  await prisma.grammar.createMany({ data: officeGrammar });

  const officeDialogues = [
    { lessonId: c2_s1_l1.id, speaker: '부장님', koreanText: '여러분, 새로 온 신입 사원입니다.', vietnameseText: 'Mọi người, đây là nhân viên mới đến.', orderIndex: 0 },
    { lessonId: c2_s1_l1.id, speaker: '하이', koreanText: '안녕하십니까? 이번에 영업부에 입사한 하이라고 합니다.', vietnameseText: 'Xin chào mọi người. Tôi là Hải, vừa gia nhập phòng kinh doanh lần này.', orderIndex: 1 },
    { lessonId: c2_s1_l1.id, speaker: '하이', koreanText: '아직 부족한 점이 많지만 열심히 배우겠습니다.', vietnameseText: 'Tôi vẫn còn nhiều thiếu sót nhưng sẽ cố gắng học hỏi.', orderIndex: 2 },
    { lessonId: c2_s1_l1.id, speaker: '부장님', koreanText: '네, 잘 부탁합니다.', vietnameseText: 'Vâng, mong được hợp tác.', orderIndex: 3 },
    
    { lessonId: c2_s2_l2.id, speaker: '하이', koreanText: '대리님, 실례합니다. 지금 통화 괜찮으십니까?', vietnameseText: 'Phó phòng, xin lỗi, bây giờ bận nghe máy được không ạ?', orderIndex: 0 },
    { lessonId: c2_s2_l2.id, speaker: '대리', koreanText: '네, 무슨 일이에요?', vietnameseText: 'Vâng, có chuyện gì vậy?', orderIndex: 1 },
    { lessonId: c2_s2_l2.id, speaker: '하이', koreanText: '거래처에 이메일을 보내야 하는데, 첨부파일 한 번만 확인해 주시겠어요?', vietnameseText: 'Tôi phải gửi email cho đối tác, anh có thể kiểm tra giúp file đính kèm một lần được không ạ?', orderIndex: 2 },
    { lessonId: c2_s2_l2.id, speaker: '대리', koreanText: '알겠습니다. 저한테 메일로 보내 주세요.', vietnameseText: 'Được rồi. Hãy gửi mail cho tôi nhé.', orderIndex: 3 },
  ];
  await prisma.dialogue.createMany({ data: officeDialogues });

  // ==========================================
  // COURSE 3: K-POP & IDOL KOREAN
  // ==========================================
  const c3_sec1 = await prisma.section.create({ data: { courseId: course3.id, title: 'Văn hóa Fandom', orderIndex: 0 } });
  const c3_sec2 = await prisma.section.create({ data: { courseId: course3.id, title: 'Đi Concert & Fansign', orderIndex: 1 } });
  await prisma.section.create({ data: { courseId: course3.id, title: 'Comment SNS & Livestream', orderIndex: 2 } });

  const c3_s1_l1 = await prisma.lesson.create({ data: { sectionId: c3_sec1.id, title: 'Thuật ngữ Fandom (Phần 1)', description: 'Bias, Maknae, Comeback...', orderIndex: 0, estimatedMinutes: 15 } });
  const c3_s1_l2 = await prisma.lesson.create({ data: { sectionId: c3_sec1.id, title: 'Thuật ngữ Fandom (Phần 2)', description: 'TMI, Aegyo, Ending Fairy...', orderIndex: 1, estimatedMinutes: 15 } });

  const c3_s2_l1 = await prisma.lesson.create({ data: { sectionId: c3_sec2.id, title: 'Giao tiếp tại Fansign', description: 'Cách nói chuyện trực tiếp với Idol', orderIndex: 0, estimatedMinutes: 20 } });
  await prisma.lesson.create({ data: { sectionId: c3_sec2.id, title: 'Fanchant & Biển quảng cáo', description: 'Từ vựng cổ vũ', orderIndex: 1, estimatedMinutes: 15 } });

  const kpopVocabs = [
    { lessonId: c3_s1_l1.id, korean: '최애', vietnamese: 'Thành viên thích nhất (Bias)', pronunciation: 'choe-ae', difficulty: Difficulty.EASY, exampleSentence: '제 최애는 정국이에요', exampleMeaning: 'Bias của tôi là Jungkook' },
    { lessonId: c3_s1_l1.id, korean: '차애', vietnamese: 'Thành viên thích thứ hai (Bias Wrecker)', pronunciation: 'cha-ae', difficulty: Difficulty.EASY, exampleSentence: '차애가 매일 바뀌어요', exampleMeaning: 'Bias wrecker thay đổi mỗi ngày' },
    { lessonId: c3_s1_l1.id, korean: '컴백', vietnamese: 'Comeback (Trở lại với bài hát mới)', pronunciation: 'keom-baek', difficulty: Difficulty.EASY, exampleSentence: '다음 달에 컴백한대요!', exampleMeaning: 'Nghe nói tháng sau họ comeback!' },
    { lessonId: c3_s1_l1.id, korean: '막내', vietnamese: 'Thành viên nhỏ tuổi nhất (Maknae)', pronunciation: 'mak-nae', difficulty: Difficulty.EASY, exampleSentence: '황금 막내예요', exampleMeaning: 'Là maknae vàng đó' },
    { lessonId: c3_s1_l1.id, korean: '리더', vietnamese: 'Trưởng nhóm', pronunciation: 'ri-deo', difficulty: Difficulty.EASY, exampleSentence: '리더가 정말 든든해요', exampleMeaning: 'Trưởng nhóm thực sự đáng tin cậy' },
    { lessonId: c3_s1_l1.id, korean: '입덕', vietnamese: 'Mới làm fan / Lọt hố', pronunciation: 'ip-deok', difficulty: Difficulty.MEDIUM, exampleSentence: '그 영상 보고 입덕했어요', exampleMeaning: 'Tôi lọt hố sau khi xem video đó' },
    { lessonId: c3_s1_l1.id, korean: '탈덕', vietnamese: 'Ngừng làm fan / Thoát hố', pronunciation: 'tal-deok', difficulty: Difficulty.MEDIUM, exampleSentence: '탈덕은 없어요', exampleMeaning: 'Không có chuyện thoát hố đâu' },

    { lessonId: c3_s1_l2.id, korean: '애교', vietnamese: 'Hành động đáng yêu (Aegyo)', pronunciation: 'ae-gyo', difficulty: Difficulty.EASY, exampleSentence: '애교 한 번 보여주세요!', exampleMeaning: 'Hãy làm aegyo một lần xem nào!' },
    { lessonId: c3_s1_l2.id, korean: '대박', vietnamese: 'Đỉnh / Tuyệt cú mèo', pronunciation: 'dae-bak', difficulty: Difficulty.EASY, exampleSentence: '이번 신곡 대박이야!', exampleMeaning: 'Bài hát mới lần này đỉnh quá!' },
    { lessonId: c3_s1_l2.id, korean: '심쿵', vietnamese: 'Đốn tim / Đứng tim', pronunciation: 'sim-kung', difficulty: Difficulty.MEDIUM, exampleSentence: '오늘 의상 보고 심쿵했어요', exampleMeaning: 'Nhìn thấy trang phục hôm nay mà đốn tim' },
    { lessonId: c3_s1_l2.id, korean: '직캠', vietnamese: 'Fancam', pronunciation: 'jik-kaem', difficulty: Difficulty.MEDIUM, exampleSentence: '직캠 매일 돌려봐요', exampleMeaning: 'Tôi xem lại fancam mỗi ngày' },

    { lessonId: c3_s2_l1.id, korean: '오빠', vietnamese: 'Anh (Fan nữ gọi Idol nam)', pronunciation: 'o-ppa', difficulty: Difficulty.EASY, exampleSentence: '오빠 잘생겼어요!', exampleMeaning: 'Oppa đẹp trai quá!' },
    { lessonId: c3_s2_l1.id, korean: '누나', vietnamese: 'Chị (Fan nam gọi Idol nữ)', pronunciation: 'nu-na', difficulty: Difficulty.EASY, exampleSentence: '누나 너무 예뻐요!', exampleMeaning: 'Noona xinh quá!' },
    { lessonId: c3_s2_l1.id, korean: '사랑해요', vietnamese: 'Em/Mình yêu bạn', pronunciation: 'sa-rang-hae-yo', difficulty: Difficulty.EASY, exampleSentence: '진짜 사랑해요', exampleMeaning: 'Mình thực sự yêu bạn' },
    { lessonId: c3_s2_l1.id, korean: '건강 조심하세요', vietnamese: 'Hãy chú ý sức khỏe', pronunciation: 'geon-gang jo-sim-ha-se-yo', difficulty: Difficulty.MEDIUM, exampleSentence: '밥 잘 챙겨 먹고 건강 조심하세요', exampleMeaning: 'Hãy ăn uống đầy đủ và chú ý sức khỏe nhé' },
    { lessonId: c3_s2_l1.id, korean: '수고했어요', vietnamese: 'Bạn đã vất vả rồi', pronunciation: 'su-go-haet-seo-yo', difficulty: Difficulty.MEDIUM, exampleSentence: '오늘 활동도 수고했어요', exampleMeaning: 'Hôm nay hoạt động cũng vất vả rồi' },
    { lessonId: c3_s2_l1.id, korean: '기억해 주세요', vietnamese: 'Xin hãy nhớ mình', pronunciation: 'gi-eok-hae ju-se-yo', difficulty: Difficulty.HARD, exampleSentence: '제 이름 꼭 기억해 주세요', exampleMeaning: 'Nhất định hãy nhớ tên mình nhé' },
  ];
  await prisma.vocabulary.createMany({ data: kpopVocabs });

  const kpopDialogues = [
    { lessonId: c3_s2_l1.id, speaker: '팬', koreanText: '오빠, 안녕하세요! 드디어 만났어요.', vietnameseText: 'Oppa, xin chào! Cuối cùng cũng được gặp.', orderIndex: 0 },
    { lessonId: c3_s2_l1.id, speaker: '아이돌', koreanText: '안녕! 이름이 뭐예요?', vietnameseText: 'Xin chào! Tên bạn là gì?', orderIndex: 1 },
    { lessonId: c3_s2_l1.id, speaker: '팬', koreanText: '제 이름은 마이에요. 베트남에서 왔어요!', vietnameseText: 'Tên em là Mai. Em đến từ Việt Nam!', orderIndex: 2 },
    { lessonId: c3_s2_l1.id, speaker: '아이돌', koreanText: '오, 와주셔서 정말 고마워요. 사랑해요!', vietnameseText: 'Ồ, thực sự cảm ơn bạn đã đến. Yêu bạn!', orderIndex: 3 },
    { lessonId: c3_s2_l1.id, speaker: '팬', koreanText: '밥 잘 챙겨 먹고 너무 무리하지 마세요. 수고했어요!', vietnameseText: 'Hãy ăn uống đầy đủ và đừng làm việc quá sức nha. Anh đã vất vả rồi!', orderIndex: 4 },
  ];
  await prisma.dialogue.createMany({ data: kpopDialogues });

  console.log('✅ Seeding complete!');
  console.log(`   Admin: admin@koreanapp.com / Admin123!`);
  console.log(`   Users: nguyen@example.com, tran@example.com, le@example.com / User123!`);
  console.log(`   Courses added:`);
  console.log(`     1. ${course1.title}`);
  console.log(`     2. ${course2.title}`);
  console.log(`     3. ${course3.title}`);
  console.log(`   Huge amounts of Sections, Lessons, Vocabs, Grammars, and Dialogues created.`);
}

main()
  .catch((e) => {
    console.error('❌ Seed error:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
