#!/usr/bin/env python3
"""
Migrate data from SQLite to MySQL (Cloud SQL)

⚠️  DEPRECATED: This script uses SQLAlchemy. SQLite is no longer supported.
   This script may need updates to work with Cloud SQL Connector.
"""

import sqlite3
import sys
import os
from pathlib import Path
from datetime import datetime
import json

# Try to import MySQL connector
try:
    import pymysql
    from sqlalchemy import create_engine, text
    from sqlalchemy.orm import sessionmaker
except ImportError:
    print("❌ Required packages not installed:")
    print("   pip install pymysql sqlalchemy")
    sys.exit(1)

def find_sqlite_db():
    """Find SQLite database file"""
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

def get_mysql_connection():
    """Get MySQL connection from environment or config"""
    # Try to get from environment variable
    db_uri = os.getenv('SQLALCHEMY_DATABASE_URI')
    
    if not db_uri:
        # Try to read from .cloudsql_user_password file
        config_file = Path(__file__).parent.parent / '.cloudsql_user_password'
        if config_file.exists():
            # This file should contain connection info, but for now we'll prompt
            print("⚠️  Connection string not found in environment")
            print("   Please provide MySQL connection details:")
            
            connection_name = input("Cloud SQL Connection Name (e.g., project:region:instance): ").strip()
            database = input("Database name: ").strip() or "lunareading"
            user = input("Database user: ").strip() or "lunareading_user"
            password = input("Database password: ").strip()
            
            db_uri = f"mysql+pymysql://{user}:{password}@/{database}?unix_socket=/cloudsql/{connection_name}"
        else:
            print("❌ MySQL connection string not found")
            print("   Set SQLALCHEMY_DATABASE_URI environment variable or run update_cloud_run_db.sh")
            sys.exit(1)
    
    try:
        engine = create_engine(db_uri)
        # Test connection
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        return engine
    except Exception as e:
        print(f"❌ Failed to connect to MySQL: {e}")
        print(f"   Connection string: {db_uri.replace(password if 'password' in str(e).lower() else '', '***')}")
        sys.exit(1)

def migrate_table(sqlite_conn, mysql_engine, table_name, columns):
    """Migrate a single table"""
    print(f"\n📦 Migrating table: {table_name}")
    
    # Read data from SQLite
    cursor = sqlite_conn.cursor()
    cursor.execute(f"SELECT * FROM {table_name}")
    rows = cursor.fetchall()
    
    if not rows:
        print(f"   ⚠️  Table is empty, skipping")
        return 0
    
    print(f"   Found {len(rows)} rows")
    
    # Get column names
    column_names = [description[0] for description in cursor.description]
    
    # Insert into MySQL
    with mysql_engine.connect() as mysql_conn:
        # Clear existing data (optional - comment out if you want to append)
        mysql_conn.execute(text(f"TRUNCATE TABLE {table_name}"))
        mysql_conn.commit()
        
        # Insert rows
        inserted = 0
        for row in rows:
            try:
                # Build INSERT statement
                values = {}
                for i, col_name in enumerate(column_names):
                    value = row[i]
                    # Handle None, datetime, and boolean values
                    if value is None:
                        values[col_name] = None
                    elif isinstance(value, datetime):
                        values[col_name] = value
                    elif isinstance(value, bool):
                        values[col_name] = int(value)
                    else:
                        values[col_name] = value
                
                # Create INSERT statement
                cols = ', '.join(column_names)
                placeholders = ', '.join([f':{col}' for col in column_names])
                insert_sql = f"INSERT INTO {table_name} ({cols}) VALUES ({placeholders})"
                
                mysql_conn.execute(text(insert_sql), values)
                inserted += 1
                
                if inserted % 100 == 0:
                    print(f"   Migrated {inserted}/{len(rows)} rows...")
                    mysql_conn.commit()
                    
            except Exception as e:
                print(f"   ⚠️  Error inserting row: {e}")
                print(f"   Row data: {dict(zip(column_names, row))}")
                continue
        
        mysql_conn.commit()
    
    print(f"   ✅ Migrated {inserted}/{len(rows)} rows successfully")
    return inserted

def main():
    """Main migration function"""
    print("🔄 Migrating from SQLite to MySQL")
    print("=" * 50)
    print()
    
    # Find SQLite database
    sqlite_path = find_sqlite_db()
    if not sqlite_path:
        print("❌ SQLite database not found!")
        print("   Searched in:")
        print("     - ./lunareading.db")
        print("     - ./backend/instance/lunareading.db")
        sys.exit(1)
    
    print(f"📂 SQLite database: {sqlite_path}")
    
    # Connect to SQLite
    sqlite_conn = sqlite3.connect(sqlite_path)
    sqlite_conn.row_factory = sqlite3.Row
    
    # Get MySQL connection
    print("🔗 Connecting to MySQL...")
    mysql_engine = get_mysql_connection()
    print("✅ Connected to MySQL")
    
    # Get list of tables
    cursor = sqlite_conn.cursor()
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'")
    tables = [row[0] for row in cursor.fetchall()]
    
    print(f"\n📊 Found {len(tables)} tables to migrate:")
    for table in tables:
        cursor.execute(f"SELECT COUNT(*) FROM {table}")
        count = cursor.fetchone()[0]
        print(f"   - {table}: {count} rows")
    
    # Confirm
    print()
    response = input("Continue with migration? (y/n): ").strip().lower()
    if response != 'y':
        print("Cancelled.")
        sys.exit(0)
    
    # Migrate tables in order (respecting foreign keys)
    # Order: user -> reading_session -> question -> answer
    table_order = ['user', 'reading_session', 'question', 'answer']
    tables_to_migrate = [t for t in table_order if t in tables]
    tables_to_migrate.extend([t for t in tables if t not in table_order])
    
    total_migrated = 0
    for table in tables_to_migrate:
        # Get column info
        cursor.execute(f"PRAGMA table_info({table})")
        columns = cursor.fetchall()
        
        migrated = migrate_table(sqlite_conn, mysql_engine, table, columns)
        total_migrated += migrated
    
    sqlite_conn.close()
    
    print()
    print("=" * 50)
    print(f"✅ Migration complete! Migrated {total_migrated} total rows")
    print()
    print("📝 Next steps:")
    print("   1. Verify data in MySQL:")
    print("      python3 scripts/query_db.py")
    print("   2. Test the application with MySQL")
    print("   3. Once verified, you can remove the SQLite database")

if __name__ == '__main__':
    main()

