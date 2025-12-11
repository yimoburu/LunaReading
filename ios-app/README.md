# LunaReading iOS App

A native iOS app that connects to the LunaReading backend, similar to the web frontend.

## Project Structure

```
LunaReadingApp/
├── LunaReadingApp.swift          # App entry point
├── Models/
│   ├── User.swift
│   └── Session.swift
├── Services/
│   └── APIService.swift          # API client (similar to axios in frontend)
├── ViewModels/
│   └── AuthViewModel.swift      # Auth state (similar to AuthContext)
└── Views/
    ├── LoginView.swift
    ├── RegisterView.swift
    ├── DashboardView.swift
    ├── SessionCreateView.swift
    ├── SessionView.swift
    └── HistoryView.swift
```

## Setup Instructions

### 1. Create Xcode Project

1. Open Xcode
2. File → New → Project
3. Choose **iOS → App**
4. Configure:
   - Product Name: `LunaReadingApp`
   - Interface: **SwiftUI**
   - Language: **Swift**
5. Save to desired location

### 2. Add Files

1. Copy all files from this `ios-app/LunaReadingApp/` folder into your Xcode project
2. Maintain the folder structure
3. Make sure all files are added to the target

### 3. Configure

- The API URL is already set in `APIService.swift`:
  ```swift
  private let baseURL = "https://lunareading-backend-bkumsoprkq-uc.a.run.app"
  ```

### 4. Run

- Build: ⌘B
- Run: ⌘R

## Features

- ✅ Login/Register (same as web frontend)
- ✅ Dashboard with user info
- ✅ Create reading sessions
- ✅ Answer questions with AI feedback
- ✅ View session history
- ✅ JWT token authentication

## API Endpoints Used

Same as the web frontend:
- `POST /api/login`
- `POST /api/register`
- `GET /api/profile`
- `POST /api/sessions`
- `GET /api/sessions`
- `GET /api/sessions/{id}`
- `POST /api/questions/{id}/answer`

## Requirements

- iOS 15.0+
- Xcode 14.0+
- Swift 5.7+
