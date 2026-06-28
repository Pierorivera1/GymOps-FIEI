# GymOps — Planning del Proyecto Final BD II
### Base de Datos II — Universidad Nacional Federico Villarreal (UNFV)
**Autor:** Piero Rivera  
**Gestor:** PostgreSQL 16 (Docker)  
**Estado:** 🟢 SQL Completo (Fases 1–7 finalizadas)

---

## ⚠️ Nota sobre Alcance

De acuerdo con el formato oficial del proyecto (`Formato_Proyecto_Final_Base_Datos_II.pdf`), el **Punto 4 — Administración y Seguridad** queda **excluido de esta versión** del proyecto. Esto incluye:

- ❌ Gestión de usuarios y roles de BD
- ❌ Permisos granulares (GRANT/REVOKE)
- ❌ Configuración de backups automáticos
- ❌ Políticas de recuperación ante desastres

Todo lo demás del formato sí está contemplado y se detalla a continuación.

---

## 📋 Secciones del Formato → Estado

| Sección del Formato | Equivalente en GymOps | Estado |
|--------------------|-----------------------|--------|
| 2.1 Análisis y propuesta | `DESCRIPCION_PROYECTO.md` | ✅ Completo |
| 2.2 Modelamiento de procesos | Diagramas BPMN, flujo, casos de uso | ✅ Completo |
| 2.3 Requerimientos funcionales/no funcionales | Listado en PLANNING (ver §3) | ✅ Completo |
| 2.4 Modelo de BD | Conceptual, lógico, físico | ✅ Completo |
| 2.5 Script de implementación | `sql/01_ddl.sql`, `sql/02_seed.sql` | ✅ Completo |
| 3.1 Manipulación de datos | `sql/03_dml.sql` | ✅ Completo |
| 3.2 Consultas avanzadas | `sql/04_queries.sql` | ✅ Completo |
| 3.3 Vistas | `sql/05_views.sql` | ✅ Completo |
| 3.4 Índices | `sql/06_indexes.sql` | ✅ Completo |
| 3.5 Procedimientos almacenados | `sql/07_procedures.sql` | ✅ Completo |
| 3.6 Funciones UDF | `sql/08_functions.sql` | ✅ Completo |
| 3.7 Triggers | `sql/09_triggers.sql` | ✅ Completo |
| ~~4. Administración y Seguridad~~ | ~~Excluido de esta versión~~ | ❌ Excluido |
| 5. Aplicación | CLI Python con psycopg2 | ✅ Completo |
| 6. Entregables | Documentación, scripts, código fuente | 🟡 En progreso |

---

## 🗂️ Estructura de Carpetas Planeada

```
proyecto_bdII/
├── PLANNING.md                 ← Este archivo
├── DESCRIPCION_PROYECTO.md     ← Análisis y descripción (§2.1)
├── diagramas/
│   ├── modelo_conceptual.png   ← Diagrama ER conceptual
│   ├── modelo_logico.png       ← Diagrama lógico (relacional)
│   ├── bpmn_sesion.png         ← BPMN: proceso de sesión de entrenamiento
│   ├── bpmn_pr.png             ← BPMN: proceso de actualización de PR
│   ├── diagrama_flujo.png      ← Flujo general del sistema
│   ├── casos_de_uso.png        ← Diagrama de casos de uso
│   └── diagrama_actividades.png
├── sql/
│   ├── 01_ddl.sql              ← CREATE DATABASE, tablas, constraints
│   ├── 02_seed.sql             ← Datos iniciales (splits recomendados por su efectividad, ejercicios)
│   ├── 03_dml.sql              ← INSERT/UPDATE/DELETE de ejemplo + validaciones
│   ├── 04_queries.sql          ← Consultas avanzadas (JOINs, CTEs, CASE, HAVING)
│   ├── 05_views.sql            ← Vistas de reporte y seguridad
│   ├── 06_indexes.sql          ← Índices y análisis de planes de ejecución
│   ├── 07_procedures.sql       ← Procedimientos almacenados (PL/pgSQL)
│   ├── 08_functions.sql        ← Funciones escalares y tipo tabla
│   └── 09_triggers.sql         ← Triggers de auditoría y validación
└── docs/
    ├── requerimientos.md       ← RF y RNF detallados
    └── manual_usuario.md       ← Manual básico de uso
```

---

## 📝 Cambios Respecto al Formato Original

### ✅ Lo que SÍ se mantiene del formato
Todos los puntos del **1 al 3** y del **5 al 7** del formato:

- **§2.1** — Análisis completo: problemática, objetivos, alcance, procesos, entidades, reglas de negocio, justificación tecnológica → `DESCRIPCION_PROYECTO.md`
- **§2.2** — Modelamiento: BPMN (proceso de sesión, proceso de PR), diagrama de flujo, casos de uso, diagrama de actividades → carpeta `diagramas/`
- **§2.3** — Requerimientos funcionales y no funcionales (ver §3 de este documento)
- **§2.4** — Modelos conceptual, lógico y físico (PostgreSQL como gestor aprobado) → `diagramas/`
- **§2.5** — Scripts DDL completos con tablas, constraints, índices, vistas, SPs, funciones y triggers → carpeta `sql/`
- **§3.1 al §3.7** — Toda la implementación SQL avanzada requerida → archivos `sql/03` al `sql/09`
- **§5** — Aplicación CLI en Python con psycopg2 conectada a PostgreSQL
- **§6** — Todos los entregables: documento, scripts SQL, código fuente, diagramas, manual

### ❌ Lo que se EXCLUYE en esta versión
**§4 — Administración y Seguridad:**
- Gestión de usuarios y roles de BD (CREATE USER, GRANT)
- Permisos y seguridad a nivel de BD
- Estrategia de backups y recuperación
- Control de transacciones (nota: las transacciones SÍ se implementan dentro de los SPs)

> **Justificación:** Esta sección será incorporada en una fase posterior del proyecto una vez que los módulos core estén funcionando correctamente.

---

## 3. Requerimientos Funcionales y No Funcionales

### Requerimientos Funcionales (RF)

| ID | Requerimiento |
|----|--------------|
| RF-01 | El sistema debe permitir registrar ejercicios con nombre, grupo muscular, tipo y equipamiento |
| RF-02 | El sistema debe permitir crear y gestionar programas de entrenamiento con días y ejercicios asignados |
| RF-03 | El sistema debe permitir iniciar y cerrar sesiones de entrenamiento |
| RF-04 | El sistema debe permitir registrar sets (ejercicio, series, reps, peso) dentro de una sesión |
| RF-05 | El sistema debe calcular automáticamente el 1RM estimado por cada set registrado |
| RF-06 | El sistema debe detectar y registrar récords personales (PR) automáticamente |
| RF-07 | El sistema debe mostrar estadísticas de progreso comparando sesiones pasadas vs actuales |
| RF-08 | El sistema debe generar reportes semanales de volumen y mejores levantamientos |
| RF-09 | El sistema debe permitir consultar el historial de cualquier ejercicio |
| RF-10 | El sistema debe registrar un log de auditoría de cambios en sets y PRs |

### Requerimientos No Funcionales (RNF)

| ID | Requerimiento |
|----|--------------|
| RNF-01 | **Rendimiento:** Las consultas frecuentes (historial, PRs) deben ejecutarse en < 100ms con índices apropiados |
| RNF-02 | **Integridad:** Todas las relaciones entre tablas deben tener FK con ON DELETE apropiado |
| RNF-03 | **Disponibilidad:** La BD debe ejecutarse en Docker y estar disponible localmente en todo momento |
| RNF-04 | **Usabilidad:** La CLI debe mostrar salida formateada (Rich tables) para todas las consultas |
| RNF-05 | **Mantenibilidad:** Todo el código SQL debe estar comentado y organizado por archivo temático |
| RNF-06 | **Portabilidad:** Los scripts SQL deben ser compatibles con PostgreSQL 14+ |
| RNF-07 | **Trazabilidad:** Todo cambio sobre `workout_set` y `personal_record` debe quedar registrado en `audit_log` |

---

## 4. Plan de Implementación SQL

### Fase 1 — DDL y Datos (sql/01 y 02)
**Objetivo:** Crear toda la estructura de la BD y poblarla con datos iniciales.

**Tablas a crear:**
```sql
-- Catálogo
muscle_group (id, name, description)
exercise (id, name, muscle_group_id, type, equipment, description)

-- Programas
program (id, name, description, days_per_week)
program_day (id, program_id, name, day_order)
routine_exercise (id, program_day_id, exercise_id, sets_target, reps_target, notes)

-- Sesiones y Sets
workout_session (id, program_day_id, started_at, ended_at, notes)
workout_set (id, session_id, exercise_id, set_number, reps, weight_kg,
             estimated_1rm, volume, is_pr, logged_at)

-- PRs y Auditoría
personal_record (id, exercise_id, max_1rm, achieved_at, set_id)
audit_log (id, table_name, operation, old_data, new_data, changed_at)
```

**Datos seed:**
- 10+ grupos musculares
- 50+ ejercicios del catálogo base
- 3 programas recomendados (Upper/Lower 4-Day, ULPPL 5-Day, PPL 6-Day) con todos sus días y ejercicios

### Fase 2 — DML y Consultas (sql/03 y 04)
**Objetivo:** Demostrar operaciones de manipulación y consultas avanzadas.

**DML (03):**
- INSERTs parametrizados para nuevas sesiones y sets
- UPDATEs de rutinas y ejercicios
- DELETEs con validación de integridad
- Filtros y validaciones

**Consultas Avanzadas (04):**

| Consulta | Técnica SQL |
|----------|------------|
| Top 5 ejercicios por volumen semanal | GROUP BY + SUM + HAVING |
| Progresión de 1RM por ejercicio en últimas 8 semanas | CTE + window function LAG() |
| Comparar carga actual vs última sesión por ejercicio | Self JOIN + CASE |
| Ejercicios sin sesión en los últimos 14 días | LEFT JOIN + IS NULL |
| Ranking de PRs por grupo muscular | CTE + RANK() |
| Distribución de volumen por día de la semana | EXTRACT + GROUP BY + CASE |

### Fase 3 — Vistas (sql/05)

| Vista | Propósito |
|-------|-----------|
| `v_session_summary` | Resumen de sesión: ejercicios, volumen total, duración |
| `v_weekly_digest` | Resumen semanal: volumen por músculo, PRs logrados |
| `v_exercise_progress` | Progresión de 1RM por ejercicio a lo largo del tiempo |
| `v_current_prs` | Vista actualizable con PRs actuales por ejercicio |
| `v_workout_history` | Historial completo de sets con datos de ejercicio y sesión |
| `v_muscle_volume_week` | Volumen semanal por grupo muscular |

### Fase 4 — Índices (sql/06)

| Índice | Columnas | Justificación |
|--------|----------|--------------|
| `idx_set_session` | `workout_set(session_id)` | Consultas de historial de sesión |
| `idx_set_exercise` | `workout_set(exercise_id, logged_at)` | Historial por ejercicio cronológico |
| `idx_set_logged_at` | `workout_set(logged_at DESC)` | Ordenamiento por fecha descendente |
| `idx_pr_exercise` | `personal_record(exercise_id)` | Lookup de PR por ejercicio |
| `idx_session_started` | `workout_session(started_at DESC)` | Consultas de sesiones recientes |
| `idx_audit_table_op` | `audit_log(table_name, operation, changed_at)` | Auditoría por tabla/operación |

### Fase 5 — Procedimientos Almacenados (sql/07)

| Procedimiento | Descripción |
|--------------|-------------|
| `sp_start_session(program_day_id)` | Crea una nueva `workout_session` y retorna su ID |
| `sp_log_set(session_id, exercise_id, reps, weight)` | Registra set, calcula 1RM, detecta PR, actualiza audit_log |
| `sp_close_session(session_id)` | Cierra la sesión registrando `ended_at` |
| `sp_get_exercise_stats(exercise_id)` | Retorna estadísticas completas de un ejercicio |
| `sp_weekly_digest(week_date)` | Genera resumen semanal del entrenamiento |

### Fase 6 — Funciones UDF (sql/08)

| Función | Tipo | Descripción |
|---------|------|-------------|
| `fn_epley_1rm(weight, reps)` | Escalar | Calcula 1RM: `weight * (1 + reps/30.0)` |
| `fn_volume(weight, reps)` | Escalar | Calcula volumen: `weight * reps` |
| `fn_is_pr(exercise_id, new_1rm)` | Escalar | Retorna TRUE si `new_1rm` supera el PR actual |
| `fn_session_volume(session_id)` | Escalar | Volumen total de una sesión |
| `fn_exercise_history(exercise_id, n_sessions)` | Tipo tabla | Retorna historial de las últimas N sesiones del ejercicio |
| `fn_weekly_volume(week_start)` | Tipo tabla | Volumen por músculo para la semana indicada |

### Fase 7 — Triggers (sql/09)

| Trigger | Evento | Acción |
|---------|--------|--------|
| `trg_calculate_1rm` | AFTER INSERT ON `workout_set` | Calcula y actualiza `estimated_1rm` y `volume` |
| `trg_update_pr` | AFTER INSERT/UPDATE ON `workout_set` | Detecta PR y actualiza `personal_record`, setea `is_pr=TRUE` |
| `trg_audit_set` | AFTER INSERT/UPDATE/DELETE ON `workout_set` | Inserta registro en `audit_log` con OLD/NEW data |
| `trg_audit_pr` | AFTER UPDATE ON `personal_record` | Registra cambio de PR en `audit_log` |
| `trg_validate_set` | BEFORE INSERT ON `workout_set` | Valida peso > 0 y reps > 0, raise exception si no |
| `trg_prevent_closed_session` | BEFORE INSERT ON `workout_set` | Impide agregar sets a sesiones ya cerradas |

---

## 5. Entregables Finales

| Entregable | Archivo/Ubicación | Estado |
|-----------|------------------|--------|
| Documento del proyecto | `DESCRIPCION_PROYECTO.md` | ✅ |
| Planning | `PLANNING.md` (este archivo) | ✅ |
| Diagramas | `diagramas/` | ✅ |
| Scripts SQL (DDL a Triggers) | `sql/01` al `sql/09` | ✅ |
| Código fuente app | `gymops/` (root del repo) | ✅ |
| Manual básico | `docs/manual_usuario.md` | 🔲 |
| Backup de BD | `backup/gymops_backup.sql` | 🔲 |

---

## 6. Cronograma Tentativo

| Semana | Actividades |
|--------|------------|
| S1 | DDL completo + seed data + modelo físico en PostgreSQL Docker |
| S2 | DML + consultas avanzadas + vistas |
| S3 | Índices + procedimientos almacenados + funciones UDF |
| S4 | Triggers + auditoría + pruebas de integración |
| S5 | Migración de app Python (SQLite → psycopg2) + testing |
| S6 | Diagramas + documentación final + manual de usuario |

---

*Última actualización: Junio 2026 — Este planning se actualizará conforme avance el proyecto.*
