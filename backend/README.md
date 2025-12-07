# LunaReading Backend Structure

This directory contains the Flask backend application organized in a modular structure.

## Directory Structure

```
backend/
├── __init__.py          # Application factory pattern
├── app.py              # Main entry point
├── config.py           # Configuration management
├── cloudsql_client.py   # Cloud SQL client wrapper
├── utils.py            # Utility functions
└── routes/             # Route handlers organized by feature
    ├── __init__.py
    ├── auth.py         # Authentication routes (register, login)
    ├── profile.py      # User profile routes
    ├── sessions.py     # Reading session routes
    ├── questions.py    # Question and answer routes
    └── admin.py        # Admin routes
```

## File Descriptions

### Core Files

- **`__init__.py`**: Creates the Flask application instance using the factory pattern. Initializes extensions (CORS, JWT) and Cloud SQL client, and registers all blueprints.

- **`app.py`**: Main entry point for running the application. Can be run directly with `python backend/app.py` or with gunicorn: `gunicorn backend.app:app`.

- **`config.py`**: Manages all configuration including:
  - Database connection (Cloud SQL MySQL via Cloud SQL Connector)
  - JWT settings
  - OpenAI API key
  - Environment variable loading

- **`cloudsql_client.py`**: Cloud SQL client wrapper using Google Cloud SQL Connector:
  - Handles all database operations
  - Manages connections securely
  - Provides CRUD operations for all entities

- **`utils.py`**: Utility functions for:
  - OpenAI API calls with error handling
  - JSON response cleaning
  - User reading level updates

### Route Files

All routes are organized into blueprints by feature:

- **`routes/auth.py`**: User registration and login
  - `POST /api/register` - Register new user
  - `POST /api/login` - Login and get token

- **`routes/profile.py`**: User profile management
  - `GET /api/profile` - Get current user profile
  - `PUT /api/profile` - Update user profile

- **`routes/sessions.py`**: Reading session management
  - `POST /api/sessions` - Create new session with AI-generated questions
  - `GET /api/sessions` - Get all user sessions
  - `GET /api/sessions/<id>` - Get specific session

- **`routes/questions.py`**: Question and answer handling
  - `POST /api/questions/<id>/answer` - Submit answer and get AI evaluation
  - `GET /api/questions/<id>/answers` - Get all answers for a question

- **`routes/admin.py`**: Admin functionality
  - `GET /api/admin/users` - Get all users with statistics

## Running the Application

### Development

**Option 1: Run from project root (recommended)**
```bash
# From project root directory
python run_backend.py
```

**Option 2: Run as module**
```bash
# From project root directory
python -m backend.app
```

**Option 3: Run directly**
```bash
# From project root directory
python backend/app.py
```

### Production (with gunicorn)
```bash
# From project root directory
gunicorn backend.app:app --bind 0.0.0.0:8080
```

**Note:** Make sure you're in the project root directory when running any of these commands, and that your virtual environment is activated.

## Benefits of This Structure

1. **Modularity**: Each feature is in its own file, making it easy to find and modify code
2. **Scalability**: Easy to add new routes or features without cluttering a single file
3. **Maintainability**: Clear separation of concerns (config, models, routes, utils)
4. **Testability**: Each module can be tested independently
5. **Organization**: Related code is grouped together logically

## Adding New Features

1. **New Route**: Create a new file in `routes/` or add to an existing one
2. **New Database Table**: Add table creation SQL to `cloudsql_client.py` `_ensure_tables_exist()` method
3. **New Utility**: Add to `utils.py`
4. **New Config**: Add to `config.py`
5. **Register Blueprint**: Import and register in `__init__.py`

## Dependencies

All dependencies are listed in `requirements.txt` at the project root.

