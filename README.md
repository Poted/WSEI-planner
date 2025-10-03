# WSEI Planner

A simple and clean mobile/web application for viewing and managing WSEI schedule.

## Features

* **Import Your Schedule**: Easily import personal class schedule using an `.ics` file.
* **Upcoming Weekend**: The main screen always shows you the schedule for the next or currently ongoing weekend with classes.
* **Full Schedule View**: Browse your entire semester schedule, grouped by day.
* **Credits Checklist**: Automatically generates a unique list of your subjects that require a final grade. You can:
    * Add multiple deadline dates.
    * Mark subjects as "Passed".
    * Add personal notes for each subject.
* **Deadline Summary**: A chronologically sorted list of all deadlines you've added.
* **Cross-Platform**: Works as a native app on Android/iOS and as a PWA in any web browser.

## Getting Started

1.  **Launch the App**: Open the app on your phone or in your browser.
2.  **Import Schedule**: On first launch, you will be prompted to import your schedule. Tap the **upload icon** in the top-right corner to select your `.ics` file.
3.  **Done!**: Your schedule is now loaded and saved locally on your device/browser.

## Tech Stack

* **Framework**: Flutter
* **Language**: Dart
* **Local Storage**: Hive
* **File Handling**: file_picker, shared_preferences
* **Calendar Parsing**: icalendar_parser
