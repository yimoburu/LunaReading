# Database Query Tool Usage

## Overview

`query_db.py` is a command-line tool for directly querying the LunaReading SQLite database.

## Installation

Make sure `tabulate` is installed:

```bash
pip install tabulate
```

Or install all requirements:

```bash
pip install -r requirements.txt
```

## Usage

### Interactive Mode

Run without arguments to enter interactive mode:

```bash
python3 scripts/query_db.py
```

Or:

```bash
./scripts/query_db.py
```

### Command Line Mode

Execute queries directly from command line:

```bash
# Show all tables
python3 scripts/query_db.py tables

# Show schema for a table
python3 scripts/query_db.py schema user
python3 scripts/query_db.py schema reading_session

# Show predefined queries
python3 scripts/query_db.py queries

# Run predefined query by number
python3 scripts/query_db.py 1  # List all users
python3 scripts/query_db.py 7  # User performance summary

# Execute custom SQL
python3 scripts/query_db.py sql "SELECT * FROM user LIMIT 5"
```

## Interactive Commands

When in interactive mode:

- `help` - Show help
- `tables` - List all tables
- `schema [table]` - Show table schema (all tables if no table specified)
- `queries` - Show predefined queries
- `1-10` - Run predefined query by number
- `sql <query>` - Execute custom SQL query
- `exit` or `quit` - Exit

## Predefined Queries

1. **List all users** - Shows all registered users
2. **Count users** - Total number of users
3. **List all sessions** - All reading sessions with user info
4. **Sessions by user** - Session statistics per user
5. **Questions with answers** - Questions and their answer statistics
6. **Final answers with ratings** - All final answers with scores and ratings
7. **User performance summary** - Comprehensive user statistics
8. **Recent activity** - Recent user, session, and answer activity
9. **Incomplete sessions** - Sessions that haven't been completed
10. **Answer submission types** - Statistics by submission type (initial/retry/final)

## Examples

### List all users

```bash
python3 scripts/query_db.py 1
```

### Get user performance

```bash
python3 scripts/query_db.py 7
```

### Custom query

```bash
python3 scripts/query_db.py sql "SELECT username, email FROM user WHERE grade_level > 3"
```

### Interactive session

```bash
python3 scripts/query_db.py
> tables
> schema user
> 1
> sql SELECT COUNT(*) FROM reading_session
> exit
```

## Database Location

The tool automatically searches for the database in:
- `./lunareading.db`
- `./backend/instance/lunareading.db`

If not found, you'll be prompted to specify the path.

## Notes

- Results are limited to 100 rows by default
- Non-SELECT queries (INSERT, UPDATE, DELETE) will commit changes
- Use with caution on production databases
- The tool uses read-only mode where possible, but can modify data

