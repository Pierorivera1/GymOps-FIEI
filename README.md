# GymOps 🏋️

> Una herramienta de seguimiento de entrenamiento para la terminal — y proyecto final de Base de Datos II en FIEI.

GymOps es una herramienta CLI que vive en tu terminal. Configuras tu split de entrenamiento, eliges el día de hoy y registras tus series. Lleva el seguimiento de tus récords personales, te indica si realmente estás progresando, y genera un resumen semanal de tu actividad.

Inspirado en [lazygit](https://github.com/jesseduffield/lazygit) — la idea de que una buena herramienta de terminal no debe estorbarte, funcionar localmente y simplemente hacer su trabajo.

---

## Características

- **Backend PostgreSQL**: Base de datos relacional completa con procedimientos almacenados, vistas, triggers e índices.
- **Splits preconfigurados**: Viene precargado con los splits clásicos de Jeff Nippard (Upper/Lower 4 días, ULPPL 5 días, PPL 6 días).
- **1RM estimado**: Calcula el máximo estimado de una repetición usando la fórmula de Epley después de cada serie.
- **Estadísticas de sobrecarga progresiva**: Compara el rendimiento de hoy contra tu última sesión.
- **Seguimiento de PRs**: Actualiza automáticamente tus récords personales y los marca cuando se superan.
- **Resúmenes semanales**: Genera resúmenes en Markdown del volumen semanal de entrenamiento y mejores levantamientos.
- **CLI bilingüe**: Cambia entre inglés y español con `gymops set-language`.
- **Interfaz TUI (Próximamente)**: Una interfaz de terminal al estilo lazygit para registrar series y ver PRs visualmente.

---

## Inicio rápido

### Requisitos previos
- Python 3.12+
- [uv](https://github.com/astral-sh/uv)
- Docker (para PostgreSQL)

### Configuración

```bash
# Clonar el repositorio
git clone https://github.com/Pierorivera1/GymOps-FIEI.git
cd GymOps-FIEI

# Iniciar PostgreSQL con Docker
docker run --name gymops-db -e POSTGRES_USER=gymops \
  -e POSTGRES_PASSWORD=gymops_pass \
  -e POSTGRES_DB=gymops_db \
  -p 5432:5432 -d postgres:16

# Crear entorno virtual e instalar dependencias
uv venv
source .venv/bin/activate
uv pip install -e .

# Inicializar la base de datos (ejecutar los scripts SQL en orden)
psql -h localhost -U gymops -d gymops_db -f proyecto_bdII/sql/01_ddl.sql
psql -h localhost -U gymops -d gymops_db -f proyecto_bdII/sql/02_seed.sql

# Verificar que funciona
gymops --help
```

---

## Uso

```bash
# Establecer el idioma preferido (en / es)
gymops set-language es

# 1. Listar todos los programas de entrenamiento disponibles
gymops list-programs

# 2. Seleccionar el programa activo que sigues
gymops select-program "Upper/Lower 4-Day"

# 3. Establecer el día de entrenamiento de hoy (hacerlo al inicio del entrenamiento)
gymops set-day "Upper A — Strength"

# 4. Registrar tus series mientras las realizas
gymops log --exercise "Barbell Bench Press" --sets 4 --reps 5 --weight 80

# 5. Revisar la sobrecarga progresiva vs la última sesión
gymops stats --exercise "Barbell Bench Press"

# 6. Ver tus récords personales
gymops prs

# 7. Ver el historial de un ejercicio
gymops history --exercise "Barbell Bench Press"

# 8. Agregar un ejercicio al catálogo
gymops add-exercise --name "Dumbbell Lateral Raise" --muscle-group "Shoulders" --type isolation

# 9. Crear un programa de entrenamiento personalizado
gymops add-program

# 10. Generar un resumen semanal en Markdown
gymops digest
```

---

## Base de datos

GymOps corre sobre **PostgreSQL 16** (Docker). El esquema incluye:

| Objeto | Cantidad | Descripción |
|--------|----------|-------------|
| Tablas | 9 | Esquema relacional principal (3FN) |
| Vistas | 9 | Reportes, seguridad y seguimiento de progreso |
| Índices | 15 | Índices B-tree, parciales y de expresión |
| Procedimientos almacenados | — | Próximamente en la Fase 5 |
| Funciones (UDF) | — | Próximamente en la Fase 6 |
| Triggers | — | Próximamente en la Fase 7 |

### Scripts SQL (`proyecto_bdII/sql/`)

| Script | Propósito |
|--------|-----------|
| `01_ddl.sql` | Esquema: tablas, PKs, FKs, CHECKs |
| `02_seed.sql` | Datos iniciales: músculos, 51 ejercicios, 3 programas |
| `03_dml.sql` | DML: sesiones, series, ejemplos de UPDATE/DELETE |
| `04_queries.sql` | 10 consultas avanzadas (CTE, funciones de ventana) |
| `05_views.sql` | 9 vistas para reportes y seguridad |
| `06_indexes.sql` | 15 índices + planes EXPLAIN ANALYZE |

### Conexión

```
Host:     localhost
Puerto:   5432
Base de datos: gymops_db
Usuario:  gymops
Contraseña: gymops_pass
```

---

## Estructura del proyecto

```
GymOps-FIEI/
├── gymops/
│   ├── cli.py          # Todos los comandos Typer del CLI
│   ├── db.py           # Capa de base de datos (migración SQLite → PostgreSQL)
│   ├── i18n.py         # Internacionalización (en / es)
│   ├── models.py       # Dataclasses: Workout, Exercise, PR, Routine
│   └── report.py       # Generador de resúmenes semanales
├── proyecto_bdII/
│   ├── DESCRIPCION_PROYECTO.md   # Descripción completa del proyecto (BD II)
│   ├── PLANNING.md               # Seguimiento de fases y plan de implementación
│   └── sql/                      # Todos los scripts SQL (fases 1–7)
└── tests/              # Suite de pruebas con pytest
```

---

## Desarrollo y pruebas

```bash
# Instalar requisitos de prueba
uv pip install pytest

# Ejecutar pruebas
uv run pytest
```

---

## BD II — Proyecto de curso

Este repositorio también funciona como **proyecto final de Base de Datos II** en FIEI/UNI.
Consulta [`proyecto_bdII/PLANNING.md`](proyecto_bdII/PLANNING.md) para el roadmap completo de implementación
y [`proyecto_bdII/DESCRIPCION_PROYECTO.md`](proyecto_bdII/DESCRIPCION_PROYECTO.md) para la descripción del proyecto.

**Stack**: PostgreSQL 16 · Python 3.12 · Docker · Typer · Rich
