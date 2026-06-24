# GymOps 🏋️

> A terminal-based workout tracker — and a Base de Datos II final project at FIEI/UNI.

GymOps is a CLI tool that lives in your terminal. You set your training split, pick today's day, and log your sets. It tracks your personal records, tells you if you're actually getting stronger, and generates a weekly summary of what you've been doing.

Inspired by [lazygit](https://github.com/jesseduffield/lazygit) — the idea that a good terminal tool should get out of your way, run locally, and just work.

---

## Features

- **PostgreSQL Backend**: Full relational database with stored procedures, views, triggers, and indexes.
- **Pre-loaded Splits**: Comes pre-seeded with Jeff Nippard's classic splits (Upper/Lower 4-Day, ULPPL 5-Day, PPL 6-Day).
- **Estimated 1RM**: Calculates estimated 1-rep max using the Epley formula after every set.
- **Progressive Overload Stats**: Compares today's performance against your last session.
- **PR Tracking**: Auto-updates your personal records and marks them when broken.
- **Weekly Digests**: Generates markdown summaries of your weekly training volume and best lifts.
- **Bilingual CLI**: Switch between English and Español with `gymops set-language`.
- **TUI Interface (Coming Soon)**: A full lazygit-style terminal UI to log sets and view PRs visually.

---

## Quickstart

### Prerequisites
- Python 3.12+
- [uv](https://github.com/astral-sh/uv)
- Docker (for PostgreSQL)

### Setup

```bash
# Clone the repository
git clone https://github.com/Pierorivera1/GymOps-FIEI.git
cd GymOps-FIEI

# Start PostgreSQL with Docker
docker run --name gymops-db -e POSTGRES_USER=gymops \
  -e POSTGRES_PASSWORD=gymops_pass \
  -e POSTGRES_DB=gymops_db \
  -p 5432:5432 -d postgres:16

# Create virtual environment and install dependencies
uv venv
source .venv/bin/activate
uv pip install -e .

# Initialize the database (run SQL scripts in order)
psql -h localhost -U gymops -d gymops_db -f proyecto_bdII/sql/01_ddl.sql
psql -h localhost -U gymops -d gymops_db -f proyecto_bdII/sql/02_seed.sql

# Confirm it works
gymops --help
```

---

## Usage

```bash
# Set your preferred language (en / es)
gymops set-language es

# 1. List all available training programs
gymops list-programs

# 2. Select the active program you follow
gymops select-program "Upper/Lower 4-Day"

# 3. Set today's training day (do this at the start of your workout)
gymops set-day "Upper A — Strength"

# 4. Log your sets as you perform them
gymops log --exercise "Barbell Bench Press" --sets 4 --reps 5 --weight 80

# 5. Check progressive overload vs last session
gymops stats --exercise "Barbell Bench Press"

# 6. View your personal records
gymops prs

# 7. View exercise history
gymops history --exercise "Barbell Bench Press"

# 8. Add an exercise to the catalog
gymops add-exercise --name "Dumbbell Lateral Raise" --muscle-group "Shoulders" --type isolation

# 9. Create a custom training program
gymops add-program

# 10. Generate a weekly Markdown digest
gymops digest
```

---

## Database

GymOps runs on **PostgreSQL 16** (Docker). The schema includes:

| Object | Count | Description |
|--------|-------|-------------|
| Tables | 9 | Core relational schema (3NF) |
| Views | 9 | Reports, security, progress tracking |
| Indexes | 15 | B-tree, partial, expression indexes |
| Stored Procedures | — | Coming in Phase 5 |
| Functions (UDF) | — | Coming in Phase 6 |
| Triggers | — | Coming in Phase 7 |

### SQL Scripts (`proyecto_bdII/sql/`)

| Script | Purpose |
|--------|---------|
| `01_ddl.sql` | Schema: tables, PKs, FKs, CHECKs |
| `02_seed.sql` | Seed: muscles, 51 exercises, 3 programs |
| `03_dml.sql` | DML: sessions, sets, UPDATE/DELETE examples |
| `04_queries.sql` | 10 advanced queries (CTE, window functions) |
| `05_views.sql` | 9 views for reports and security |
| `06_indexes.sql` | 15 indexes + EXPLAIN ANALYZE plans |

### Connection

```
Host:     localhost
Port:     5432
Database: gymops_db
User:     gymops
Password: gymops_pass
```

---

## Project Structure

```
GymOps-FIEI/
├── gymops/
│   ├── cli.py          # All Typer CLI commands
│   ├── db.py           # Database layer (SQLite → PostgreSQL migration)
│   ├── i18n.py         # Internationalisation (en / es)
│   ├── models.py       # Dataclasses: Workout, Exercise, PR, Routine
│   └── report.py       # Weekly digest generator
├── proyecto_bdII/
│   ├── DESCRIPCION_PROYECTO.md   # Full project description (BD II)
│   ├── PLANNING.md               # Phase tracker and implementation plan
│   └── sql/                      # All SQL scripts (phases 1–7)
└── tests/              # pytest test suite
```

---

## Development & Tests

```bash
# Install test requirements
uv pip install pytest

# Run tests
uv run pytest
```

---

## BD II — Course Project

This repo doubles as a **Base de Datos II final project** at FIEI/UNI.
See [`proyecto_bdII/PLANNING.md`](proyecto_bdII/PLANNING.md) for the full implementation roadmap
and [`proyecto_bdII/DESCRIPCION_PROYECTO.md`](proyecto_bdII/DESCRIPCION_PROYECTO.md) for the project description.

**Stack**: PostgreSQL 16 · Python 3.12 · Docker · Typer · Rich
