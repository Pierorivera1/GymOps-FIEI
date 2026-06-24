-- =============================================================================
-- GymOps — Base de Datos II (FIEI)
-- Script 06: ÍNDICES y OPTIMIZACIÓN
-- Gestor: PostgreSQL 16
-- Autor: Piero Rivera
-- =============================================================================
-- Cubre:
--   - Índices B-tree (equivalente a clustered/nonclustered en SQL Server)
--   - Índices parciales (filtered indexes)
--   - Índices compuestos
--   - Índices en expresiones
--   - Análisis de planes de ejecución con EXPLAIN ANALYZE
-- =============================================================================

-- Eliminar índices si existen (para re-ejecución idempotente)
DROP INDEX IF EXISTS idx_set_session;
DROP INDEX IF EXISTS idx_set_exercise_date;
DROP INDEX IF EXISTS idx_set_logged_at;
DROP INDEX IF EXISTS idx_set_is_pr;
DROP INDEX IF EXISTS idx_set_exercise_1rm;
DROP INDEX IF EXISTS idx_pr_exercise;
DROP INDEX IF EXISTS idx_pr_max_1rm;
DROP INDEX IF EXISTS idx_session_started;
DROP INDEX IF EXISTS idx_session_program_day;
DROP INDEX IF EXISTS idx_session_active;
DROP INDEX IF EXISTS idx_audit_table_op;
DROP INDEX IF EXISTS idx_audit_changed_at;
DROP INDEX IF EXISTS idx_exercise_muscle;
DROP INDEX IF EXISTS idx_exercise_name_lower;
DROP INDEX IF EXISTS idx_routine_day;


-- =============================================================================
-- GRUPO 1: Índices sobre workout_set
-- Tabla más consultada — cada log de entrenamiento es un set
-- =============================================================================

-- IDX-01: Búsqueda de todos los sets de una sesión (JOIN más frecuente)
-- Tipo: B-tree en columna FK
-- Uso: v_session_summary, sp_log_set, sp_close_session
CREATE INDEX idx_set_session
    ON workout_set (session_id);

COMMENT ON INDEX idx_set_session IS
'Acelera los JOINs entre workout_set y workout_session. Consulta más frecuente del sistema.';


-- IDX-02: Historial de un ejercicio ordenado cronológicamente (compuesto)
-- Tipo: B-tree compuesto — exercise_id + logged_at
-- Uso: gymops history, v_workout_history, v_exercise_progress
CREATE INDEX idx_set_exercise_date
    ON workout_set (exercise_id, logged_at DESC);

COMMENT ON INDEX idx_set_exercise_date IS
'Índice compuesto para historial cronológico por ejercicio. Evita sort en consultas de historial.';


-- IDX-03: Ordenamiento global por fecha descendente (últimas sesiones)
-- Tipo: B-tree DESC — optimiza queries sin filtro de ejercicio
-- Uso: v_workout_history ORDER BY fecha DESC
CREATE INDEX idx_set_logged_at
    ON workout_set (logged_at DESC);

COMMENT ON INDEX idx_set_logged_at IS
'Índice descendente en fecha de log para consultas de actividad reciente.';


-- IDX-04: Índice parcial — solo sets que son PRs
-- Tipo: B-tree parcial (filtered index en SQL Server)
-- Uso: v_current_prs, v_pr_timeline — filtra solo is_pr = TRUE
CREATE INDEX idx_set_is_pr
    ON workout_set (exercise_id, estimated_1rm DESC)
    WHERE is_pr = TRUE;

COMMENT ON INDEX idx_set_is_pr IS
'Índice parcial: solo indexa sets que son PRs (is_pr=TRUE). Muy selectivo y ligero.';


-- IDX-05: Optimización de ranking de 1RM por ejercicio
-- Tipo: B-tree compuesto para window functions de ranking
-- Uso: fn_epley_1rm, v_exercise_progress RANK()
CREATE INDEX idx_set_exercise_1rm
    ON workout_set (exercise_id, estimated_1rm DESC NULLS LAST);

COMMENT ON INDEX idx_set_exercise_1rm IS
'Optimiza RANK() y MAX() de 1RM por ejercicio. Acelera detección de PRs.';


-- =============================================================================
-- GRUPO 2: Índices sobre personal_record
-- Tabla pequeña pero con alta frecuencia de lectura en cada log
-- =============================================================================

-- IDX-06: Lookup de PR por ejercicio (UNIQUE ya existe, este es covering)
-- Tipo: B-tree — cubre la columna más buscada
-- Uso: trg_update_pr, fn_is_pr, v_current_prs
CREATE INDEX idx_pr_exercise
    ON personal_record (exercise_id);

COMMENT ON INDEX idx_pr_exercise IS
'Lookup O(log n) del PR de un ejercicio. Crítico para el trigger de actualización de PR.';


-- IDX-07: Ranking de PRs por valor de 1RM
-- Tipo: B-tree DESC — optimiza ranking y top-N
-- Uso: v_current_prs ORDER BY 1RM, Q5 ranking por músculo
CREATE INDEX idx_pr_max_1rm
    ON personal_record (max_1rm DESC);

COMMENT ON INDEX idx_pr_max_1rm IS
'Índice descendente en max_1rm para rankings y consultas de top ejercicios.';


-- =============================================================================
-- GRUPO 3: Índices sobre workout_session
-- =============================================================================

-- IDX-08: Consultas de sesiones ordenadas por fecha (más reciente primero)
-- Tipo: B-tree DESC
-- Uso: v_session_summary, sp_start_session, sp_weekly_digest
CREATE INDEX idx_session_started
    ON workout_session (started_at DESC);

COMMENT ON INDEX idx_session_started IS
'Índice descendente en fecha de inicio de sesión para consultas de actividad reciente.';


-- IDX-09: Filtro por día de programa
-- Tipo: B-tree en FK
-- Uso: Consultas que filtran por día específico del programa
CREATE INDEX idx_session_program_day
    ON workout_session (program_day_id);

COMMENT ON INDEX idx_session_program_day IS
'Acelera joins y filtros entre workout_session y program_day.';


-- IDX-10: Índice parcial — solo sesiones activas (ended_at IS NULL)
-- Tipo: B-tree parcial
-- Uso: trg_prevent_closed_session, sp_log_set validación
CREATE INDEX idx_session_active
    ON workout_session (id)
    WHERE ended_at IS NULL;

COMMENT ON INDEX idx_session_active IS
'Índice parcial: solo sesiones abiertas (ended_at IS NULL). Mínimo espacio, máxima velocidad.';


-- =============================================================================
-- GRUPO 4: Índices sobre audit_log
-- Tabla que crece continuamente — queries de auditoría deben ser rápidos
-- =============================================================================

-- IDX-11: Filtro por tabla y operación en el audit log
-- Tipo: B-tree compuesto
-- Uso: Consultas de auditoría por tabla/tipo de operación
CREATE INDEX idx_audit_table_op
    ON audit_log (table_name, operation, changed_at DESC);

COMMENT ON INDEX idx_audit_table_op IS
'Índice compuesto para auditoría: filtra por tabla + operación y ordena por fecha.';


-- IDX-12: Consultas de auditoría por rango de fechas
-- Tipo: B-tree DESC para retention queries y borrado por antigüedad
-- Uso: DELETE FROM audit_log WHERE changed_at < NOW() - INTERVAL '90 days'
CREATE INDEX idx_audit_changed_at
    ON audit_log (changed_at DESC);

COMMENT ON INDEX idx_audit_changed_at IS
'Optimiza borrado por retención (changed_at < fecha) y consultas temporales de auditoría.';


-- =============================================================================
-- GRUPO 5: Índices sobre exercise y routine_exercise
-- =============================================================================

-- IDX-13: Filtro de ejercicios por músculo
-- Tipo: B-tree en FK
-- Uso: gymops list por músculo, v_exercise_catalog WHERE musculo = X
CREATE INDEX idx_exercise_muscle
    ON exercise (muscle_group_id);

COMMENT ON INDEX idx_exercise_muscle IS
'Acelera filtros de ejercicios por grupo muscular. Reduce seq scan sobre exercise.';


-- IDX-14: Búsqueda case-insensitive por nombre de ejercicio
-- Tipo: B-tree en expresión (LOWER)
-- Uso: gymops log --exercise "barbell bench press" (búsqueda sin distinción de mayúsculas)
CREATE INDEX idx_exercise_name_lower
    ON exercise (LOWER(name));

COMMENT ON INDEX idx_exercise_name_lower IS
'Índice en expresión LOWER(name). Permite búsqueda case-insensitive en O(log n).';


-- IDX-15: Ejercicios asignados a un día de programa
-- Tipo: B-tree en FK
-- Uso: sp_start_session, v_program_overview
CREATE INDEX idx_routine_day
    ON routine_exercise (program_day_id);

COMMENT ON INDEX idx_routine_day IS
'Acelera carga de rutina al iniciar sesión: obtener ejercicios del día actual.';


-- =============================================================================
-- ANÁLISIS DE PLANES DE EJECUCIÓN (EXPLAIN ANALYZE)
-- =============================================================================

SELECT '=== PLANES DE EJECUCIÓN ===' AS seccion;

-- PLAN 1: Consulta de historial de un ejercicio (usa idx_set_exercise_date)
SELECT '--- Plan 1: historial de ejercicio ---' AS plan;
EXPLAIN (FORMAT TEXT, ANALYZE, BUFFERS)
SELECT ws.set_number, ws.reps, ws.weight_kg, ws.estimated_1rm, ws.logged_at
FROM workout_set ws
WHERE ws.exercise_id = (SELECT id FROM exercise WHERE name = 'Barbell Bench Press')
ORDER BY ws.logged_at DESC
LIMIT 10;

-- PLAN 2: Lookup de PR de un ejercicio (usa idx_pr_exercise)
SELECT '--- Plan 2: PR de ejercicio ---' AS plan;
EXPLAIN (FORMAT TEXT, ANALYZE, BUFFERS)
SELECT max_1rm, achieved_at
FROM personal_record
WHERE exercise_id = (SELECT id FROM exercise WHERE name = 'Barbell Bench Press');

-- PLAN 3: Consulta de sesiones recientes (usa idx_session_started)
SELECT '--- Plan 3: sesiones recientes ---' AS plan;
EXPLAIN (FORMAT TEXT, ANALYZE, BUFFERS)
SELECT id, started_at, ended_at
FROM workout_session
ORDER BY started_at DESC
LIMIT 5;

-- PLAN 4: Búsqueda case-insensitive de ejercicio (usa idx_exercise_name_lower)
SELECT '--- Plan 4: búsqueda case-insensitive ---' AS plan;
EXPLAIN (FORMAT TEXT, ANALYZE, BUFFERS)
SELECT id, name, type FROM exercise
WHERE LOWER(name) = LOWER('barbell bench press');

-- PLAN 5: Todos los PRs (usa idx_set_is_pr — índice parcial)
SELECT '--- Plan 5: sets que son PR (índice parcial) ---' AS plan;
EXPLAIN (FORMAT TEXT, ANALYZE, BUFFERS)
SELECT exercise_id, estimated_1rm, logged_at
FROM workout_set
WHERE is_pr = TRUE
ORDER BY estimated_1rm DESC;


-- =============================================================================
-- RESUMEN DE ÍNDICES CREADOS
-- =============================================================================
SELECT '=== ÍNDICES CREADOS EN LA BD ===' AS seccion;

SELECT
    indexname                               AS indice,
    tablename                               AS tabla,
    indexdef                                AS definicion
FROM pg_indexes
WHERE schemaname = 'public'
  AND indexname NOT LIKE '%_pkey'       -- excluir PKs (ya son índices automáticos)
ORDER BY tablename, indexname;
