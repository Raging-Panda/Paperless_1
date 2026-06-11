# paperless1

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

* [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
* [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
* [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## ABOUT PROJECT

Paperless Mobile app project
App Design Overview The app I are designing is a modern solution aimed at streamlining the payment and receipt process. By utilizing cutting-edge technology such as NFC (Near Field Communication) and QR codes, it offers users a seamless way to manage their transactions. Below is a detailed look at the features and functionality of my app. Key Features 1. NFC and QR Code Integration NFC Reader: The app allows users to tap their phone on NFC-enabled terminals to link their account with the transaction effortlessly. This feature is particularly useful in environments where quick transactions are essential. QR Code Scanning: For devices that do not support NFC or in situations where NFC is unavailable, the app can scan QR codes. This alternative ensures all users can benefit from the app’s capabilities. 2. Digital Receipt Management Instant Receipt Capture: Once a payment is processed via NFC or QR code, the receipt is automatically sent to the app. This eliminates the need for printed receipts, contributing to a more sustainable environment. Secure Storage: Receipts are securely stored within the app, allowing users to easily access, sort, and manage their purchase history. Additional Features 1. User Account Linking Simple Setup: Users can quickly set up their accounts by linking payment methods and personal information, enabling them to use the app immediately. Multiple Payment Options: The app supports various payment methods, offering flexibility and convenience to users. 2. Data Privacy and Security Encryption: All transactions and personal data are encrypted to ensure privacy and security. User Control: Users have full control over their data, with options to delete or export transaction histories as needed. 3. Enhanced User Experience User-Friendly Interface: The app features an intuitive design that makes navigation easy, even for less tech-savvy users. Notifications and Alerts: Users receive instant notifications of transactions, ensuring they are always informed of their purchase activities. Potential Benefits Eco-Friendly: By reducing the need for paper receipts, the app promotes an environmentally friendly approach to shopping. Convenience: Users can effortlessly manage their receipts and financial records all in one place. Security: With advanced security measures, users can trust that their personal and financial information is well-protected. Your app is set to revolutionize the way users manage transactions, bringing convenience and security to their fingertips.



## Feature Development

### UX & Polish
- Between screen transitions, add a loading spinner to indicate that the app is processing the transaction and fetching the receipt data. This will enhance the user experience by providing feedback during potentially long operations.
- Welcome screen text color change, cannot see text with light background.

### Gamification & Engagement

**Core Loop**
Every scan earns XP. XP fills a progress bar toward the next level. Levels unlock badges, reward eligibility, and profile cosmetics.

**Points & Multipliers**
- Base XP per scan.
- Streak multiplier — longer active streak increases XP earned per scan.
- Bonus XP for first scan at a new store.
- Bonus XP for completing a weekly challenge.
- Receipt quality bonus — extra XP when a receipt has a matched store logo, assigned category, and complete data.

**Tiers / Levels**
A progression ladder (e.g. Bronze → Silver → Gold → Platinum → Eco Elite). Higher tiers unlock better reward vouchers, profile customisation options, and streak shield allowances.

**Badges & Achievements**
- *First Scan* — onboarding hook.
- *7-Day Streak*, *30-Day Streak* — retention milestones.
- *Explorer* — scanned at X different stores.
- *Loyal Regular* — 50 scans at the same store.
- *Eco Warrior* — 100 paperless receipts captured.
- *Budget Master* — stayed under budget for a full month.
- *Green Giant* — X kg of paper saved (calculated from receipt count).
- *Store-specific badges* — scan at a particular retailer enough times to earn a branded badge (e.g. "Woolies Regular"); retailers can sponsor these.
- *Seasonal / limited-edition badges* — holiday events and special periods (Black Friday Scanner, December Spree) with exclusive badges not earnable outside that window.

**Streaks**
- Daily scan streak counter displayed prominently on the home screen.
- Streak shields — earned or unlocked by tier — protect a streak if the user misses a day.
- Streak-at-risk push notification — "You haven't scanned today, your 12-day streak is at risk."

**Weekly Challenges**
Rotating short-term goals (e.g. "Scan at 3 different stores this week", "Log a receipt over R500"). Completing a challenge triggers a mystery reward reveal (scratch-card mechanic) for a randomised bonus — extra XP, a voucher, or a badge. Variable reward loop drives re-engagement.

**Environmental Impact Tracker**
Surfacing a live "paper saved" counter (sheets, grams, CO2 equivalent) on the profile screen ties gamification directly to the app's eco-friendly core purpose. Lifetime stats — total scans, total paper saved, longest streak ever — are shown as a persistent trophy shelf.

**Social & Competitive** *(backlog)*
- Friends leaderboard — weekly XP rankings among friends.
- Direct friend challenge — "who can scan more this week."
- Referral bonus — invite a friend who completes their first scan and both accounts earn bonus XP. Organic growth mechanic.

**Onboarding Quest Line**
Guided starter missions walk new users through app features (link an account, scan a first receipt, set a budget) while rewarding each completed step. Reduces drop-off during onboarding.

**Rewards Redemption** *(backlog)*
Points redeemable for partner store discount vouchers and optionally for environmental/charitable donations, reinforcing the eco angle.

**Annual "Wrapped" Recap** *(backlog)*
A shareable end-of-year card showing total scans, paper saved, top stores visited, longest streak, and badges earned. Combines gamification with the financial intelligence features and is designed to be shared on social media.

### Receipt Management
- Store logo on scanned/fetched receipts for better visual identification in the receipt list.
- Online transactions like Takealot, Uber, etc. will not have a physical receipt to scan, so the app can integrate with email or bank APIs to automatically fetch digital receipts for online purchases.
- Filter by company or store name in the receipt list to allow users to easily find specific transactions.
- Tags and custom categories (e.g. Groceries, Work, Entertainment) applied to receipts for filtering and reporting.
- Receipt OCR and item-level detail extraction so users can search for a specific product, not just a store name.

### Store & Company Profiles
- Companies have their own profile for terms and conditions for returns/refunds, warranty information, etc. which can be accessed from the receipt details screen.
- Return and warranty reminders: push notification when a return window (e.g. 30 days) or warranty period is nearing expiry, calculated from the receipt date. Ties directly into company profiles.

### Financial Intelligence
- Spending analytics: charts and breakdowns of spending by store, category, and time period. The receipt data is already captured; visualising it adds significant value.
- Budget alerts: set monthly spending limits per store or category, with notifications when approaching the limit.
- Tax and expense export: export receipts as PDF or CSV, grouped by category or date range, for expense claims or tax filing.

### Social & Sharing
- Split receipt: divide a receipt between contacts and track who owes what, useful for shared grocery runs or group meals.
- Household sharing: a shared receipt vault for family members so one scan covers the whole household record.

### Loyalty & Payments
- Loyalty card wallet: store and display loyalty and rewards cards alongside receipts, a natural companion to the NFC/QR scanning flow.

### Reliability
- Offline mode: cache receipts locally so users can view their history without a connection and sync when back online.





