import { PrismaClient, Difficulty } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Seeding specialized vocabulary...');

  const specializedVocabs = [
    // IT Category
    {
      korean: '개발자',
      vietnamese: 'Lập trình viên / Nhà phát triển',
      pronunciation: 'gae-bal-ja',
      difficulty: Difficulty.EASY,
      category: 'IT',
      exampleSentence: '그는 유능한 웹 개발자입니다.',
      exampleMeaning: 'Anh ấy là một nhà phát triển web tài năng.',
    },
    {
      korean: '버그',
      vietnamese: 'Lỗi lập trình / Bug',
      pronunciation: 'beo-geu',
      difficulty: Difficulty.EASY,
      category: 'IT',
      exampleSentence: '프로그램에서 버그를 발견했습니다.',
      exampleMeaning: 'Tôi đã phát hiện ra lỗi trong chương trình.',
    },
    {
      korean: '데이터베이스',
      vietnamese: 'Cơ sở dữ liệu',
      pronunciation: 'de-i-teo-be-i-seu',
      difficulty: Difficulty.MEDIUM,
      category: 'IT',
      exampleSentence: '데이터베이스에 정보를 저장합니다.',
      exampleMeaning: 'Lưu trữ thông tin vào cơ sở dữ liệu.',
    },
    {
      korean: '소스 코드',
      vietnamese: 'Mã nguồn / Source code',
      pronunciation: 'so-seu ko-deu',
      difficulty: Difficulty.MEDIUM,
      category: 'IT',
      exampleSentence: '소스 코드를 깃허브에 올렸습니다.',
      exampleMeaning: 'Tôi đã tải mã nguồn lên GitHub.',
    },
    {
      korean: '서버',
      vietnamese: 'Máy chủ / Server',
      pronunciation: 'seo-beo',
      difficulty: Difficulty.EASY,
      category: 'IT',
      exampleSentence: '서버가 다운되었습니다.',
      exampleMeaning: 'Máy chủ đã bị sập.',
    },
    {
      korean: '인공지능',
      vietnamese: 'Trí tuệ nhân tạo (AI)',
      pronunciation: 'in-gong-ji-neung',
      difficulty: Difficulty.MEDIUM,
      category: 'IT',
      exampleSentence: '인공지능 기술이 빠르게 발전하고 있습니다.',
      exampleMeaning: 'Công nghệ trí tuệ nhân tạo đang phát triển nhanh chóng.',
    },

    // BUSINESS Category
    {
      korean: '계약서',
      vietnamese: 'Hợp đồng / Bản thỏa thuận',
      pronunciation: 'gye-yak-seo',
      difficulty: Difficulty.MEDIUM,
      category: 'BUSINESS',
      exampleSentence: '계약서에 서명해 주세요.',
      exampleMeaning: 'Vui lòng ký vào hợp đồng.',
    },
    {
      korean: '결재',
      vietnamese: 'Phê duyệt / Ký duyệt',
      pronunciation: 'gyeol-jae',
      difficulty: Difficulty.HARD,
      category: 'BUSINESS',
      exampleSentence: '부장님께 결재를 받았습니다.',
      exampleMeaning: 'Tôi đã nhận được sự phê duyệt từ trưởng phòng.',
    },
    {
      korean: '서류',
      vietnamese: 'Tài liệu / Hồ sơ',
      pronunciation: 'seo-ryu',
      difficulty: Difficulty.EASY,
      category: 'BUSINESS',
      exampleSentence: '회의 서류를 준비했습니다.',
      exampleMeaning: 'Tôi đã chuẩn bị tài liệu cuộc họp.',
    },
    {
      korean: '회의',
      vietnamese: 'Cuộc họp',
      pronunciation: 'hoe-ui',
      difficulty: Difficulty.EASY,
      category: 'BUSINESS',
      exampleSentence: '오후 두 시에 회의가 있습니다.',
      exampleMeaning: 'Có cuộc họp vào lúc 2 giờ chiều.',
    },
    {
      korean: '협력',
      vietnamese: 'Hợp tác',
      pronunciation: 'hyeop-ryeok',
      difficulty: Difficulty.MEDIUM,
      category: 'BUSINESS',
      exampleSentence: '두 회사는 긴밀히 협력하고 있습니다.',
      exampleMeaning: 'Hai công ty đang hợp tác chặt chẽ với nhau.',
    },

    // EPS Category (Manufacturing)
    {
      korean: '제조업',
      vietnamese: 'Ngành sản xuất chế tạo',
      pronunciation: 'je-jo-eop',
      difficulty: Difficulty.MEDIUM,
      category: 'EPS',
      exampleSentence: '한국의 제조업 공장에서 일합니다.',
      exampleMeaning: 'Làm việc tại nhà máy sản xuất chế tạo của Hàn Quốc.',
    },
    {
      korean: '작업장',
      vietnamese: 'Nơi làm việc / Xưởng làm việc',
      pronunciation: 'ja-geop-jang',
      difficulty: Difficulty.EASY,
      category: 'EPS',
      exampleSentence: '작업장을 항상 깨끗하게 청소합시다.',
      exampleMeaning: 'Hãy luôn dọn dẹp nơi làm việc sạch sẽ.',
    },
    {
      korean: '안전모',
      vietnamese: 'Mũ bảo hộ',
      pronunciation: 'an-jeon-mo',
      difficulty: Difficulty.EASY,
      category: 'EPS',
      exampleSentence: '공장에서는 반드시 안전모를 착용해야 합니다.',
      exampleMeaning: 'Trong nhà máy nhất định phải đội mũ bảo hộ.',
    },
    {
      korean: '공구',
      vietnamese: 'Công cụ / Dụng cụ',
      pronunciation: 'gong-gu',
      difficulty: Difficulty.EASY,
      category: 'EPS',
      exampleSentence: '작업이 끝난 후 공구를 정리하세요.',
      exampleMeaning: 'Sau khi hoàn thành công việc, hãy sắp xếp lại dụng cụ.',
    },
    {
      korean: '작업복',
      vietnamese: 'Quần áo bảo hộ / Đồng phục lao động',
      pronunciation: 'ja-geop-bok',
      difficulty: Difficulty.EASY,
      category: 'EPS',
      exampleSentence: '작업복으로 갈아입으세요.',
      exampleMeaning: 'Hãy thay quần áo bảo hộ.',
    },

    // CONSTRUCTION Category
    {
      korean: '비계',
      vietnamese: 'Giàn giáo',
      pronunciation: 'bi-gye',
      difficulty: Difficulty.HARD,
      category: 'CONSTRUCTION',
      exampleSentence: '비계 위에서 작업할 때는 조심해야 합니다.',
      exampleMeaning: 'Khi làm việc trên giàn giáo phải cẩn thận.',
    },
    {
      korean: '벽돌',
      vietnamese: 'Gạch',
      pronunciation: 'byeok-dol',
      difficulty: Difficulty.EASY,
      category: 'CONSTRUCTION',
      exampleSentence: '벽돌을 차곡차곡 쌓으세요.',
      exampleMeaning: 'Hãy xếp gạch chồng ngay ngắn lên.',
    },
    {
      korean: '시멘트',
      vietnamese: 'Xi măng',
      pronunciation: 'si-men-teu',
      difficulty: Difficulty.EASY,
      category: 'CONSTRUCTION',
      exampleSentence: '시멘트와 모래를 섞습니다.',
      exampleMeaning: 'Trộn xi măng với cát.',
    },
    {
      korean: '콘크리트',
      vietnamese: 'Bê tông',
      pronunciation: 'kon-keu-ri-teu',
      difficulty: Difficulty.EASY,
      category: 'CONSTRUCTION',
      exampleSentence: '콘크리트가 단단하게 굳었습니다.',
      exampleMeaning: 'Bê tông đã đông cứng lại chắc chắn.',
    },
    {
      korean: '안전대',
      vietnamese: 'Dây đai an toàn',
      pronunciation: 'an-jeon-dae',
      difficulty: Difficulty.MEDIUM,
      category: 'CONSTRUCTION',
      exampleSentence: '높은 곳에서 작업할 때는 안전대를 걸어야 합니다.',
      exampleMeaning: 'Khi làm việc ở trên cao phải móc dây đai an toàn.',
    },
  ];

  for (const item of specializedVocabs) {
    await prisma.vocabulary.create({
      data: item,
    });
  }

  console.log('✅ Seeding specialized vocabulary complete!');
}

main()
  .catch((e) => {
    console.error('❌ Seed error:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
