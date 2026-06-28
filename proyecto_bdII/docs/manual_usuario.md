# Manual de Usuario — GymOps 🏋️

Bienvenido a **GymOps**, tu gestor de entrenamientos personal en la terminal. Este proyecto final para el curso de **Base de Datos II (FIEI/UNI)** combina una aplicación CLI rápida y elegante desarrollada en Python con una potente base de datos relacional en **PostgreSQL 16**.

GymOps está diseñado especialmente para **personas sin experiencia previa en el gimnasio**. Olvídate de planificar complejas rutinas o cargar pesadas aplicaciones llenas de publicidad: GymOps viene precargado con rutinas científicas diseñadas por expertos (como Jeff Nippard) para que solo tengas que llegar al gimnasio, seleccionar tu rutina y empezar a registrar. Asimismo, si eres un atleta intermedio o avanzado, el sistema te permite diseñar tus propios programas de entrenamiento personalizados.

---

## 1. Requisitos Previos e Instalación

Para ejecutar GymOps localmente, necesitas tener instalado:
* **Python 3.12+**
* **Docker** y Docker Compose
* **uv** (el gestor rápido de entornos y paquetes de Python)

### Paso 1: Levantar PostgreSQL en Docker
Ejecuta el siguiente comando para levantar el servidor de base de datos PostgreSQL 16 de manera aislada y reproducible:

```bash
docker run --name gymops-db \
  -e POSTGRES_USER=gymops \
  -e POSTGRES_PASSWORD=gymops_pass \
  -e POSTGRES_DB=gymops_db \
  -p 5432:5432 \
  -d postgres:16
```

### Paso 2: Clonar e instalar la aplicación CLI
Clona el repositorio e instala el proyecto en modo editable usando `uv`:

```bash
# Clonar
git clone https://github.com/Pierorivera1/GymOps-FIEI.git
cd GymOps-FIEI

# Crear entorno virtual e instalar dependencias
uv venv
source .venv/bin/activate
uv pip install -e .
```

### Paso 3: Inicializar la Base de Datos
Ejecuta los scripts SQL principales en orden utilizando el cliente `psql`. Esto creará el esquema y poblará la base de datos con los datos iniciales (splits de Jeff Nippard y catálogo de ejercicios):

```bash
psql -h localhost -U gymops -d gymops_db -f proyecto_bdII/sql/01_ddl.sql
psql -h localhost -U gymops -d gymops_db -f proyecto_bdII/sql/02_seed.sql
```
*(Nota: Al invocar cualquier comando de GymOps por primera vez, el sistema ejecutará automáticamente las vistas, índices, procedimientos, funciones y triggers restantes de forma transparente).*

---

## 2. Flujo de Uso Paso a Paso (Para Principiantes)

Si eres nuevo en el gimnasio, sigue esta guía simple para empezar tu entrenamiento:

### Paso 2.1: Establece el idioma en español
GymOps es bilingüe. Configúralo en español para ver todas las guías y tablas traducidas:
```bash
gymops set-language es
```

### Paso 2.2: Explora las rutinas predefinidas
Visualiza los programas de entrenamiento disponibles para ver cuál se adapta mejor a tu disponibilidad semanal:
```bash
gymops list-programs
```
Verás rutinas listas de Jeff Nippard, tales como:
* `Upper/Lower 4-Day` (Torso/Pierna - 4 días a la semana)
* `ULPPL 5-Day` (Torso/Pierna/Empuje/Tirón/Pierna - 5 días a la semana)
* `PPL 6-Day` (Empuje/Tirón/Pierna - 6 días a la semana)

### Paso 2.3: Elige tu programa activo
Selecciona la rutina que planeas seguir (por ejemplo, el split de Torso/Pierna de 4 días):
```bash
gymops select-program "Upper/Lower 4-Day"
```

### Paso 2.4: Al llegar al gimnasio: Elige el día de hoy
Al iniciar tu sesión de entrenamiento, dile a la aplicación qué día vas a entrenar hoy. Esto activará los ejercicios sugeridos y las repeticiones objetivo para el día:
```bash
gymops set-day "Upper A — Strength"
```

### Paso 2.5: Registra tus series de entrenamiento (sets)
Durante o después de cada ejercicio, registra el número de series, repeticiones y peso levantado. Por ejemplo, si hiciste 4 series de Press de Banca con barra con 80 kg:
```bash
gymops log --exercise "Barbell Bench Press" --sets 4 --reps 5 --weight 80
```
**¿Qué ocurre en la base de datos bajo el capó?**
1. Se inicia una sesión de entrenamiento activa en la tabla `workout_session` si no existía.
2. Un trigger `BEFORE INSERT` valida que el peso y repeticiones sean mayores a 0.
3. Un trigger `AFTER INSERT` calcula tu **1RM estimado** (Repetición Máxima Estimada) usando la **Fórmula de Epley** (`1RM = peso * (1 + reps/30)`) y calcula el volumen de entrenamiento de cada serie.
4. El motor SQL detecta automáticamente si has roto tu récord personal (PR) histórico en ese ejercicio y actualiza la tabla `personal_record` en tiempo real.
5. Se escribe automáticamente un registro en la tabla de auditoría `audit_log`.

---

## 3. Comandos de Consulta y Análisis de Progreso

### 3.1. Récords Personales (PRs)
Visualiza tus mejores marcas históricas ordenadas por ejercicio:
```bash
gymops prs
```
Muestra una tabla ordenada con el peso máximo levantado, el 1RM estimado y la fecha exacta en la que lograste tu marca.

### 3.2. Historial de un Ejercicio
Consulta todo tu historial registrado para un ejercicio en específico para saber qué peso cargaste en semanas anteriores:
```bash
gymops history --exercise "Barbell Bench Press"
```

### 3.3. Estadísticas de Sobrecarga Progresiva
Compara tu sesión de hoy directamente contra la sesión anterior para evaluar si has logrado progresar (hacerte más fuerte, sacar más repeticiones o cargar más peso):
```bash
gymops stats --exercise "Barbell Bench Press"
```
**Posibles resultados:**
* 🟢 **Progreso:** Muestra el incremento en tu fuerza estimada con un porcentaje (ej. `+5.00% ▲`).
* 🟡 **Meseta:** Te indica que tu 1RM estimado se mantuvo igual y te sugiere añadir 1-2.5 kg o subir repeticiones.
* 🔴 **Descanso necesario:** Si tu fuerza disminuyó, te recuerda que la fatiga acumulada es normal y te recomienda cuidar el sueño, descanso y nutrición.

### 3.4. Resumen Semanal de Progreso (Digest)
Genera un reporte completo de tu última semana de entrenamientos en formato Markdown:
```bash
gymops digest
```
Esto crea un archivo `digest_YYYY-MM-DD.md` que incluye un desglose de series totales completadas, ejercicios entrenados, volumen total acumulado y PRs rotos durante la semana. Utiliza la vista integrada `v_workout_history` para procesar la información en la base de datos de manera óptima.

---

## 4. Gestión Avanzada: Crear Rutinas y Ejercicios Propios

Si prefieres personalizar tu entrenamiento, GymOps te proporciona herramientas flexibles:

### 4.1. Agregar Ejercicios al Catálogo
Si deseas registrar un ejercicio que no viene en el catálogo base:
```bash
gymops add-exercise --name "Dumbbell Incline Bench Press" --muscle-group "Chest" --type compound
```

### 4.2. Asistente Interactivo de Programas
Crea un programa de entrenamiento a tu medida ejecutando:
```bash
gymops add-program
```
El asistente interactivo te guiará paso a paso en la terminal para:
1. Definir el nombre del programa.
2. Crear cada día de entrenamiento (ej: "Día de Empuje", "Día de Jalón").
3. Asignar ejercicios del catálogo a cada día.
4. Establecer las series y repeticiones objetivo para cada ejercicio.

---

## 5. Detalles Técnicos de la Base de Datos (PostgreSQL 16)

GymOps está sustentado por una base de datos PostgreSQL normalizada en **Tercera Forma Normal (3FN)**. A continuación se presentan las entidades principales:

* `muscle_group`: Grupos musculares principales (Pecho, Espalda, Piernas, etc.).
* `exercise`: Catálogo maestro de ejercicios con su tipo de movimiento (compuesto o aislamiento).
* `program` y `program_day`: Estructuras de las rutinas de entrenamiento.
* `routine_exercise`: Tabla de rompimiento que asocia ejercicios con días específicos indicando las series/repeticiones objetivo.
* `workout_session` y `workout_set`: Registro del entrenamiento en vivo del usuario.
* `personal_record`: Tabla que mantiene la mejor marca de 1RM lograda en la historia por el usuario para cada ejercicio.
* `audit_log`: Registro inmutable de auditoría para auditorías de cambios y validaciones (RF-10, RNF-07).

---

¡Felicidades! Ahora estás listo para ir al gimnasio con tu terminal y registrar tu progreso con **GymOps**. ¡La constancia y el registro de cargas son las claves de la sobrecarga progresiva!
