#!/usr/bin/env python3
"""
Initialize LunaReading database - creates database and tables if they don't exist
"""

import os
import sys
from pathlib import Path
from dotenv import load_dotenv
from google.cloud.sql.connector import Connector
import pymysql

# Load .env
project_root = Path(__file__).parent.parent
env_path = project_root / '.env'
load_dotenv(dotenv_path=env_path, override=True)

# Get configuration
INSTANCE_CONNECTION_NAME = os.getenv('CLOUDSQL_INSTANCE_CONNECTION_NAME')
DATABASE = os.getenv('CLOUDSQL_DATABASE', 'lunareading')
USER = os.getenv('CLOUDSQL_USER')
PASSWORD = os.getenv('CLOUDSQL_PASSWORD')

# Validate database name (cannot use system databases)
SYSTEM_DATABASES = ['mysql', 'information_schema', 'performance_schema', 'sys']
if DATABASE.lower() in SYSTEM_DATABASES:
    print(f"❌ ERROR: Cannot use system database '{DATABASE}'")
    print("")
    print("Please set CLOUDSQL_DATABASE to a non-system database name in your .env file:")
    print("  CLOUDSQL_DATABASE=lunareading")
    print("")
    print("Then create the database:")
    instance_name = INSTANCE_CONNECTION_NAME.split(':')[-1] if INSTANCE_CONNECTION_NAME else 'INSTANCE_NAME'
    print(f"  gcloud sql databases create lunareading --instance={instance_name}")
    sys.exit(1)

if not INSTANCE_CONNECTION_NAME:
    print("❌ ERROR: CLOUDSQL_INSTANCE_CONNECTION_NAME not set in .env")
    sys.exit(1)

if not USER or not PASSWORD:
    print("❌ ERROR: CLOUDSQL_USER and CLOUDSQL_PASSWORD must be set in .env")
    sys.exit(1)

print(f"🔧 Initializing database: {DATABASE}")
print(f"   Instance: {INSTANCE_CONNECTION_NAME}")
print(f"   User: {USER}")
print()

try:
    # Initialize connector
    connector = Connector()
    
    # Connect to MySQL server (without specifying a database)
    def get_conn():
        return connector.connect(
            INSTANCE_CONNECTION_NAME,
            "pymysql",
            user=USER,
            password=PASSWORD,
        )
    
    # Step 1: Check if database exists, create if not
    print("Step 1: Checking if database exists...")
    with get_conn() as conn:
        with conn.cursor() as cursor:
            cursor.execute("SHOW DATABASES")
            databases = [db[0] for db in cursor.fetchall()]
            
            if DATABASE in databases:
                print(f"✅ Database '{DATABASE}' already exists")
            else:
                print(f"📝 Database '{DATABASE}' does not exist, creating...")
                cursor.execute(f"CREATE DATABASE IF NOT EXISTS `{DATABASE}` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci")
                conn.commit()
                print(f"✅ Database '{DATABASE}' created successfully")
    
    # Step 2: Connect to the specific database and create tables
    print(f"\nStep 2: Creating tables in database '{DATABASE}'...")
    
    def get_db_conn():
        return connector.connect(
            INSTANCE_CONNECTION_NAME,
            "pymysql",
            user=USER,
            password=PASSWORD,
            db=DATABASE,
        )
    
    with get_db_conn() as conn:
        with conn.cursor() as cursor:
            # Users table
            print("  Creating 'users' table...")
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS users (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    username VARCHAR(80) UNIQUE NOT NULL,
                    email VARCHAR(120) UNIQUE NOT NULL,
                    password_hash VARCHAR(255) NOT NULL,
                    grade_level INT NOT NULL,
                    reading_level FLOAT DEFAULT 0.0,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
            """)
            
            # Reading sessions table
            print("  Creating 'reading_sessions' table...")
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
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
            """)
            
            # Questions table
            print("  Creating 'questions' table...")
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS questions (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    session_id INT NOT NULL,
                    question_text TEXT NOT NULL,
                    question_number INT NOT NULL,
                    model_answer TEXT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (session_id) REFERENCES reading_sessions(id) ON DELETE CASCADE
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
            """)
            
            # Answers table
            print("  Creating 'answers' table...")
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
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
            """)
            
            conn.commit()
            print("\n✅ All tables created successfully!")
    
    # Step 3: Verify tables exist
    print(f"\nStep 3: Verifying tables in '{DATABASE}'...")
    with get_db_conn() as conn:
        with conn.cursor() as cursor:
            cursor.execute("SHOW TABLES")
            tables = [table[0] for table in cursor.fetchall()]
            
            expected_tables = ['users', 'reading_sessions', 'questions', 'answers']
            print(f"   Found {len(tables)} tables: {', '.join(tables)}")
            
            for table in expected_tables:
                if table in tables:
                    print(f"   ✅ {table}")
                else:
                    print(f"   ❌ {table} (missing!)")
    
    connector.close()
    
    print("\n🎉 Database initialization complete!")
    print(f"\nYou can now use the database '{DATABASE}' with your application.")
    
except Exception as e:
    print(f"\n❌ Error: {e}")
    print(f"   Error type: {type(e).__name__}")
    import traceback
    traceback.print_exc()
    sys.exit(1)

