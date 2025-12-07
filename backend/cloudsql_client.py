"""
Cloud SQL client using Google Cloud SQL Connector

This module provides a database client using the standard Google Cloud SQL Connector
pattern for secure connections to Cloud SQL instances.
"""

import os
import warnings
from typing import Optional, List, Dict, Any
from google.cloud.sql.connector import Connector
import pymysql
from contextlib import contextmanager

# Suppress TLS version warnings from Cloud SQL Connector
# These warnings occur when LibreSSL doesn't support TLSv1.3,
# but the connector automatically falls back to TLSv1.2 which is secure.
warnings.filterwarnings('ignore', message='.*TLSv1.3.*', category=UserWarning)
warnings.filterwarnings('ignore', message='.*OpenSSL.*', category=UserWarning)


class CloudSQLClient:
    """
    Client for Cloud SQL operations using Google Cloud SQL Connector.
    
    This follows the standard Google Cloud SQL Connector pattern:
    - Single Connector instance (thread-safe, reusable)
    - Connection pooling handled by the connector
    - Proper connection lifecycle management
    """
    
    def __init__(self, instance_connection_name: str, database: str, 
                 user: str, password: str, driver: str = "pymysql"):
        """
        Initialize Cloud SQL client with standard connector pattern.
        
        Args:
            instance_connection_name: Cloud SQL instance connection name (format: project:region:instance)
            database: Database name
            user: Database user
            password: Database password
            driver: Database driver ('pymysql' for MySQL)
        """
        self.instance_connection_name = instance_connection_name
        self.database = database
        self.user = user
        self.password = password
        self.driver = driver
        
        # Initialize connector (thread-safe, reusable, handles connection pooling)
        # This is the standard pattern: create one Connector instance per application
        self.connector = Connector()
        
        # Track if tables have been created (lazy initialization)
        self._tables_created = False
    
    def _get_connection(self):
        """
        Get a database connection using the standard connector pattern.
        
        This is the standard way to get connections with google.cloud.sql.connector:
        - connector.connect() returns a connection object
        - Connection is automatically managed by the connector
        - Connection pooling is handled internally
        
        Returns:
            Connection object from the connector
        """
        return self.connector.connect(
            self.instance_connection_name,
            self.driver,
            user=self.user,
            password=self.password,
            db=self.database,
        )
    
    @contextmanager
    def get_connection(self):
        """
        Get a database connection context manager.
        
        This follows the standard pattern:
        - Get connection from connector
        - Yield connection for use
        - Automatically close connection when done
        
        Usage:
            with db_client.get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("SELECT * FROM users")
        """
        # Ensure tables exist on first connection (lazy initialization)
        if not self._tables_created:
            try:
                self._ensure_tables_exist()
                self._tables_created = True
            except Exception as e:
                print(f"⚠️  Warning: Could not create tables on first connection: {e}")
                # Continue anyway - tables might already exist
        
        # Get connection using standard connector pattern
        conn = self._get_connection()
        try:
            yield conn
        finally:
            conn.close()
    
    def _ensure_tables_exist(self):
        """Create tables if they don't exist (lazy initialization)"""
        conn = self._get_connection()
        try:
            cursor = conn.cursor()
            
            # Verify we're connected to the correct database
            cursor.execute("SELECT DATABASE()")
            current_db = cursor.fetchone()[0]
            
            if current_db != self.database:
                raise ValueError(
                    f"Connected to wrong database. Expected '{self.database}', "
                    f"but connected to '{current_db}'. "
                    f"Please ensure database '{self.database}' exists. "
                    f"Run: ./scripts/initialize_database.sh"
                )
            
            # Users table
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS users (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    username VARCHAR(80) UNIQUE NOT NULL,
                    email VARCHAR(120) UNIQUE NOT NULL,
                    password_hash VARCHAR(255) NOT NULL,
                    grade_level INT NOT NULL,
                    reading_level FLOAT DEFAULT 0.0,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)
            
            # Reading sessions table
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS reading_sessions (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    user_id INT NOT NULL,
                    book_title VARCHAR(200) NOT NULL,
                    chapter VARCHAR(100) NOT NULL,
                    total_questions INT NOT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    completed_at TIMESTAMP NULL,
                    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
                )
            """)
            
            # Questions table
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS questions (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    session_id INT NOT NULL,
                    question_text TEXT NOT NULL,
                    question_number INT NOT NULL,
                    model_answer TEXT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (session_id) REFERENCES reading_sessions(id) ON DELETE CASCADE
                )
            """)
            
            # Answers table
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS answers (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    question_id INT NOT NULL,
                    answer_text TEXT NOT NULL,
                    feedback TEXT,
                    score FLOAT,
                    rating INT,
                    examples TEXT,
                    is_final BOOLEAN DEFAULT FALSE,
                    submission_type VARCHAR(20) DEFAULT 'initial',
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (question_id) REFERENCES questions(id) ON DELETE CASCADE
                )
            """)
            
            conn.commit()
            cursor.close()
            print("✅ Database tables created/verified successfully")
        except Exception as e:
            error_msg = str(e).lower()
            if 'database' in error_msg and ('doesn\'t exist' in error_msg or 'does not exist' in error_msg or 'unknown database' in error_msg):
                raise ValueError(
                    f"Database '{self.database}' does not exist. "
                    f"Please create it first by running: ./scripts/initialize_database.sh"
                ) from e
            elif 'table' in error_msg and 'mysql.' in error_msg:
                raise ValueError(
                    f"Database connection error. It appears the database '{self.database}' may not exist "
                    f"or the connection is using the wrong database. "
                    f"Please run: ./scripts/initialize_database.sh to create the database and tables."
                ) from e
            else:
                print(f"❌ Error creating database tables: {e}")
                import traceback
                print(f"Error traceback: {traceback.format_exc()}")
                raise
        finally:
            conn.close()
    
    # User operations
    def insert_user(self, username: str, email: str, password_hash: str, 
                   grade_level: int, reading_level: float = None) -> int:
        """Insert a new user and return the ID"""
        with self.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                INSERT INTO users (username, email, password_hash, grade_level, reading_level)
                VALUES (%s, %s, %s, %s, %s)
            """, (username, email, password_hash, grade_level, reading_level))
            user_id = cursor.lastrowid
            conn.commit()
            cursor.close()
            return user_id
    
    def get_user_by_id(self, user_id: int) -> Optional[Dict[str, Any]]:
        """Get user by ID"""
        with self.get_connection() as conn:
            cursor = conn.cursor(pymysql.cursors.DictCursor)
            cursor.execute("""
                SELECT id, username, email, password_hash, grade_level, reading_level, created_at
                FROM users
                WHERE id = %s
            """, (user_id,))
            user = cursor.fetchone()
            cursor.close()
            return user
    
    def get_user_by_username(self, username: str) -> Optional[Dict[str, Any]]:
        """Get user by username"""
        with self.get_connection() as conn:
            cursor = conn.cursor(pymysql.cursors.DictCursor)
            cursor.execute("""
                SELECT id, username, email, password_hash, grade_level, reading_level, created_at
                FROM users
                WHERE username = %s
            """, (username,))
            user = cursor.fetchone()
            cursor.close()
            return user
    
    def get_user_by_email(self, email: str) -> Optional[Dict[str, Any]]:
        """Get user by email"""
        with self.get_connection() as conn:
            cursor = conn.cursor(pymysql.cursors.DictCursor)
            cursor.execute("""
                SELECT id, username, email, password_hash, grade_level, reading_level, created_at
                FROM users
                WHERE email = %s
            """, (email,))
            user = cursor.fetchone()
            cursor.close()
            return user
    
    def update_user(self, user_id: int, **kwargs):
        """Update user fields"""
        if not kwargs:
            return
        
        set_clauses = []
        values = []
        
        for key, value in kwargs.items():
            if key in ['grade_level', 'reading_level']:
                set_clauses.append(f"{key} = %s")
                values.append(value)
        
        if set_clauses:
            values.append(user_id)
            with self.get_connection() as conn:
                cursor = conn.cursor()
                query = f"UPDATE users SET {', '.join(set_clauses)} WHERE id = %s"
                cursor.execute(query, values)
                conn.commit()
                cursor.close()
    
    def get_all_users(self) -> List[Dict[str, Any]]:
        """Get all users"""
        with self.get_connection() as conn:
            cursor = conn.cursor(pymysql.cursors.DictCursor)
            cursor.execute("""
                SELECT id, username, email, password_hash, grade_level, reading_level, created_at
                FROM users
                ORDER BY created_at DESC
            """)
            users = cursor.fetchall()
            cursor.close()
            return users
    
    # Session operations
    def insert_session(self, user_id: int, book_title: str, chapter: str, 
                      total_questions: int) -> int:
        """Insert a new reading session and return the ID"""
        with self.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                INSERT INTO reading_sessions (user_id, book_title, chapter, total_questions)
                VALUES (%s, %s, %s, %s)
            """, (user_id, book_title, chapter, total_questions))
            session_id = cursor.lastrowid
            conn.commit()
            cursor.close()
            return session_id
    
    def get_session_by_id(self, session_id: int, user_id: Optional[int] = None) -> Optional[Dict[str, Any]]:
        """Get session by ID, optionally filtered by user_id"""
        with self.get_connection() as conn:
            cursor = conn.cursor(pymysql.cursors.DictCursor)
            if user_id:
                cursor.execute("""
                    SELECT id, user_id, book_title, chapter, total_questions, created_at, completed_at
                    FROM reading_sessions
                    WHERE id = %s AND user_id = %s
                """, (session_id, user_id))
            else:
                cursor.execute("""
                    SELECT id, user_id, book_title, chapter, total_questions, created_at, completed_at
                    FROM reading_sessions
                    WHERE id = %s
                """, (session_id,))
            session = cursor.fetchone()
            cursor.close()
            return session
    
    def get_sessions_by_user(self, user_id: int) -> List[Dict[str, Any]]:
        """Get all sessions for a user"""
        with self.get_connection() as conn:
            cursor = conn.cursor(pymysql.cursors.DictCursor)
            cursor.execute("""
                SELECT id, user_id, book_title, chapter, total_questions, created_at, completed_at
                FROM reading_sessions
                WHERE user_id = %s
                ORDER BY created_at DESC
            """, (user_id,))
            sessions = cursor.fetchall()
            cursor.close()
            return sessions
    
    def update_session(self, session_id: int, completed_at: Optional[str] = None):
        """Update session"""
        if completed_at is None:
            return
        
        with self.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                UPDATE reading_sessions
                SET completed_at = %s
                WHERE id = %s
            """, (completed_at, session_id))
            conn.commit()
            cursor.close()
    
    # Question operations
    def insert_question(self, session_id: int, question_text: str, question_number: int, 
                       model_answer: Optional[str] = None) -> int:
        """Insert a new question and return the ID"""
        with self.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                INSERT INTO questions (session_id, question_text, question_number, model_answer)
                VALUES (%s, %s, %s, %s)
            """, (session_id, question_text, question_number, model_answer))
            question_id = cursor.lastrowid
            conn.commit()
            cursor.close()
            return question_id
    
    def get_question_by_id(self, question_id: int) -> Optional[Dict[str, Any]]:
        """Get question by ID"""
        with self.get_connection() as conn:
            cursor = conn.cursor(pymysql.cursors.DictCursor)
            cursor.execute("""
                SELECT id, session_id, question_text, question_number, model_answer, created_at
                FROM questions
                WHERE id = %s
            """, (question_id,))
            question = cursor.fetchone()
            cursor.close()
            return question
    
    def get_questions_by_session(self, session_id: int) -> List[Dict[str, Any]]:
        """Get all questions for a session"""
        with self.get_connection() as conn:
            cursor = conn.cursor(pymysql.cursors.DictCursor)
            cursor.execute("""
                SELECT id, session_id, question_text, question_number, model_answer, created_at
                FROM questions
                WHERE session_id = %s
                ORDER BY question_number
            """, (session_id,))
            questions = cursor.fetchall()
            cursor.close()
            return questions
    
    # Answer operations
    def insert_answer(self, question_id: int, answer_text: str, feedback: Optional[str] = None,
                     score: Optional[float] = None, rating: Optional[int] = None,
                     examples: Optional[str] = None, is_final: bool = False,
                     submission_type: str = "initial") -> int:
        """Insert a new answer and return the ID"""
        with self.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                INSERT INTO answers (question_id, answer_text, feedback, score, rating, examples, is_final, submission_type)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            """, (question_id, answer_text, feedback, score, rating, examples, is_final, submission_type))
            answer_id = cursor.lastrowid
            conn.commit()
            cursor.close()
            return answer_id
    
    def get_answers_by_question(self, question_id: int) -> List[Dict[str, Any]]:
        """Get all answers for a question"""
        with self.get_connection() as conn:
            cursor = conn.cursor(pymysql.cursors.DictCursor)
            cursor.execute("""
                SELECT id, question_id, answer_text, feedback, score, rating, examples, is_final, submission_type, created_at
                FROM answers
                WHERE question_id = %s
                ORDER BY created_at ASC
            """, (question_id,))
            answers = cursor.fetchall()
            cursor.close()
            return answers
    
    def get_final_answer_by_question(self, question_id: int) -> Optional[Dict[str, Any]]:
        """Get the final answer for a question"""
        with self.get_connection() as conn:
            cursor = conn.cursor(pymysql.cursors.DictCursor)
            cursor.execute("""
                SELECT id, question_id, answer_text, feedback, score, rating, examples, is_final, submission_type, created_at
                FROM answers
                WHERE question_id = %s AND is_final = TRUE
                ORDER BY created_at DESC
                LIMIT 1
            """, (question_id,))
            answer = cursor.fetchone()
            cursor.close()
            return answer
    
    def get_initial_answer_by_question(self, question_id: int) -> Optional[Dict[str, Any]]:
        """Get the initial answer for a question"""
        with self.get_connection() as conn:
            cursor = conn.cursor(pymysql.cursors.DictCursor)
            cursor.execute("""
                SELECT id, question_id, answer_text, feedback, score, rating, examples, is_final, submission_type, created_at
                FROM answers
                WHERE question_id = %s AND submission_type = 'initial'
                ORDER BY created_at ASC
                LIMIT 1
            """, (question_id,))
            answer = cursor.fetchone()
            cursor.close()
            return answer
    
    # Statistics operations
    def check_session_completed(self, session_id: int) -> bool:
        """Check if all questions in a session have final answers"""
        with self.get_connection() as conn:
            cursor = conn.cursor(pymysql.cursors.DictCursor)
            cursor.execute("""
                SELECT 
                    COUNT(DISTINCT q.id) as total_questions,
                    SUM(CASE WHEN a.is_final = TRUE THEN 1 ELSE 0 END) as completed_questions
                FROM questions q
                LEFT JOIN answers a ON q.id = a.question_id AND a.is_final = TRUE
                WHERE q.session_id = %s
            """, (session_id,))
            result = cursor.fetchone()
            cursor.close()
            if result:
                return result['total_questions'] > 0 and result['completed_questions'] == result['total_questions']
            return False
    
    def get_session_statistics(self, session_id: int) -> Dict[str, Any]:
        """Get statistics for a session"""
        with self.get_connection() as conn:
            cursor = conn.cursor(pymysql.cursors.DictCursor)
            cursor.execute("""
                SELECT 
                    COUNT(DISTINCT q.id) as total_questions,
                    COUNT(DISTINCT CASE WHEN a.is_final = TRUE THEN q.id END) as completed_questions
                FROM questions q
                LEFT JOIN answers a ON q.id = a.question_id AND a.is_final = TRUE
                WHERE q.session_id = %s
            """, (session_id,))
            result = cursor.fetchone()
            cursor.close()
            if result:
                return {
                    'total_questions': result['total_questions'] or 0,
                    'completed_questions': result['completed_questions'] or 0
                }
            return {'total_questions': 0, 'completed_questions': 0}
    
    def get_user_session_stats(self, user_id: int) -> Dict[str, Any]:
        """Get statistics for all sessions of a user"""
        with self.get_connection() as conn:
            cursor = conn.cursor(pymysql.cursors.DictCursor)
            cursor.execute("""
                SELECT 
                    COUNT(DISTINCT s.id) as total_sessions,
                    COUNT(DISTINCT CASE WHEN s.completed_at IS NOT NULL THEN s.id END) as completed_sessions,
                    COUNT(DISTINCT q.id) as total_questions,
                    AVG(CASE WHEN a.is_final = TRUE THEN a.score END) as avg_score,
                    COUNT(DISTINCT CASE WHEN a.is_final = TRUE AND a.score IS NOT NULL THEN a.id END) as scored_questions
                FROM reading_sessions s
                LEFT JOIN questions q ON s.id = q.session_id
                LEFT JOIN answers a ON q.id = a.question_id AND a.is_final = TRUE
                WHERE s.user_id = %s
            """, (user_id,))
            result = cursor.fetchone()
            cursor.close()
            if result:
                return {
                    'total_sessions': result['total_sessions'] or 0,
                    'completed_sessions': result['completed_sessions'] or 0,
                    'total_questions': result['total_questions'] or 0,
                    'average_score': float(result['avg_score']) if result['avg_score'] else None,
                    'scored_questions': result['scored_questions'] or 0
                }
            return {
                'total_sessions': 0,
                'completed_sessions': 0,
                'total_questions': 0,
                'average_score': None,
                'scored_questions': 0
            }
    
    def get_session_avg_score(self, session_id: int) -> Optional[float]:
        """Get average score for a session"""
        with self.get_connection() as conn:
            cursor = conn.cursor(pymysql.cursors.DictCursor)
            cursor.execute("""
                SELECT AVG(a.score) as avg_score
                FROM questions q
                JOIN answers a ON q.id = a.question_id
                WHERE q.session_id = %s AND a.is_final = TRUE AND a.score IS NOT NULL
            """, (session_id,))
            result = cursor.fetchone()
            cursor.close()
            if result and result['avg_score']:
                return float(result['avg_score'])
            return None
    
    def close(self):
        """
        Close the connector.
        
        This should be called when the application shuts down to properly
        clean up resources. The connector will close all pooled connections.
        """
        if hasattr(self, 'connector') and self.connector:
            self.connector.close()
