# Smart Ledger AI

Smart Ledger AI is a professional, offline-first shop management and digital ledger application built with Flutter. Designed for small to medium merchants, it combines the reliability of a local database with the convenience of cloud synchronization via Google Sheets and an intelligent voice assistant.

## 🚀 Core Features

### 🔒 Security & Privacy
*   **Mandatory Google Sign-In**: Secure your data with your Google account.
*   **App Lock**: Enable a 4-digit PIN or use Biometrics (Fingerprint/Face Unlock) to protect your ledger.
*   **Offline Mode**: Access your data even without an internet connection.
*   **Privacy-First**: Your data stays on your device and in your private Google Sheets.

### 📊 Professional Ledger
*   **Customer Management**: Unique customer profiles with phone-number based identification.
*   **Quick Entries**: Easily add Credit (Udhar) or Payments (Jama) with product details.
*   **Customer Detail View**: Full transaction history for every customer.
*   **WhatsApp Sharing**: Instantly send transaction alerts and balance reminders to customers via WhatsApp.

### 🤖 Intelligent Assistant
*   **Voice Commands**: Tap the bot icon and speak to manage your shop.
*   **Natural Language Support**: Understands English and Hinglish (e.g., *"Raj ne 500 jama kiye"*, *"Add groceries 200 for Rahul"*).
*   **Auto-Cleaning**: Automatically extracts product names and amounts from your voice.

### ☁️ Cloud Sync & Restore
*   **Google Sheets Sync**: Your data is automatically backed up to a readable "Smart Ledger Backup" spreadsheet in your Google account.
*   **1-Minute Auto-Backup**: Changes are synced intelligently in the background.
*   **One-Tap Restore**: Switch phones easily—just log in and pull your entire history back from Google Sheets.

### 📈 Reports
*   **PDF Statements**: Generate professional outstanding reports for your business.
*   **Dashboard**: Real-time summary of total customers, outstanding balance, and today's business.

## 🛠 Installation & Setup

1.  **Clone the Repo**:
    ```bash
    git clone [repository-url]
    cd smartledger_ai
    ```

2.  **Install Dependencies**:
    ```bash
    flutter pub get
    ```

3.  **Google Project Setup**:
    *   Create a project in [Google Cloud Console](https://console.cloud.google.com/).
    *   Enable **Google Sheets API** and **Google Drive API**.
    *   Add your **SHA-1 Fingerprint** (Run `cd android && ./gradlew signingReport`) to an **Android Client ID**.
    *   Add your email as a **Test User** in the OAuth Consent Screen.

4.  **Run the App**:
    ```bash
    flutter run
    ```

## 📱 Voice Command Examples
*   *"Add 500 for Raj"*
*   *"Rahul paid 200"*
*   *"Raj ka balance dikhao"*
*   *"Sync to cloud"*
*   *"Show today's hisab"*

## 🧱 Technical Stack
*   **Framework**: Flutter
*   **State Management**: Riverpod
*   **Database**: Drift (SQLite)
*   **Authentication**: Google Sign-In
*   **Cloud API**: Google Sheets & Drive API
*   **Native**: Local Auth (Biometrics), Speech to Text

---

### **Files to Push to Git**

To ensure your project works on other machines or in CI/CD, make sure to push the following:

*   **`lib/`**: All source code (includes new auth, data, and security layers).
*   **`pubspec.yaml`**: Updated dependencies and assets.
*   **`android/`**: 
    *   `app/build.gradle.kts`, `build.gradle.kts`, `settings.gradle.kts` (Build configurations).
    *   `gradle/wrapper/gradle-wrapper.properties` (Gradle version 8.12).
    *   `app/src/main/AndroidManifest.xml` (Permissions and App label).
*   **`ios/`**: `Runner/Info.plist` (App label and permissions).
*   **`assets/`**: `logo.png`.
*   **`README.md`**: This updated file.

*Note: Do not push `google-service.json` if it contains private credentials, though it is often needed for Android builds.*
