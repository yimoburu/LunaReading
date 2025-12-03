#!/usr/bin/env python3
"""
Database migration script to add new columns to the Answer table:
- rating (Integer)
- examples (Text/JSON)
- submission_type (String)

This script safely adds these columns if they don't already exist.
"""

import sqlite3
import os
from pathlib import Path

def migrate_database(db_path):
    """Add new columns to Answer table if they don't exist"""
    
    if not os.path.exists(db_path):
        print(f"Database file not found: {db_path}")
        print("The database will be created automatically when you run the app.")
        return
    
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    try:
        # Check if columns exist
        cursor.execute("PRAGMA table_info(answer)")
        columns = [row[1] for row in cursor.fetchall()]
        
        changes_made = False
        
        # Add rating column if it doesn't exist
        if 'rating' not in columns:
            print("Adding 'rating' column...")
            cursor.execute("ALTER TABLE answer ADD COLUMN rating INTEGER")
            changes_made = True
            print("✅ Added 'rating' column")
        else:
            print("✅ 'rating' column already exists")
        
        # Add examples column if it doesn't exist
        if 'examples' not in columns:
            print("Adding 'examples' column...")
            cursor.execute("ALTER TABLE answer ADD COLUMN examples TEXT")
            changes_made = True
            print("✅ Added 'examples' column")
        else:
            print("✅ 'examples' column already exists")
        
        # Add submission_type column if it doesn't exist
        if 'submission_type' not in columns:
            print("Adding 'submission_type' column...")
            cursor.execute("ALTER TABLE answer ADD COLUMN submission_type VARCHAR(20) DEFAULT 'initial'")
            changes_made = True
            print("✅ Added 'submission_type' column")
        else:
            print("✅ 'submission_type' column already exists")
        
        conn.commit()
        
        if changes_made:
            print("\n✅ Migration completed successfully!")
        else:
            print("\n✅ Database is already up to date.")
            
    except Exception as e:
        conn.rollback()
        print(f"❌ Error during migration: {e}")
        raise
    finally:
        conn.close()

if __name__ == "__main__":
    # Try to find the database file
    # Check common locations
    possible_paths = [
        "lunareading.db",
        "backend/lunareading.db",
        os.path.expanduser("~/lunareading.db"),
    ]
    
    # Also check for environment variable
    db_path = os.getenv("DATABASE_URL", "").replace("sqlite:///", "")
    
    if db_path and os.path.exists(db_path):
        print(f"Using database from DATABASE_URL: {db_path}")
        migrate_database(db_path)
    else:
        # Try to find the database
        found = False
        for path in possible_paths:
            if os.path.exists(path):
                print(f"Found database at: {path}")
                migrate_database(path)
                found = True
                break
        
        if not found:
            print("Could not find database file.")
            print("Please specify the database path:")
            print("  python migrate_database.py <path_to_database.db>")
            print("\nOr set DATABASE_URL environment variable:")
            print("  export DATABASE_URL=sqlite:///path/to/database.db")
            print("  python migrate_database.py")

