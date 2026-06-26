# flake8: noqa
"""
GymOps i18n — Internationalisation module.

Handles language selection and text translation for CLI output.
Supported languages: English (en), Spanish (es).

Language preference is persisted in ~/.gymops/config.json.
"""

import json
from pathlib import Path
from typing import Literal

# Supported languages
Language = Literal["en", "es"]
SUPPORTED_LANGUAGES: list[Language] = ["en", "es"]

# Config file path (same folder as the DB)
_CONFIG_DIR = Path.home() / ".gymops"
_CONFIG_FILE = _CONFIG_DIR / "config.json"


# ---------------------------------------------------------------------------
# Persistence
# ---------------------------------------------------------------------------

def get_language() -> Language:
    """
    Read the saved language preference from config.json.

    Returns 'en' by default if no config file exists.
    """
    if _CONFIG_FILE.exists():
        try:
            data = json.loads(_CONFIG_FILE.read_text())
            lang = data.get("language", "en")
            if lang in SUPPORTED_LANGUAGES:
                return lang  # type: ignore[return-value]
        except (json.JSONDecodeError, KeyError):
            pass
    return "en"


def set_language(lang: Language) -> None:
    """
    Save the language preference to config.json.

    Args:
        lang: Language code to persist ('en' or 'es').
    """
    _CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    existing: dict = {}
    if _CONFIG_FILE.exists():
        try:
            existing = json.loads(_CONFIG_FILE.read_text())
        except json.JSONDecodeError:
            existing = {}
    existing["language"] = lang
    _CONFIG_FILE.write_text(json.dumps(existing, indent=2))


# ---------------------------------------------------------------------------
# Translations
# ---------------------------------------------------------------------------

_TRANSLATIONS: dict[str, dict[Language, str]] = {

    # ---- Shared / General ---------------------------------------------------
    "saved_ok":          {"en": "Saved to database ✓",         "es": "Guardado en la base de datos ✓"},
    "error_prefix":      {"en": "Error:",                       "es": "Error:"},
    "status":            {"en": "Status:",                      "es": "Estado:"},

    # ---- gymops log ---------------------------------------------------------
    "log_success_title": {"en": "🏋️  Workout Logged Successfully!", "es": "🏋️  ¡Entreno Registrado Exitosamente!"},
    "log_exercise":      {"en": "Exercise:",                    "es": "Ejercicio:"},
    "log_sets_reps":     {"en": "Sets x Reps:",                "es": "Series x Reps:"},
    "log_weight":        {"en": "Weight:",                      "es": "Peso:"},
    "log_1rm":           {"en": "Est. 1RM:",                    "es": "1RM Est.:"},
    "log_timestamp":     {"en": "Timestamp:",                   "es": "Fecha/Hora:"},
    "log_guidelines":    {"en": "Routine Guidelines for",       "es": "Pautas de rutina para"},
    "log_target_reps":   {"en": "Target Reps for",             "es": "Reps objetivo para"},
    "log_suggested":     {"en": "Suggested",                    "es": "Sugerido"},
    "log_range":         {"en": "range:",                       "es": "rango:"},

    # ---- gymops add-exercise -------------------------------------------------
    "addex_title":       {"en": "📝 New Exercise Registered",   "es": "📝 Nuevo Ejercicio Registrado"},
    "addex_name":        {"en": "Name:",                        "es": "Nombre:"},
    "addex_muscle":      {"en": "Muscle Group:",                "es": "Grupo Muscular:"},
    "addex_type":        {"en": "Type:",                        "es": "Tipo:"},
    "addex_type_err":    {"en": "Type must be 'compound' or 'isolation'.",
                          "es": "El tipo debe ser 'compound' o 'isolation'."},

    # ---- gymops list-programs -----------------------------------------------
    "prog_title":        {"en": "📋 Available Training Programs", "es": "📋 Programas de Entrenamiento Disponibles"},
    "prog_status":       {"en": "Status",                       "es": "Estado"},
    "prog_name":         {"en": "Program",                      "es": "Programa"},
    "prog_author":       {"en": "Created By",                   "es": "Creado por"},
    "prog_days":         {"en": "Days",                         "es": "Días"},
    "prog_active":       {"en": "✓ ACTIVE",                     "es": "✓ ACTIVO"},
    "prog_today":        {"en": "← today",                      "es": "← hoy"},
    "prog_exercises":    {"en": "exercises",                     "es": "ejercicios"},
    "prog_training_days":{"en": "Training Days:",               "es": "Días de Entrenamiento:"},

    # ---- gymops select-program ----------------------------------------------
    "selp_not_found":    {"en": "Program '{name}' not found.",  "es": "Programa '{name}' no encontrado."},
    "selp_activated":    {"en": "is now active!",               "es": "ahora está activo!"},
    "selp_hint":         {"en": "Use 'gymops set-day' to choose today's training day.",
                          "es": "Usa 'gymops set-day' para elegir el día de hoy."},

    # ---- gymops set-day -----------------------------------------------------
    "setday_no_prog":    {"en": "No active program. Set one first with: gymops select-program",
                          "es": "Sin programa activo. Establece uno con: gymops select-program"},
    "setday_not_found":  {"en": "Day '{name}' not found in the active program.",
                          "es": "El día '{name}' no existe en el programa activo."},
    "setday_set":        {"en": "Training day set to",          "es": "Día de entreno establecido en"},
    "setday_hint":       {"en": "Your logs today will be guided by this day's targets.",
                          "es": "Tus registros de hoy serán guiados por los objetivos de este día."},

    # ---- gymops prs ---------------------------------------------------------
    "prs_title":         {"en": "🏆 Personal Records",          "es": "🏆 Récords Personales"},
    "prs_exercise":      {"en": "Exercise",                     "es": "Ejercicio"},
    "prs_max_weight":    {"en": "Max Weight (kg)",              "es": "Peso Máx. (kg)"},
    "prs_1rm":           {"en": "Est. 1RM (kg)",                "es": "1RM Est. (kg)"},
    "prs_date":          {"en": "Date",                         "es": "Fecha"},
    "prs_empty":         {"en": "No personal records yet. Start logging workouts!",
                          "es": "Sin récords aún. ¡Empieza a registrar entrenamientos!"},

    # ---- gymops history -----------------------------------------------------
    "hist_title":        {"en": "📜 History",                   "es": "📜 Historial"},
    "hist_date":         {"en": "Date",                         "es": "Fecha"},
    "hist_sets":         {"en": "Sets",                         "es": "Series"},
    "hist_reps":         {"en": "Reps",                         "es": "Reps"},
    "hist_weight":       {"en": "Weight (kg)",                  "es": "Peso (kg)"},
    "hist_1rm":          {"en": "Est. 1RM (kg)",                "es": "1RM Est. (kg)"},
    "hist_empty":        {"en": "No history found for '{name}'.", "es": "Sin historial para '{name}'."},

    # ---- gymops stats -------------------------------------------------------
    "stats_title":       {"en": "📈 Progressive Overload Stats for:", "es": "📈 Estadísticas de Sobrecarga Progresiva para:"},
    "stats_prev":        {"en": "Previous Session",             "es": "Sesión Anterior"},
    "stats_curr":        {"en": "Current Session",              "es": "Sesión Actual"},
    "stats_no_data":     {"en": "Not enough data for '{name}'. Log at least 2 sessions first.",
                          "es": "Datos insuficientes para '{name}'. Registra al menos 2 sesiones."},
    "stats_success":     {"en": "💪 PROGRESSIVE OVERLOAD SUCCESS!\nEstimated strength improved by",
                          "es": "💪 ¡ÉXITO EN SOBRECARGA PROGRESIVA!\nLa fuerza estimada mejoró un"},
    "stats_plateau":     {"en": "📊 PLATEAU DETECTED\nNo change in estimated 1RM (+0.00%).\nSuggestion: Try increasing reps or adding 1-2.5 kg next time.",
                          "es": "📊 MESETA DETECTADA\nSin cambio en 1RM estimado (+0.00%).\nSugerencia: Intenta más reps o añade 1-2.5 kg la próxima vez."},
    "stats_decrease":    {"en": "📉 STRENGTH DECREASE DETECTED\nEstimated 1RM dropped by",
                          "es": "📉 DISMINUCIÓN DE FUERZA DETECTADA\nEl 1RM estimado cayó un"},
    "stats_note":        {"en": "This can be normal. Rest, nutrition, and sleep matter!",
                          "es": "Esto puede ser normal. ¡El descanso, la nutrición y el sueño importan!"},

    # ---- gymops digest ------------------------------------------------------
    "digest_title":      {"en": "📊 Digest Generated Successfully!", "es": "📊 ¡Resumen Generado Exitosamente!"},
    "digest_file":       {"en": "File Name:",                   "es": "Nombre de Archivo:"},
    "digest_days":       {"en": "Days Analyzed:",               "es": "Días Analizados:"},
    "digest_days_unit":  {"en": "days",                         "es": "días"},

    # ---- gymops set-language ------------------------------------------------
    "lang_set":          {"en": "Language set to English 🇬🇧 ✓", "es": "Idioma establecido en Español 🇵🇪 ✓"},
    "lang_invalid":      {"en": "Invalid language. Choose: en (English) or es (Español).",
                          "es": "Idioma inválido. Elige: en (English) o es (Español)."},
    "lang_current_en":   {"en": "Current language: English 🇬🇧", "es": "Idioma actual: English 🇬🇧"},
    "lang_current_es":   {"en": "Current language: Español 🇵🇪", "es": "Idioma actual: Español 🇵🇪"},

    # ---- gymops guide & suggestions -----------------------------------------
    "guide_title":       {"en": "📋 Fitness Guides & Articles", "es": "📋 Artículos y Guías de Fitness"},
    "guide_list_slug":   {"en": "Slug",                         "es": "Slug"},
    "guide_list_title":  {"en": "Title",                        "es": "Título"},
    "guide_list_cat":    {"en": "Category",                     "es": "Categoría"},
    "guide_err_not_found":{"en": "Article '{slug}' not found.", "es": "Artículo '{slug}' no encontrado."},
    
    # Contextual Suggestions
    "sug_list_programs": {"en": "Suggestion: Use 'gymops select-program \"<program_name>\"' to activate a routine.",
                          "es": "Sugerencia: Usa 'gymops select-program \"<nombre>\"' para activar una rutina."},
    "sug_select_program":{"en": "Suggestion: Use 'gymops set-day \"<day_name>\"' to choose today's training day.",
                          "es": "Sugerencia: Usa 'gymops set-day \"<nombre>\"' para establecer el día de entrenamiento de hoy."},
    "sug_set_day":       {"en": "Suggestion: Use 'gymops log --exercise \"<exercise>\" --sets <S> --reps <R> --weight <W>' to log a set.",
                          "es": "Sugerencia: Usa 'gymops log --exercise \"<ejercicio>\" --sets <series> --reps <reps> --weight <peso>' para registrar tu primera serie."},
    "sug_log":           {"en": "Suggestion: Use 'gymops stats --exercise \"{exercise}\"' to check your progression.",
                          "es": "Sugerencia: Usa 'gymops stats --exercise \"{exercise}\"' en tu próxima sesión para verificar si lograste sobrecarga progresiva."},
    "sug_stats":         {"en": "Suggestion: Use 'gymops digest' at the end of the week to generate a Markdown digest.",
                          "es": "Sugerencia: Usa 'gymops digest' al finalizar tu semana para generar tu resumen Markdown de progreso."},
    "sug_guide_list":    {"en": "Suggestion: Use 'gymops guide read <slug>' to read an article.",
                          "es": "Sugerencia: Usa 'gymops guide read <slug>' para leer una guía específica."},
    "sug_guide_read":    {"en": "Suggestion: Use 'gymops list-programs' to begin exploring routines.",
                          "es": "Sugerencia: Usa 'gymops list-programs' para comenzar a explorar tus rutinas de entrenamiento."},
}


def t(key: str, **kwargs: str) -> str:
    """
    Return the translated string for the given key in the active language.

    Args:
        key:    Translation key defined in _TRANSLATIONS.
        **kwargs: Named placeholders to substitute in the string (e.g. name='Bench Press').

    Returns:
        Translated string with placeholders replaced, or the key itself if not found.
    """
    lang = get_language()
    entry = _TRANSLATIONS.get(key, {})
    text = entry.get(lang, entry.get("en", key))
    if kwargs:
        for k, v in kwargs.items():
            text = text.replace(f"{{{k}}}", v)
    return text
