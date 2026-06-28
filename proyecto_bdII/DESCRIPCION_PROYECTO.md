# GymOps — Descripción del Proyecto Final
### Base de Datos II — Universidad Nacional Federico Villarreal (UNFV)
**Autor:** Piero Rivera  
**Gestor de BD:** PostgreSQL (Docker)  
**Versión:** 1.0 — Fase inicial (sin módulo de Administración y Seguridad)

---

## 1. Presentación General del Proyecto

### 1.1 Descripción de la Problemática

El seguimiento del entrenamiento físico es una tarea que la mayoría de atletas aficionados y naturales realiza de manera informal: anotaciones en el celular, cuadernos o simplemente memoria. Este enfoque genera inconsistencias en el registro, pérdida de historial, imposibilidad de analizar tendencias de progreso y falta de motivación al no poder visualizar mejoras a lo largo del tiempo.

**GymOps** nace como respuesta a esta problemática. Es un sistema de seguimiento de entrenamientos basado en terminal (CLI) que permite al usuario registrar sus sesiones de entrenamiento, controlar su historial de cargas, detectar récords personales (PR) y generar resúmenes semanales — todo desde la línea de comandos, sin depender de aplicaciones en la nube.

Para el proyecto de Base de Datos II, GymOps utiliza una base de datos relacional robusta en **PostgreSQL**, incorporando todas las capacidades avanzadas de SQL requeridas por el curso.

---

### 1.2 Objetivos del Sistema

**Objetivo General:**  
Implementar una base de datos relacional en PostgreSQL que soporte el sistema GymOps, permitiendo el registro, consulta y análisis de entrenamientos físicos mediante el uso de todas las herramientas avanzadas de SQL.

**Objetivos Específicos:**
- Diseñar e implementar un modelo relacional normalizado (3FN) que represente las entidades del dominio del entrenamiento físico.
- Implementar procedimientos almacenados que automaticen el cálculo de 1RM estimado (fórmula Epley), detección de PRs y control de sobrecarga progresiva.
- Crear vistas para reportes de rendimiento por ejercicio, músculo y programa de entrenamiento.
- Implementar triggers para auditoría de cambios y validaciones automáticas de negocio.
- Crear funciones definidas por el usuario (escalares y tipo tabla) para cálculos reutilizables.
- Optimizar consultas frecuentes mediante índices estratégicos.

---

### 1.3 Alcance del Proyecto

**Incluido en esta versión:**
- Módulo de Gestión de Ejercicios (catálogo por músculo y tipo)
- Módulo de Programas de Entrenamiento (splits, días, rutinas predefinidas)
- Módulo de Sesiones de Entrenamiento (log de sets por sesión)
- Módulo de Análisis de Progreso (1RM estimado, sobrecarga progresiva, PRs)
- Módulo de Reportes (resúmenes semanales, estadísticas por ejercicio)
- Implementación SQL completa: DDL, DML, vistas, índices, SPs, funciones, triggers

**Fuera de alcance en esta versión:**
- Módulo de Administración y Seguridad (gestión de usuarios/roles, backups automatizados)
- Interfaz web o móvil (la aplicación es estrictamente CLI)
- Sincronización en la nube

---

### 1.4 Descripción de Procesos Principales

| # | Proceso | Descripción |
|---|---------|-------------|
| P1 | Gestión de Catálogo | El usuario puede agregar, modificar y consultar ejercicios del catálogo por grupo muscular, tipo (compuesto/aislamiento) y equipamiento. |
| P2 | Gestión de Programas | Creación y selección de programas de entrenamiento (splits) con sus días y ejercicios asignados. Pre-cargados: Upper/Lower, PPL, ULPPL (splits recomendados por su efectividad). |
| P3 | Registro de Sesión | Al iniciar entrenamiento se crea una sesión. El usuario registra series (sets), repeticiones y peso por ejercicio. |
| P4 | Cálculo de 1RM | Por cada set registrado, el sistema calcula automáticamente el 1RM estimado usando la **fórmula de Epley**: `1RM = peso × (1 + reps/30)`. |
| P5 | Control de PR | El sistema compara el 1RM estimado actual contra el histórico y actualiza el récord personal si corresponde. |
| P6 | Análisis de Sobrecarga | Al consultar estadísticas, el sistema compara el volumen/carga de la sesión actual vs la última sesión del mismo día. |
| P7 | Generación de Reportes | El sistema genera resúmenes semanales con volumen total, mejores lifts y progresión por ejercicio. |

---

### 1.5 Identificación de Entidades Principales

| Entidad | Descripción |
|---------|-------------|
| `muscle_group` | Grupos musculares (pecho, espalda, piernas, hombros, etc.) |
| `exercise` | Catálogo maestro de ejercicios (nombre, músculo, tipo, equipamiento) |
| `program` | Programa de entrenamiento (ej: "Upper/Lower 4-Day") |
| `program_day` | Día dentro de un programa (ej: "Upper A — Strength") |
| `routine_exercise` | Ejercicios asignados a un día de programa (con series y reps objetivo) |
| `workout_session` | Sesión de entrenamiento realizada (fecha, usuario, programa y día) |
| `workout_set` | Set individual registrado (ejercicio, reps, peso, 1RM calculado) |
| `personal_record` | Récord personal por ejercicio (máximo 1RM histórico) |
| `audit_log` | Registro de auditoría de cambios en sets y PRs |

---

### 1.6 Reglas de Negocio Relevantes

1. **RN-01:** Un `workout_set` debe estar asociado obligatoriamente a una `workout_session` activa.
2. **RN-02:** El 1RM estimado se calcula automáticamente al insertar un `workout_set` (trigger AFTER INSERT).
3. **RN-03:** Un PR se actualiza solo si el nuevo 1RM supera el 1RM registrado en `personal_record` para ese ejercicio.
4. **RN-04:** No se pueden registrar sets con peso ≤ 0 o repeticiones ≤ 0 (CHECK constraint).
5. **RN-05:** Un `program_day` pertenece a un único `program`.
6. **RN-06:** La `workout_session` registra la fecha y hora de inicio; la de fin se actualiza al cerrar la sesión.
7. **RN-07:** El campo `is_pr` en `workout_set` se establece en `TRUE` automáticamente si el set rompe el PR actual.
8. **RN-08:** El volumen de un set = `peso × reps` (campo calculado o función).

---

### 1.7 Justificación Tecnológica

| Tecnología | Justificación |
|-----------|--------------|
| **PostgreSQL** | SGBD relacional open-source de clase enterprise. Soporta PL/pgSQL, triggers, CTE, funciones de ventana, índices parciales y todas las características requeridas por el curso. |
| **Docker** | Permite levantar PostgreSQL de forma reproducible y aislada, sin instalación directa. Facilita el despliegue consistente del entorno. |
| **Python + Typer + Rich** | Stack de la aplicación CLI. Se conecta a PostgreSQL vía `psycopg2`. Demuestra integración real entre app y BD. |
| **PostgreSQL Nativo** | El diseño del sistema en PostgreSQL aprovecha características enterprise avanzadas (procedimientos almacenados, triggers complejos, vistas y funciones) para asegurar la integridad, consistencia y el rendimiento de la base de datos. |

---

## 2. Módulos del Sistema

### 2.1 Módulo de Ejercicios
CRUD sobre el catálogo maestro de ejercicios. Clasificación por grupo muscular, tipo de movimiento (compuesto/aislamiento) y equipamiento requerido.

### 2.2 Módulo de Programas
Gestión de programas de entrenamiento y rutinas diarias. Incluye programas pre-cargados (splits conocidos y recomendados por su efectividad) y permite creación de programas personalizados.

### 2.3 Módulo de Sesiones
Núcleo del sistema. Registro de entrenamientos en tiempo real: creación de sesión, log de sets y cierre de sesión.

### 2.4 Módulo de Análisis y PRs
Motor analítico. Calcula 1RM estimado (Epley), detecta PRs, y analiza sobrecarga progresiva comparando sesiones. Interactúa con triggers y funciones de la BD.

### 2.5 Módulo de Reportes
Generación de resúmenes en formato Markdown/texto. Consulta vistas pre-definidas en la BD para informes de entrenamiento semanal.

---

## 3. Entorno Tecnológico

```
Sistema Operativo:    Linux (Ubuntu)
Gestor de BD:         PostgreSQL 16 (Docker)
Lenguaje App:         Python 3.12
Conector BD:          psycopg2 (SQL directo, sin ORM)
Gestor de paquetes:   uv
CLI Framework:        Typer
UI de terminal:       Rich (salida formateada y colores)
Control de versiones: Git + GitHub
```

---

## 4. Diagrama de Entidades (Preliminar)

```
muscle_group ──< exercise >── routine_exercise ──> program_day ──> program
                    │
                    ▼
              workout_set ──> workout_session
                    │
                    ▼
              personal_record
                    │
                    ▼
               audit_log
```

---

*Documento sujeto a actualizaciones conforme avance el desarrollo del proyecto.*
