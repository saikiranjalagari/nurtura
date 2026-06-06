# Nurtura API

Local Node.js + PostgreSQL backend for the Nurtura Flutter app.

## Requirements

- **Node.js** 18+ (installed: v22)
- **PostgreSQL** — auto-started via `embedded-postgres` if not installed system-wide

## Quick start

```powershell
cd api
npm install
npm start
```

Server runs at **http://localhost:3000**

- Health: `GET /api/health`
- Demo user id: `1` (seeded as Priya Sharma)

## Database

- **Name:** `nurtura`
- **User:** `postgres`
- **Password:** `postgres`
- **Port:** `5432`
- **Data folder:** `api/data/pg` (embedded PostgreSQL)

Manual setup (optional):

```powershell
npm run db:setup
```

## API endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/health` | Health check |
| POST | `/api/users/register` | Create user profile |
| GET | `/api/users/:id` | Get user |
| GET | `/api/home/:userId` | Home dashboard |
| GET | `/api/pregnancy/weeks/:week` | Week details |
| GET | `/api/diet/foods` | Diet foods by category |
| PUT | `/api/diet/water/:userId` | Update water tracker |
| GET | `/api/emergency/symptoms` | Emergency symptoms |
| GET | `/api/appointments/:userId` | List appointments |
| POST | `/api/appointments/:userId` | Add appointment |
| GET | `/api/chat/:userId` | Chat history |
| POST | `/api/chat/:userId` | Send message (rule-based AI) |

## Flutter app

```powershell
cd ..
flutter pub get
flutter run -d chrome
```

Use **Login (Demo User)** for instant access, or **Get Started** to register a new profile.
