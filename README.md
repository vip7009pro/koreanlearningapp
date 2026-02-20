# 🇰🇷 Korean Learning Platform

A comprehensive Korean learning platform built for Vietnamese professionals working at Korean companies.

## Architecture

- **📱 Mobile App** – Flutter (Riverpod, GoRouter, Dio, Hive)
- **🌐 Admin Web** – React + Vite + TypeScript + Tailwind
- **⚙ Backend API** – NestJS + Prisma + PostgreSQL
- **🗄 Database** – PostgreSQL 16
- **📦 Cache** – Redis 7
- **🐳 Docker** – Full containerization

## Quick Start

### Prerequisites
- Docker & Docker Compose
- Node.js 20+ & Yarn (for development)
- Flutter 3.x (for mobile development)

### Run with Docker (Production)
```bash
docker compose -f docker/docker-compose.yml up --build
```

Services will be available at:
| Service | URL |
|---------|-----|
| API | http://localhost:3000 |
| API Docs (Swagger) | http://localhost:3000/api/docs |
| Admin Web | http://localhost:5173 |
| PgAdmin | http://localhost:5050 |

### Default Admin Credentials
- **Email:** admin@koreanapp.com
- **Password:** Admin123!

### Development Setup

```bash
# Install dependencies
yarn install

# Start all services in dev mode
yarn dev

# Or start individually
cd apps/api && yarn dev
cd apps/admin-web && yarn dev
```

### Flutter Mobile

```bash
cd apps/mobile
flutter pub get
flutter run
```

## Project Structure

```
korean-learning-platform/
├── apps/
│   ├── mobile/          # Flutter mobile app
│   ├── admin-web/       # React admin dashboard
│   └── api/             # NestJS backend API
├── packages/
│   ├── shared-types/    # Shared TypeScript types
│   ├── eslint-config/   # Shared ESLint configuration
│   └── tsconfig/        # Shared TypeScript configs
├── docker/
│   └── docker-compose.yml
└── README.md
```

## Features

### Backend API
- JWT Authentication with Role-based Access Control
- Full CRUD for Courses, Sections, Lessons, Vocabulary, Grammar, Dialogues, Quizzes
- Spaced Repetition System (SRS) for vocabulary review
- AI module for writing correction and quiz generation
- Gamification (XP, Streaks, Badges, Leaderboard)
- Subscription management with mock payment
- File upload (audio/images)
- WebSocket real-time updates
- Analytics tracking
- Swagger API documentation

### Admin Web
- Dashboard with analytics
- Complete content management
- User administration
- Audio upload management
- CSV import/export
- Rich text editor

### Mobile App
- Course browsing and lesson completion
- Vocabulary flashcards with SRS
- Grammar lessons
- Dialogue practice with audio
- Quiz system
- AI-powered writing practice
- Speaking practice
- Offline learning support
- Dark mode
- Leaderboard

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Mobile | Flutter, Riverpod, GoRouter, Dio, Hive |
| Admin Web | React, Vite, TypeScript, Tailwind, React Query, Zustand |
| Backend | NestJS, Prisma, PostgreSQL, Redis, BullMQ |
| Infrastructure | Docker, Turborepo, Yarn Workspaces |
