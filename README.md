# MindLog - 감성 다이어리 프로젝트

## 📌 프로젝트 소개

**MindLog**는 이미지 기반 태그 추출과 감성 분석을 활용하여 사용자에게 맞춤형 음악을 추천하는 **감성 다이어리 앱**입니다. 사용자는 간단한 텍스트와 이미지를 업로드하여 자신의 감정을 기록하고, AI 모델이 이를 분석하여 감성에 맞는 음악을 추천합니다.

---

## 🎯 주요 기능

### 📝 **일기 작성 및 감성 분석**

- 사용자는 텍스트와 이미지를 업로드하여 감성을 기록할 수 있습니다.
- AI 모델이 사용자의 감정을 분석하여 감성 태그를 자동 생성합니다.

### 🎵 **음악 추천**

- 감성 분석 결과를 바탕으로 Spotify 또는 Apple Music API를 활용하여 맞춤형 음악을 추천합니다.

### 🏷 **이미지 태그 생성**

- 사용자가 업로드한 이미지를 AI 모델이 분석하여 자동으로 태그를 생성합니다.

### 📊 **감정 변화 시각화**

- 사용자의 감정 변화를 그래프로 표현하여 감성 일기의 흐름을 시각적으로 확인할 수 있습니다.

---

## 🔧 기술 스택

### 📱 **프론트엔드 (iOS)**

- **Swift** (UIKit / SwiftUI)
- **Combine / Alamofire** (API 통신)

### ⚙️ **백엔드**

- **FastAPI** (Python 기반 API 서버)
- **PostgreSQL** (데이터베이스)
- **SQLAlchemy** (ORM)
- **Docker & Docker Compose**

### 🧠 **AI 서버**

- **FastAPI** (AI 모델 엔드포인트)
- **Hugging Face Transformers** (감성 분석 모델)
- **OpenAI CLIP / BLIP** (이미지 캡셔닝 및 태그 추출)
- **DVC** (데이터 및 모델 버전 관리)

### 🔧 **배포 및 관리**

- **GitHub Actions** (CI/CD 자동화)
- **Docker Compose** (로컬 개발환경 통합 실행)

---

## 📂 프로젝트 폴더 구조

```
mindlog-project/
├── backend/          # FastAPI 기반 백엔드 서버
│   ├── app/
│   │   ├── main.py   # API 엔트리 포인트
│   │   ├── routers/  # API 엔드포인트 관리
│   ├── Dockerfile    # 백엔드 서버 Docker 설정
│   ├── requirements.txt  # 백엔드 패키지 목록
│
├── ai-server/        # AI 모델 서버
│   ├── app/
│   │   ├── main.py   # AI API 엔트리 포인트
│   │   ├── models/   # AI 모델 로딩 및 실행
│   │   ├── inference.py # 추론 로직
│   ├── Dockerfile    # AI 서버 Docker 설정
│   ├── requirements.txt  # AI 서버 패키지 목록
│
├── ios/              # iOS 프론트엔드 (Swift)
│   ├── MindLog.xcodeproj  # Xcode 프로젝트 파일
│   ├── MindLog/      # iOS 앱 코드
│   ├── Podfile       # CocoaPods 의존성 관리
│
├── docker-compose.yml # 전체 서비스 실행을 위한 Docker Compose 설정
├── .github/workflows/ # CI/CD 자동화 스크립트
│
├── README.md         # 프로젝트 소개 및 실행 방법
└── .gitignore        # Git 관리 제외 파일 목록
```

---

## 🚀 실행 방법

### 1️⃣ **로컬 개발 환경 실행**

```bash
docker-compose up --build
```

위 명령어를 실행하면 백엔드, AI 서버, 데이터베이스가 함께 실행됩니다.

### 2️⃣ **백엔드 단독 실행**

```bash
cd backend
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### 3️⃣ **AI 서버 실행**

```bash
cd ai-server
uvicorn app.main:app --reload --host 0.0.0.0 --port 8001
```

---

## 🤝 팀원

| 이름   | 역할                          |
| ------ | ----------------------------- |
| 임재민 | iOS 개발, 데이터 시각화       |
| 김정인 | 백엔드, iOS 연동, 시스템 통합 |
| 조석희 | AI 모델 개발 및 음악 추천     |
| 이재우 | UI/UX 디자인, 제품 방향성     |

---

## 📌 향후 개발 계획

- **OAuth 로그인 기능 추가**
- **감정 기반 자동 태그 추천 기능 개선**
- **Spotify / Apple Music 연동 강화**
- **감성 시각화 인터페이스 개선**

---

## 📜 라이선스

이 프로젝트는 MIT 라이선스를 따릅니다.

📩 문의: [팀 이메일 또는 GitHub Issue 활용]
