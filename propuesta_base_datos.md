# Propuesta de Base de Datos - GymOps 🏋️

Este documento resume el estado actual del proyecto GymOps y la propuesta para adaptarlo a los requerimientos del curso de **Base de Datos II**.

## 1. Estado Actual de GymOps
*   **Motor de Base de Datos**: SQLite (almacenamiento local en `~/.gymops/gymops.db`).
*   **Estructura**: Tablas básicas (`exercises`, `programs`, `program_days`, `day_exercises`, `workouts`, `prs` y `active_program`).
*   **Limitación**: SQLite no soporta nativamente procedimientos almacenados complejos, funciones de usuario SQL personalizadas, ni un sistema de seguridad basado en roles y usuarios (`GRANT`/`REVOKE`).

## 2. Propuesta de Cambio (Alineado al PDF del Curso)
Proponemos migrar el diseño físico a **PostgreSQL** e implementar un script SQL avanzado que contenga:

### A. Estructura y Restricciones
*   Agregar una tabla de auditoría (`audit_log`) e incorporar restricciones (`CHECK`, `UNIQUE`) rigurosas.

### B. Consultas y Vistas Avanzadas
*   Creación de vistas para reportes semanales y progreso de fuerza usando `JOIN`, `GROUP BY`, funciones agregadas y subconsultas/CTEs.

### C. Programación en la Base de Datos (PL/pgSQL)
*   **Procedimiento Almacenado (`sp_log_workout_set`)**: Registro transaccional de sets deportivos, que controle errores (`EXCEPTION`) y actualice récords personales automáticamente.
*   **Función Escalar (`fn_calculate_epley_1rm`)**: Cálculo matemático del 1RM estimado.
*   **Disparador (`tg_audit_workout_changes`)**: Auditoría automática que guarde un historial de modificaciones en la tabla de entrenamientos.

### D. Seguridad y Administración
*   Definición de roles (`gym_admin`, `gym_member`) con privilegios limitados y comandos de respaldo/recuperación de la base de datos.

## 3. Próximos Pasos
1.  **Crear el archivo SQL completo** (`schema_completo.sql`) en esta misma carpeta, listo para ser entregado.
2.  (Opcional) Modificar el código Python de GymOps para realizar la conexión real a PostgreSQL.
