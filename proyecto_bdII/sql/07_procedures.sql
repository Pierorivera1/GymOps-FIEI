-- =============================================================================
-- GymOps — Base de Datos II (FIEI)
-- Script 07: Procedimientos Almacenados (PL/pgSQL)
-- Gestor: PostgreSQL 16
-- Autor: Piero Rivera
-- Fase 5 del Plan de Implementación SQL
-- =============================================================================
-- Contenido:
--   SP-01  sp_start_session(p_program_day_id)
--   SP-02  sp_log_set(p_session_id, p_exercise_id, p_set_number, p_reps, p_weight_kg)
--   SP-03  sp_close_session(p_session_id)
--   SP-04  sp_get_exercise_stats(p_exercise_id)
--   SP-05  sp_weekly_digest(p_week_date)
-- =============================================================================


-- =============================================================================
-- SP-01: sp_start_session
-- Descripción : Crea una nueva sesión de entrenamiento y devuelve su ID.
--               Valida que el program_day_id exista antes de insertar.
-- Parámetros  : p_program_day_id  INT  — ID del día del programa (puede ser NULL
--                                         para sesión libre sin programa asignado)
-- Retorna     : session_id INT, started_at TIMESTAMP, program_day_name TEXT
-- Uso         : SELECT * FROM sp_start_session(3);
-- =============================================================================
CREATE OR REPLACE FUNCTION sp_start_session(
    p_program_day_id INT DEFAULT NULL
)
RETURNS TABLE(session_id INT, started_at TIMESTAMP, program_day_name TEXT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_session_id   INT;
    v_day_name     TEXT;
    v_started_at   TIMESTAMP;
BEGIN
    -- Validar que el program_day_id exista si fue proporcionado
    IF p_program_day_id IS NOT NULL THEN
        SELECT name INTO v_day_name
        FROM program_day
        WHERE id = p_program_day_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'program_day_id % no existe en la tabla program_day.', p_program_day_id
                USING ERRCODE = 'no_data_found';
        END IF;
    ELSE
        v_day_name := 'Sesión libre (sin programa)';
    END IF;

    -- Crear la sesión
    INSERT INTO workout_session (program_day_id, started_at)
    VALUES (p_program_day_id, NOW())
    RETURNING id, workout_session.started_at
    INTO v_session_id, v_started_at;

    RAISE NOTICE 'Sesión % iniciada a las % — Día: %', v_session_id, v_started_at, v_day_name;

    RETURN QUERY
    SELECT v_session_id, v_started_at, v_day_name;
END;
$$;

COMMENT ON FUNCTION sp_start_session(INT) IS
    'SP-01: Crea una nueva workout_session. Valida el program_day_id si se provee. '
    'Retorna session_id, started_at y el nombre del día del programa.';


-- =============================================================================
-- SP-02: sp_log_set
-- Descripción : Registra un set dentro de una sesión activa.
--               Calcula el 1RM estimado (Epley) y el volumen.
--               Detecta si es un nuevo PR y actualiza personal_record.
--               Inserta registro en audit_log.
-- Nota        : Los triggers de la Fase 7 (09_triggers.sql) también realizarán
--               estos cálculos automáticamente; este SP los hace de forma explícita
--               para demostrar el flujo de negocio en PL/pgSQL.
-- Parámetros  : p_session_id   INT
--               p_exercise_id  INT
--               p_set_number   SMALLINT
--               p_reps         SMALLINT
--               p_weight_kg    NUMERIC(6,2)
-- Retorna     : set_id, estimated_1rm, volume, is_pr, pr_message
-- Uso         : SELECT * FROM sp_log_set(1, 5, 1, 8, 100.0);
-- =============================================================================
CREATE OR REPLACE FUNCTION sp_log_set(
    p_session_id   INT,
    p_exercise_id  INT,
    p_set_number   SMALLINT,
    p_reps         SMALLINT,
    p_weight_kg    NUMERIC(6,2)
)
RETURNS TABLE(
    set_id        INT,
    estimated_1rm NUMERIC(6,2),
    volume        NUMERIC(8,2),
    is_pr         BOOLEAN,
    pr_message    TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_set_id        INT;
    v_1rm           NUMERIC(6,2);
    v_volume        NUMERIC(8,2);
    v_is_pr         BOOLEAN := FALSE;
    v_pr_msg        TEXT;
    v_current_pr    NUMERIC(6,2);
    v_session_ended TIMESTAMP;
    v_exercise_name VARCHAR(100);
BEGIN
    -- -------------------------------------------------------------------------
    -- Validaciones previas
    -- -------------------------------------------------------------------------

    -- 1. La sesión debe existir y estar activa (ended_at IS NULL)
    SELECT ended_at INTO v_session_ended
    FROM workout_session
    WHERE id = p_session_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La sesión % no existe.', p_session_id
            USING ERRCODE = 'no_data_found';
    END IF;

    IF v_session_ended IS NOT NULL THEN
        RAISE EXCEPTION 'La sesión % ya fue cerrada el %. No se pueden agregar sets.',
            p_session_id, v_session_ended
            USING ERRCODE = 'check_violation';
    END IF;

    -- 2. El ejercicio debe existir
    SELECT name INTO v_exercise_name
    FROM exercise
    WHERE id = p_exercise_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El ejercicio_id % no existe en el catálogo.', p_exercise_id
            USING ERRCODE = 'no_data_found';
    END IF;

    -- 3. Validaciones de negocio
    IF p_reps <= 0 THEN
        RAISE EXCEPTION 'Las repeticiones deben ser mayor a 0. Recibido: %', p_reps
            USING ERRCODE = 'check_violation';
    END IF;

    IF p_weight_kg <= 0 THEN
        RAISE EXCEPTION 'El peso debe ser mayor a 0 kg. Recibido: %', p_weight_kg
            USING ERRCODE = 'check_violation';
    END IF;

    -- -------------------------------------------------------------------------
    -- Cálculos de negocio
    -- -------------------------------------------------------------------------

    -- Fórmula Epley: 1RM = weight * (1 + reps / 30.0)
    v_1rm    := ROUND(p_weight_kg * (1.0 + p_reps::NUMERIC / 30.0), 2);

    -- Volumen del set: weight * reps
    v_volume := ROUND(p_weight_kg * p_reps, 2);

    -- -------------------------------------------------------------------------
    -- Detección de PR
    -- -------------------------------------------------------------------------
    SELECT max_1rm INTO v_current_pr
    FROM personal_record
    WHERE exercise_id = p_exercise_id;

    IF NOT FOUND OR v_1rm > v_current_pr THEN
        v_is_pr := TRUE;
    END IF;

    -- -------------------------------------------------------------------------
    -- Insertar el set
    -- -------------------------------------------------------------------------
    INSERT INTO workout_set (
        session_id, exercise_id, set_number,
        reps, weight_kg, estimated_1rm, volume, is_pr
    )
    VALUES (
        p_session_id, p_exercise_id, p_set_number,
        p_reps, p_weight_kg, v_1rm, v_volume, v_is_pr
    )
    RETURNING id INTO v_set_id;

    -- -------------------------------------------------------------------------
    -- Actualizar o insertar PR
    -- -------------------------------------------------------------------------
    IF v_is_pr THEN
        INSERT INTO personal_record (exercise_id, max_1rm, achieved_at, set_id)
        VALUES (p_exercise_id, v_1rm, NOW(), v_set_id)
        ON CONFLICT (exercise_id) DO UPDATE
            SET max_1rm      = EXCLUDED.max_1rm,
                achieved_at  = EXCLUDED.achieved_at,
                set_id       = EXCLUDED.set_id;

        v_pr_msg := FORMAT(
            '🏆 ¡NUEVO PR en %s! 1RM estimado: %s kg (anterior: %s kg)',
            v_exercise_name,
            v_1rm,
            COALESCE(v_current_pr::TEXT, 'ninguno')
        );

        RAISE NOTICE '%', v_pr_msg;
    ELSE
        v_pr_msg := FORMAT(
            'Set registrado — %s: %s reps × %s kg → 1RM: %s kg',
            v_exercise_name, p_reps, p_weight_kg, v_1rm
        );
    END IF;

    -- -------------------------------------------------------------------------
    -- Registro de auditoría
    -- -------------------------------------------------------------------------
    INSERT INTO audit_log (table_name, operation, old_data, new_data)
    VALUES (
        'workout_set',
        'INSERT',
        NULL,
        jsonb_build_object(
            'set_id',        v_set_id,
            'session_id',    p_session_id,
            'exercise_id',   p_exercise_id,
            'exercise',      v_exercise_name,
            'set_number',    p_set_number,
            'reps',          p_reps,
            'weight_kg',     p_weight_kg,
            'estimated_1rm', v_1rm,
            'volume',        v_volume,
            'is_pr',         v_is_pr
        )
    );

    -- -------------------------------------------------------------------------
    -- Resultado
    -- -------------------------------------------------------------------------
    RETURN QUERY
    SELECT v_set_id, v_1rm, v_volume, v_is_pr, v_pr_msg;
END;
$$;

COMMENT ON FUNCTION sp_log_set(INT, INT, SMALLINT, SMALLINT, NUMERIC) IS
    'SP-02: Registra un set en una sesión activa. Calcula 1RM (Epley) y volumen. '
    'Detecta y actualiza PRs. Inserta en audit_log. Valida sesión abierta y datos positivos.';


-- =============================================================================
-- SP-03: sp_close_session
-- Descripción : Cierra una sesión activa registrando su ended_at.
--               Muestra resumen: ejercicios trabajados, sets totales,
--               volumen total y PRs logrados en la sesión.
-- Parámetros  : p_session_id  INT
-- Retorna     : session_id, duration_minutes, total_sets, total_volume_kg,
--               prs_achieved, exercises_worked
-- Uso         : SELECT * FROM sp_close_session(1);
-- =============================================================================
CREATE OR REPLACE FUNCTION sp_close_session(
    p_session_id INT
)
RETURNS TABLE(
    session_id        INT,
    duration_minutes  NUMERIC(8,2),
    total_sets        BIGINT,
    total_volume_kg   NUMERIC(12,2),
    prs_achieved      BIGINT,
    exercises_worked  BIGINT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_started_at   TIMESTAMP;
    v_ended_at     TIMESTAMP;
    v_duration     NUMERIC(8,2);
    v_total_sets   BIGINT;
    v_total_vol    NUMERIC(12,2);
    v_prs          BIGINT;
    v_exercises    BIGINT;
BEGIN
    -- Verificar que la sesión exista
    SELECT started_at, ended_at
    INTO v_started_at, v_ended_at
    FROM workout_session
    WHERE id = p_session_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La sesión % no existe.', p_session_id
            USING ERRCODE = 'no_data_found';
    END IF;

    -- Verificar que no esté ya cerrada
    IF v_ended_at IS NOT NULL THEN
        RAISE EXCEPTION 'La sesión % ya fue cerrada el %. Use sp_get_exercise_stats para consultar.',
            p_session_id, v_ended_at
            USING ERRCODE = 'check_violation';
    END IF;

    -- Verificar que tenga al menos un set registrado
    SELECT COUNT(*) INTO v_total_sets
    FROM workout_set
    WHERE workout_set.session_id = p_session_id;

    IF v_total_sets = 0 THEN
        RAISE WARNING 'La sesión % no tiene sets registrados. Cerrando de todos modos.', p_session_id;
    END IF;

    -- Cerrar la sesión
    UPDATE workout_session
    SET ended_at = NOW()
    WHERE id = p_session_id
    RETURNING ended_at INTO v_ended_at;

    -- Calcular duración en minutos
    v_duration := ROUND(EXTRACT(EPOCH FROM (v_ended_at - v_started_at)) / 60.0, 2);

    -- Calcular estadísticas de la sesión
    SELECT
        COUNT(*)                                   AS total_sets,
        COALESCE(SUM(volume), 0)                   AS total_volume,
        COUNT(*) FILTER (WHERE is_pr = TRUE)       AS prs,
        COUNT(DISTINCT exercise_id)                AS exercises
    INTO v_total_sets, v_total_vol, v_prs, v_exercises
    FROM workout_set
    WHERE workout_set.session_id = p_session_id;

    RAISE NOTICE '✅ Sesión % cerrada — Duración: % min | Sets: % | Volumen: % kg | PRs: % | Ejercicios: %',
        p_session_id, v_duration, v_total_sets, v_total_vol, v_prs, v_exercises;

    RETURN QUERY
    SELECT
        p_session_id,
        v_duration,
        v_total_sets,
        v_total_vol,
        v_prs,
        v_exercises;
END;
$$;

COMMENT ON FUNCTION sp_close_session(INT) IS
    'SP-03: Cierra una sesión activa (registra ended_at). '
    'Retorna resumen: duración, sets totales, volumen acumulado, PRs y ejercicios trabajados.';


-- =============================================================================
-- SP-04: sp_get_exercise_stats
-- Descripción : Retorna estadísticas completas de un ejercicio:
--               PR actual, mejor volumen por sesión, progresión de 1RM,
--               número de sesiones entrenadas y última fecha.
-- Parámetros  : p_exercise_id  INT
-- Retorna     : conjunto de métricas del ejercicio
-- Uso         : SELECT * FROM sp_get_exercise_stats(5);
-- =============================================================================
CREATE OR REPLACE FUNCTION sp_get_exercise_stats(
    p_exercise_id INT
)
RETURNS TABLE(
    exercise_name       VARCHAR(100),
    muscle_group        VARCHAR(50),
    current_pr_1rm      NUMERIC(6,2),
    pr_achieved_at      TIMESTAMP,
    best_session_volume NUMERIC(12,2),
    avg_reps            NUMERIC(5,2),
    avg_weight_kg       NUMERIC(6,2),
    total_sets_logged   BIGINT,
    total_sessions      BIGINT,
    last_session_date   TIMESTAMP,
    days_since_last     INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_name     VARCHAR(100);
    v_muscle   VARCHAR(50);
BEGIN
    -- Verificar que el ejercicio exista
    SELECT e.name, mg.name
    INTO v_name, v_muscle
    FROM exercise e
    JOIN muscle_group mg ON mg.id = e.muscle_group_id
    WHERE e.id = p_exercise_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El ejercicio_id % no existe en el catálogo.', p_exercise_id
            USING ERRCODE = 'no_data_found';
    END IF;

    RETURN QUERY
    WITH sets_data AS (
        -- Todos los sets del ejercicio con datos de sesión
        SELECT
            ws.session_id,
            ws.reps,
            ws.weight_kg,
            ws.estimated_1rm,
            ws.volume,
            ws.logged_at
        FROM workout_set ws
        WHERE ws.exercise_id = p_exercise_id
    ),
    session_volumes AS (
        -- Volumen total por sesión
        SELECT
            session_id,
            SUM(volume) AS session_volume
        FROM sets_data
        GROUP BY session_id
    )
    SELECT
        v_name                                           AS exercise_name,
        v_muscle                                         AS muscle_group,
        pr.max_1rm                                       AS current_pr_1rm,
        pr.achieved_at                                   AS pr_achieved_at,
        MAX(sv.session_volume)                           AS best_session_volume,
        ROUND(AVG(sd.reps), 2)                           AS avg_reps,
        ROUND(AVG(sd.weight_kg), 2)                      AS avg_weight_kg,
        COUNT(sd.reps)                                   AS total_sets_logged,
        COUNT(DISTINCT sd.session_id)                    AS total_sessions,
        MAX(sd.logged_at)                                AS last_session_date,
        EXTRACT(DAY FROM NOW() - MAX(sd.logged_at))::INT AS days_since_last
    FROM sets_data sd
    LEFT JOIN session_volumes sv ON sv.session_id = sd.session_id
    LEFT JOIN personal_record pr ON pr.exercise_id = p_exercise_id
    GROUP BY pr.max_1rm, pr.achieved_at;
END;
$$;

COMMENT ON FUNCTION sp_get_exercise_stats(INT) IS
    'SP-04: Retorna estadísticas completas de un ejercicio: PR actual, volumen máximo '
    'por sesión, promedios de reps y peso, total de sets/sesiones y días desde la última sesión.';


-- =============================================================================
-- SP-05: sp_weekly_digest
-- Descripción : Genera el resumen semanal de entrenamiento para la semana
--               que contiene la fecha indicada. Incluye:
--               — Volumen total por grupo muscular
--               — Número de sesiones completadas
--               — PRs logrados en la semana
--               — Ejercicio con mayor volumen de la semana
-- Parámetros  : p_week_date  DATE  — cualquier fecha dentro de la semana deseada
--                                     (por defecto: semana actual)
-- Retorna     : week_start, week_end, muscle_group, sessions_count, total_sets,
--               total_volume_kg, prs_in_week, top_exercise, top_exercise_vol
-- Uso         : SELECT * FROM sp_weekly_digest(CURRENT_DATE);
--               SELECT * FROM sp_weekly_digest('2026-06-15');
-- =============================================================================
CREATE OR REPLACE FUNCTION sp_weekly_digest(
    p_week_date DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE(
    week_start         DATE,
    week_end           DATE,
    muscle_group       VARCHAR(50),
    sessions_count     BIGINT,
    total_sets         BIGINT,
    total_volume_kg    NUMERIC(12,2),
    prs_in_week        BIGINT,
    top_exercise       VARCHAR(100),
    top_exercise_vol   NUMERIC(12,2)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_week_start DATE;
    v_week_end   DATE;
    v_row_count  INT;
BEGIN
    -- Calcular lunes y domingo de la semana que contiene p_week_date
    v_week_start := DATE_TRUNC('week', p_week_date::TIMESTAMP)::DATE;
    v_week_end   := v_week_start + INTERVAL '6 days';

    RAISE NOTICE 'Generando digest para la semana % al %', v_week_start, v_week_end;

    -- Verificar si hay datos para esa semana
    SELECT COUNT(*) INTO v_row_count
    FROM workout_session ws
    WHERE ws.started_at::DATE BETWEEN v_week_start AND v_week_end
      AND ws.ended_at IS NOT NULL;

    IF v_row_count = 0 THEN
        RAISE WARNING 'No se encontraron sesiones cerradas entre % y %.', v_week_start, v_week_end;
    END IF;

    RETURN QUERY
    WITH week_sets AS (
        -- Todos los sets de sesiones cerradas en la semana
        SELECT
            wset.id           AS set_id,
            wset.session_id,
            wset.exercise_id,
            wset.volume,
            wset.is_pr,
            wsess.started_at
        FROM workout_set wset
        JOIN workout_session wsess ON wsess.id = wset.session_id
        WHERE wsess.started_at::DATE BETWEEN v_week_start AND v_week_end
          AND wsess.ended_at IS NOT NULL
    ),
    by_muscle AS (
        -- Agrupación por grupo muscular
        SELECT
            mg.name                              AS muscle_name,
            COUNT(DISTINCT ws.session_id)        AS sessions,
            COUNT(ws.set_id)                     AS sets_count,
            COALESCE(SUM(ws.volume), 0)          AS vol_total,
            COUNT(*) FILTER (WHERE ws.is_pr)     AS prs_count
        FROM week_sets ws
        JOIN exercise e       ON e.id  = ws.exercise_id
        JOIN muscle_group mg  ON mg.id = e.muscle_group_id
        GROUP BY mg.name
    ),
    top_ex AS (
        -- Ejercicio con mayor volumen por grupo muscular
        SELECT DISTINCT ON (e.muscle_group_id)
            mg.name           AS mg_name,
            e.name            AS ex_name,
            SUM(ws.volume) OVER (PARTITION BY ws.exercise_id) AS ex_vol
        FROM week_sets ws
        JOIN exercise e       ON e.id  = ws.exercise_id
        JOIN muscle_group mg  ON mg.id = e.muscle_group_id
        ORDER BY e.muscle_group_id, ex_vol DESC
    )
    SELECT
        v_week_start                    AS week_start,
        v_week_end::DATE                AS week_end,
        bm.muscle_name                  AS muscle_group,
        bm.sessions                     AS sessions_count,
        bm.sets_count                   AS total_sets,
        bm.vol_total                    AS total_volume_kg,
        bm.prs_count                    AS prs_in_week,
        tx.ex_name                      AS top_exercise,
        tx.ex_vol                       AS top_exercise_vol
    FROM by_muscle bm
    LEFT JOIN top_ex tx ON tx.mg_name = bm.muscle_name
    ORDER BY bm.vol_total DESC;
END;
$$;

COMMENT ON FUNCTION sp_weekly_digest(DATE) IS
    'SP-05: Genera el resumen semanal de entrenamiento. '
    'Agrupa por grupo muscular: sesiones, sets, volumen total, PRs y ejercicio top. '
    'Acepta cualquier fecha de la semana deseada (default: semana actual).';


-- =============================================================================
-- Verificación: listar los SPs creados
-- =============================================================================
SELECT
    routine_name                 AS procedimiento,
    routine_type                 AS tipo,
    data_type                    AS retorna,
    external_language            AS lenguaje
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name IN (
      'sp_start_session',
      'sp_log_set',
      'sp_close_session',
      'sp_get_exercise_stats',
      'sp_weekly_digest'
  )
ORDER BY routine_name;
