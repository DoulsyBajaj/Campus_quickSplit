# Campus QuickSplit

A high-performance expense management and debt-simplification web application built with Flutter, designed to help students and group members track shared expenses, analyze spending habits, and settle debts with minimal physical transactions.

**Live Demo:** [https://doulsybajaj.github.io/Campus_quickSplit/](https://doulsybajaj.github.io/Campus_quickSplit/)  
**Android APK:** [Download Latest APK](https://github.com/DoulsyBajaj/Campus_quickSplit/releases/latest/download/app-release.apk)
---

## Project Overview

**Campus QuickSplit** solves the hassle of managing shared expenses for group events, trips, and shared campus living. Instead of requiring every individual to pay back each person across dozens of individual transactions, the app executes an optimized algorithm to reduce total transfers down to the bare minimum needed to clear all debts.

Built as a local-first Progressive Web App (PWA), all data remains strictly private on your device using Hive local storage.

---

## Tech Stack & Key Libraries

* **Core Framework:** [Flutter Web](https://flutter.dev)
* **Language:** [Dart](https://dart.dev)
* **Local Database:** [Hive](https://pub.dev/packages/hive) & [hive_flutter](https://pub.dev/packages/hive_flutter) (Blazingly fast, lightweight NoSQL key-value store)
* **Data Visualization:** Custom Canvas Painters & Chart rendering modules for spend breakdown
* **Hosting & CI/CD:** GitHub Pages & Git Workflows

---

## Data Processes & Algorithms

### 1. Greedy Cash-Flow Settlement Algorithm
* **Net Balance Computation:** Calculates net standing for every participant:
  $$\text{Net Balance} = \text{Total Amount Paid} - \text{Total Share Owed}$$
* **Optimization Loop:** Identifies the maximum debtor (person owing the most) and maximum creditor (person owed the most).
* **Transfer Resolution:** Settles the minimum of the absolute debt/credit between these two parties, updates their balances, and recursively repeats until all net balances equal zero.
* **Efficiency:** Reduces $N(N-1)$ potential group transactions down to a maximum of $N-1$ total settlements.

### 2. Multi-Payer Split Allocations
* Handles complex bills where multiple members contribute varying partial amounts toward a single item.

### 3. Local-First Offline Persistence
* Serializes application state models directly into local Hive boxes.
* Provides full offline capabilities without cloud database delays or server dependencies.

### 4. Transactional Safety Buffer
* Features swipe-to-delete functionality backed by an async state buffer, allowing instant deletion rollbacks before committing changes to storage.

---

## Getting Started Locally

### Prerequisites
* [Flutter SDK](https://docs.flutter.dev/get-started/install) installed on your local machine.
* Google Chrome or any modern web browser.

### Installation & Local Setup

1. **Clone the repository:**
   ```bash
   git clone [https://github.com/DoulsyBajaj/Campus_quickSplit.git](https://github.com/DoulsyBajaj/Campus_quickSplit.git)
   cd Campus_quickSplit
   ```

2. **Install project dependencies:**
   ```bash
   flutter pub get
   ```

3. **Launch in Chrome:**
   ```bash
   flutter run -d chrome
   ```

---

## Web Build & Deployment

To compile and update the production web bundle hosted on GitHub Pages:

```bash
# 1. Compile production web bundle with repository path prefix
flutter build web --base-href "/Campus_quickSplit/"

# 2. Deploy compiled build to gh-pages branch
cd build/web
git init
git add .
git commit -m "Deploy web release"
git branch -M gh-pages
git remote add origin [https://github.com/DoulsyBajaj/Campus_quickSplit.git](https://github.com/DoulsyBajaj/Campus_quickSplit.git)
git push -u -f origin gh-pages
```

---

## Contributing

Contributions, issues, and feature requests are welcome! Feel free to check the [issues page](https://github.com/DoulsyBajaj/Campus_quickSplit/issues).
