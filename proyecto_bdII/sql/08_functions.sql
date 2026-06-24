-- =============================================================================
-- GymOps — Base de Datos II (FIEI)
-- Script 08: Funciones UDF (PL/pgSQL)
-- Gestor: PostgreSQL 16
-- Autor: Piero Rivera
-- Fase 6 del Plan de Implementación SQL
-- =============================================================================
-- Contenido:
--   FN-01  fn_epley_1rm(weight, reps)          → NUMERIC  (escalar)
--   FN-02  fn_volume(weight, reps)              → NUMERIC  (escalar)
--   FN-03  fn_is_pr(exercise_id, new_1rm)       → BOOLEAN  (escalar)
--   FN-04  fn_session_volume(session_id)        → NUMERIC  (escalar)
--   FN-05  fn_exercise_history(exercise_id, n)  → SETOF    (tipo tabla)
--   FN-06  fn_weekly_volume(week_start)         → SETOF    (tipo tabla)
-- =============================================================================


-- =============================================================================
-- FN-01: fn_epley_1rm
-- Descripción : Calcula el 1RM estimado usando la fórmula de Epley.
--               Fórmula: weight * (1 + reps / 30.0)
--               Considerada la más precisa para rangos de 1–10 repeticiones.
-- Parámetros  : p_weight_kg  NUMERIC — Peso levantado (kg)
--               p_reps       INT     — Repeticiones realizadas
-- Retorna     : NUMERIC(6,2) — 1RM estimado en kg
-- Uso         : SELECT fn_epley_1rm(100, 8);   → 126.67
-- =============================================================================
CREATE OR REPLACE FUNCTION fn_epley_1rm(
    p_weight_kg  NUMERIC,
    p_reps       INT
)
RETURNS NUMERIC(6,2)
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    -- Validaciones
    IF p_weight_kg IS NULL OR p_weight_kg <= 0 THEN
        RAISE EXCEPTION 'fn_epley_1rm: el peso debe ser > 0. Recibido: %', p_weight_kg;
    END IF;

    IF p_reps IS NULL OR p_reps <= 0 THEN
        RAISE EXCEPTION 'fn_epley_1rm: las reps deben ser > 0. Recibido: %', p_reps;
    END IF;

    -- Con 1 repetición el 1RM ES el peso levantado (evita inflación)
    IF p_reps = 1 THEN
        RETURN ROUND(p_weight_kg, 2);
    END IF;

    RETURN ROUND(p_weight_kg * (1.0 + p_reps::NUMERIC / 30.0), 2);
END;
$$;

COMMENT ON FUNCTION fn_epley_1rm(NUMERIC, INT) IS
    'FN-01 (Escalar): Calcula el 1RM estimado mediante la fórmula de Epley: '
    'weight * (1 + reps/30). Retorna el mismo peso si reps = 1. IMMUTABLE.';


-- =============================================================================
-- FN-02: fn_volume
-- Descripción : Calcula el volumen de un set (carga total desplazada).
--               Fórmula: weight_kg × reps
-- Parámetros  : p_weight_kg  NUMERIC — Peso en kg
--               p_reps       INT     — Repeticiones
-- Retorna     : NUMERIC(8,2) — Volumen total del set en kg
-- Uso         : SELECT fn_volume(100, 8);   → 800.00
-- =============================================================================
CREATE OR REPLACE FUNCTION fn_volume(
    p_weight_kg  NUMERIC,
    p_reps       INT
)
RETURNS NUMERIC(8,2)
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    IF p_weight_kg IS NULL OR p_weight_kg <= 0 THEN
        RAISE EXCEPTION 'fn_volume: el peso debe ser > 0. Recibido: %', p_weight_kg;
    END IF;

    IF p_reps IS NULL OR p_reps <= 0 THEN
        RAISE EXCEPTION 'fn_volume: las reps deben ser > 0. Recibido: %', p_reps;
    END IF;

    RETURN ROUND(p_weight_kg * p_reps, 2);
END;
$$;

COMMENT ON FUNCTION fn_volume(NUMERIC, INT) IS
    'FN-02 (Escalar): Calcula el volumen de un set: weight_kg × reps. IMMUTABLE.';


-- =============================================================================
-- FN-03: fn_is_pr
-- Descripción : Comprueba si un 1RM dado supera el PR actual del ejercicio.
--               Retorna TRUE si:
--               — No existe PR previo para el ejercicio, o
--               — El nuevo 1RM supera estrictamente el PR registrado.
-- Parámetros  : p_exercise_id  INT     — ID del ejercicio a consultar
--               p_new_1rm      NUMERIC — 1RM candidato a PR
-- Retorna     : BOOLEAN
-- Uso         : SELECT fn_is_pr(5, 130.50);
-- =============================================================================
CREATE OR REPLACE FUNCTION fn_is_pr(
    p_exercise_id  INT,
    p_new_1rm      NUMERIC
)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_current_pr NUMERIC(6,2);
BEGIN
    IF p_exercise_id IS NULL THEN
        RAISE EXCEPTION 'fn_is_pr: exercise_id no puede ser NULL.';
    END IF;

    IF p_new_1rm IS NULL OR p_new_1rm <= 0 THEN
        RAISE EXCEPTION 'fn_is_pr: new_1rm debe ser > 0. Recibido: %', p_new_1rm;
    END IF;

    -- Buscar PR actual
    SELECT max_1rm INTO v_current_pr
    FROM personal_record
    WHERE exercise_id = p_exercise_id;

    -- Si no hay PR previo → es PR por definición
    IF NOT FOUND THEN
        RETURN TRUE;
    END IF;

    RETURN p_new_1rm > v_current_pr;
END;
$$;

COMMENT ON FUNCTION fn_is_pr(INT, NUMERIC) IS
    'FN-03 (Escalar): Retorna TRUE si p_new_1rm supera el PR actual del ejercicio '
    'o si el ejercicio no tiene PR registrado aún. STABLE (consulta BD).';


-- =============================================================================
-- FN-04: fn_session_volume
-- Descripción : Calcula el volumen total acumulado en una sesión de entrenamiento.
--               Suma los volúmenes (weight_kg × reps) de todos los sets
--               registrados en esa sesión.
-- Parámetros  : p_session_id  INT — ID de la sesión
-- Retorna     : NUMERIC(12,2) — Volumen total de la sesión en kg
--               NULL si la sesión no existe o no tiene sets.
-- Uso         : SELECT fn_session_volume(1);
-- =============================================================================
CREATE OR REPLACE FUNCTION fn_session_volume(
    p_session_id INT
)
RETURNS NUMERIC(12,2)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_total   NUMERIC(12,2);
    v_exists  BOOLEAN;
BEGIN
    -- Verificar que la sesión exista
    SELECT EXISTS(SELECT 1 FROM workout_session WHERE id = p_session_id)
    INTO v_exists;

    IF NOT v_exists THEN
        RAISE EXCEPTION 'fn_session_volume: la sesión % no existe.', p_session_id;
    END IF;

    -- Sumar volúmenes
    SELECT COALESCE(SUM(volume), 0)
    INTO v_total
    FROM workout_set
    WHERE session_id = p_session_id;

    RETURN v_total;
END;
$$;

COMMENT ON FUNCTION fn_session_volume(INT) IS
    'FN-04 (Escalar): Retorna el volumen total (kg) acumulado de todos los sets '
    'de una sesión. Retorna 0 si la sesión existe pero no tiene sets.';


-- =============================================================================
-- FN-05: fn_exercise_history
-- Descripción : Retorna el historial de las últimas N sesiones en las que
--               se realizó un ejercicio específico.
--               Muestra por set: sesión, fecha, set_number, reps, peso,
--               1RM estimado, volumen y si fue PR.
-- Parámetros  : p_exercise_id  INT — ID del ejercicio
--               p_n_sessions   INT — Número de sesiones a recuperar (default: 5)
-- Retorna     : SETOF (tipo tabla con historial)
-- Uso         : SELECT * FROM fn_exercise_history(5, 5);
--               SELECT * FROM fn_exercise_history(5);
-- =============================================================================
CREATE OR REPLACE FUNCTION fn_exercise_history(
    p_exercise_id  INT,
    p_n_sessions   INT DEFAULT 5
)
RETURNS TABLE(
    session_id     INT,
    session_date   TIMESTAMP,
    set_number     SMALLINT,
    reps           SMALLINT,
    weight_kg      NUMERIC(6,2),
    estimated_1rm  NUMERIC(6,2),
    volume         NUMERIC(8,2),
    is_pr          BOOLEAN,
    set_rank       BIGINT       -- posición del set dentro de la sesión
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_exercise_name VARCHAR(100);
BEGIN
    -- Verificar ejercicio
    SELECT name INTO v_exercise_name
    FROM exercise
    WHERE id = p_exercise_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'fn_exercise_history: ejercicio_id % no existe.', p_exercise_id;
    END IF;

    IF p_n_sessions IS NULL OR p_n_sessions <= 0 THEN
        RAISE EXCEPTION 'fn_exercise_history: n_sessions debe ser > 0. Recibido: %', p_n_sessions;
    END IF;

    RAISE NOTICE 'Historial de "%" — últimas % sesiones', v_exercise_name, p_n_sessions;

    RETURN QUERY
    WITH ranked_sessions AS (
        -- Obtener las N sesiones más recientes con este ejercicio
        SELECT DISTINCT ws.session_id,
               wsess.started_at AS session_date,
               DENSE_RANK() OVER (ORDER BY wsess.started_at DESC) AS session_rank
        FROM workout_set ws
        JOIN workout_session wsess ON wsess.id = ws.session_id
        WHERE ws.exercise_id = p_exercise_id
    ),
    top_sessions AS (
        SELECT rs.session_id, rs.session_date
        FROM ranked_sessions rs
        WHERE rs.session_rank <= p_n_sessions
    )
    SELECT
        ws.session_id,
        ts.session_date,
        ws.set_number,
        ws.reps,
        ws.weight_kg,
        ws.estimated_1rm,
        ws.volume,
        ws.is_pr,
        ROW_NUMBER() OVER (
            PARTITION BY ws.session_id
            ORDER BY ws.set_number
        ) AS set_rank
    FROM workout_set ws
    JOIN top_sessions ts ON ts.session_id = ws.session_id
    WHERE ws.exercise_id = p_exercise_id
    ORDER BY ts.session_date DESC, ws.set_number;
END;
$$;

COMMENT ON FUNCTION fn_exercise_history(INT, INT) IS
    'FN-05 (Tipo tabla): Retorna el historial de sets de las últimas N sesiones '
    'en las que se realizó el ejercicio. Muestra reps, peso, 1RM, volumen e is_pr '
    'ordenados por fecha descendente. Default: últimas 5 sesiones.';


-- =============================================================================
-- FN-06: fn_weekly_volume
-- Descripción : Calcula el volumen de entrenamiento por grupo muscular
--               para la semana que contiene la fecha indicada.
--               Incluye conteo de sets, sesiones únicas y si hubo PR.
-- Parámetros  : p_week_start  DATE — lunes de la semana a analizar
--                                    (default: lunes de la semana actual)
-- Retorna     : SETOF (tipo tabla por grupo muscular)
-- Uso         : SELECT * FROM fn_weekly_volume(DATE_TRUNC('week', CURRENT_DATE)::DATE);
--               SELECT * FROM fn_weekly_volume();
-- =============================================================================
CREATE OR REPLACE FUNCTION fn_weekly_volume(
    p_week_start DATE DEFAULT DATE_TRUNC('week', CURRENT_DATE)::DATE
)
RETURNS TABLE(
    week_start       DATE,
    week_end         DATE,
    muscle_group     VARCHAR(50),
    total_sets       BIGINT,
    total_volume_kg  NUMERIC(12,2),
    unique_exercises BIGINT,
    unique_sessions  BIGINT,
    prs_achieved     BIGINT,
    avg_volume_set   NUMERIC(8,2)    -- volumen promedio por set
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_week_end DATE;
BEGIN
    v_week_end := p_week_start + INTERVAL '6 days';

    RAISE NOTICE 'Volumen semanal: % → %', p_week_start, v_week_end;

    RETURN QUERY
    SELECT
        p_week_start                                          AS week_start,
        v_week_end                                            AS week_end,
        mg.name                                               AS muscle_group,
        COUNT(ws.id)                                          AS total_sets,
        COALESCE(ROUND(SUM(ws.volume), 2), 0)                AS total_volume_kg,
        COUNT(DISTINCT ws.exercise_id)                        AS unique_exercises,
        COUNT(DISTINCT ws.session_id)                         AS unique_sessions,
        COUNT(ws.id) FILTER (WHERE ws.is_pr = TRUE)          AS prs_achieved,
        COALESCE(ROUND(AVG(ws.volume), 2), 0)                AS avg_volume_set
    FROM workout_set ws
    JOIN workout_session wsess ON wsess.id  = ws.session_id
    JOIN exercise e            ON e.id      = ws.exercise_id
    JOIN muscle_group mg       ON mg.id     = e.muscle_group_id
    WHERE wsess.started_at::DATE BETWEEN p_week_start AND v_week_end
      AND wsess.ended_at IS NOT NULL         -- sólo sesiones cerradas
    GROUP BY mg.name
    ORDER BY total_volume_kg DESC;
END;
$$;

COMMENT ON FUNCTION fn_weekly_volume(DATE) IS
    'FN-06 (Tipo tabla): Retorna el volumen semanal de entrenamiento agrupado por '
    'grupo muscular. Incluye sets totales, ejercicios únicos, sesiones, PRs y '
    'volumen promedio por set. Sólo considera sesiones cerradas (ended_at NOT NULL).';


-- =============================================================================
-- Verificación: listar funciones UDF creadas
-- =============================================================================
SELECT
    routine_name               AS funcion,
    data_type                  AS tipo_retorno,
    external_language          AS lenguaje,
    routine_type               AS tipo
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name IN (
      'fn_epley_1rm',
      'fn_volume',
      'fn_is_pr',
      'fn_session_volume',
      'fn_exercise_history',
      'fn_weekly_volume'
  )
ORDER BY routine_name;

-- =============================================================================
-- Ejemplos de uso comentados
-- =============================================================================

-- FN-01: Calcular 1RM para 100 kg × 8 reps → 126.67 kg
-- SELECT fn_epley_1rm(100, 8);

-- FN-02: Volumen de 100 kg × 8 reps → 800.00 kg
-- SELECT fn_volume(100, 8);

-- FN-03: ¿Es PR el ejercicio 5 con 1RM de 130.5 kg?
-- SELECT fn_is_pr(5, 130.5);

-- FN-04: Volumen total de la sesión 1
-- SELECT fn_session_volume(1);

-- FN-05: Historial de las últimas 3 sesiones del ejercicio 5
-- SELECT * FROM fn_exercise_history(5, 3);

-- FN-06: Volumen de la semana actual por grupo muscular
-- SELECT * FROM fn_weekly_volume();
