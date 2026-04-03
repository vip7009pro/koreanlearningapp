# 🇰🇷 Korean Learning Platform for Professionals

A comprehensive, AI-powered Korean learning platform tailored specifically for Vietnamese professionals working at Korean companies or preparing for certification exams like TOPIK. This monorepo contains the entire ecosystem: Mobile App, Admin Dashboard, and Backend services.

## 🏗 System Architecture & Tech Stack

This project is built using a modern decoupled architecture inside a Turborepo monorepo workspace.

### 📱 Mobile App (Cross-Platform)
- **Framework:** Flutter (3.x)
- **State Management:** Riverpod
- **Routing:** GoRouter
- **Networking:** Dio
- **Local Storage/Cache:** Hive
- **Media & Audio:** `audioplayers` (Audio playback & TTS integration)
- **UI Architecture:** Material 3, specialized for rich learning interfaces (Flashcards, Quizzes, Exam UI)

### 🌐 Admin Web Interface
- **Framework:** React + Vite
- **Language:** TypeScript
- **Styling:** TailwindCSS
- **State Management:** Zustand (Global State) + React Query (Server State)
- **Routing:** React Router DOM
- **UI Components:** Lucide React (Icons)

### ⚙️ Backend API
- **Framework:** NestJS
- **Language:** TypeScript
- **Database ORM:** Prisma
- **Database:** PostgreSQL 16
- **Caching & Job Queue:** Redis 7 + BullMQ
- **Authentication:** JWT with strict Role-based Access Control (User/Admin)
- **AI Integration:** OpenRouter API / Google Gemini API (for LLM interactions)

### 🚀 Infrastructure & DevOps
- **Containerization:** Full Docker support (`docker-compose`)
- **Monorepo Management:** Turborepo, Yarn Workspaces
- **Shared Packages:** Shared ESLint configs, Prettier, TypeScript configs.

---

## ✨ Core Features

### 🎓 Content Delivery & Learning Modules
- **Structured Courses:** Hierarchical structure (`Course` → `Section` → `Lesson`).
- **Rich Lesson Components:** 
  - **Vocabulary:** Interactive flashcards with **Swipe Gestures** and Spaced Repetition (SRS).
  - **Grammar:** Pattern explanations with Vietnamese translations and examples.
  - **Dialogues:** Multi-character conversations with sequential audio playback.
  - **Quizzes:** Multiple-choice, True/False, Fill-In-The-Blanks.
- **TOPIK Exam Preparation:** Full simulation of TOPIK I & II.
  - **Listening Sections:** With audio playback and Korean transcripts.
  - **Reading Sections:** Complex comprehension passages.
  - **Writing Sections:** `SHORT_TEXT` and `ESSAY` formats with AI evaluation.
- **Gamification:** Experience Points (XP) progression, configurable Daily Goals, Streaks, Leaderboards, and Achievements.

### 🤖 First-Class AI Integration
- **AI Writing Evaluator:** Real-time feedback for writing practice. OpenRouter integration to assess grammar, vocabulary usage, and naturalness. Includes dynamically configurable default writing topics.
- **Content Generation Pipeline ("Copy Prompt" Workflow):**
  - High-quality, context-aware prompt generation for courses and exams.
  - Cross-platform support (Web & Mobile Admin) to generate prompts, copy to powerful external LLMs (e.g., GPT-4, Claude 3.5 Sonnet, Gemini 2.0).
  - Admins can simply paste the generated JSON back into bulk-import tools.
  - System enforces strict schema, duplicate checking (`existingKorean` for vocab), and correct JSON structures.

### 🛠 Powerful Admin Capabilities (Web & Mobile)
- **Bulk Import System:** Mass import JSON data for vocab, grammar, dialogues, quizzes, and massive TOPIK exam payloads.
- **Mobile Admin Dashboard:** Allows authorized admins to review, edit, and bulk-load data or TOPIK exams directly from their mobile devices while on the go.
- **Audio & Media Management:** Attachment tracking for dialogue lines, vocab terms, and listening exams.
- **Analytics:** Basic dashboard reporting for user activity and completion limits.

---

## 🚀 Quick Start Guide

### Prerequisites
- Node.js 20+ & Yarn (for development)
- Docker & Docker Compose (for database & cache)
- Flutter 3.x (for mobile application)
- API Keys: To employ AI features, an [OpenRouter](https://openrouter.ai/) or Gemini API Key is required.

### 1. Running the Backend Ecosystem (Dev Mode)
First, spin up PostgreSQL and Redis using Docker:

```bash
docker compose -f docker/docker-compose.yml up -d db redis pgadmin
```

Install dependencies, run Prisma migrations, and start the development servers:
```bash
yarn install

# Run database migrations and seed default Admin user
cd apps/api
yarn prisma migrate dev
yarn prisma db seed

# Run the API and Admin-Web simultaneously
cd ../../ 
yarn dev
```

| Service | URL / Port |
|---------|------------|
| Backend API | `http://localhost:3000` |
| Swagger Docs | `http://localhost:3000/api/docs` |
| Admin Web UI | `http://localhost:5173` |

**Default Admin Account:**
- **Email:** `admin@koreanapp.com`
- **Password:** `Admin123!`

### 2. Running the Flutter App

Ensure you have a connected device or running simulator.

```bash
cd apps/mobile
flutter pub get
flutter run
```

*Note: For the Flutter app to access the local backend on an Android Emulator, ensure network configurations map `localhost` to `10.0.2.2`, or configure the `api_client.dart` with your machine's local IP address.*

---

## 📁 Repository Structure

```text
koreanlearningapp/
├── apps/
│   ├── api/             # NestJS Backend API (Services, Prisma Schema, Controllers)
│   ├── admin-web/       # React SPA for Content Management
│   └── mobile/          # Flutter Application (User App + Mobile Admin Features)
├── packages/
│   ├── eslint-config/   # Shared code style governance
│   └── tsconfig/        # Common TypeScript configurations
├── docker/              # Docker compose configurations for dependencies
├── sample_course_import.json # Reference data format for JSON imports
└── README.md
```

## 🔐 Security & Validation

- All endpoints are heavily guarded with robust NestJS Guards (AuthGuard, RolesGuard).
- The JSON bulk import pipeline includes strict backend DTO validation to sanitize, catch, and repair AI-generated hallucinations prior to database ingestion.
- Secure environment separation (development, staging, production) managed via `.env` variables (e.g., `JWT_SECRET`, `OPENROUTER_API_KEY`, `DATABASE_URL`).
