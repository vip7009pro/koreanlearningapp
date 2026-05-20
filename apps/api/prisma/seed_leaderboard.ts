import { PrismaClient, UserRole } from '@prisma/client';

const prisma = new PrismaClient();

const LAST_NAMES = [
  'Nguyễn', 'Trần', 'Lê', 'Phạm', 'Hoàng', 'Huỳnh', 'Phan', 'Vũ', 'Võ', 'Đặng',
  'Bùi', 'Đỗ', 'Hồ', 'Ngô', 'Dương', 'Lý', 'Vương', 'Trịnh', 'Lương', 'Mai',
  'Đinh', 'Đoàn', 'Tống', 'Lâm', 'Phùng', 'Tăng', 'Hà', 'Thái', 'Trương', 'Quách'
];

const MIDDLE_MALE = [
  'Văn', 'Hữu', 'Minh', 'Quang', 'Hải', 'Quốc', 'Đức', 'Duy', 'Anh', 'Thành',
  'Đình', 'Xuân', 'Hoàng', 'Việt', 'Ngọc', 'Thanh', 'Tiến', 'Mạnh', 'Trọng', 'Công',
  'Tuấn', 'Tùng', 'Khôi', 'Nhật', 'Bảo', 'Gia', 'Thế', 'Phước', 'Khắc', 'Đông'
];

const MIDDLE_FEMALE = [
  'Thị', 'Ngọc', 'Quỳnh', 'Thu', 'Thanh', 'Phương', 'Cát', 'Khánh', 'Minh', 'Kim',
  'Tuyết', 'Yến', 'Ánh', 'Hồng', 'Trúc', 'Kiều', 'Như', 'Huyền', 'Diệu', 'Mỹ',
  'Tú', 'Lan', 'Bảo', 'Tường', 'Gia', 'Trang', 'Hạ', 'Xuân', 'Thảo', 'Hoài'
];

const GIVEN_MALE = [
  'Anh', 'Bình', 'Cường', 'Dũng', 'Duy', 'Giang', 'Hải', 'Hùng', 'Huy', 'Khánh',
  'Linh', 'Minh', 'Nam', 'Phong', 'Quân', 'Sơn', 'Thắng', 'Toàn', 'Tuấn', 'Tùng',
  'Việt', 'Bách', 'Lâm', 'Khoa', 'Hoàng', 'Long', 'Đức', 'Phúc', 'Tâm', 'Kiệt',
  'Thịnh', 'Vinh', 'Trung', 'Hào', 'Hưng', 'Khang', 'Phát', 'Đạt', 'Hiếu', 'Nhân'
];

const GIVEN_FEMALE = [
  'Vy', 'Yến', 'Trang', 'Thảo', 'Ngọc', 'Hoa', 'Hương', 'Lan', 'Mai', 'Linh',
  'Phương', 'Hằng', 'Anh', 'Hà', 'Trâm', 'Oanh', 'Chi', 'Giang', 'Diệp', 'Quỳnh',
  'Nhi', 'Trinh', 'Tú', 'Nguyệt', 'Cúc', 'Trúc', 'Đào', 'Hồng', 'Lâm', 'Tuyết',
  'Vân', 'Châu', 'Trà', 'Nguyên', 'Khuyên', 'Liên', 'Mỹ', 'Dung', 'Hạnh', 'Duyên'
];

const DOMAINS = ['gmail.com', 'yahoo.com', 'outlook.com', 'hotmail.com', 'fpt.edu.vn', 'vnu.edu.vn'];

function removeDiacritics(str: string): string {
  return str
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/đ/g, 'd')
    .replace(/Đ/g, 'd');
}

async function main() {
  console.log('🌱 Start seeding 500 leaderboard users...');

  const generatedEmails = new Set<string>();
  const users = [];

  // Generate 500 random users
  for (let i = 0; i < 500; i++) {
    const isMale = Math.random() > 0.5;
    const last = LAST_NAMES[Math.floor(Math.random() * LAST_NAMES.length)];
    const middle = isMale
      ? MIDDLE_MALE[Math.floor(Math.random() * MIDDLE_MALE.length)]
      : MIDDLE_FEMALE[Math.floor(Math.random() * MIDDLE_FEMALE.length)];
    const given = isMale
      ? GIVEN_MALE[Math.floor(Math.random() * GIVEN_MALE.length)]
      : GIVEN_FEMALE[Math.floor(Math.random() * GIVEN_FEMALE.length)];

    const displayName = `${last} ${middle} ${given}`;

    // Create a safe, unique email username
    const cleanGiven = removeDiacritics(given).toLowerCase();
    const cleanMiddle = removeDiacritics(middle).toLowerCase();
    const cleanLast = removeDiacritics(last).toLowerCase();
    const baseEmail = `${cleanGiven}.${cleanMiddle}.${cleanLast}`.replace(/\s+/g, '');
    const domain = DOMAINS[Math.floor(Math.random() * DOMAINS.length)];

    let email = `${baseEmail}@${domain}`;
    let counter = 1;
    while (generatedEmails.has(email)) {
      email = `${baseEmail}${counter}@${domain}`;
      counter++;
    }
    generatedEmails.add(email);

    // Distribution: some very high XP, many moderate XP, and some new users.
    const totalXP = Math.floor(Math.pow(Math.random(), 2.5) * 18000) + 10;
    const streakDays = Math.floor(Math.pow(Math.random(), 2) * 60);

    users.push({
      email,
      displayName,
      totalXP,
      streakDays,
      role: UserRole.USER,
      passwordHash: '$2b$10$wE9dDqH0aB9o9W5J9z9qOuW9e/6a1kZzK7f3Y6M5O2b.O4i.X2a1G', // Hash for 'Password123'
      aiTicketsBalance: Math.floor(Math.random() * 20),
    });
  }

  // Create users in batch
  const count = await prisma.user.createMany({
    data: users,
    skipDuplicates: true,
  });

  console.log(`✅ Seeded ${count.count} leaderboard users successfully!`);
}

main()
  .catch((e) => {
    console.error('❌ Seed leaderboard error:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
