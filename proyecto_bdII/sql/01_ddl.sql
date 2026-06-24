-- =============================================================================
-- GymOps — Base de Datos II (FIEI)
-- Script 01: DDL — Definición de estructura de la base de datos
-- Gestor: PostgreSQL 16
-- Autor: Piero Rivera
-- =============================================================================

-- Eliminar tablas si existen (orden inverso de dependencias)
DROP TABLE IF EXISTS audit_log           CASCADE;
DROP TABLE IF EXISTS personal_record     CASCADE;
DROP TABLE IF EXISTS workout_set         CASCADE;
DROP TABLE IF EXISTS workout_session     CASCADE;
DROP TABLE IF EXISTS routine_exercise    CASCADE;
DROP TABLE IF EXISTS program_day         CASCADE;
DROP TABLE IF EXISTS program             CASCADE;
DROP TABLE IF EXISTS exercise            CASCADE;
DROP TABLE IF EXISTS muscle_group        CASCADE;

-- =============================================================================
-- 1. MUSCLE_GROUP — Grupos musculares
-- =============================================================================
CREATE TABLE muscle_group (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(50)  NOT NULL UNIQUE,
    description TEXT
);

COMMENT ON TABLE  muscle_group            IS 'Catálogo de grupos musculares del cuerpo humano';
COMMENT ON COLUMN muscle_group.name       IS 'Nombre del grupo muscular (ej: Pecho, Espalda)';

-- =============================================================================
-- 2. EXERCISE — Catálogo de ejercicios
-- =============================================================================
CREATE TABLE exercise (
    id               SERIAL PRIMARY KEY,
    name             VARCHAR(100) NOT NULL UNIQUE,
    muscle_group_id  INT          NOT NULL REFERENCES muscle_group(id) ON DELETE RESTRICT,
    type             VARCHAR(20)  NOT NULL CHECK (type IN ('compound', 'isolation')),
    equipment        VARCHAR(50)  NOT NULL DEFAULT 'barbell',
    description      TEXT,
    created_at       TIMESTAMP    NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  exercise                   IS 'Catálogo maestro de ejercicios disponibles';
COMMENT ON COLUMN exercise.type              IS 'compound = ejercicio multiarticular, isolation = monoarticular';
COMMENT ON COLUMN exercise.equipment         IS 'Equipamiento requerido (barbell, dumbbell, cable, machine, bodyweight)';

-- =============================================================================
-- 3. PROGRAM — Programas de entrenamiento
-- =============================================================================
CREATE TABLE program (
    id             SERIAL PRIMARY KEY,
    name           VARCHAR(100) NOT NULL UNIQUE,
    description    TEXT,
    days_per_week  SMALLINT     NOT NULL CHECK (days_per_week BETWEEN 1 AND 7),
    author         VARCHAR(100),
    created_at     TIMESTAMP    NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  program                IS 'Programas de entrenamiento (splits)';
COMMENT ON COLUMN program.author         IS 'Autor del programa (ej: Jeff Nippard)';

-- =============================================================================
-- 4. PROGRAM_DAY — Días de cada programa
-- =============================================================================
CREATE TABLE program_day (
    id          SERIAL PRIMARY KEY,
    program_id  INT          NOT NULL REFERENCES program(id) ON DELETE CASCADE,
    name        VARCHAR(100) NOT NULL,
    day_order   SMALLINT     NOT NULL CHECK (day_order >= 1),
    focus       VARCHAR(100),
    UNIQUE (program_id, day_order)
);

COMMENT ON TABLE  program_day            IS 'Días individuales dentro de un programa de entrenamiento';
COMMENT ON COLUMN program_day.focus      IS 'Enfoque del día (ej: Fuerza, Hipertrofia, Empuje, Tirón)';

-- =============================================================================
-- 5. ROUTINE_EXERCISE — Ejercicios asignados a cada día
-- =============================================================================
CREATE TABLE routine_exercise (
    id              SERIAL PRIMARY KEY,
    program_day_id  INT          NOT NULL REFERENCES program_day(id) ON DELETE CASCADE,
    exercise_id     INT          NOT NULL REFERENCES exercise(id)     ON DELETE RESTRICT,
    sets_target     SMALLINT     NOT NULL CHECK (sets_target > 0),
    reps_target     VARCHAR(20)  NOT NULL,   -- permite rangos: "6-8", "8-12", "12-15"
    rest_seconds    SMALLINT,
    notes           TEXT,
    order_in_day    SMALLINT     NOT NULL DEFAULT 1,
    UNIQUE (program_day_id, exercise_id)
);

COMMENT ON TABLE  routine_exercise              IS 'Ejercicios prescritos para cada día del programa';
COMMENT ON COLUMN routine_exercise.reps_target  IS 'Rango de repeticiones objetivo (ej: "6-8", "8-12")';

-- =============================================================================
-- 6. WORKOUT_SESSION — Sesión de entrenamiento realizada
-- =============================================================================
CREATE TABLE workout_session (
    id              SERIAL PRIMARY KEY,
    program_day_id  INT          REFERENCES program_day(id) ON DELETE SET NULL,
    started_at      TIMESTAMP    NOT NULL DEFAULT NOW(),
    ended_at        TIMESTAMP,
    notes           TEXT,
    CONSTRAINT chk_session_dates CHECK (ended_at IS NULL OR ended_at > started_at)
);

COMMENT ON TABLE  workout_session               IS 'Sesión de entrenamiento realizada por el usuario';
COMMENT ON COLUMN workout_session.ended_at      IS 'NULL mientras la sesión está activa';

-- =============================================================================
-- 7. WORKOUT_SET — Sets registrados en una sesión
-- =============================================================================
CREATE TABLE workout_set (
    id              SERIAL PRIMARY KEY,
    session_id      INT            NOT NULL REFERENCES workout_session(id) ON DELETE CASCADE,
    exercise_id     INT            NOT NULL REFERENCES exercise(id)         ON DELETE RESTRICT,
    set_number      SMALLINT       NOT NULL CHECK (set_number > 0),
    reps            SMALLINT       NOT NULL CHECK (reps > 0),
    weight_kg       NUMERIC(6,2)   NOT NULL CHECK (weight_kg > 0),
    estimated_1rm   NUMERIC(6,2),             -- calculado por trigger
    volume          NUMERIC(8,2),             -- weight_kg * reps, calculado por trigger
    is_pr           BOOLEAN        NOT NULL DEFAULT FALSE,
    logged_at       TIMESTAMP      NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  workout_set                IS 'Serie individual registrada durante una sesión';
COMMENT ON COLUMN workout_set.estimated_1rm  IS 'Fórmula Epley: weight * (1 + reps/30)';
COMMENT ON COLUMN workout_set.volume         IS 'Volumen del set: weight_kg * reps';
COMMENT ON COLUMN workout_set.is_pr          IS 'TRUE si este set estableció un récord personal';

-- =============================================================================
-- 8. PERSONAL_RECORD — Récords personales por ejercicio
-- =============================================================================
CREATE TABLE personal_record (
    id           SERIAL PRIMARY KEY,
    exercise_id  INT           NOT NULL UNIQUE REFERENCES exercise(id) ON DELETE CASCADE,
    max_1rm      NUMERIC(6,2)  NOT NULL CHECK (max_1rm > 0),
    achieved_at  TIMESTAMP     NOT NULL DEFAULT NOW(),
    set_id       INT           REFERENCES workout_set(id) ON DELETE SET NULL
);

COMMENT ON TABLE  personal_record             IS 'Récord personal más alto por ejercicio (1RM estimado)';
COMMENT ON COLUMN personal_record.max_1rm     IS 'Máximo 1RM estimado alcanzado históricamente';
COMMENT ON COLUMN personal_record.set_id      IS 'Set específico donde se logró el PR';

-- =============================================================================
-- 9. AUDIT_LOG — Registro de auditoría de cambios
-- =============================================================================
CREATE TABLE audit_log (
    id          SERIAL PRIMARY KEY,
    table_name  VARCHAR(50)  NOT NULL,
    operation   VARCHAR(10)  NOT NULL CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE')),
    old_data    JSONB,
    new_data    JSONB,
    changed_at  TIMESTAMP    NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  audit_log             IS 'Log de auditoría de operaciones sobre tablas críticas';
COMMENT ON COLUMN audit_log.old_data    IS 'Estado anterior del registro (NULL en INSERT)';
COMMENT ON COLUMN audit_log.new_data    IS 'Estado nuevo del registro (NULL en DELETE)';

-- =============================================================================
-- Verificación final
-- =============================================================================
SELECT
    table_name,
    (SELECT COUNT(*) FROM information_schema.columns c
     WHERE c.table_name = t.table_name AND c.table_schema = 'public') AS columnas
FROM information_schema.tables t
WHERE table_schema = 'public'
ORDER BY table_name;
