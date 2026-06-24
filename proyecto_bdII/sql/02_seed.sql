-- =============================================================================
-- GymOps — Base de Datos II (FIEI)
-- Script 02: SEED — Datos iniciales
-- Autor: Piero Rivera
-- =============================================================================

-- =============================================================================
-- 1. GRUPOS MUSCULARES
-- =============================================================================
INSERT INTO muscle_group (name, description) VALUES
    ('Pecho',      'Músculos pectorales: mayor y menor'),
    ('Espalda',    'Dorsal ancho, trapecio, romboides y erectores espinales'),
    ('Hombros',    'Deltoides anterior, lateral y posterior'),
    ('Bíceps',     'Bíceps braquial y braquiorradial'),
    ('Tríceps',    'Tríceps braquial: cabezas larga, lateral y medial'),
    ('Piernas',    'Cuádriceps, isquiotibiales y glúteos'),
    ('Glúteos',    'Glúteo mayor, medio y menor'),
    ('Abdomen',    'Recto abdominal, oblicuos y transverso'),
    ('Pantorrilla','Gastrocnemio y sóleo'),
    ('Antebrazos', 'Flexores y extensores del antebrazo');

-- =============================================================================
-- 2. EJERCICIOS (50+ del catálogo base)
-- =============================================================================

-- PECHO
INSERT INTO exercise (name, muscle_group_id, type, equipment, description) VALUES
    ('Barbell Bench Press',          1, 'compound',  'barbell',   'Press de banca con barra — ejercicio principal de pecho'),
    ('Incline Barbell Bench Press',  1, 'compound',  'barbell',   'Press inclinado con barra — enfoque en pecho superior'),
    ('Decline Barbell Bench Press',  1, 'compound',  'barbell',   'Press declinado con barra — pecho inferior'),
    ('Dumbbell Bench Press',         1, 'compound',  'dumbbell',  'Press de banca con mancuernas'),
    ('Incline Dumbbell Press',       1, 'compound',  'dumbbell',  'Press inclinado con mancuernas'),
    ('Cable Fly',                    1, 'isolation', 'cable',     'Aperturas en polea — énfasis en aducción del pecho'),
    ('Dumbbell Fly',                 1, 'isolation', 'dumbbell',  'Aperturas con mancuernas'),
    ('Chest Dip',                    1, 'compound',  'bodyweight','Fondos en paralelas con énfasis en pecho'),
    ('Push Up',                      1, 'compound',  'bodyweight','Flexiones de pecho');

-- ESPALDA
INSERT INTO exercise (name, muscle_group_id, type, equipment, description) VALUES
    ('Barbell Row',                  2, 'compound',  'barbell',   'Remo con barra — ejercicio principal de espalda'),
    ('Pull Up',                      2, 'compound',  'bodyweight','Dominadas con agarre prono'),
    ('Chin Up',                      2, 'compound',  'bodyweight','Dominadas con agarre supino — mayor activación de bíceps'),
    ('Lat Pulldown',                 2, 'compound',  'cable',     'Jalón al pecho en polea — enfoque en dorsal ancho'),
    ('Seated Cable Row',             2, 'compound',  'cable',     'Remo sentado en polea — dorsal y romboides'),
    ('Dumbbell Row',                 2, 'compound',  'dumbbell',  'Remo con mancuerna a una mano'),
    ('Face Pull',                    2, 'isolation', 'cable',     'Jalón a la cara — deltoides posterior y manguito rotador'),
    ('Deadlift',                     2, 'compound',  'barbell',   'Peso muerto convencional — ejercicio rey de fuerza'),
    ('Romanian Deadlift',            2, 'compound',  'barbell',   'Peso muerto rumano — isquiotibiales y lumbar');

-- HOMBROS
INSERT INTO exercise (name, muscle_group_id, type, equipment, description) VALUES
    ('Overhead Press',               3, 'compound',  'barbell',   'Press militar con barra — deltoides anterior y lateral'),
    ('Dumbbell Shoulder Press',      3, 'compound',  'dumbbell',  'Press de hombros con mancuernas'),
    ('Lateral Raise',                3, 'isolation', 'dumbbell',  'Elevaciones laterales — deltoides lateral'),
    ('Cable Lateral Raise',          3, 'isolation', 'cable',     'Elevaciones laterales en polea'),
    ('Rear Delt Fly',                3, 'isolation', 'dumbbell',  'Aperturas posteriores — deltoides posterior'),
    ('Arnold Press',                 3, 'compound',  'dumbbell',  'Press Arnold — trabaja los 3 haces del deltoides');

-- BÍCEPS
INSERT INTO exercise (name, muscle_group_id, type, equipment, description) VALUES
    ('Barbell Curl',                 4, 'isolation', 'barbell',   'Curl con barra — ejercicio principal de bíceps'),
    ('Dumbbell Curl',                4, 'isolation', 'dumbbell',  'Curl con mancuernas alternado'),
    ('Incline Dumbbell Curl',        4, 'isolation', 'dumbbell',  'Curl inclinado — mayor estiramiento del bíceps'),
    ('Hammer Curl',                  4, 'isolation', 'dumbbell',  'Curl martillo — énfasis en braquiorradial'),
    ('Cable Curl',                   4, 'isolation', 'cable',     'Curl en polea baja'),
    ('Preacher Curl',                4, 'isolation', 'barbell',   'Curl en banco predicador');

-- TRÍCEPS
INSERT INTO exercise (name, muscle_group_id, type, equipment, description) VALUES
    ('Tricep Pushdown',              5, 'isolation', 'cable',     'Extensión en polea alta — cabeza lateral del tríceps'),
    ('Overhead Tricep Extension',    5, 'isolation', 'dumbbell',  'Extensión sobre la cabeza — cabeza larga del tríceps'),
    ('Skull Crusher',                5, 'isolation', 'barbell',   'Press francés con barra — tríceps completo'),
    ('Tricep Dip',                   5, 'compound',  'bodyweight','Fondos en paralelas — énfasis en tríceps'),
    ('Close Grip Bench Press',       5, 'compound',  'barbell',   'Press agarre cerrado — tríceps y pecho');

-- PIERNAS
INSERT INTO exercise (name, muscle_group_id, type, equipment, description) VALUES
    ('Barbell Squat',                6, 'compound',  'barbell',   'Sentadilla con barra — ejercicio rey de piernas'),
    ('Front Squat',                  6, 'compound',  'barbell',   'Sentadilla frontal — mayor énfasis en cuádriceps'),
    ('Leg Press',                    6, 'compound',  'machine',   'Prensa de piernas en máquina'),
    ('Bulgarian Split Squat',        6, 'compound',  'dumbbell',  'Sentadilla búlgara — cuádriceps y glúteos'),
    ('Hack Squat',                   6, 'compound',  'machine',   'Hack squat en máquina'),
    ('Leg Extension',                6, 'isolation', 'machine',   'Extensión de piernas — cuádriceps aislado'),
    ('Leg Curl',                     6, 'isolation', 'machine',   'Curl de piernas — isquiotibiales aislado'),
    ('Stiff Leg Deadlift',           6, 'compound',  'barbell',   'Peso muerto piernas rígidas — isquiotibiales');

-- GLÚTEOS
INSERT INTO exercise (name, muscle_group_id, type, equipment, description) VALUES
    ('Hip Thrust',                   7, 'compound',  'barbell',   'Empuje de cadera con barra — glúteo mayor'),
    ('Cable Kickback',               7, 'isolation', 'cable',     'Patada trasera en polea — glúteo medio y mayor'),
    ('Glute Bridge',                 7, 'isolation', 'bodyweight','Puente de glúteos en el suelo');

-- ABDOMEN
INSERT INTO exercise (name, muscle_group_id, type, equipment, description) VALUES
    ('Plank',                        8, 'isolation', 'bodyweight','Plancha isométrica — core completo'),
    ('Cable Crunch',                 8, 'isolation', 'cable',     'Crunch en polea — recto abdominal'),
    ('Hanging Leg Raise',            8, 'isolation', 'bodyweight','Elevación de piernas colgado — abdomen inferior');

-- PANTORRILLA
INSERT INTO exercise (name, muscle_group_id, type, equipment, description) VALUES
    ('Standing Calf Raise',          9, 'isolation', 'machine',   'Elevación de talones de pie — gastrocnemio'),
    ('Seated Calf Raise',            9, 'isolation', 'machine',   'Elevación de talones sentado — sóleo');

-- =============================================================================
-- 3. PROGRAMAS DE ENTRENAMIENTO (Jeff Nippard)
-- =============================================================================

-- Programa 1: Upper/Lower 4-Day
INSERT INTO program (name, description, days_per_week, author) VALUES
    ('Upper/Lower 4-Day', 'Split superior/inferior de 4 días por semana. Enfoque en fuerza e hipertrofia.', 4, 'Jeff Nippard');

-- Días del Upper/Lower 4-Day
INSERT INTO program_day (program_id, name, day_order, focus) VALUES
    (1, 'Upper A — Strength',      1, 'Superior — Fuerza (cargas altas, reps bajas)'),
    (1, 'Lower A — Strength',      2, 'Inferior — Fuerza (sentadilla y peso muerto)'),
    (1, 'Upper B — Hypertrophy',   3, 'Superior — Hipertrofia (volumen moderado)'),
    (1, 'Lower B — Hypertrophy',   4, 'Inferior — Hipertrofia (volumen y tiempo bajo tensión)');

-- Ejercicios Upper A (Fuerza)
INSERT INTO routine_exercise (program_day_id, exercise_id, sets_target, reps_target, rest_seconds, order_in_day) VALUES
    (1, (SELECT id FROM exercise WHERE name = 'Barbell Bench Press'),        4, '3-5',   180, 1),
    (1, (SELECT id FROM exercise WHERE name = 'Barbell Row'),                4, '3-5',   180, 2),
    (1, (SELECT id FROM exercise WHERE name = 'Overhead Press'),             3, '6-8',   120, 3),
    (1, (SELECT id FROM exercise WHERE name = 'Pull Up'),                    3, '6-8',   120, 4),
    (1, (SELECT id FROM exercise WHERE name = 'Incline Dumbbell Press'),     3, '8-12',  90,  5),
    (1, (SELECT id FROM exercise WHERE name = 'Face Pull'),                  3, '12-15', 60,  6);

-- Ejercicios Lower A (Fuerza)
INSERT INTO routine_exercise (program_day_id, exercise_id, sets_target, reps_target, rest_seconds, order_in_day) VALUES
    (2, (SELECT id FROM exercise WHERE name = 'Barbell Squat'),              4, '3-5',   240, 1),
    (2, (SELECT id FROM exercise WHERE name = 'Romanian Deadlift'),          3, '6-8',   180, 2),
    (2, (SELECT id FROM exercise WHERE name = 'Leg Press'),                  3, '8-12',  120, 3),
    (2, (SELECT id FROM exercise WHERE name = 'Leg Curl'),                   3, '10-12', 90,  4),
    (2, (SELECT id FROM exercise WHERE name = 'Standing Calf Raise'),        4, '10-15', 60,  5);

-- Ejercicios Upper B (Hipertrofia)
INSERT INTO routine_exercise (program_day_id, exercise_id, sets_target, reps_target, rest_seconds, order_in_day) VALUES
    (3, (SELECT id FROM exercise WHERE name = 'Incline Barbell Bench Press'), 4, '8-12',  90,  1),
    (3, (SELECT id FROM exercise WHERE name = 'Lat Pulldown'),                4, '8-12',  90,  2),
    (3, (SELECT id FROM exercise WHERE name = 'Dumbbell Shoulder Press'),     3, '10-12', 90,  3),
    (3, (SELECT id FROM exercise WHERE name = 'Seated Cable Row'),            3, '10-12', 90,  4),
    (3, (SELECT id FROM exercise WHERE name = 'Cable Fly'),                   3, '12-15', 60,  5),
    (3, (SELECT id FROM exercise WHERE name = 'Lateral Raise'),               4, '15-20', 45,  6),
    (3, (SELECT id FROM exercise WHERE name = 'Barbell Curl'),                3, '10-12', 60,  7),
    (3, (SELECT id FROM exercise WHERE name = 'Tricep Pushdown'),             3, '10-12', 60,  8);

-- Ejercicios Lower B (Hipertrofia)
INSERT INTO routine_exercise (program_day_id, exercise_id, sets_target, reps_target, rest_seconds, order_in_day) VALUES
    (4, (SELECT id FROM exercise WHERE name = 'Bulgarian Split Squat'),      4, '8-12',  120, 1),
    (4, (SELECT id FROM exercise WHERE name = 'Leg Press'),                  4, '10-15', 90,  2),
    (4, (SELECT id FROM exercise WHERE name = 'Leg Extension'),              3, '12-15', 60,  3),
    (4, (SELECT id FROM exercise WHERE name = 'Leg Curl'),                   3, '10-12', 60,  4),
    (4, (SELECT id FROM exercise WHERE name = 'Hip Thrust'),                 3, '10-12', 90,  5),
    (4, (SELECT id FROM exercise WHERE name = 'Seated Calf Raise'),          4, '12-15', 60,  6);

-- Programa 2: PPL 6-Day
INSERT INTO program (name, description, days_per_week, author) VALUES
    ('PPL 6-Day', 'Push/Pull/Legs 6 días por semana. Alta frecuencia y volumen para hipertrofia avanzada.', 6, 'Jeff Nippard');

-- Días del PPL 6-Day
INSERT INTO program_day (program_id, name, day_order, focus) VALUES
    (2, 'Push A — Strength',      1, 'Empuje con énfasis en fuerza (pecho, hombros, tríceps)'),
    (2, 'Pull A — Strength',      2, 'Tirón con énfasis en fuerza (espalda, bíceps)'),
    (2, 'Legs A — Strength',      3, 'Piernas con énfasis en fuerza (cuádriceps dominante)'),
    (2, 'Push B — Hypertrophy',   4, 'Empuje con énfasis en hipertrofia'),
    (2, 'Pull B — Hypertrophy',   5, 'Tirón con énfasis en hipertrofia'),
    (2, 'Legs B — Hypertrophy',   6, 'Piernas con énfasis en hipertrofia (isquiotibiales dominante)');

-- Programa 3: ULPPL 5-Day
INSERT INTO program (name, description, days_per_week, author) VALUES
    ('ULPPL 5-Day', 'Hybrid Upper/Lower + Push/Pull/Legs. 5 días por semana, balance entre fuerza e hipertrofia.', 5, 'Jeff Nippard');

-- Días del ULPPL 5-Day
INSERT INTO program_day (program_id, name, day_order, focus) VALUES
    (3, 'Upper — Strength',        1, 'Superior: press y remos pesados'),
    (3, 'Lower — Strength',        2, 'Inferior: sentadilla y peso muerto'),
    (3, 'Push — Hypertrophy',      3, 'Empuje: pecho, hombros, tríceps con volumen'),
    (3, 'Pull — Hypertrophy',      4, 'Tirón: espalda y bíceps con volumen'),
    (3, 'Legs — Hypertrophy',      5, 'Piernas: cuádriceps e isquiotibiales con volumen');

-- =============================================================================
-- Verificación del seed
-- =============================================================================
SELECT 'muscle_group'   AS tabla, COUNT(*) AS registros FROM muscle_group
UNION ALL
SELECT 'exercise',       COUNT(*) FROM exercise
UNION ALL
SELECT 'program',        COUNT(*) FROM program
UNION ALL
SELECT 'program_day',    COUNT(*) FROM program_day
UNION ALL
SELECT 'routine_exercise', COUNT(*) FROM routine_exercise
ORDER BY tabla;
