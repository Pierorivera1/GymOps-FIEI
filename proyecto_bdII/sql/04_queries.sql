-- =============================================================================
-- GymOps — Base de Datos II (FIEI)
-- Script 04: Consultas SQL Avanzadas
-- Gestor: PostgreSQL 16
-- Autor: Piero Rivera
-- =============================================================================
-- Cubre: JOIN, GROUP BY, HAVING, Subconsultas, Funciones de agregación,
--        CASE, CTE, Funciones de ventana (LAG, RANK, SUM OVER)
-- =============================================================================


-- =============================================================================
-- Q1: Top ejercicios por volumen total en las últimas 4 semanas
--     Técnicas: JOIN, GROUP BY, SUM, HAVING, ORDER BY
-- =============================================================================
SELECT
    ex.name                             AS ejercicio,
    mg.name                             AS musculo,
    COUNT(DISTINCT ws.session_id)       AS sesiones,
    COUNT(ws.id)                        AS total_series,
    SUM(ws.reps)                        AS total_reps,
    ROUND(SUM(ws.volume)::numeric, 1)   AS volumen_total_kg
FROM workout_set ws
JOIN exercise       ex   ON ws.exercise_id     = ex.id
JOIN muscle_group   mg   ON ex.muscle_group_id = mg.id
JOIN workout_session sess ON ws.session_id     = sess.id
WHERE sess.started_at >= NOW() - INTERVAL '28 days'
GROUP BY ex.name, mg.name
HAVING COUNT(ws.id) >= 3                -- solo ejercicios con al menos 3 series registradas
ORDER BY volumen_total_kg DESC
LIMIT 10;


-- =============================================================================
-- Q2: Progresión de 1RM por ejercicio a lo largo del tiempo
--     Técnicas: CTE, LAG() window function, diferencia porcentual
-- =============================================================================
WITH historial_1rm AS (
    SELECT
        ex.name                             AS ejercicio,
        sess.started_at::date               AS fecha,
        MAX(ws.estimated_1rm)               AS max_1rm_sesion
    FROM workout_set ws
    JOIN exercise        ex   ON ws.exercise_id  = ex.id
    JOIN workout_session sess ON ws.session_id   = sess.id
    GROUP BY ex.name, sess.started_at::date
),
con_progresion AS (
    SELECT
        ejercicio,
        fecha,
        max_1rm_sesion,
        LAG(max_1rm_sesion) OVER (
            PARTITION BY ejercicio
            ORDER BY fecha
        )                                   AS _1rm_sesion_anterior,
        ROUND(
            (max_1rm_sesion - LAG(max_1rm_sesion) OVER (
                PARTITION BY ejercicio ORDER BY fecha
            )) /
            NULLIF(LAG(max_1rm_sesion) OVER (
                PARTITION BY ejercicio ORDER BY fecha
            ), 0) * 100
        , 2)                                AS cambio_pct
    FROM historial_1rm
)
SELECT
    ejercicio,
    fecha,
    max_1rm_sesion                          AS "1RM_sesion_kg",
    _1rm_sesion_anterior                    AS "1RM_anterior_kg",
    COALESCE(cambio_pct, 0)                 AS "cambio_%",
    CASE
        WHEN cambio_pct > 0  THEN '▲ Mejora'
        WHEN cambio_pct < 0  THEN '▼ Baja'
        WHEN cambio_pct = 0  THEN '─ Meseta'
        ELSE                      '· Primera sesión'
    END                                     AS tendencia
FROM con_progresion
WHERE ejercicio = 'Barbell Bench Press'
ORDER BY fecha;


-- =============================================================================
-- Q3: Comparar sesión actual vs sesión anterior por ejercicio
--     Técnicas: Self JOIN, CASE, Subconsulta correlacionada
-- =============================================================================
WITH sesiones_por_ejercicio AS (
    SELECT
        ex.name                             AS ejercicio,
        sess.started_at::date               AS fecha,
        ROUND(AVG(ws.weight_kg)::numeric, 2)    AS peso_promedio,
        SUM(ws.reps)                        AS reps_totales,
        ROUND(SUM(ws.volume)::numeric, 1)   AS volumen_total,
        MAX(ws.estimated_1rm)               AS mejor_1rm,
        ROW_NUMBER() OVER (
            PARTITION BY ex.name
            ORDER BY sess.started_at DESC
        )                                   AS n_sesion
    FROM workout_set ws
    JOIN exercise        ex   ON ws.exercise_id = ex.id
    JOIN workout_session sess ON ws.session_id  = sess.id
    GROUP BY ex.name, sess.started_at::date
)
SELECT
    actual.ejercicio,
    actual.fecha                            AS fecha_actual,
    anterior.fecha                          AS fecha_anterior,
    actual.mejor_1rm                        AS "1RM_actual",
    anterior.mejor_1rm                      AS "1RM_anterior",
    ROUND((actual.mejor_1rm - anterior.mejor_1rm)::numeric, 2)  AS dif_1rm,
    actual.volumen_total                    AS volumen_actual,
    anterior.volumen_total                  AS volumen_anterior,
    CASE
        WHEN actual.mejor_1rm > anterior.mejor_1rm THEN '💪 Sobrecarga progresiva'
        WHEN actual.mejor_1rm = anterior.mejor_1rm THEN '📊 Meseta'
        ELSE                                             '📉 Disminución'
    END                                     AS resultado
FROM sesiones_por_ejercicio actual
JOIN sesiones_por_ejercicio anterior
    ON actual.ejercicio = anterior.ejercicio
    AND actual.n_sesion = 1
    AND anterior.n_sesion = 2;


-- =============================================================================
-- Q4: Ejercicios sin entrenamiento en los últimos 14 días
--     Técnicas: LEFT JOIN, IS NULL, subconsulta, filtro temporal
-- =============================================================================
SELECT
    ex.name         AS ejercicio,
    mg.name         AS musculo,
    ex.type         AS tipo,
    MAX(ws.logged_at)::date AS ultima_sesion
FROM exercise ex
JOIN muscle_group mg ON ex.muscle_group_id = mg.id
LEFT JOIN workout_set ws ON ws.exercise_id = ex.id
GROUP BY ex.name, mg.name, ex.type
HAVING MAX(ws.logged_at) < NOW() - INTERVAL '14 days'
    OR MAX(ws.logged_at) IS NULL
ORDER BY ultima_sesion NULLS FIRST, mg.name;


-- =============================================================================
-- Q5: Ranking de PRs por grupo muscular
--     Técnicas: CTE, RANK(), JOIN múltiple
-- =============================================================================
WITH ranking_prs AS (
    SELECT
        mg.name                             AS musculo,
        ex.name                             AS ejercicio,
        pr.max_1rm,
        pr.achieved_at::date                AS fecha_pr,
        RANK() OVER (
            PARTITION BY mg.name
            ORDER BY pr.max_1rm DESC
        )                                   AS ranking
    FROM personal_record pr
    JOIN exercise       ex   ON pr.exercise_id     = ex.id
    JOIN muscle_group   mg   ON ex.muscle_group_id = mg.id
)
SELECT
    musculo,
    ranking,
    ejercicio,
    max_1rm                                 AS "1RM_max_kg",
    fecha_pr
FROM ranking_prs
WHERE ranking <= 3
ORDER BY musculo, ranking;


-- =============================================================================
-- Q6: Distribución de volumen de entrenamiento por día de la semana
--     Técnicas: EXTRACT, TO_CHAR, GROUP BY, CASE, ORDER BY personalizado
-- =============================================================================
SELECT
    CASE EXTRACT(DOW FROM sess.started_at)
        WHEN 0 THEN 'Domingo'
        WHEN 1 THEN 'Lunes'
        WHEN 2 THEN 'Martes'
        WHEN 3 THEN 'Miércoles'
        WHEN 4 THEN 'Jueves'
        WHEN 5 THEN 'Viernes'
        WHEN 6 THEN 'Sábado'
    END                                     AS dia_semana,
    COUNT(DISTINCT sess.id)                 AS sesiones,
    COUNT(ws.id)                            AS total_series,
    ROUND(SUM(ws.volume)::numeric, 1)       AS volumen_total_kg,
    ROUND(AVG(ws.volume)::numeric, 1)       AS volumen_promedio_serie
FROM workout_session sess
JOIN workout_set ws ON ws.session_id = sess.id
GROUP BY EXTRACT(DOW FROM sess.started_at)
ORDER BY EXTRACT(DOW FROM sess.started_at);


-- =============================================================================
-- Q7: Volumen semanal por grupo muscular (últimas 6 semanas)
--     Técnicas: DATE_TRUNC, GROUP BY múltiple, SUM, ORDER BY
-- =============================================================================
SELECT
    DATE_TRUNC('week', sess.started_at)::date   AS semana,
    mg.name                                      AS musculo,
    COUNT(ws.id)                                 AS series,
    SUM(ws.reps)                                 AS total_reps,
    ROUND(SUM(ws.volume)::numeric, 1)            AS volumen_kg
FROM workout_set ws
JOIN exercise       ex   ON ws.exercise_id     = ex.id
JOIN muscle_group   mg   ON ex.muscle_group_id = mg.id
JOIN workout_session sess ON ws.session_id     = sess.id
WHERE sess.started_at >= NOW() - INTERVAL '42 days'
GROUP BY DATE_TRUNC('week', sess.started_at), mg.name
ORDER BY semana DESC, volumen_kg DESC;


-- =============================================================================
-- Q8: Resumen completo de sesión (total, mejor 1RM, duración)
--     Técnicas: JOIN, EXTRACT, AGG functions, subconsulta escalar
-- =============================================================================
SELECT
    sess.id                                         AS sesion_id,
    pd.name                                         AS dia_programa,
    sess.started_at::date                           AS fecha,
    EXTRACT(EPOCH FROM (sess.ended_at - sess.started_at)) / 60
                                                    AS duracion_minutos,
    COUNT(ws.id)                                    AS total_series,
    SUM(ws.reps)                                    AS total_reps,
    ROUND(SUM(ws.volume)::numeric, 1)               AS volumen_total_kg,
    ROUND(MAX(ws.estimated_1rm)::numeric, 2)        AS mejor_1rm_sesion,
    COUNT(CASE WHEN ws.is_pr THEN 1 END)            AS prs_logrados
FROM workout_session sess
LEFT JOIN program_day pd  ON sess.program_day_id = pd.id
LEFT JOIN workout_set ws  ON ws.session_id       = sess.id
GROUP BY sess.id, pd.name, sess.started_at, sess.ended_at
ORDER BY sess.started_at DESC;


-- =============================================================================
-- Q9: Ejercicios por encima del promedio de 1RM de su grupo muscular
--     Técnicas: Subconsulta correlacionada, AVG, comparación
-- =============================================================================
SELECT
    ex.name                                 AS ejercicio,
    mg.name                                 AS musculo,
    pr.max_1rm                              AS "1RM_personal",
    ROUND(avg_grupo.promedio_1rm::numeric, 2)   AS "1RM_promedio_grupo",
    ROUND((pr.max_1rm - avg_grupo.promedio_1rm)::numeric, 2) AS diferencia
FROM personal_record pr
JOIN exercise     ex  ON pr.exercise_id     = ex.id
JOIN muscle_group mg  ON ex.muscle_group_id = mg.id
JOIN (
    SELECT
        ex2.muscle_group_id,
        AVG(pr2.max_1rm)    AS promedio_1rm
    FROM personal_record pr2
    JOIN exercise ex2 ON pr2.exercise_id = ex2.id
    GROUP BY ex2.muscle_group_id
) avg_grupo ON ex.muscle_group_id = avg_grupo.muscle_group_id
WHERE pr.max_1rm > avg_grupo.promedio_1rm
ORDER BY mg.name, diferencia DESC;


-- =============================================================================
-- Q10: Acumulado de volumen con ventana deslizante (running total)
--      Técnicas: SUM OVER (window function acumulativa), CTE
-- =============================================================================
WITH volumen_diario AS (
    SELECT
        sess.started_at::date               AS fecha,
        ROUND(SUM(ws.volume)::numeric, 1)   AS volumen_dia
    FROM workout_set ws
    JOIN workout_session sess ON ws.session_id = sess.id
    GROUP BY sess.started_at::date
)
SELECT
    fecha,
    volumen_dia,
    ROUND(SUM(volumen_dia) OVER (
        ORDER BY fecha
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )::numeric, 1)                          AS volumen_acumulado,
    ROUND(AVG(volumen_dia) OVER (
        ORDER BY fecha
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    )::numeric, 1)                          AS media_movil_3_dias
FROM volumen_diario
ORDER BY fecha;
