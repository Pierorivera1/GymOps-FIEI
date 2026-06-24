-- =============================================================================
-- GymOps — Base de Datos II (FIEI)
-- Script 09: Triggers (PL/pgSQL)
-- Gestor: PostgreSQL 16
-- Autor: Piero Rivera
-- Fase 7 del Plan de Implementación SQL
-- =============================================================================
-- Contenido:
--   TRG-01  trg_validate_set          — BEFORE INSERT ON workout_set
--   TRG-02  trg_prevent_closed_session — BEFORE INSERT ON workout_set
--   TRG-03  trg_calculate_1rm         — AFTER INSERT ON workout_set
--   TRG-04  trg_update_pr             — AFTER INSERT/UPDATE ON workout_set
--   TRG-05  trg_audit_set             — AFTER INSERT/UPDATE/DELETE ON workout_set
--   TRG-06  trg_audit_pr              — AFTER UPDATE ON personal_record
-- =============================================================================
-- ORDEN DE EJECUCIÓN EN UN INSERT sobre workout_set:
--   1. trg_validate_set           (BEFORE) → valida reps > 0 y weight > 0
--   2. trg_prevent_closed_session (BEFORE) → bloquea si la sesión está cerrada
--   3. INSERT real en workout_set
--   4. trg_calculate_1rm          (AFTER)  → rellena estimated_1rm y volume
--   5. trg_update_pr              (AFTER)  → detecta PR y actualiza personal_record
--   6. trg_audit_set              (AFTER)  → registra operación en audit_log
-- =============================================================================


-- =============================================================================
-- FUNCIÓN AUXILIAR: fn_trg_validate_set_row
-- Usada internamente por TRG-01
-- =============================================================================
CREATE OR REPLACE FUNCTION fn_trg_validate_set_row()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Validar reps > 0
    IF NEW.reps IS NULL OR NEW.reps <= 0 THEN
        RAISE EXCEPTION
            '[trg_validate_set] Reps inválidas: %. Deben ser > 0.',
            NEW.reps
            USING ERRCODE = 'check_violation';
    END IF;

    -- Validar weight_kg > 0
    IF NEW.weight_kg IS NULL OR NEW.weight_kg <= 0 THEN
        RAISE EXCEPTION
            '[trg_validate_set] Peso inválido: % kg. Debe ser > 0.',
            NEW.weight_kg
            USING ERRCODE = 'check_violation';
    END IF;

    -- Validar set_number > 0
    IF NEW.set_number IS NULL OR NEW.set_number <= 0 THEN
        RAISE EXCEPTION
            '[trg_validate_set] set_number inválido: %. Debe ser > 0.',
            NEW.set_number
            USING ERRCODE = 'check_violation';
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION fn_trg_validate_set_row() IS
    'Función trigger de TRG-01: valida reps > 0, weight_kg > 0 y set_number > 0 '
    'antes de insertar un set. Hace RAISE EXCEPTION si algún valor es inválido.';


-- =============================================================================
-- TRG-01: trg_validate_set
-- Evento   : BEFORE INSERT ON workout_set
-- Objetivo : Validar que reps > 0, weight_kg > 0 y set_number > 0
--            antes de persistir el registro. Rechaza el INSERT si falla.
-- =============================================================================
DROP TRIGGER IF EXISTS trg_validate_set ON workout_set;

CREATE TRIGGER trg_validate_set
    BEFORE INSERT ON workout_set
    FOR EACH ROW
    EXECUTE FUNCTION fn_trg_validate_set_row();

COMMENT ON TRIGGER trg_validate_set ON workout_set IS
    'TRG-01 (BEFORE INSERT): Valida integridad de negocio — reps > 0, '
    'weight_kg > 0, set_number > 0. Lanza excepción si algún valor es inválido.';


-- =============================================================================
-- FUNCIÓN AUXILIAR: fn_trg_prevent_closed_session_row
-- Usada internamente por TRG-02
-- =============================================================================
CREATE OR REPLACE FUNCTION fn_trg_prevent_closed_session_row()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_ended_at TIMESTAMP;
BEGIN
    SELECT ended_at INTO v_ended_at
    FROM workout_session
    WHERE id = NEW.session_id;

    IF v_ended_at IS NOT NULL THEN
        RAISE EXCEPTION
            '[trg_prevent_closed_session] La sesión % fue cerrada el %. '
            'No se pueden registrar sets en una sesión cerrada.',
            NEW.session_id, v_ended_at
            USING ERRCODE = 'check_violation';
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION fn_trg_prevent_closed_session_row() IS
    'Función trigger de TRG-02: bloquea el INSERT de un set si la sesión '
    'a la que pertenece ya tiene ended_at registrado (sesión cerrada).';


-- =============================================================================
-- TRG-02: trg_prevent_closed_session
-- Evento   : BEFORE INSERT ON workout_set
-- Objetivo : Impedir agregar sets a una sesión que ya fue cerrada
--            (ended_at IS NOT NULL). Protege la integridad del historial.
-- =============================================================================
DROP TRIGGER IF EXISTS trg_prevent_closed_session ON workout_set;

CREATE TRIGGER trg_prevent_closed_session
    BEFORE INSERT ON workout_set
    FOR EACH ROW
    EXECUTE FUNCTION fn_trg_prevent_closed_session_row();

COMMENT ON TRIGGER trg_prevent_closed_session ON workout_set IS
    'TRG-02 (BEFORE INSERT): Bloquea la inserción de sets en sesiones '
    'ya cerradas (ended_at IS NOT NULL). Garantiza inmutabilidad del historial.';


-- =============================================================================
-- FUNCIÓN AUXILIAR: fn_trg_calculate_1rm_row
-- Usada internamente por TRG-03
-- =============================================================================
CREATE OR REPLACE FUNCTION fn_trg_calculate_1rm_row()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_1rm    NUMERIC(6,2);
    v_volume NUMERIC(8,2);
BEGIN
    -- Fórmula Epley: 1RM = weight * (1 + reps/30)
    -- Para 1 rep: el 1RM es igual al peso levantado
    IF NEW.reps = 1 THEN
        v_1rm := NEW.weight_kg;
    ELSE
        v_1rm := ROUND(NEW.weight_kg * (1.0 + NEW.reps::NUMERIC / 30.0), 2);
    END IF;

    -- Volumen del set
    v_volume := ROUND(NEW.weight_kg * NEW.reps, 2);

    -- Actualizar los campos calculados en el mismo registro
    UPDATE workout_set
    SET estimated_1rm = v_1rm,
        volume        = v_volume
    WHERE id = NEW.id;

    RETURN NULL;  -- AFTER trigger, no hay NEW para retornar
END;
$$;

COMMENT ON FUNCTION fn_trg_calculate_1rm_row() IS
    'Función trigger de TRG-03: calcula y persiste estimated_1rm (Epley) y '
    'volume (weight×reps) en el set recién insertado mediante UPDATE directo.';


-- =============================================================================
-- TRG-03: trg_calculate_1rm
-- Evento   : AFTER INSERT ON workout_set
-- Objetivo : Calcular y guardar el 1RM estimado (Epley) y el volumen
--            del set automáticamente tras cada inserción.
--            Evita que el código de aplicación deba calcularlos.
-- =============================================================================
DROP TRIGGER IF EXISTS trg_calculate_1rm ON workout_set;

CREATE TRIGGER trg_calculate_1rm
    AFTER INSERT ON workout_set
    FOR EACH ROW
    EXECUTE FUNCTION fn_trg_calculate_1rm_row();

COMMENT ON TRIGGER trg_calculate_1rm ON workout_set IS
    'TRG-03 (AFTER INSERT): Rellena automáticamente estimated_1rm y volume '
    'en cada set usando la fórmula de Epley y weight×reps.';


-- =============================================================================
-- FUNCIÓN AUXILIAR: fn_trg_update_pr_row
-- Usada internamente por TRG-04
-- =============================================================================
CREATE OR REPLACE FUNCTION fn_trg_update_pr_row()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_1rm        NUMERIC(6,2);
    v_current_pr NUMERIC(6,2);
BEGIN
    -- Recalcular 1RM (puede que aún sea NULL si el TRG-03 aún no actualizó)
    IF NEW.reps = 1 THEN
        v_1rm := NEW.weight_kg;
    ELSE
        v_1rm := ROUND(NEW.weight_kg * (1.0 + NEW.reps::NUMERIC / 30.0), 2);
    END IF;

    -- Obtener PR actual del ejercicio
    SELECT max_1rm INTO v_current_pr
    FROM personal_record
    WHERE exercise_id = NEW.exercise_id;

    -- Si es PR: upsert en personal_record y marcar el set
    IF NOT FOUND OR v_1rm > v_current_pr THEN

        INSERT INTO personal_record (exercise_id, max_1rm, achieved_at, set_id)
        VALUES (NEW.exercise_id, v_1rm, NOW(), NEW.id)
        ON CONFLICT (exercise_id) DO UPDATE
            SET max_1rm     = EXCLUDED.max_1rm,
                achieved_at = EXCLUDED.achieved_at,
                set_id      = EXCLUDED.set_id;

        -- Marcar el set como PR
        UPDATE workout_set
        SET is_pr = TRUE
        WHERE id = NEW.id;

        RAISE NOTICE '[trg_update_pr] ¡Nuevo PR en ejercicio_id %! 1RM: %.2f kg (anterior: %)',
            NEW.exercise_id, v_1rm, COALESCE(v_current_pr::TEXT, 'ninguno');
    END IF;

    RETURN NULL;
END;
$$;

COMMENT ON FUNCTION fn_trg_update_pr_row() IS
    'Función trigger de TRG-04: detecta si el set es un nuevo PR comparando '
    'su 1RM estimado con personal_record. Si supera el PR actual, actualiza '
    'personal_record y marca is_pr=TRUE en el set.';


-- =============================================================================
-- TRG-04: trg_update_pr
-- Evento   : AFTER INSERT OR UPDATE ON workout_set
-- Objetivo : Detectar automáticamente nuevos récords personales.
--            Si el 1RM del set supera el PR actual del ejercicio:
--            — Actualiza (upsert) la tabla personal_record
--            — Marca is_pr = TRUE en el workout_set correspondiente
-- =============================================================================
DROP TRIGGER IF EXISTS trg_update_pr ON workout_set;

CREATE TRIGGER trg_update_pr
    AFTER INSERT OR UPDATE ON workout_set
    FOR EACH ROW
    EXECUTE FUNCTION fn_trg_update_pr_row();

COMMENT ON TRIGGER trg_update_pr ON workout_set IS
    'TRG-04 (AFTER INSERT/UPDATE): Detecta PRs automáticamente. '
    'Si el 1RM calculado supera el PR actual, actualiza personal_record '
    'y marca is_pr=TRUE en el set.';


-- =============================================================================
-- FUNCIÓN AUXILIAR: fn_trg_audit_set_row
-- Usada internamente por TRG-05
-- =============================================================================
CREATE OR REPLACE FUNCTION fn_trg_audit_set_row()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_old_data JSONB := NULL;
    v_new_data JSONB := NULL;
    v_op       VARCHAR(10);
BEGIN
    v_op := TG_OP;

    -- Construir JSON de datos anteriores (UPDATE y DELETE)
    IF TG_OP IN ('UPDATE', 'DELETE') THEN
        v_old_data := jsonb_build_object(
            'id',           OLD.id,
            'session_id',   OLD.session_id,
            'exercise_id',  OLD.exercise_id,
            'set_number',   OLD.set_number,
            'reps',         OLD.reps,
            'weight_kg',    OLD.weight_kg,
            'estimated_1rm', OLD.estimated_1rm,
            'volume',       OLD.volume,
            'is_pr',        OLD.is_pr,
            'logged_at',    OLD.logged_at
        );
    END IF;

    -- Construir JSON de datos nuevos (INSERT y UPDATE)
    IF TG_OP IN ('INSERT', 'UPDATE') THEN
        v_new_data := jsonb_build_object(
            'id',           NEW.id,
            'session_id',   NEW.session_id,
            'exercise_id',  NEW.exercise_id,
            'set_number',   NEW.set_number,
            'reps',         NEW.reps,
            'weight_kg',    NEW.weight_kg,
            'estimated_1rm', NEW.estimated_1rm,
            'volume',       NEW.volume,
            'is_pr',        NEW.is_pr,
            'logged_at',    NEW.logged_at
        );
    END IF;

    INSERT INTO audit_log (table_name, operation, old_data, new_data, changed_at)
    VALUES ('workout_set', v_op, v_old_data, v_new_data, NOW());

    RETURN NULL;  -- AFTER trigger
END;
$$;

COMMENT ON FUNCTION fn_trg_audit_set_row() IS
    'Función trigger de TRG-05: inserta un registro en audit_log con los datos '
    'OLD y NEW en formato JSONB para cada INSERT/UPDATE/DELETE sobre workout_set.';


-- =============================================================================
-- TRG-05: trg_audit_set
-- Evento   : AFTER INSERT OR UPDATE OR DELETE ON workout_set
-- Objetivo : Registrar toda modificación sobre workout_set en audit_log
--            con los datos anteriores (OLD) y nuevos (NEW) en JSONB.
--            Garantiza trazabilidad total de sets (RF-10, RNF-07).
-- =============================================================================
DROP TRIGGER IF EXISTS trg_audit_set ON workout_set;

CREATE TRIGGER trg_audit_set
    AFTER INSERT OR UPDATE OR DELETE ON workout_set
    FOR EACH ROW
    EXECUTE FUNCTION fn_trg_audit_set_row();

COMMENT ON TRIGGER trg_audit_set ON workout_set IS
    'TRG-05 (AFTER INSERT/UPDATE/DELETE): Auditoría completa de workout_set. '
    'Persiste OLD y NEW en JSONB dentro de audit_log. Cubre RF-10 y RNF-07.';


-- =============================================================================
-- FUNCIÓN AUXILIAR: fn_trg_audit_pr_row
-- Usada internamente por TRG-06
-- =============================================================================
CREATE OR REPLACE FUNCTION fn_trg_audit_pr_row()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Solo auditar cuando el max_1rm cambia efectivamente
    IF OLD.max_1rm IS DISTINCT FROM NEW.max_1rm THEN
        INSERT INTO audit_log (table_name, operation, old_data, new_data, changed_at)
        VALUES (
            'personal_record',
            'UPDATE',
            jsonb_build_object(
                'id',          OLD.id,
                'exercise_id', OLD.exercise_id,
                'max_1rm',     OLD.max_1rm,
                'achieved_at', OLD.achieved_at,
                'set_id',      OLD.set_id
            ),
            jsonb_build_object(
                'id',          NEW.id,
                'exercise_id', NEW.exercise_id,
                'max_1rm',     NEW.max_1rm,
                'achieved_at', NEW.achieved_at,
                'set_id',      NEW.set_id
            ),
            NOW()
        );

        RAISE NOTICE '[trg_audit_pr] PR del ejercicio_id % actualizado: %.2f → %.2f kg',
            NEW.exercise_id, OLD.max_1rm, NEW.max_1rm;
    END IF;

    RETURN NULL;
END;
$$;

COMMENT ON FUNCTION fn_trg_audit_pr_row() IS
    'Función trigger de TRG-06: registra en audit_log el cambio de PR '
    'sólo cuando max_1rm cambia efectivamente (usa IS DISTINCT FROM).';


-- =============================================================================
-- TRG-06: trg_audit_pr
-- Evento   : AFTER UPDATE ON personal_record
-- Objetivo : Registrar en audit_log cada cambio de PR (max_1rm).
--            Sólo actúa si max_1rm cambia efectivamente (IS DISTINCT FROM),
--            evitando registros redundantes de actualizaciones nulas.
-- =============================================================================
DROP TRIGGER IF EXISTS trg_audit_pr ON personal_record;

CREATE TRIGGER trg_audit_pr
    AFTER UPDATE ON personal_record
    FOR EACH ROW
    EXECUTE FUNCTION fn_trg_audit_pr_row();

COMMENT ON TRIGGER trg_audit_pr ON personal_record IS
    'TRG-06 (AFTER UPDATE): Auditoría de cambios en personal_record. '
    'Registra en audit_log sólo cuando max_1rm cambia (IS DISTINCT FROM). '
    'Cubre RNF-07 para la tabla de PRs.';


-- =============================================================================
-- Verificación: listar triggers y funciones trigger creados
-- =============================================================================

-- Triggers activos
SELECT
    trigger_name                  AS trigger,
    event_manipulation            AS evento,
    action_timing                 AS momento,
    event_object_table            AS tabla,
    action_orientation            AS orientacion
FROM information_schema.triggers
WHERE trigger_schema = 'public'
  AND event_object_table IN ('workout_set', 'personal_record')
ORDER BY event_object_table, action_timing DESC, trigger_name;

-- Funciones trigger creadas
SELECT
    routine_name                  AS funcion_trigger,
    external_language             AS lenguaje
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name IN (
      'fn_trg_validate_set_row',
      'fn_trg_prevent_closed_session_row',
      'fn_trg_calculate_1rm_row',
      'fn_trg_update_pr_row',
      'fn_trg_audit_set_row',
      'fn_trg_audit_pr_row'
  )
ORDER BY routine_name;

-- =============================================================================
-- Tabla resumen del orden de ejecución de triggers en workout_set
-- =============================================================================
-- Operación INSERT:
--   Momento  | Trigger                      | Acción
--   ---------|------------------------------|----------------------------------
--   BEFORE   | trg_validate_set             | Valida reps > 0, weight > 0
--   BEFORE   | trg_prevent_closed_session   | Bloquea si sesión cerrada
--   (INSERT) | —                            | Se persiste el registro
--   AFTER    | trg_calculate_1rm            | Calcula 1RM y volumen
--   AFTER    | trg_update_pr                | Detecta PR, actualiza tabla
--   AFTER    | trg_audit_set                | Registra en audit_log
--
-- Operación UPDATE:
--   AFTER    | trg_update_pr                | Re-evalúa PR si peso/reps cambia
--   AFTER    | trg_audit_set                | Registra OLD/NEW en audit_log
--
-- Operación DELETE:
--   AFTER    | trg_audit_set                | Registra eliminación en audit_log
-- =============================================================================
