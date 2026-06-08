<<<<<<< HEAD
<p align="center">
  <img src="build/app/icon.png" alt="HabitPeak Logo" width="128" height="128" style="border-radius: 28%; box-shadow: 0px 8px 16px rgba(0, 0, 0, 0.15);" />
</p>

<h1 align="center">HabitPeak</h1>

<p align="center">
  <strong>A premium, offline-first, local-only habit tracker built with Flutter and SQLite.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-%3E%3D_3.10.0-02569B?logo=flutter&style=for-the-badge" alt="Flutter Version" />
  <img src="https://img.shields.io/badge/Platform-Android-3DDC84?logo=android&style=for-the-badge" alt="Platform Android" />
  <img src="https://img.shields.io/badge/Database-SQLite-003B57?logo=sqlite&style=for-the-badge" alt="Database SQLite" />
  <img src="https://img.shields.io/badge/State--Management-Riverpod-008080?logo=dart&style=for-the-badge" alt="State Management Riverpod" />
  <img src="https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge" alt="License MIT" />
</p>

---

HabitPeak is a modern, privacy-respecting habit tracker designed for high performance and zero friction. There are no account creations, no cloud servers, no advertisements, and no heavy gamification. Just a clean, premium, and lightning-fast tool to help you build consistency and reach your peak performance.

## ✨ Principles & Philosophy

*   **🔒 Complete Privacy:** All habit data is stored locally on your device. No cloud sync, no tracking, and no external dependencies.
*   **⚡ Premium Performance:** Lightning-fast cold starts and page transitions. Built-in SQLite indexing ensures instant queries.
*   **📈 Stable History (Revision System):** Modifying a habit's target or schedule doesn't warp your historical data. A clean revision history keeps your past progress accurate.
*   **📱 Native Integration:** Premium Android Glance home screen widgets that allow viewing progress and completing habits with a single tap.

---

## 📱 Key Features

| Feature | Description |
| :--- | :--- |
| **📋 Multi-Type Habits** | Track habits with checkboxes (yes/no), numeric inputs (e.g. water tracking), or timers (custom target duration). |
| **🔄 Advanced Recurrence** | Daily, weekly, monthly, specific days of the week, custom intervals, date-bound schedules, or weekday/weekend exclusions. |
| **🔥 Smart Streak Recovery** | Built-in safety net allows you to restore a broken streak up to **twice per month** within a 24-hour grace window from the missed day. |
| **📊 High-Fidelity Analytics** | Beautifully detailed daily, weekly, and monthly charts tracking completion rates, streaks, times, consistency patterns, and scores. |
| **🧩 Home Screen Widgets** | Fully interactive home screen widgets using Android Glance to mark habits as done and check progress on the go. |
| **🔔 Smart Local Reminders** | Customizable local notifications to remind you to complete habits, send summaries, and alert you of missed habits. |
| **💾 Easy Backups & Export** | Secure your data with offline JSON exports/imports, or export your completion history to CSV for custom analysis. |

---

## 📸 Screenshots

> [!NOTE]
> Add your own device screenshots inside `assets/screenshots/` to display them here!

<p align="center">
  <img src="assets/screenshots/home-light.png" alt="Home Light Mode" width="180" style="margin: 10px;" />
  <img src="assets/screenshots/home-dark.png" alt="Home Dark Mode" width="180" style="margin: 10px;" />
  <img src="assets/screenshots/analytics.png" alt="Analytics View" width="180" style="margin: 10px;" />
  <img src="assets/screenshots/android-widget.png" alt="Glance Widget" width="180" style="margin: 10px;" />
</p>

---

## 🛠️ Built With

*   **Framework:** [Flutter](https://flutter.dev) (Dart)
*   **State Management:** [Riverpod](https://riverpod.dev) for DI and reactive state boundaries
*   **Database:** SQLite via [sqflite](https://pub.dev/packages/sqflite)
*   **Charts:** [fl_chart](https://pub.dev/packages/fl_chart) for premium performance visuals
*   **Widgets:** [home_widget](https://pub.dev/packages/home_widget) with Jetpack Compose Glance
*   **Notifications:** [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications)

---

## 📂 Project Architecture

The codebase follows a modular clean architecture:

```text
lib/
  ├── app/             # App shell, theme styling, global provider registries
  ├── core/            # Database schema migrations, date utilities, and global helpers
  └── features/        # Modular domain feature folders
        ├── habits/      # Habit creation, type logic, revision engine, and UI cards
        ├── analytics/   # Analytical engine, streak math, score calculation, charts
        ├── timer/       # Persistent timer system that survives app restarts
        ├── notifications/# Android local notification manager
        ├── widgets/     # Jetpack Compose Glance widget bindings and event callbacks
        ├── backup/      # JSON backup file parsing and CSV reporting
        └── settings/    # Day reset boundaries, themes, and configuration flags
```

---

## 🚀 Getting Started

### Prerequisites

*   Install the latest [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable branch).
*   Setup an Android Emulator or connect a physical Android device.

### Installation

1.  **Clone the Repository**
    ```bash
    git clone https://github.com/your-username/habitpeak.git
    cd habitpeak
    ```

2.  **Install Dependencies**
    ```bash
    flutter pub get
    ```

3.  **Run the Application**
    ```bash
    flutter run
    ```

4.  **For Android Widget Development**
    Ensure home screen widgets are supported on your test device:
    ```bash
    flutter run -d android
    ```

---

## 🤝 Contribution Guidelines

We welcome contributions of all types! To keep development fast, clean, and organized:

1.  Keep business logic inside **Domain/Service providers** and keep presentation layers clean of query logic.
2.  Optimize database operations by adding indexes to `app_database.dart` rather than querying large structures inside the UI layer.
3.  Add unit or widget tests for any new features or scheduling changes. Check out existing tests in `test/` for references.
4.  Ensure all code conforms to rules specified in `analysis_options.yaml` (`flutter analyze`).

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](file:///c:/Users/ahmed/OneDrive/Documents/New%20project%202/LICENSE) file for details.
=======
# HabitPeak
>>>>>>> 23fe16c0d88c6681c8329235c39b5561e3e7f76a
