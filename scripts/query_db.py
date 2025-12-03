#!/usr/bin/env python3
"""
Database Query Tool for LunaReading
Allows direct SQL queries to the SQLite database
"""

import sqlite3
import sys
import os
from pathlib import Path
from datetime import datetime
import json
from tabulate import tabulate

# Try to find the database file
def find_database():
    """Find the database file in common locations"""
    possible_paths = [
        Path.cwd() / 'lunareading.db',
        Path.cwd() / 'backend' / 'instance' / 'lunareading.db',
        Path(__file__).parent.parent / 'lunareading.db',
        Path(__file__).parent.parent / 'backend' / 'instance' / 'lunareading.db',
    ]
    
    for path in possible_paths:
        if path.exists():
            return str(path)
    
    return None

def get_connection(db_path):
    """Get database connection"""
    if not os.path.exists(db_path):
        print(f"❌ Database not found at: {db_path}")
        return None
    
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row  # Return rows as dictionaries
    return conn

def show_tables(conn):
    """Show all tables in the database"""
    cursor = conn.cursor()
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")
    tables = [row[0] for row in cursor.fetchall()]
    
    print("\n📊 Tables in database:")
    for table in tables:
        print(f"  - {table}")
    return tables

def show_schema(conn, table_name=None):
    """Show schema for a table or all tables"""
    cursor = conn.cursor()
    
    if table_name:
        cursor.execute(f"PRAGMA table_info({table_name})")
        columns = cursor.fetchall()
        
        print(f"\n📋 Schema for '{table_name}':")
        print(tabulate(columns, headers=['cid', 'name', 'type', 'notnull', 'dflt_value', 'pk'], tablefmt='grid'))
    else:
        tables = show_tables(conn)
        for table in tables:
            cursor.execute(f"PRAGMA table_info({table})")
            columns = cursor.fetchall()
            print(f"\n📋 Schema for '{table}':")
            print(tabulate(columns, headers=['cid', 'name', 'type', 'notnull', 'dflt_value', 'pk'], tablefmt='grid'))

def execute_query(conn, query, limit=100):
    """Execute a SQL query and return results"""
    try:
        cursor = conn.cursor()
        cursor.execute(query)
        
        # Check if it's a SELECT query
        if query.strip().upper().startswith('SELECT'):
            rows = cursor.fetchall()
            if rows:
                # Get column names
                columns = [description[0] for description in cursor.description]
                
                # Limit results
                if len(rows) > limit:
                    rows = rows[:limit]
                    print(f"\n⚠️  Showing first {limit} rows (total: {len(cursor.fetchall()) + limit})")
                
                # Convert rows to list of lists for tabulate
                data = [list(row) for row in rows]
                
                print(f"\n✅ Query executed successfully ({len(rows)} rows)")
                print(tabulate(data, headers=columns, tablefmt='grid', maxcolwidths=50))
            else:
                print("\n✅ Query executed successfully (0 rows)")
        else:
            # For non-SELECT queries (INSERT, UPDATE, DELETE)
            conn.commit()
            print(f"\n✅ Query executed successfully")
            print(f"   Rows affected: {cursor.rowcount}")
            
    except sqlite3.Error as e:
        print(f"\n❌ Error executing query: {e}")
        return None

def get_predefined_queries():
    """Get list of predefined queries"""
    return {
        '1': {
            'name': 'List all users',
            'query': 'SELECT id, username, email, grade_level, reading_level, created_at FROM user ORDER BY created_at DESC'
        },
        '2': {
            'name': 'Count users',
            'query': 'SELECT COUNT(*) as total_users FROM user'
        },
        '3': {
            'name': 'List all sessions',
            'query': '''SELECT s.id, u.username, s.book_title, s.chapter, s.total_questions, 
                        s.created_at, s.completed_at 
                        FROM reading_session s 
                        JOIN user u ON s.user_id = u.id 
                        ORDER BY s.created_at DESC'''
        },
        '4': {
            'name': 'Sessions by user',
            'query': '''SELECT u.username, COUNT(s.id) as session_count, 
                        AVG(q_count.total) as avg_questions
                        FROM user u
                        LEFT JOIN reading_session s ON u.id = s.user_id
                        LEFT JOIN (SELECT session_id, COUNT(*) as total FROM question GROUP BY session_id) q_count 
                        ON s.id = q_count.session_id
                        GROUP BY u.id, u.username
                        ORDER BY session_count DESC'''
        },
        '5': {
            'name': 'Questions with answers',
            'query': '''SELECT q.id, q.question_number, q.question_text, 
                        COUNT(a.id) as answer_count,
                        MAX(a.score) as best_score,
                        MAX(a.rating) as best_rating
                        FROM question q
                        LEFT JOIN answer a ON q.id = a.question_id
                        GROUP BY q.id
                        ORDER BY q.id DESC
                        LIMIT 20'''
        },
        '6': {
            'name': 'Final answers with ratings',
            'query': '''SELECT a.id, q.question_text, a.answer_text, 
                        a.score, a.rating, a.submission_type, a.created_at
                        FROM answer a
                        JOIN question q ON a.question_id = q.id
                        WHERE a.is_final = 1
                        ORDER BY a.created_at DESC
                        LIMIT 20'''
        },
        '7': {
            'name': 'User performance summary',
            'query': '''SELECT u.username, u.grade_level, u.reading_level,
                        COUNT(DISTINCT s.id) as total_sessions,
                        COUNT(DISTINCT q.id) as total_questions,
                        COUNT(DISTINCT a.id) as total_answers,
                        AVG(a.score) as avg_score,
                        AVG(a.rating) as avg_rating
                        FROM user u
                        LEFT JOIN reading_session s ON u.id = s.user_id
                        LEFT JOIN question q ON s.id = q.session_id
                        LEFT JOIN answer a ON q.id = a.question_id AND a.is_final = 1
                        GROUP BY u.id, u.username, u.grade_level, u.reading_level
                        ORDER BY total_sessions DESC'''
        },
        '8': {
            'name': 'Recent activity',
            'query': '''SELECT 
                        'user' as type, id, username as name, created_at
                        FROM user
                        UNION ALL
                        SELECT 
                        'session' as type, id, book_title || ' - ' || chapter as name, created_at
                        FROM reading_session
                        UNION ALL
                        SELECT 
                        'answer' as type, id, 'Answer #' || id as name, created_at
                        FROM answer
                        ORDER BY created_at DESC
                        LIMIT 30'''
        },
        '9': {
            'name': 'Incomplete sessions',
            'query': '''SELECT s.id, u.username, s.book_title, s.chapter,
                        s.total_questions,
                        COUNT(DISTINCT q.id) as questions_created,
                        COUNT(DISTINCT CASE WHEN a.is_final = 1 THEN q.id END) as questions_completed
                        FROM reading_session s
                        JOIN user u ON s.user_id = u.id
                        LEFT JOIN question q ON s.id = q.session_id
                        LEFT JOIN answer a ON q.id = a.question_id
                        WHERE s.completed_at IS NULL
                        GROUP BY s.id
                        HAVING questions_completed < s.total_questions
                        ORDER BY s.created_at DESC'''
        },
        '10': {
            'name': 'Answer submission types',
            'query': '''SELECT submission_type, 
                        COUNT(*) as count,
                        AVG(score) as avg_score,
                        AVG(rating) as avg_rating
                        FROM answer
                        GROUP BY submission_type
                        ORDER BY count DESC'''
        }
    }

def show_predefined_queries():
    """Show list of predefined queries"""
    queries = get_predefined_queries()
    print("\n📝 Predefined Queries:")
    for key, value in queries.items():
        print(f"  {key}. {value['name']}")

def interactive_mode(conn):
    """Interactive query mode"""
    queries = get_predefined_queries()
    
    print("\n" + "="*60)
    print("🔍 Database Query Tool - Interactive Mode")
    print("="*60)
    print("\nCommands:")
    print("  help          - Show this help")
    print("  tables        - List all tables")
    print("  schema [table]- Show table schema(s)")
    print("  queries       - Show predefined queries")
    print("  [1-10]        - Run predefined query")
    print("  sql <query>   - Execute custom SQL query")
    print("  exit/quit     - Exit")
    print("\n" + "="*60)
    
    while True:
        try:
            command = input("\n> ").strip()
            
            if not command:
                continue
            
            if command.lower() in ['exit', 'quit', 'q']:
                print("\n👋 Goodbye!")
                break
            
            elif command.lower() == 'help':
                print("\nCommands:")
                print("  help          - Show this help")
                print("  tables        - List all tables")
                print("  schema [table]- Show table schema(s)")
                print("  queries       - Show predefined queries")
                print("  [1-10]        - Run predefined query")
                print("  sql <query>   - Execute custom SQL query")
                print("  exit/quit     - Exit")
            
            elif command.lower() == 'tables':
                show_tables(conn)
            
            elif command.lower().startswith('schema'):
                parts = command.split()
                table_name = parts[1] if len(parts) > 1 else None
                show_schema(conn, table_name)
            
            elif command.lower() == 'queries':
                show_predefined_queries()
            
            elif command in queries:
                print(f"\n🔍 Running: {queries[command]['name']}")
                execute_query(conn, queries[command]['query'])
            
            elif command.lower().startswith('sql '):
                query = command[4:].strip()
                execute_query(conn, query)
            
            else:
                # Try as direct SQL query
                execute_query(conn, command)
                
        except KeyboardInterrupt:
            print("\n\n👋 Goodbye!")
            break
        except Exception as e:
            print(f"\n❌ Error: {e}")

def main():
    """Main function"""
    # Find database
    db_path = find_database()
    
    if not db_path:
        print("❌ Database not found!")
        print("\nSearched in:")
        print("  - ./lunareading.db")
        print("  - ./backend/instance/lunareading.db")
        print("\nPlease specify database path:")
        db_path = input("Database path: ").strip()
        
        if not db_path or not os.path.exists(db_path):
            print("❌ Invalid database path")
            sys.exit(1)
    
    print(f"📂 Using database: {db_path}")
    
    # Connect to database
    conn = get_connection(db_path)
    if not conn:
        sys.exit(1)
    
    try:
        # Check if command line arguments provided
        if len(sys.argv) > 1:
            if sys.argv[1] == 'tables':
                show_tables(conn)
            elif sys.argv[1] == 'schema':
                table = sys.argv[2] if len(sys.argv) > 2 else None
                show_schema(conn, table)
            elif sys.argv[1] == 'queries':
                show_predefined_queries()
            elif sys.argv[1].isdigit():
                queries = get_predefined_queries()
                if sys.argv[1] in queries:
                    execute_query(conn, queries[sys.argv[1]]['query'])
                else:
                    print(f"❌ Query {sys.argv[1]} not found")
            else:
                # Execute SQL query from command line
                query = ' '.join(sys.argv[1:])
                execute_query(conn, query)
        else:
            # Interactive mode
            interactive_mode(conn)
    finally:
        conn.close()

if __name__ == '__main__':
    main()

