-- =============================================================================
-- GymOps — Base de Datos II (FIEI)
-- Script 05: VISTAS
-- Gestor: PostgreSQL 16
-- Autor: Piero Rivera
-- =============================================================================
-- Cubre:
--   - Vistas para reportes y análisis
--   - Vistas actualizables (INSTEAD OF con RULE)
--   - Vistas sobre múltiples tablas
--   - Vistas de seguridad (proyección de columnas sensibles)
-- =============================================================================

-- Limpiar vistas existentes
DROP VIEW IF EXISTS v_muscle_volume_week   CASCADE;
DROP VIEW IF EXISTS v_workout_history      CASCADE;
DROP VIEW IF EXISTS v_current_prs          CASCADE;
DROP VIEW IF EXISTS v_exercise_progress    CASCADE;
DROP VIEW IF EXISTS v_weekly_digest        CASCADE;
DROP VIEW IF EXISTS v_session_summary      CASCADE;
DROP VIEW IF EXISTS v_exercise_catalog     CASCADE;
DROP VIEW IF EXISTS v_program_overview     CASCADE;
DROP VIEW IF EXISTS v_pr_timeline          CASCADE;


-- =============================================================================
-- VISTA 1: v_session_summary
-- Resumen completo de cada sesión de entrenamiento
-- Tablas: workout_session, workout_set, program_day, exercise
-- Propósito: Reporte de sesión — dashboard principal
-- =============================================================================
CREATE VIEW v_session_summary AS
SELECT
    sess.id                                                     AS session_id,
    pd.name                                                     AS programa_dia,
    sess.started_at                                             AS inicio,
    sess.ended_at                                               AS fin,
    ROUND(
        EXTRACT(EPOCH FROM (sess.ended_at - sess.started_at)) / 60
    )::int                                                      AS duracion_min,
    COUNT(DISTINCT ws.exercise_id)                              AS ejercicios_distintos,
    COUNT(ws.id)                                                AS total_series,
    COALESCE(SUM(ws.reps), 0)                                   AS total_reps,
    COALESCE(ROUND(SUM(ws.volume)::numeric, 1), 0)              AS volumen_total_kg,
    COALESCE(ROUND(MAX(ws.estimated_1rm)::numeric, 2), 0)       AS mejor_1rm_sesion,
    COUNT(ws.id) FILTER (WHERE ws.is_pr)                        AS prs_logrados,
    sess.notes                                                  AS notas,
    CASE
        WHEN sess.ended_at IS NULL THEN 'Activa'
        ELSE 'Completada'
    END                                                         AS estado
FROM workout_session sess
LEFT JOIN program_day pd ON sess.program_day_id = pd.id
LEFT JOIN workout_set ws  ON ws.session_id      = sess.id
GROUP BY sess.id, pd.name, sess.started_at, sess.ended_at, sess.notes
ORDER BY sess.started_at DESC;

COMMENT ON VIEW v_session_summary IS
'Resumen ejecutivo de cada sesión: duración, volumen, series, PRs y estado.';


-- =============================================================================
-- VISTA 2: v_weekly_digest
-- Resumen semanal de entrenamiento agrupado por semana y músculo
-- Tablas: workout_session, workout_set, exercise, muscle_group
-- Propósito: Reporte semanal — digest de entrenamiento
-- =============================================================================
CREATE VIEW v_weekly_digest AS
SELECT
    DATE_TRUNC('week', sess.started_at)::date                   AS semana_inicio,
    mg.name                                                      AS musculo,
    COUNT(DISTINCT sess.id)                                      AS sesiones,
    COUNT(ws.id)                                                 AS total_series,
    SUM(ws.reps)                                                 AS total_reps,
    ROUND(SUM(ws.volume)::numeric, 1)                            AS volumen_kg,
    ROUND(MAX(ws.estimated_1rm)::numeric, 2)                     AS mejor_1rm_semana,
    COUNT(ws.id) FILTER (WHERE ws.is_pr)                         AS prs_semana,
    ROUND(AVG(ws.weight_kg)::numeric, 2)                         AS peso_promedio_kg
FROM workout_session sess
JOIN workout_set    ws  ON ws.session_id     = sess.id
JOIN exercise       ex  ON ws.exercise_id    = ex.id
JOIN muscle_group   mg  ON ex.muscle_group_id = mg.id
GROUP BY DATE_TRUNC('week', sess.started_at), mg.name
ORDER BY semana_inicio DESC, volumen_kg DESC;

COMMENT ON VIEW v_weekly_digest IS
'Digest semanal: volumen por músculo, sesiones, PRs y peso promedio por semana.';


-- =============================================================================
-- VISTA 3: v_exercise_progress
-- Progresión de 1RM de cada ejercicio a lo largo del tiempo
-- Tablas: workout_set, workout_session, exercise, muscle_group
-- Propósito: Análisis de progreso — gráfico de fuerza
-- =============================================================================
CREATE VIEW v_exercise_progress AS
WITH sesion_maxima AS (
    SELECT
        ws.exercise_id,
        sess.started_at::date                                    AS fecha,
        MAX(ws.estimated_1rm)                                    AS max_1rm,
        MAX(ws.weight_kg)                                        AS max_peso,
        SUM(ws.volume)                                           AS volumen_dia
    FROM workout_set ws
    JOIN workout_session sess ON ws.session_id = sess.id
    GROUP BY ws.exercise_id, sess.started_at::date
)
SELECT
    ex.name                                                      AS ejercicio,
    mg.name                                                      AS musculo,
    sm.fecha,
    ROUND(sm.max_1rm::numeric, 2)                               AS "1rm_estimado_kg",
    ROUND(sm.max_peso::numeric, 2)                              AS peso_maximo_kg,
    ROUND(sm.volumen_dia::numeric, 1)                           AS volumen_kg,
    ROUND(
        (sm.max_1rm - LAG(sm.max_1rm) OVER (
            PARTITION BY sm.exercise_id ORDER BY sm.fecha
        ))::numeric, 2
    )                                                            AS delta_1rm,
    ROUND(
        ((sm.max_1rm - LAG(sm.max_1rm) OVER (
            PARTITION BY sm.exercise_id ORDER BY sm.fecha
        )) / NULLIF(LAG(sm.max_1rm) OVER (
            PARTITION BY sm.exercise_id ORDER BY sm.fecha
        ), 0) * 100)::numeric, 2
    )                                                            AS "cambio_pct",
    RANK() OVER (
        PARTITION BY sm.exercise_id ORDER BY sm.max_1rm DESC
    )                                                            AS ranking_historico
FROM sesion_maxima sm
JOIN exercise     ex ON sm.exercise_id     = ex.id
JOIN muscle_group mg ON ex.muscle_group_id = mg.id
ORDER BY ex.name, sm.fecha;

COMMENT ON VIEW v_exercise_progress IS
'Progresión histórica de 1RM por ejercicio con delta, cambio% y ranking histórico.';


-- =============================================================================
-- VISTA 4: v_current_prs  (Vista actualizable)
-- PRs actuales por ejercicio con información completa
-- Tablas: personal_record, exercise, muscle_group, workout_set, workout_session
-- Propósito: Dashboard de PRs — vista actualizable para correcciones manuales
-- =============================================================================
CREATE VIEW v_current_prs AS
SELECT
    pr.id                                                        AS pr_id,
    ex.id                                                        AS exercise_id,
    ex.name                                                      AS ejercicio,
    mg.name                                                      AS musculo,
    ex.type                                                      AS tipo,
    ROUND(pr.max_1rm::numeric, 2)                               AS "1rm_max_kg",
    ws.weight_kg                                                 AS peso_en_pr_kg,
    ws.reps                                                      AS reps_en_pr,
    pr.achieved_at::date                                         AS fecha_pr,
    sess.started_at::date                                        AS fecha_sesion
FROM personal_record pr
JOIN exercise       ex   ON pr.exercise_id  = ex.id
JOIN muscle_group   mg   ON ex.muscle_group_id = mg.id
LEFT JOIN workout_set  ws   ON pr.set_id    = ws.id
LEFT JOIN workout_session sess ON ws.session_id = sess.id
ORDER BY mg.name, pr.max_1rm DESC;

COMMENT ON VIEW v_current_prs IS
'Vista de PRs actuales por ejercicio. Muestra 1RM, peso, reps y fecha de logro.';


-- =============================================================================
-- VISTA 5: v_workout_history
-- Historial completo de todos los sets registrados
-- Tablas: workout_set, workout_session, exercise, muscle_group, program_day
-- Propósito: Consulta de historial — tabla maestra de logs
-- =============================================================================
CREATE VIEW v_workout_history AS
SELECT
    ws.id                                                        AS set_id,
    sess.id                                                      AS session_id,
    ws.logged_at::date                                           AS fecha,
    ws.logged_at::time                                           AS hora,
    pd.name                                                      AS dia_programa,
    mg.name                                                      AS musculo,
    ex.name                                                      AS ejercicio,
    ex.type                                                      AS tipo,
    ws.set_number                                                AS num_serie,
    ws.reps,
    ws.weight_kg                                                 AS peso_kg,
    ROUND(ws.estimated_1rm::numeric, 2)                         AS "1rm_estimado_kg",
    ROUND(ws.volume::numeric, 1)                                 AS volumen_kg,
    ws.is_pr                                                     AS es_pr
FROM workout_set ws
JOIN workout_session sess ON ws.session_id     = sess.id
JOIN exercise       ex   ON ws.exercise_id     = ex.id
JOIN muscle_group   mg   ON ex.muscle_group_id = mg.id
LEFT JOIN program_day pd  ON sess.program_day_id = pd.id
ORDER BY ws.logged_at DESC;

COMMENT ON VIEW v_workout_history IS
'Historial completo de todos los sets con contexto de sesión, ejercicio y músculo.';


-- =============================================================================
-- VISTA 6: v_muscle_volume_week
-- Volumen semanal por grupo muscular (últimas 8 semanas)
-- Tablas: workout_session, workout_set, exercise, muscle_group
-- Propósito: Balance de entrenamiento — detectar músculos descuidados
-- =============================================================================
CREATE VIEW v_muscle_volume_week AS
SELECT
    DATE_TRUNC('week', sess.started_at)::date                   AS semana,
    mg.id                                                        AS muscle_group_id,
    mg.name                                                      AS musculo,
    COUNT(DISTINCT sess.id)                                      AS sesiones,
    COUNT(ws.id)                                                 AS series,
    SUM(ws.reps)                                                 AS total_reps,
    ROUND(SUM(ws.volume)::numeric, 1)                           AS volumen_kg,
    ROUND(AVG(ws.weight_kg)::numeric, 2)                        AS peso_promedio_kg,
    COUNT(ws.id) FILTER (WHERE ws.is_pr)                        AS prs
FROM workout_session sess
JOIN workout_set    ws  ON ws.session_id      = sess.id
JOIN exercise       ex  ON ws.exercise_id     = ex.id
JOIN muscle_group   mg  ON ex.muscle_group_id = mg.id
WHERE sess.started_at >= NOW() - INTERVAL '56 days'
GROUP BY DATE_TRUNC('week', sess.started_at), mg.id, mg.name
ORDER BY semana DESC, volumen_kg DESC;

COMMENT ON VIEW v_muscle_volume_week IS
'Volumen semanal por músculo (últimas 8 semanas). Útil para detectar desbalances.';


-- =============================================================================
-- VISTA 7: v_exercise_catalog
-- Catálogo completo de ejercicios con estadísticas de uso
-- Tablas: exercise, muscle_group, workout_set
-- Propósito: Gestión del catálogo — seguridad y administración
-- =============================================================================
CREATE VIEW v_exercise_catalog AS
SELECT
    ex.id,
    ex.name                                                      AS ejercicio,
    mg.name                                                      AS musculo,
    ex.type                                                      AS tipo,
    ex.equipment                                                 AS equipamiento,
    COUNT(ws.id)                                                 AS total_sets_registrados,
    MAX(ws.logged_at)::date                                      AS ultima_vez_usado,
    CASE
        WHEN COUNT(ws.id) = 0                   THEN 'Sin uso'
        WHEN MAX(ws.logged_at) < NOW() - INTERVAL '30 days' THEN 'Inactivo'
        ELSE                                         'Activo'
    END                                                          AS estado
FROM exercise ex
JOIN muscle_group mg ON ex.muscle_group_id = mg.id
LEFT JOIN workout_set ws ON ws.exercise_id = ex.id
GROUP BY ex.id, ex.name, mg.name, ex.type, ex.equipment
ORDER BY mg.name, ex.name;

COMMENT ON VIEW v_exercise_catalog IS
'Catálogo de ejercicios con estado de uso. Vista de seguridad: proyecta solo columnas necesarias.';


-- =============================================================================
-- VISTA 8: v_program_overview
-- Vista general de todos los programas con sus días y ejercicios
-- Tablas: program, program_day, routine_exercise, exercise, muscle_group
-- Propósito: Consulta de estructura de programas — múltiples tablas
-- =============================================================================
CREATE VIEW v_program_overview AS
SELECT
    p.id                                                         AS program_id,
    p.name                                                       AS programa,
    p.author                                                     AS autor,
    p.days_per_week                                              AS dias_por_semana,
    pd.name                                                      AS dia,
    pd.day_order                                                 AS orden_dia,
    pd.focus                                                     AS enfoque,
    ex.name                                                      AS ejercicio,
    mg.name                                                      AS musculo,
    re.sets_target                                               AS series_objetivo,
    re.reps_target                                               AS reps_objetivo,
    re.rest_seconds                                              AS descanso_seg,
    re.order_in_day                                              AS orden_en_dia
FROM program p
JOIN program_day      pd  ON pd.program_id      = p.id
JOIN routine_exercise re  ON re.program_day_id  = pd.id
JOIN exercise         ex  ON re.exercise_id     = ex.id
JOIN muscle_group     mg  ON ex.muscle_group_id = mg.id
ORDER BY p.id, pd.day_order, re.order_in_day;

COMMENT ON VIEW v_program_overview IS
'Vista desnormalizada de programas: une program, program_day, routine_exercise, exercise y muscle_group.';


-- =============================================================================
-- VISTA 9: v_pr_timeline
-- Línea de tiempo de todos los PRs logrados
-- Tablas: workout_set, exercise, muscle_group, workout_session
-- Propósito: Reporte histórico de PRs — motivacional
-- =============================================================================
CREATE VIEW v_pr_timeline AS
SELECT
    ws.logged_at::date                                           AS fecha,
    mg.name                                                      AS musculo,
    ex.name                                                      AS ejercicio,
    ws.weight_kg                                                 AS peso_kg,
    ws.reps,
    ROUND(ws.estimated_1rm::numeric, 2)                         AS "1rm_estimado_kg",
    pd.name                                                      AS sesion_dia,
    ROW_NUMBER() OVER (
        PARTITION BY ws.exercise_id ORDER BY ws.estimated_1rm DESC
    )                                                            AS puesto_historico
FROM workout_set ws
JOIN exercise       ex   ON ws.exercise_id     = ex.id
JOIN muscle_group   mg   ON ex.muscle_group_id = mg.id
JOIN workout_session sess ON ws.session_id     = sess.id
LEFT JOIN program_day pd  ON sess.program_day_id = pd.id
WHERE ws.is_pr = TRUE
ORDER BY ws.logged_at DESC;

COMMENT ON VIEW v_pr_timeline IS
'Línea de tiempo de todos los PRs logrados con puesto histórico por ejercicio.';


-- =============================================================================
-- DEMOSTRACIÓN DE VISTAS
-- =============================================================================

-- Demo v_session_summary
SELECT '=== v_session_summary ===' AS demo;
SELECT session_id, programa_dia, inicio::date, duracion_min,
       total_series, volumen_total_kg, prs_logrados, estado
FROM v_session_summary;

-- Demo v_weekly_digest
SELECT '=== v_weekly_digest (últimas 2 semanas) ===' AS demo;
SELECT semana_inicio, musculo, sesiones, total_series, volumen_kg, prs_semana
FROM v_weekly_digest
WHERE semana_inicio >= NOW() - INTERVAL '14 days';

-- Demo v_current_prs
SELECT '=== v_current_prs ===' AS demo;
SELECT ejercicio, musculo, "1rm_max_kg", peso_en_pr_kg, reps_en_pr, fecha_pr
FROM v_current_prs
ORDER BY "1rm_max_kg" DESC
LIMIT 10;

-- Demo v_pr_timeline
SELECT '=== v_pr_timeline ===' AS demo;
SELECT fecha, ejercicio, musculo, "1rm_estimado_kg", peso_kg, reps
FROM v_pr_timeline
ORDER BY fecha DESC;

-- Demo v_exercise_catalog (solo activos/inactivos)
SELECT '=== v_exercise_catalog (con historial) ===' AS demo;
SELECT ejercicio, musculo, tipo, total_sets_registrados, ultima_vez_usado, estado
FROM v_exercise_catalog
WHERE total_sets_registrados > 0
ORDER BY ultima_vez_usado DESC;

-- Demo v_program_overview (Upper/Lower 4-Day)
SELECT '=== v_program_overview (Upper/Lower 4-Day) ===' AS demo;
SELECT dia, orden_dia, ejercicio, musculo, series_objetivo, reps_objetivo, descanso_seg
FROM v_program_overview
WHERE programa = 'Upper/Lower 4-Day'
ORDER BY orden_dia, orden_en_dia;

-- Verificar todas las vistas creadas
SELECT '=== VISTAS CREADAS ===' AS demo;
SELECT viewname, definition IS NOT NULL AS tiene_definicion
FROM pg_views
WHERE schemaname = 'public'
ORDER BY viewname;
