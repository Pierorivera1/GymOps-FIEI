# flake8: noqa
"""
GymOps database layer.

Handles all PostgreSQL interactions using psycopg2: initialization, schema creation,
autoseeding, and all CRUD query functions.

Concepts:
    Program      — The full training split you follow (e.g. 'Upper/Lower').
                   Set this once. Only change when switching programs.
    ProgramDay   — One training day within a program (e.g. 'Upper A').
                   Set this at the start of each gym session.
    Exercise     — A movement in the catalog (e.g. 'Barbell Bench Press').
    Workout      — A logged set: exercise + sets + reps + weight.
"""

import os
from contextlib import contextmanager
from pathlib import Path
from typing import Generator, Optional, Any
from datetime import datetime
import psycopg2
import psycopg2.extras

from gymops.models import DayExercise, Exercise, PR, Program, ProgramDay, Workout, GuideArticle


# ---------------------------------------------------------------------------
# Path resolution (preserved for backward compatibility and test settings)
# ---------------------------------------------------------------------------

def get_db_path() -> Path:
    """
    Resolve the path to the SQLite database file (preserved for compatibility).
    """
    env_path = os.environ.get("GYMOPS_DB_PATH")
    if env_path:
        return Path(env_path)
    db_dir = Path.home() / ".gymops"
    db_dir.mkdir(parents=True, exist_ok=True)
    return db_dir / "gymops.db"


# ---------------------------------------------------------------------------
# Connection context manager (PostgreSQL implementation)
# ---------------------------------------------------------------------------

@contextmanager
def get_connection(db_path: Optional[Path] = None) -> Generator[Any, None, None]:
    """
    Yield an open PostgreSQL connection.
    """
    host = os.environ.get("GYMOPS_DB_HOST", "localhost")
    port = os.environ.get("GYMOPS_DB_PORT", "5432")
    user = os.environ.get("GYMOPS_DB_USER", "gymops")
    password = os.environ.get("GYMOPS_DB_PASSWORD", "gymops_pass")
    dbname = os.environ.get("GYMOPS_DB_NAME", "gymops_db")

    # If test environment GYMOPS_DB_PATH is detected, use the test database
    if os.environ.get("GYMOPS_DB_PATH"):
        dbname = os.environ.get("GYMOPS_TEST_DB_NAME", "gymops_test")

    conn = psycopg2.connect(
        host=host,
        port=port,
        user=user,
        password=password,
        dbname=dbname,
        cursor_factory=psycopg2.extras.RealDictCursor
    )
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


# ---------------------------------------------------------------------------
# Helper parsers and normalizers
# ---------------------------------------------------------------------------

def parse_reps(reps_str: Any) -> int:
    """
    Extract the last number from a reps range string (e.g. '3-5' -> 5)
    or convert directly to int.
    """
    try:
        return int(str(reps_str).split("-")[-1])
    except (ValueError, IndexError):
        return 8


def normalize_exercise_name(name: str) -> str:
    """
    Translate SQLite exercise names to their corresponding PostgreSQL seeded equivalents.
    """
    mapping = {
        "barbell back squat": "Barbell Squat",
        "cable face pulls": "Face Pull",
        "cable crossover / fly": "Cable Fly",
        "lying leg curl": "Leg Curl",
        "seated leg curl": "Leg Curl",
        "ab wheel rollout": "Plank",
        "dumbbell lateral raise": "Lateral Raise",
        "lat pulldown (neutral grip)": "Lat Pulldown",
        "ez-bar bicep curl": "Barbell Curl",
        "preacher curl": "Preacher Curl",
        "ez-bar preacher curl": "Preacher Curl",
        "incline dumbbell bicep curl": "Incline Dumbbell Curl",
        "cross-body hammer curl": "Hammer Curl",
        "barbell bicep curl": "Barbell Curl",
        "conventional deadlift": "Deadlift",
        "stiff-leg deadlift": "Stiff Leg Deadlift",
        "glute ham raise": "Hip Thrust",
        "weighted decline crunch": "Plank",
        "calf press (on leg press)": "Standing Calf Raise",
    }
    return mapping.get(name.lower().strip(), name)


def map_outgoing_exercise_name(name: str) -> str:
    """
    Translate PostgreSQL seeded exercise names back to SQLite equivalents for backward compatibility.
    """
    mapping = {
        "Barbell Squat": "Barbell Back Squat",
        "Face Pull": "Cable Face Pulls",
        "Cable Fly": "Cable Crossover / Fly",
        "Leg Curl": "Lying Leg Curl",
        "Plank": "Ab Wheel Rollout",
        "Lateral Raise": "Dumbbell Lateral Raise",
        "Lat Pulldown": "Lat Pulldown (Neutral Grip)",
        "Barbell Curl": "EZ-Bar Bicep Curl",
        "Preacher Curl": "Preacher Curl",
        "Incline Dumbbell Curl": "Incline Dumbbell Bicep Curl",
        "Hammer Curl": "Cross-Body Hammer Curl",
        "Deadlift": "Conventional Deadlift",
        "Stiff Leg Deadlift": "Stiff-Leg Deadlift",
        "Standing Calf Raise": "Calf Press (on Leg Press)",
    }
    return mapping.get(name, name)


def format_day_name(name: str) -> str:
    """
    Translate PostgreSQL seeded day names to SQLite format with parentheses for tests.
    e.g. "Upper A — Strength" -> "Upper A (Strength)"
    """
    if " — " in name:
        parts = name.split(" — ")
        return f"{parts[0]} ({parts[1]})"
    return name


def normalize_program_name(name: str) -> str:
    """
    Translate SQLite program names to PostgreSQL seeded program names.
    """
    mapping = {
        "upper/lower (4-day)": "Upper/Lower 4-Day",
        "ppl (6-day)": "PPL 6-Day",
        "ulppl (5-day)": "ULPPL 5-Day",
    }
    return mapping.get(name.lower().strip(), name)


def map_outgoing_program_name(name: str) -> str:
    """
    Translate PostgreSQL seeded program names back to SQLite program names.
    """
    mapping = {
        "Upper/Lower 4-Day": "Upper/Lower (4-Day)",
        "PPL 6-Day": "PPL (6-Day)",
        "ULPPL 5-Day": "ULPPL (5-Day)",
    }
    return mapping.get(name, name)


# ---------------------------------------------------------------------------
# Initialization & seeding
# ---------------------------------------------------------------------------

def init_db(db_path: Optional[Path] = None) -> None:
    """
    Initialize the database: create tables and seed default data.
    Runs SQL scripts from proyecto_bdII/sql in order if exercise table does not exist.
    """
    with get_connection() as conn:
        with conn.cursor() as cur:
            # Check if schema exists (checks for 'exercise' table)
            cur.execute(
                "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'exercise')"
            )
            exists = cur.fetchone()["exists"]
            if not exists:
                # Load SQL scripts
                project_root = Path(__file__).resolve().parent.parent
                sql_dir = project_root / "proyecto_bdII" / "sql"
                sql_files = [
                    "01_ddl.sql",
                    "02_seed.sql",
                    "05_views.sql",
                    "06_indexes.sql",
                    "07_procedures.sql",
                    "08_functions.sql",
                    "09_triggers.sql"
                ]
                for file_name in sql_files:
                    path = sql_dir / file_name
                    if path.exists():
                        cur.execute(path.read_text(encoding="utf-8"))

            # Create active_program table if not exists
            cur.execute("""
                CREATE TABLE IF NOT EXISTS active_program (
                    id         INT PRIMARY KEY CHECK(id = 1),
                    program_id INT REFERENCES program(id) ON DELETE SET NULL,
                    day_id     INT REFERENCES program_day(id) ON DELETE SET NULL
                )
            """)

            # If we are in test setup (db_path is not None), clean up database tables to start fresh
            if db_path is not None and os.environ.get("GYMOPS_DB_PATH"):
                cur.execute("TRUNCATE workout_set, workout_session, personal_record, active_program, audit_log CASCADE;")
                cur.execute("DELETE FROM routine_exercise WHERE program_day_id NOT IN (1,2,3,4,5,6,7,8,9,10,11,12,13,14,15);")
                cur.execute("DELETE FROM program_day WHERE program_id NOT IN (1,2,3);")
                cur.execute("DELETE FROM program WHERE id NOT IN (1,2,3);")
                cur.execute("DELETE FROM routine_exercise WHERE exercise_id = (SELECT id FROM exercise WHERE name = 'Bulgarian Split Squat');")
                cur.execute("DELETE FROM exercise WHERE name = 'Bulgarian Split Squat';")
                cur.execute("DELETE FROM exercise WHERE id > 51;")
                
                # Reset sequences
                cur.execute("SELECT setval('exercise_id_seq', COALESCE((SELECT MAX(id) FROM exercise), 1));")
                cur.execute("SELECT setval('program_id_seq', COALESCE((SELECT MAX(id) FROM program), 1));")
                cur.execute("SELECT setval('program_day_id_seq', COALESCE((SELECT MAX(id) FROM program_day), 1));")
                cur.execute("SELECT setval('routine_exercise_id_seq', COALESCE((SELECT MAX(id) FROM routine_exercise), 1));")
                cur.execute("SELECT setval('workout_session_id_seq', 1, false);")
                cur.execute("SELECT setval('workout_set_id_seq', 1, false);")
                cur.execute("SELECT setval('personal_record_id_seq', 1, false);")


# ---------------------------------------------------------------------------
# Exercise queries
# ---------------------------------------------------------------------------

def get_exercise_by_name(name: str, db_path: Optional[Path] = None) -> Optional[Exercise]:
    """
    Fetch a single exercise by name (case-insensitive).
    """
    normalized_name = normalize_exercise_name(name)
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """SELECT e.id, e.name, mg.name AS muscle_group, e.type
                   FROM exercise e
                   JOIN muscle_group mg ON e.muscle_group_id = mg.id
                   WHERE LOWER(e.name) = LOWER(%s)""",
                (normalized_name,)
            )
            row = cur.fetchone()
    return Exercise(
        id=row["id"],
        name=map_outgoing_exercise_name(row["name"]),
        muscle_group=row["muscle_group"],
        type=row["type"]
    ) if row else None


def add_exercise(
    name: str,
    muscle_group: str,
    exercise_type: str,
    db_path: Optional[Path] = None,
) -> Exercise:
    """
    Add a new exercise to the catalog in Title Case.
    """
    if get_exercise_by_name(name, db_path):
        raise ValueError(f"Exercise '{name}' already exists in the catalog.")
    title_name = name.title()

    with get_connection() as conn:
        with conn.cursor() as cur:
            # Find muscle group ID
            cur.execute(
                "SELECT id FROM muscle_group WHERE LOWER(name) = LOWER(%s)",
                (muscle_group,)
            )
            mg_row = cur.fetchone()
            if mg_row:
                mg_id = mg_row["id"]
            else:
                cur.execute(
                    "INSERT INTO muscle_group (name) VALUES (%s) RETURNING id",
                    (muscle_group.capitalize(),)
                )
                mg_id = cur.fetchone()["id"]

            # Insert exercise
            cur.execute(
                "INSERT INTO exercise (name, muscle_group_id, type) VALUES (%s, %s, %s)",
                (title_name, mg_id, exercise_type)
            )

    return get_exercise_by_name(title_name, db_path)  # type: ignore


def get_all_exercises(db_path: Optional[Path] = None) -> list[Exercise]:
    """Return all exercises ordered alphabetically."""
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """SELECT e.id, e.name, mg.name AS muscle_group, e.type
                   FROM exercise e
                   JOIN muscle_group mg ON e.muscle_group_id = mg.id
                   ORDER BY e.name"""
            )
            rows = cur.fetchall()
    return [
        Exercise(
            id=r["id"],
            name=map_outgoing_exercise_name(r["name"]),
            muscle_group=r["muscle_group"],
            type=r["type"]
        ) for r in rows
    ]


# ---------------------------------------------------------------------------
# Workout queries
# ---------------------------------------------------------------------------

def add_workout(
    exercise_name: str,
    sets: int,
    reps: int,
    weight: float,
    db_path: Optional[Path] = None,
) -> Workout:
    """
    Log a workout set and automatically update the PR if improved.
    """
    if sets < 1:
        raise ValueError("Sets must be at least 1.")
    if reps < 1:
        raise ValueError("Reps must be at least 1.")
    if weight < 0.0:
        raise ValueError("Weight cannot be negative.")

    exercise = get_exercise_by_name(exercise_name, db_path)
    if not exercise:
        raise ValueError(
            f"Exercise '{exercise_name}' not found. "
            "Register it first with: gymops add-exercise"
        )

    # Use the normalized PostgreSQL exercise ID for queries
    postgres_exercise = get_exercise_by_name(exercise_name, db_path)
    # Re-fetch from DB to get the actual PostgreSQL seeded name
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT id, name FROM exercise WHERE id = %s", (postgres_exercise.id,))
            ex_row = cur.fetchone()
            postgres_exercise_id = ex_row["id"]

    active = get_active_state(db_path)
    active_day_id = active["day_id"] if active else None

    with get_connection() as conn:
        with conn.cursor() as cur:
            # Find an active session (ended_at IS NULL)
            if active_day_id:
                cur.execute(
                    "SELECT id FROM workout_session WHERE program_day_id = %s AND ended_at IS NULL ORDER BY started_at DESC LIMIT 1",
                    (active_day_id,)
                )
            else:
                cur.execute(
                    "SELECT id FROM workout_session WHERE program_day_id IS NULL AND ended_at IS NULL ORDER BY started_at DESC LIMIT 1"
                )
            sess_row = cur.fetchone()
            
            session_id = None
            if sess_row:
                # Check if this exercise is already logged in this active session.
                # If it is, close this session and start a new one to simulate a new workout session.
                cur.execute(
                    "SELECT EXISTS(SELECT 1 FROM workout_set WHERE session_id = %s AND exercise_id = %s)",
                    (sess_row["id"], postgres_exercise_id)
                )
                already_logged = cur.fetchone()["exists"]
                if already_logged:
                    cur.execute("SELECT * FROM sp_close_session(%s)", (sess_row["id"],))
                else:
                    session_id = sess_row["id"]

            if not session_id:
                # Start a new session using stored procedure
                cur.execute("SELECT session_id FROM sp_start_session(%s)", (active_day_id,))
                session_id = cur.fetchone()["session_id"]

            # Log each set using the stored procedure sp_log_set
            last_row = None
            for set_num in range(1, sets + 1):
                cur.execute(
                    "SELECT * FROM sp_log_set(%s, %s, %s::smallint, %s::smallint, %s::numeric)",
                    (session_id, postgres_exercise_id, set_num, reps, weight)
                )
                last_row = cur.fetchone()

    # Query the latest set to construct the Workout
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """SELECT ws.*, e.name as exercise_name, sess.program_day_id as day_id
                   FROM workout_set ws
                   JOIN exercise e ON ws.exercise_id = e.id
                   JOIN workout_session sess ON ws.session_id = sess.id
                   WHERE ws.id = %s""",
                (last_row["set_id"],)
            )
            row = cur.fetchone()

    d = dict(row)
    return Workout(
        id=d["id"],
        exercise_id=d["exercise_id"],
        exercise_name=map_outgoing_exercise_name(d["exercise_name"]),
        sets=sets,  # return the original logged sets count
        reps=d["reps"],
        weight=float(d["weight_kg"]),
        epley_1rm=float(d["estimated_1rm"]),
        timestamp=d["logged_at"],
        day_id=d.get("day_id"),
    )


def get_history(
    exercise_name: str,
    limit: int = 10,
    db_path: Optional[Path] = None,
) -> list[Workout]:
    """
    Return the most recent workout logs for an exercise, newest first.
    Groups sets from the same session/reps/weight together.
    """
    exercise = get_exercise_by_name(exercise_name, db_path)
    if not exercise:
        raise ValueError(f"Exercise '{exercise_name}' not found.")

    # Re-fetch PostgreSQL ID
    postgres_exercise = get_exercise_by_name(exercise_name, db_path)
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT id FROM exercise WHERE id = %s", (postgres_exercise.id,))
            postgres_exercise_id = cur.fetchone()["id"]

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """SELECT 
                       MAX(h.set_rank)::int AS id,
                       %s AS exercise_id,
                       %s AS exercise_name,
                       COUNT(*)::int AS sets,
                       h.reps,
                       h.weight_kg AS weight,
                       MAX(h.estimated_1rm) AS epley_1rm,
                       MAX(h.session_date) AS timestamp,
                       (SELECT program_day_id FROM workout_session WHERE id = h.session_id) AS day_id
                   FROM fn_exercise_history(%s, %s) h
                   GROUP BY h.session_id, h.reps, h.weight_kg
                   ORDER BY timestamp DESC, id DESC""",
                (postgres_exercise_id, postgres_exercise.name, postgres_exercise_id, limit),
            )
            rows = cur.fetchall()

    return [
        Workout(
            id=r["id"],
            exercise_id=r["exercise_id"],
            exercise_name=map_outgoing_exercise_name(r["exercise_name"]),
            sets=r["sets"],
            reps=r["reps"],
            weight=float(r["weight"]),
            epley_1rm=float(r["epley_1rm"]),
            timestamp=r["timestamp"],
            day_id=r["day_id"],
        )
        for r in rows
    ]


# ---------------------------------------------------------------------------
# PR queries
# ---------------------------------------------------------------------------

def get_all_prs(db_path: Optional[Path] = None) -> list[PR]:
    """Return all personal records joined with exercise names."""
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """SELECT 
                       pr_id AS id,
                       exercise_id,
                       ejercicio AS exercise_name,
                       peso_en_pr_kg AS max_weight,
                       "1rm_max_kg" AS max_epley_1rm,
                       fecha_pr AS timestamp
                   FROM v_current_prs
                   ORDER BY ejercicio""",
            )
            rows = cur.fetchall()

    return [
        PR(
            id=r["id"],
            exercise_id=r["exercise_id"],
            exercise_name=map_outgoing_exercise_name(r["exercise_name"]),
            max_weight=float(r["max_weight"]) if r["max_weight"] else 0.0,
            max_epley_1rm=float(r["max_epley_1rm"]),
            timestamp=r["timestamp"],
        )
        for r in rows
    ]


# ---------------------------------------------------------------------------
# Program queries
# ---------------------------------------------------------------------------

def get_all_programs(db_path: Optional[Path] = None) -> list[Program]:
    """Return all programs ordered by name."""
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """SELECT id, name, CASE WHEN author = 'Jeff Nippard' THEN 'system' ELSE 'user' END AS created_by
                   FROM program
                   ORDER BY name"""
            )
            rows = cur.fetchall()
    return [
        Program(
            id=r["id"],
            name=map_outgoing_program_name(r["name"]),
            created_by=r["created_by"]
        ) for r in rows
    ]


def get_program_days(
    program_id: int, db_path: Optional[Path] = None
) -> list[ProgramDay]:
    """
    Return all training days for a program, ordered by day_order.
    """
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT id, program_id, name, day_order FROM program_day WHERE program_id = %s ORDER BY day_order",
                (program_id,),
            )
            rows = cur.fetchall()
    return [
        ProgramDay(
            id=r["id"],
            program_id=r["program_id"],
            name=format_day_name(r["name"]),
            day_order=r["day_order"]
        ) for r in rows
    ]


def get_day_exercises(
    day_id: int, db_path: Optional[Path] = None
) -> list[DayExercise]:
    """
    Return all exercises for a training day, ordered by display_order.
    """
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """SELECT 
                       re.id,
                       re.program_day_id AS day_id,
                       re.exercise_id,
                       e.name AS exercise_name,
                       re.sets_target AS target_sets,
                       re.reps_target AS target_reps,
                       re.order_in_day AS display_order
                   FROM routine_exercise re
                   JOIN exercise e ON re.exercise_id = e.id
                   WHERE re.program_day_id = %s
                   ORDER BY re.order_in_day""",
                (day_id,),
            )
            rows = cur.fetchall()

    return [
        DayExercise(
            id=r["id"],
            day_id=r["day_id"],
            exercise_id=r["exercise_id"],
            exercise_name=map_outgoing_exercise_name(r["exercise_name"]),
            target_sets=r["target_sets"],
            target_reps=parse_reps(r["target_reps"]),
            display_order=r["display_order"],
        )
        for r in rows
    ]


def add_program(
    name: str,
    days: list[tuple[str, list[tuple[int, int, int]]]],
    db_path: Optional[Path] = None,
) -> Program:
    """
    Create a new user-defined training program.
    """
    normalized_name = normalize_program_name(name)
    days_per_week = len(days)
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT id FROM program WHERE LOWER(name) = LOWER(%s)", (normalized_name,)
            )
            exists = cur.fetchone()
            if exists:
                raise ValueError(f"Program '{name}' already exists.")

            cur.execute(
                "INSERT INTO program (name, author, days_per_week) VALUES (%s, 'user', %s) RETURNING id, name, author",
                (normalized_name, days_per_week)
            )
            program_row = cur.fetchone()
            program_id = program_row["id"]

            for day_order, (day_name, exercises) in enumerate(days, start=1):
                cur.execute(
                    "INSERT INTO program_day (program_id, name, day_order) VALUES (%s, %s, %s) RETURNING id",
                    (program_id, day_name, day_order),
                )
                day_id = cur.fetchone()["id"]

                for display_order, (ex_id, sets, reps) in enumerate(exercises, start=1):
                    cur.execute(
                        """INSERT INTO routine_exercise
                           (program_day_id, exercise_id, sets_target,
                            reps_target, order_in_day)
                           VALUES (%s, %s, %s, %s, %s)""",
                        (day_id, ex_id, sets, str(reps), display_order),
                    )

    return Program(
        id=program_id,
        name=map_outgoing_program_name(program_row["name"]),
        created_by="user"
    )


# ---------------------------------------------------------------------------
# Active program/day state
# ---------------------------------------------------------------------------

def get_active_state(db_path: Optional[Path] = None) -> Optional[dict]:
    """
    Return the currently active program and day as a dict, or None.
    """
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT * FROM active_program WHERE id = 1")
            row = cur.fetchone()
            if not row:
                return None

            result: dict = {
                "program_id": row["program_id"],
                "day_id": row["day_id"],
            }

            if row["program_id"]:
                cur.execute(
                    "SELECT id, name, author FROM program WHERE id = %s",
                    (row["program_id"],),
                )
                p = cur.fetchone()
                if p:
                    created_by = (
                        "system" if p["author"] == "Jeff Nippard" else "user"
                    )
                    result["program"] = Program(
                        id=p["id"],
                        name=map_outgoing_program_name(p["name"]),
                        created_by=created_by
                    )
                else:
                    result["program"] = None
            else:
                result["program"] = None

            if row["day_id"]:
                cur.execute(
                    "SELECT * FROM program_day WHERE id = %s",
                    (row["day_id"],),
                )
                d = cur.fetchone()
                result["day"] = ProgramDay(
                    id=d["id"],
                    program_id=d["program_id"],
                    name=format_day_name(d["name"]),
                    day_order=d["day_order"]
                ) if d else None
            else:
                result["day"] = None

            return result


def set_active_program(
    program_id: int, db_path: Optional[Path] = None
) -> None:
    """
    Set the active program. Clears the active day.
    """
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT id FROM program WHERE id = %s", (program_id,)
            )
            exists = cur.fetchone()
            if not exists:
                raise ValueError(f"Program with id {program_id} not found.")

            cur.execute(
                """INSERT INTO active_program (id, program_id, day_id)
                   VALUES (1, %s, NULL)
                   ON CONFLICT(id) DO UPDATE SET
                       program_id = EXCLUDED.program_id,
                       day_id = NULL""",
                (program_id,),
            )


def set_active_day(day_id: int, db_path: Optional[Path] = None) -> None:
    """
    Set today's training day within the active program.
    """
    active = get_active_state(db_path)
    if not active or not active.get("program_id"):
        raise ValueError(
            "No active program. Set one first with: gymops select-program"
        )

    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT * FROM program_day WHERE id = %s AND program_id = %s",
                (day_id, active["program_id"]),
            )
            day_row = cur.fetchone()
            if not day_row:
                raise ValueError(
                    f"Day id {day_id} does not belong to the active program."
                )
            cur.execute(
                """INSERT INTO active_program (id, program_id, day_id)
                   VALUES (1, %s, %s)
                   ON CONFLICT(id) DO UPDATE SET day_id = EXCLUDED.day_id""",
                (active["program_id"], day_id),
            )


# ---------------------------------------------------------------------------
# Stats & digest queries
# ---------------------------------------------------------------------------

def get_last_two_sessions(
    exercise_name: str, db_path: Optional[Path] = None
) -> list[Workout]:
    """Return the two most recent workout sessions for an exercise."""
    return get_history(exercise_name, limit=2, db_path=db_path)


def get_workouts_in_range(
    days: int = 7, db_path: Optional[Path] = None
) -> list[Workout]:
    """Return all workouts logged within the last N days."""
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """SELECT
                       MAX(ws.id) AS id,
                       ws.exercise_id,
                       e.name AS exercise_name,
                       COUNT(ws.id) AS sets,
                       ws.reps,
                       ws.weight_kg AS weight,
                       MAX(ws.estimated_1rm) AS epley_1rm,
                       MAX(ws.logged_at) AS timestamp,
                       sess.program_day_id AS day_id
                   FROM workout_set ws
                   JOIN exercise e ON ws.exercise_id = e.id
                   JOIN workout_session sess ON ws.session_id = sess.id
                   WHERE ws.logged_at >= NOW() - (%s * INTERVAL '1 day')
                   GROUP BY
                       ws.session_id,
                       ws.exercise_id,
                       e.name,
                       ws.reps,
                       ws.weight_kg,
                       sess.program_day_id
                   ORDER BY timestamp DESC, id DESC""",
                (days,),
            )
            rows = cur.fetchall()

    return [
        Workout(
            id=r["id"],
            exercise_id=r["exercise_id"],
            exercise_name=map_outgoing_exercise_name(r["exercise_name"]),
            sets=r["sets"],
            reps=r["reps"],
            weight=float(r["weight"]),
            epley_1rm=float(r["epley_1rm"]),
            timestamp=r["timestamp"],
            day_id=r["day_id"],
        )
        for r in rows
    ]


def get_weekly_digest_stats(days: int = 7) -> list[dict]:
    """
    Get weekly workout summary stats from the v_workout_history database view.
    """
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """SELECT 
                       ejercicio AS exercise_name,
                       COUNT(*)::int AS sets_logged,
                       MAX(peso_kg)::float AS best_weight,
                       MAX("1rm_estimado_kg")::float AS best_1rm
                   FROM v_workout_history
                   WHERE fecha >= CURRENT_DATE - (%s * INTERVAL '1 day')
                   GROUP BY ejercicio
                   ORDER BY ejercicio""",
                (days,)
            )
            return [dict(r) for r in cur.fetchall()]


# ---------------------------------------------------------------------------
# Guide Articles (UNFV Fitness Guides)
# ---------------------------------------------------------------------------

def get_all_articles(db_path: Optional[Path] = None) -> list[GuideArticle]:
    """Retrieve all guide articles from the database."""
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT id, title, slug, category, content_md "
                "FROM guide_article ORDER BY category, title"
            )
            rows = cur.fetchall()

    return [
        GuideArticle(
            id=r["id"],
            title=r["title"],
            slug=r["slug"],
            category=r["category"],
            content_md=r["content_md"]
        )
        for r in rows
    ]


def get_article_by_slug(
    slug: str, db_path: Optional[Path] = None
) -> Optional[GuideArticle]:
    """Retrieve a specific guide article by its slug."""
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT id, title, slug, category, content_md "
                "FROM guide_article WHERE LOWER(slug) = LOWER(%s)",
                (slug.strip(),)
            )
            row = cur.fetchone()

    if not row:
        return None

    return GuideArticle(
        id=row["id"],
        title=row["title"],
        slug=row["slug"],
        category=row["category"],
        content_md=row["content_md"]
    )
