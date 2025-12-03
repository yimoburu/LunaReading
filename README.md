# LunaReading - Reading Comprehension Practice Platform

A web application designed to help elementary students practice their reading comprehension skills with AI-powered question generation and feedback.

## Features

- **User Management**: Create profiles with grade level specification
- **Adaptive Question Generation**: AI generates questions slightly above the student's current reading level
- **Interactive Answering**: Students answer questions through a user-friendly web interface
- **AI-Powered Feedback**: Receive constructive feedback and refine answers until they meet the standard
- **Progress Tracking**: View history of all reading sessions
- **Reading Level Assessment**: Automatic assessment of reading level based on answer quality

## Tech Stack

- **Backend**: Flask (Python)
- **Frontend**: React
- **Database**: SQLite
- **AI**: OpenAI GPT-4

## Setup Instructions

### Prerequisites

- Python 3.8+
- Node.js 16+
- OpenAI API key

### Backend Setup

1. Navigate to the project root directory
2. Create a virtual environment:
   ```bash
   python3 -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

4. Create a `.env` file in the root directory:
   ```bash
   cp .env.example .env
   ```

5. Edit `.env` and add your OpenAI API key:
   ```
   OPENAI_API_KEY=your-openai-api-key-here
   JWT_SECRET_KEY=your-secret-key-change-in-production
   ```

6. Run the backend server:
   ```bash
   cd backend
   python app.py
   ```

The backend will run on `http://localhost:5001` (port 5000 is often used by macOS AirPlay)

### Frontend Setup

1. Navigate to the frontend directory:
   ```bash
   cd frontend
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Start the development server:
   ```bash
   npm start
   ```

The frontend will run on `http://localhost:3000` and will proxy API requests to the backend on port 5001

## Usage

1. **Register**: Create a new account with your grade level
2. **Create Session**: Specify a book, chapter, and number of questions
3. **Answer Questions**: Read and answer the generated comprehension questions
4. **Receive Feedback**: Get AI-powered feedback on your answers
5. **Refine Answers**: Improve your answers based on feedback until they meet the standard
6. **Track Progress**: View your history and see your reading level improve

## Project Structure

```
LunaReading/
├── backend/
│   └── app.py              # Flask backend application
├── frontend/
│   ├── public/
│   ├── src/
│   │   ├── components/     # React components
│   │   ├── context/        # Auth context
│   │   └── App.js          # Main app component
│   └── package.json
├── requirements.txt        # Python dependencies
├── .env.example           # Environment variables template
└── README.md
```

## API Endpoints

- `POST /api/register` - Register a new user
- `POST /api/login` - Login user
- `GET /api/profile` - Get user profile
- `PUT /api/profile` - Update user profile
- `POST /api/sessions` - Create a new reading session
- `GET /api/sessions` - Get all user sessions
- `GET /api/sessions/<id>` - Get a specific session
- `POST /api/questions/<id>/answer` - Submit an answer
- `GET /api/questions/<id>/answers` - Get all answers for a question

## Notes

- Make sure to keep your OpenAI API key secure and never commit it to version control
- The reading level assessment adjusts based on performance over time
- Questions are generated to be slightly challenging but appropriate for the student's level

