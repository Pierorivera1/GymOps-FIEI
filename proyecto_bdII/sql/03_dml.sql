-- =============================================================================
-- GymOps — Base de Datos II (FIEI)
-- Script 03: DML — Manipulación de datos
-- Gestor: PostgreSQL 16
-- Autor: Piero Rivera
-- =============================================================================
-- Cubre: INSERT, UPDATE, DELETE, consultas parametrizadas, filtros, validaciones
-- =============================================================================


-- =============================================================================
-- SECCIÓN A: INSERCIÓN DE DATOS DE ENTRENAMIENTO (datos demo realistas)
-- =============================================================================
-- Simulamos 6 semanas de entrenamiento con el programa Upper/Lower 4-Day.
-- estimated_1rm = weight_kg * (1 + reps / 30.0)   [Fórmula de Epley]
-- volume        = weight_kg * reps
-- Nota: En la versión con triggers (script 09) estos campos se calcularán
--       automáticamente al hacer INSERT en workout_set.
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- SESIÓN 1 — Semana 1 (Upper A: Fuerza) — hace 42 días
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO workout_session (program_day_id, started_at, ended_at, notes)
VALUES (1, NOW() - INTERVAL '42 days', NOW() - INTERVAL '42 days' + INTERVAL '75 minutes',
        'Primera sesión de fuerza. Todo se siente pesado.');

INSERT INTO workout_set (session_id, exercise_id, set_number, reps, weight_kg, estimated_1rm, volume, is_pr, logged_at)
SELECT
    (SELECT id FROM workout_session ORDER BY started_at ASC LIMIT 1 OFFSET 0),
    id, set_num, reps_val, weight_val,
    ROUND((weight_val * (1 + reps_val / 30.0))::numeric, 2),
    ROUND((weight_val * reps_val)::numeric, 2),
    FALSE,
    NOW() - INTERVAL '42 days'
FROM exercise, (VALUES
    ('Barbell Bench Press',       1, 5, 70.0),
    ('Barbell Bench Press',       2, 5, 70.0),
    ('Barbell Bench Press',       3, 5, 70.0),
    ('Barbell Bench Press',       4, 4, 70.0),
    ('Barbell Row',               1, 5, 65.0),
    ('Barbell Row',               2, 5, 65.0),
    ('Barbell Row',               3, 5, 65.0),
    ('Overhead Press',            1, 8, 45.0),
    ('Overhead Press',            2, 7, 45.0),
    ('Overhead Press',            3, 7, 45.0),
    ('Pull Up',                   1, 8, 0.0),
    ('Pull Up',                   2, 6, 0.0),
    ('Pull Up',                   3, 6, 0.0)
) AS d(ex_name, set_num, reps_val, weight_val)
WHERE exercise.name = d.ex_name;

-- ─────────────────────────────────────────────────────────────────────────────
-- SESIÓN 2 — Semana 1 (Lower A: Fuerza) — hace 41 días
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO workout_session (program_day_id, started_at, ended_at, notes)
VALUES (2, NOW() - INTERVAL '41 days', NOW() - INTERVAL '41 days' + INTERVAL '80 minutes',
        'Sentadilla pesada. Lumbar un poco cargada al final.');

INSERT INTO workout_set (session_id, exercise_id, set_number, reps, weight_kg, estimated_1rm, volume, is_pr, logged_at)
SELECT
    (SELECT id FROM workout_session ORDER BY started_at ASC LIMIT 1 OFFSET 1),
    id, set_num, reps_val, weight_val,
    ROUND((weight_val * (1 + reps_val / 30.0))::numeric, 2),
    ROUND((weight_val * reps_val)::numeric, 2),
    FALSE,
    NOW() - INTERVAL '41 days'
FROM exercise, (VALUES
    ('Barbell Squat',             1, 5, 90.0),
    ('Barbell Squat',             2, 5, 90.0),
    ('Barbell Squat',             3, 5, 90.0),
    ('Barbell Squat',             4, 3, 90.0),
    ('Romanian Deadlift',         1, 8, 70.0),
    ('Romanian Deadlift',         2, 8, 70.0),
    ('Romanian Deadlift',         3, 8, 70.0),
    ('Leg Press',                 1, 12, 140.0),
    ('Leg Press',                 2, 12, 140.0),
    ('Leg Press',                 3, 10, 140.0),
    ('Leg Curl',                  1, 12, 35.0),
    ('Leg Curl',                  2, 12, 35.0),
    ('Standing Calf Raise',       1, 15, 60.0),
    ('Standing Calf Raise',       2, 15, 60.0),
    ('Standing Calf Raise',       3, 12, 60.0)
) AS d(ex_name, set_num, reps_val, weight_val)
WHERE exercise.name = d.ex_name;

-- ─────────────────────────────────────────────────────────────────────────────
-- SESIÓN 3 — Semana 2 (Upper A: Fuerza) — hace 35 días
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO workout_session (program_day_id, started_at, ended_at, notes)
VALUES (1, NOW() - INTERVAL '35 days', NOW() - INTERVAL '35 days' + INTERVAL '70 minutes',
        'Semana 2: +2.5 kg en banco.');

INSERT INTO workout_set (session_id, exercise_id, set_number, reps, weight_kg, estimated_1rm, volume, is_pr, logged_at)
SELECT
    (SELECT id FROM workout_session ORDER BY started_at ASC LIMIT 1 OFFSET 2),
    id, set_num, reps_val, weight_val,
    ROUND((weight_val * (1 + reps_val / 30.0))::numeric, 2),
    ROUND((weight_val * reps_val)::numeric, 2),
    FALSE,
    NOW() - INTERVAL '35 days'
FROM exercise, (VALUES
    ('Barbell Bench Press',       1, 5, 72.5),
    ('Barbell Bench Press',       2, 5, 72.5),
    ('Barbell Bench Press',       3, 5, 72.5),
    ('Barbell Bench Press',       4, 5, 72.5),
    ('Barbell Row',               1, 5, 67.5),
    ('Barbell Row',               2, 5, 67.5),
    ('Barbell Row',               3, 5, 67.5),
    ('Overhead Press',            1, 8, 47.5),
    ('Overhead Press',            2, 8, 47.5),
    ('Overhead Press',            3, 7, 47.5),
    ('Pull Up',                   1, 9, 0.0),
    ('Pull Up',                   2, 8, 0.0),
    ('Pull Up',                   3, 7, 0.0),
    ('Incline Barbell Bench Press', 1, 10, 55.0),
    ('Incline Barbell Bench Press', 2, 10, 55.0),
    ('Incline Barbell Bench Press', 3, 9,  55.0)
) AS d(ex_name, set_num, reps_val, weight_val)
WHERE exercise.name = d.ex_name;

-- ─────────────────────────────────────────────────────────────────────────────
-- SESIÓN 4 — Semana 2 (Lower A: Fuerza) — hace 34 días
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO workout_session (program_day_id, started_at, ended_at, notes)
VALUES (2, NOW() - INTERVAL '34 days', NOW() - INTERVAL '34 days' + INTERVAL '85 minutes',
        'Sentadilla sólida. +5 kg respecto semana 1.');

INSERT INTO workout_set (session_id, exercise_id, set_number, reps, weight_kg, estimated_1rm, volume, is_pr, logged_at)
SELECT
    (SELECT id FROM workout_session ORDER BY started_at ASC LIMIT 1 OFFSET 3),
    id, set_num, reps_val, weight_val,
    ROUND((weight_val * (1 + reps_val / 30.0))::numeric, 2),
    ROUND((weight_val * reps_val)::numeric, 2),
    FALSE,
    NOW() - INTERVAL '34 days'
FROM exercise, (VALUES
    ('Barbell Squat',             1, 5, 95.0),
    ('Barbell Squat',             2, 5, 95.0),
    ('Barbell Squat',             3, 5, 95.0),
    ('Barbell Squat',             4, 4, 95.0),
    ('Romanian Deadlift',         1, 8, 72.5),
    ('Romanian Deadlift',         2, 8, 72.5),
    ('Romanian Deadlift',         3, 7, 72.5),
    ('Leg Press',                 1, 12, 150.0),
    ('Leg Press',                 2, 12, 150.0),
    ('Leg Press',                 3, 12, 150.0),
    ('Leg Curl',                  1, 12, 37.5),
    ('Leg Curl',                  2, 12, 37.5),
    ('Leg Curl',                  3, 10, 37.5),
    ('Standing Calf Raise',       1, 15, 65.0),
    ('Standing Calf Raise',       2, 15, 65.0),
    ('Standing Calf Raise',       3, 15, 65.0),
    ('Standing Calf Raise',       4, 12, 65.0)
) AS d(ex_name, set_num, reps_val, weight_val)
WHERE exercise.name = d.ex_name;

-- ─────────────────────────────────────────────────────────────────────────────
-- SESIÓN 5 — Semana 3 (Upper B: Hipertrofia) — hace 28 días
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO workout_session (program_day_id, started_at, ended_at, notes)
VALUES (3, NOW() - INTERVAL '28 days', NOW() - INTERVAL '28 days' + INTERVAL '90 minutes',
        'Sesión de volumen. Mucha bomba muscular.');

INSERT INTO workout_set (session_id, exercise_id, set_number, reps, weight_kg, estimated_1rm, volume, is_pr, logged_at)
SELECT
    (SELECT id FROM workout_session ORDER BY started_at ASC LIMIT 1 OFFSET 4),
    id, set_num, reps_val, weight_val,
    ROUND((weight_val * (1 + reps_val / 30.0))::numeric, 2),
    ROUND((weight_val * reps_val)::numeric, 2),
    FALSE,
    NOW() - INTERVAL '28 days'
FROM exercise, (VALUES
    ('Incline Barbell Bench Press', 1, 10, 57.5),
    ('Incline Barbell Bench Press', 2, 10, 57.5),
    ('Incline Barbell Bench Press', 3, 9,  57.5),
    ('Incline Barbell Bench Press', 4, 8,  57.5),
    ('Lat Pulldown',              1, 10, 55.0),
    ('Lat Pulldown',              2, 10, 55.0),
    ('Lat Pulldown',              3, 10, 55.0),
    ('Lat Pulldown',              4, 9,  55.0),
    ('Dumbbell Shoulder Press',   1, 12, 20.0),
    ('Dumbbell Shoulder Press',   2, 12, 20.0),
    ('Dumbbell Shoulder Press',   3, 10, 20.0),
    ('Seated Cable Row',          1, 12, 50.0),
    ('Seated Cable Row',          2, 12, 50.0),
    ('Seated Cable Row',          3, 12, 50.0),
    ('Cable Fly',                 1, 15, 12.0),
    ('Cable Fly',                 2, 15, 12.0),
    ('Cable Fly',                 3, 15, 12.0),
    ('Lateral Raise',             1, 15, 10.0),
    ('Lateral Raise',             2, 15, 10.0),
    ('Lateral Raise',             3, 15, 10.0),
    ('Lateral Raise',             4, 12, 10.0),
    ('Barbell Curl',              1, 10, 30.0),
    ('Barbell Curl',              2, 10, 30.0),
    ('Barbell Curl',              3, 10, 30.0),
    ('Tricep Pushdown',           1, 12, 22.5),
    ('Tricep Pushdown',           2, 12, 22.5),
    ('Tricep Pushdown',           3, 12, 22.5)
) AS d(ex_name, set_num, reps_val, weight_val)
WHERE exercise.name = d.ex_name;

-- ─────────────────────────────────────────────────────────────────────────────
-- SESIÓN 6 — Semana 3 (Lower B: Hipertrofia) — hace 27 días
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO workout_session (program_day_id, started_at, ended_at, notes)
VALUES (4, NOW() - INTERVAL '27 days', NOW() - INTERVAL '27 days' + INTERVAL '80 minutes',
        'Piernas con volumen. Cuádriceps destruidos.');

INSERT INTO workout_set (session_id, exercise_id, set_number, reps, weight_kg, estimated_1rm, volume, is_pr, logged_at)
SELECT
    (SELECT id FROM workout_session ORDER BY started_at ASC LIMIT 1 OFFSET 5),
    id, set_num, reps_val, weight_val,
    ROUND((weight_val * (1 + reps_val / 30.0))::numeric, 2),
    ROUND((weight_val * reps_val)::numeric, 2),
    FALSE,
    NOW() - INTERVAL '27 days'
FROM exercise, (VALUES
    ('Bulgarian Split Squat',     1, 10, 30.0),
    ('Bulgarian Split Squat',     2, 10, 30.0),
    ('Bulgarian Split Squat',     3, 9,  30.0),
    ('Bulgarian Split Squat',     4, 8,  30.0),
    ('Leg Press',                 1, 15, 160.0),
    ('Leg Press',                 2, 15, 160.0),
    ('Leg Press',                 3, 12, 160.0),
    ('Leg Press',                 4, 12, 160.0),
    ('Leg Extension',             1, 15, 40.0),
    ('Leg Extension',             2, 15, 40.0),
    ('Leg Extension',             3, 12, 40.0),
    ('Leg Curl',                  1, 12, 40.0),
    ('Leg Curl',                  2, 12, 40.0),
    ('Leg Curl',                  3, 10, 40.0),
    ('Hip Thrust',                1, 12, 80.0),
    ('Hip Thrust',                2, 12, 80.0),
    ('Hip Thrust',                3, 12, 80.0),
    ('Seated Calf Raise',         1, 15, 45.0),
    ('Seated Calf Raise',         2, 15, 45.0),
    ('Seated Calf Raise',         3, 15, 45.0),
    ('Seated Calf Raise',         4, 12, 45.0)
) AS d(ex_name, set_num, reps_val, weight_val)
WHERE exercise.name = d.ex_name;

-- ─────────────────────────────────────────────────────────────────────────────
-- SESIÓN 7 — Semana 4 (Upper A: Fuerza) — hace 21 días — PICO DE FUERZA
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO workout_session (program_day_id, started_at, ended_at, notes)
VALUES (1, NOW() - INTERVAL '21 days', NOW() - INTERVAL '21 days' + INTERVAL '65 minutes',
        'PR en banco! 80 kg x 5. Mejor sesión hasta ahora.');

INSERT INTO workout_set (session_id, exercise_id, set_number, reps, weight_kg, estimated_1rm, volume, is_pr, logged_at)
SELECT
    (SELECT id FROM workout_session ORDER BY started_at ASC LIMIT 1 OFFSET 6),
    id, set_num, reps_val, weight_val,
    ROUND((weight_val * (1 + reps_val / 30.0))::numeric, 2),
    ROUND((weight_val * reps_val)::numeric, 2),
    is_pr_val,
    NOW() - INTERVAL '21 days'
FROM exercise, (VALUES
    ('Barbell Bench Press',       1, 5, 77.5, FALSE),
    ('Barbell Bench Press',       2, 5, 77.5, FALSE),
    ('Barbell Bench Press',       3, 5, 80.0, TRUE),
    ('Barbell Bench Press',       4, 4, 80.0, FALSE),
    ('Barbell Row',               1, 5, 70.0, TRUE),
    ('Barbell Row',               2, 5, 70.0, FALSE),
    ('Barbell Row',               3, 5, 70.0, FALSE),
    ('Overhead Press',            1, 8, 50.0, TRUE),
    ('Overhead Press',            2, 8, 50.0, FALSE),
    ('Overhead Press',            3, 7, 50.0, FALSE),
    ('Pull Up',                   1, 10, 0.0, TRUE),
    ('Pull Up',                   2, 9,  0.0, FALSE),
    ('Pull Up',                   3, 8,  0.0, FALSE)
) AS d(ex_name, set_num, reps_val, weight_val, is_pr_val)
WHERE exercise.name = d.ex_name;

-- ─────────────────────────────────────────────────────────────────────────────
-- SESIÓN 8 — Semana 5 (Upper A: Fuerza) — hace 14 días
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO workout_session (program_day_id, started_at, ended_at, notes)
VALUES (1, NOW() - INTERVAL '14 days', NOW() - INTERVAL '14 days' + INTERVAL '72 minutes',
        'Manteniendo la forma en banco. Subida en remo.');

INSERT INTO workout_set (session_id, exercise_id, set_number, reps, weight_kg, estimated_1rm, volume, is_pr, logged_at)
SELECT
    (SELECT id FROM workout_session ORDER BY started_at ASC LIMIT 1 OFFSET 7),
    id, set_num, reps_val, weight_val,
    ROUND((weight_val * (1 + reps_val / 30.0))::numeric, 2),
    ROUND((weight_val * reps_val)::numeric, 2),
    FALSE,
    NOW() - INTERVAL '14 days'
FROM exercise, (VALUES
    ('Barbell Bench Press',       1, 5, 80.0),
    ('Barbell Bench Press',       2, 5, 80.0),
    ('Barbell Bench Press',       3, 4, 80.0),
    ('Barbell Bench Press',       4, 4, 80.0),
    ('Barbell Row',               1, 5, 72.5),
    ('Barbell Row',               2, 5, 72.5),
    ('Barbell Row',               3, 5, 72.5),
    ('Overhead Press',            1, 8, 50.0),
    ('Overhead Press',            2, 7, 50.0),
    ('Overhead Press',            3, 7, 50.0),
    ('Pull Up',                   1, 9,  0.0),
    ('Pull Up',                   2, 9,  0.0),
    ('Pull Up',                   3, 8,  0.0),
    ('Incline Barbell Bench Press', 1, 10, 60.0),
    ('Incline Barbell Bench Press', 2, 10, 60.0),
    ('Incline Barbell Bench Press', 3, 9,  60.0)
) AS d(ex_name, set_num, reps_val, weight_val)
WHERE exercise.name = d.ex_name;

-- ─────────────────────────────────────────────────────────────────────────────
-- SESIÓN 9 — Semana 6 (Upper A: Fuerza) — hace 7 días (más reciente)
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO workout_session (program_day_id, started_at, ended_at, notes)
VALUES (1, NOW() - INTERVAL '7 days', NOW() - INTERVAL '7 days' + INTERVAL '68 minutes',
        'Semana 6. Banco cansado pero remo en PR.');

INSERT INTO workout_set (session_id, exercise_id, set_number, reps, weight_kg, estimated_1rm, volume, is_pr, logged_at)
SELECT
    (SELECT id FROM workout_session ORDER BY started_at ASC LIMIT 1 OFFSET 8),
    id, set_num, reps_val, weight_val,
    ROUND((weight_val * (1 + reps_val / 30.0))::numeric, 2),
    ROUND((weight_val * reps_val)::numeric, 2),
    is_pr_val,
    NOW() - INTERVAL '7 days'
FROM exercise, (VALUES
    ('Barbell Bench Press',       1, 5, 80.0, FALSE),
    ('Barbell Bench Press',       2, 5, 80.0, FALSE),
    ('Barbell Bench Press',       3, 5, 82.5, TRUE),
    ('Barbell Bench Press',       4, 3, 82.5, FALSE),
    ('Barbell Row',               1, 5, 75.0, TRUE),
    ('Barbell Row',               2, 5, 75.0, FALSE),
    ('Barbell Row',               3, 5, 75.0, FALSE),
    ('Overhead Press',            1, 8, 52.5, TRUE),
    ('Overhead Press',            2, 8, 52.5, FALSE),
    ('Overhead Press',            3, 6, 52.5, FALSE),
    ('Pull Up',                   1, 10, 0.0, FALSE),
    ('Pull Up',                   2, 10, 0.0, FALSE),
    ('Pull Up',                   3, 9,  0.0, FALSE),
    ('Incline Barbell Bench Press', 1, 10, 62.5, TRUE),
    ('Incline Barbell Bench Press', 2, 10, 62.5, FALSE),
    ('Incline Barbell Bench Press', 3, 9,  62.5, FALSE)
) AS d(ex_name, set_num, reps_val, weight_val, is_pr_val)
WHERE exercise.name = d.ex_name;


-- =============================================================================
-- SECCIÓN B: POBLAR personal_record (PR actual por ejercicio)
-- =============================================================================
-- Insertamos el mejor 1RM histórico por ejercicio de la data registrada.
-- En el flujo real esto lo hace el trigger trg_update_pr (script 09).
-- =============================================================================

INSERT INTO personal_record (exercise_id, max_1rm, achieved_at, set_id)
SELECT
    ws.exercise_id,
    MAX(ws.estimated_1rm)                                           AS max_1rm,
    MAX(ws.logged_at)                                               AS achieved_at,
    (SELECT id FROM workout_set ws2
     WHERE ws2.exercise_id = ws.exercise_id
     ORDER BY ws2.estimated_1rm DESC LIMIT 1)                       AS set_id
FROM workout_set ws
WHERE ws.is_pr = TRUE
GROUP BY ws.exercise_id
ON CONFLICT (exercise_id) DO UPDATE
    SET max_1rm     = EXCLUDED.max_1rm,
        achieved_at = EXCLUDED.achieved_at,
        set_id      = EXCLUDED.set_id;


-- =============================================================================
-- SECCIÓN C: OPERACIONES UPDATE
-- =============================================================================

-- C.1 Corregir un set: el peso fue registrado mal (error de captura)
-- Caso de uso: usuario registró 80 kg pero en realidad fue 77.5 kg
UPDATE workout_set
SET weight_kg     = 77.5,
    estimated_1rm = ROUND((77.5 * (1 + reps / 30.0))::numeric, 2),
    volume        = ROUND((77.5 * reps)::numeric, 2)
WHERE id = (
    SELECT ws.id FROM workout_set ws
    JOIN workout_session sess ON ws.session_id = sess.id
    JOIN exercise ex ON ws.exercise_id = ex.id
    WHERE ex.name = 'Barbell Bench Press'
      AND ws.set_number = 1
      AND sess.started_at < NOW() - INTERVAL '40 days'
    ORDER BY sess.started_at ASC
    LIMIT 1
);

-- C.2 Actualizar las notas de una sesión
UPDATE workout_session
SET notes = 'Semana 1: inicio del bloque de fuerza. Base sólida.'
WHERE id = (SELECT id FROM workout_session ORDER BY started_at ASC LIMIT 1);

-- C.3 Actualizar el objetivo de reps en una rutina (ajuste de programa)
UPDATE routine_exercise
SET reps_target  = '4-6',
    notes        = 'Ajustado a rango de fuerza pura por el entrenador'
WHERE program_day_id = 1
  AND exercise_id = (SELECT id FROM exercise WHERE name = 'Barbell Bench Press');

-- C.4 Ajuste de descanso en Press Militar
UPDATE routine_exercise
SET rest_seconds = 150
WHERE program_day_id = 1
  AND exercise_id = (SELECT id FROM exercise WHERE name = 'Overhead Press');


-- =============================================================================
-- SECCIÓN D: OPERACIONES DELETE CON VALIDACIÓN
-- =============================================================================

-- D.1 Eliminar un ejercicio personalizado si NO tiene historial de sets
--     Eliminación segura: solo borra si el ejercicio no ha sido usado.
DELETE FROM exercise
WHERE name = 'Ejercicio de Prueba'
  AND id NOT IN (SELECT DISTINCT exercise_id FROM workout_set)
  AND id NOT IN (SELECT DISTINCT exercise_id FROM routine_exercise);

-- D.2 Eliminar sesiones incompletas (sin sets registrados)
--     Limpieza de sesiones fantasma que se abrieron pero no se usaron.
DELETE FROM workout_session
WHERE ended_at IS NULL
  AND started_at < NOW() - INTERVAL '24 hours'
  AND id NOT IN (SELECT DISTINCT session_id FROM workout_set);

-- D.3 Eliminar entradas del audit_log antiguas (retención de 90 días)
DELETE FROM audit_log
WHERE changed_at < NOW() - INTERVAL '90 days';


-- =============================================================================
-- SECCIÓN E: CONSULTAS PARAMETRIZADAS Y FILTROS
-- =============================================================================

-- E.1 Consulta parametrizada: historial reciente de un ejercicio
--     ($1 = nombre del ejercicio, $2 = número de registros)
--     Equivalente en psycopg2: cursor.execute(query, ('Barbell Bench Press', 10))
SELECT
    ex.name                              AS ejercicio,
    ws.set_number                        AS serie,
    ws.reps                              AS reps,
    ws.weight_kg                         AS peso_kg,
    ws.estimated_1rm                     AS "1RM_estimado",
    ws.volume                            AS volumen,
    ws.is_pr                             AS es_pr,
    ws.logged_at::date                   AS fecha
FROM workout_set ws
JOIN exercise ex     ON ws.exercise_id = ex.id
JOIN workout_session sess ON ws.session_id = sess.id
WHERE ex.name = 'Barbell Bench Press'   -- $1: parámetro del ejercicio
ORDER BY ws.logged_at DESC
LIMIT 10;                               -- $2: parámetro de límite

-- E.2 Consulta con filtro por músculo y tipo
SELECT
    ex.name         AS ejercicio,
    mg.name         AS musculo,
    ex.type         AS tipo,
    ex.equipment    AS equipamiento
FROM exercise ex
JOIN muscle_group mg ON ex.muscle_group_id = mg.id
WHERE mg.name = 'Pecho'
  AND ex.type = 'compound'
ORDER BY ex.name;

-- E.3 Validación de existencia antes de insertar un set
--     Verifica que la sesión esté abierta (ended_at IS NULL)
SELECT id, started_at, ended_at
FROM workout_session
WHERE id = 1
  AND ended_at IS NULL;  -- Si no devuelve filas: sesión ya cerrada, no insertar


-- =============================================================================
-- Verificación final de datos
-- =============================================================================
SELECT
    'workout_session' AS tabla, COUNT(*) AS registros FROM workout_session
UNION ALL
SELECT 'workout_set',    COUNT(*) FROM workout_set
UNION ALL
SELECT 'personal_record', COUNT(*) FROM personal_record
ORDER BY tabla;
