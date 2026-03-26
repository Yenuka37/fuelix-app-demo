# Fuelix App — Codebase Memory

## App Overview
**Fuelix** is a Flutter smart fuel management app for Sri Lanka. It tracks fuel usage, manages vehicle quotas, handles wallet top-ups, and generates QR-based Fuel Passes per vehicle. Uses SQLite (sqflite) for local persistence. Supports light/dark themes.

---

## Tech Stack
- Flutter (Material 3, `useMaterial3: true`)
- `sqflite` — local SQLite DB
- `google_fonts` — SpaceGrotesk (headings) + Inter (body)
- `shared_preferences` — tutorial/onboarding seen flags
- `qr_flutter` — QR code rendering
- `crypto` — SHA-256 password hashing
- Portrait-only orientation lock

---

## Project Structure
```
lib/
├── main.dart
├── theme/
│   └── app_theme.dart
├── models/
│   ├── user_model.dart
│   ├── vehicle_model.dart
│   ├── quota_model.dart
│   ├── topup_model.dart          (WalletModel + TopUpTransactionModel)
│   └── fuel_log_model.dart
├── database/
│   └── db_helper.dart
├── services/
│   ├── quota_service.dart
│   └── tutorial_service.dart
├── screens/
│   ├── splash_screen.dart
│   ├── login_screen.dart
│   ├── signup_screen.dart
│   ├── onboarding_screen.dart
│   ├── home_screen.dart
│   ├── profile_screen.dart
│   ├── vehicles_screen.dart
│   └── topup_screen.dart
└── widgets/
    ├── custom_button.dart
    └── tutorial_overlay.dart
```

---

## Routes (main.dart)
| Route | Screen |
|-------|--------|
| `/` | SplashScreen |
| `/login` | LoginScreen |
| `/signup` | SignupScreen |
| `/home` | HomeScreen (arg: UserModel) |
| `/profile` | ProfileScreen (arg: UserModel) |
| `/vehicles` | VehiclesScreen (arg: UserModel) |
| `/topup` | TopUpScreen (arg: UserModel) |

After login, if onboarding not seen → `OnboardingScreen(user)` (not a named route, pushed via `MaterialPageRoute`).

---

## Theme (app_theme.dart)

### AppColors
| Name | Value | Use |
|------|-------|-----|
| `emerald` | `#00C896` | Primary green |
| `emeraldDark` | `#00A87E` | |
| `emeraldLight` | `#4DFFC4` | |
| `ocean` | `#0A84FF` | Secondary blue |
| `oceanDark` | `#0066CC` | |
| `amber` | `#FF9F0A` | Accent/warning |
| `error` | `#FF453A` | Error red |
| `success` | `#00C896` | Same as emerald |
| `warning` | `#FF9F0A` | Same as amber |

**Light mode surfaces:** `lightBackground #F5F7FA`, `lightSurface #FFFFFF`, `lightSurfaceAlt #EEF1F6`, `lightBorder #DDE2EC`  
**Dark mode surfaces:** `darkBackground #0D1117`, `darkSurface #161B22`, `darkSurfaceAlt #21262D`, `darkBorder #30363D`

**Text (light):** `lightText #111827`, `lightTextSub #6B7280`, `lightTextMuted #9CA3AF`  
**Text (dark):** `darkText #F0F6FC`, `darkTextSub #8B949E`, `darkTextMuted #484F58`

### Gradients (AppTheme static)
- `primaryGradient`: emerald → ocean (topLeft → bottomRight)
- `accentGradient`: ocean → emerald
- `warmGradient`: amber → emerald

### Background gradient pattern used across all screens:
```dart
isDark ? [Color(0xFF0D1117), Color(0xFF0A1628)] : [Color(0xFFF0FDF8), Color(0xFFEFF6FF)]
(topLeft → bottomRight)
```

---

## Database (db_helper.dart)
Singleton. DB name: `fuelix.db`, version: **8**.

### Tables
| Table | Key columns |
|-------|-------------|
| `users` | id, first_name, last_name, nic (UNIQUE), mobile, address_line1/2/3, district, province, postal_code, email (UNIQUE), password (SHA-256), created_at |
| `vehicles` | id, user_id, type, make, model, year, registration_no, fuel_type, engine_cc, color, fuel_pass_code (nullable), qr_generated_at, created_at |
| `fuel_quotas` | id, vehicle_id, week_start, week_end, quota_litres, used_litres |
| `wallets` | user_id (PK), balance, updated_at |
| `topup_transactions` | id, user_id, amount, method, status, reference, created_at |
| `fuel_logs` | id, user_id, vehicle_id, litres, fuel_type, fuel_grade, price_per_litre, total_cost, station_name, logged_at |

### Key Methods
- `insertUser(UserModel)` → hashes password, creates wallet row
- `validateLogin(nic, password)` → SHA-256 compare
- `nicExists / emailExists / mobileExists` → uniqueness checks
- `setFuelPassCode(vehicleId, code, vehicleType)` → atomic: sets code + creates initial quota record
- `getCurrentWeekQuota(vehicleId, vehicleType)` → returns existing or creates new week quota
- `processTopUp(userId, amount, method)` → atomic: updates wallet + inserts transaction
- `saveFuelLog(log, vehicleType)` → atomic 6-step transaction:
  1. Get/create week quota
  2. Check litre headroom → returns `-1` if exceeded
  3. Check wallet balance → returns `-2` if insufficient
  4. Deduct litres from quota
  5. Deduct cost from wallet
  6. Insert log row
  - Returns: row id (>0) success, -1 quota exceeded, -2 insufficient balance, -3 error
- `getFuelLogStats(userId)` → aggregates: total_logs, total_litres, total_spent
- `deleteFuelLog(id)` — does NOT reverse quota/wallet (by design)

---

## Models

### UserModel
Fields: id, firstName, lastName, nic, mobile, addressLine1/2/3, district, province, postalCode, email, password, createdAt  
Helpers: `fullName`, `fullAddress`

### VehicleModel
Fields: id, userId, type, make, model, year, registrationNo, fuelType, engineCC, color, fuelPassCode, qrGeneratedAt, createdAt  
Helpers: `hasQr`, `isLocked` (= hasQr), `displayName` ("Make Model (Year)"), `shortDisplay` ("Make Model")

### FuelQuotaModel
Fields: id, vehicleId, weekStart, weekEnd, quotaLitres, usedLitres  
Computed: `remainingLitres`, `usedPercent`, `isExhausted`

### WalletModel
Fields: userId, balance (LKR), updatedAt  
Helper: `formattedBalance` ("LKR X.XX")

### TopUpTransactionModel
Fields: id, userId, amount, method, status (enum: pending/completed/failed), reference, createdAt  
Helper: `statusLabel`

### FuelLogModel
Fields: id, userId, vehicleId, litres, fuelType, fuelGrade, pricePerLitre, totalCost, stationName, loggedAt  
Helpers: `formattedDate` ("25 Mar 2026"), `formattedTime` ("14:35")

---

## Services

### QuotaService (pure logic, no DB)
**Weekly quotas by vehicle type:**
| Type | Litres/week |
|------|------------|
| Car | 25 |
| Van | 25 |
| Motorcycle | 2 |
| Truck | 20 |
| Bus | 45 |
| Three-Wheeler | 15 |

- Week = Monday–Sunday
- `weekStart(date)` / `weekEnd(date)` — Mon 00:00 to Sun 23:59:59.999
- `newWeekQuota(vehicleId, vehicleType)` — creates fresh quota
- `daysRemainingLabel(now)` — "X days left" / "X hrs left" / "Resets tonight"
- `weekLabel(weekStartDate)` — "24 Mar – 30 Mar"

### TutorialService (SharedPreferences)
Keys: `tutorial_seen_{keyName}`  
Enum `TutorialKey`: `onboarding`, `homeTour`, `vehiclesTour`, `topupTour`, `fuelPassTour`  
Methods: `isSeen(key)`, `markSeen(key)`, `reset(key)`, `resetAll()`

---

## Screens

### SplashScreen
- 3 AnimationControllers: logo (elasticOut scale), text (slide+fade), shimmer (repeat)
- Background: gradient + decorative radial circles + grid painter
- After ~2.6s → navigate to `/login`

### LoginScreen
- NIC (12-digit or 9+V/X) + password form
- On success: check `TutorialService.isSeen(onboarding)` → if not seen → `OnboardingScreen`, else `/home`
- Fade+slide entrance animation

### SignupScreen (4-step PageView, NeverScrollableScrollPhysics)
- **Step 1:** firstName, lastName, NIC, mobile (validates uniqueness via DB)
- **Step 2:** address lines 1-3, province (9 Sri Lanka provinces), district (cascading from province), postalCode
- **Step 3:** email, password (min 8, 1 uppercase, 1 number), confirm password
- **Step 4:** Sequential OTP verification — mobile first, then email
  - OTP generated with `Random().nextInt(900000) + 100000` (demo: shown in snackbar)
  - Resend cooldown: 60s → 90s → 120s+
  - Phase progress indicator (3 dots: Mobile → Email → Done)
  - `_OtpCard` widget: active/verified/locked states
- On completion: `insertUser` → redirect to `/login`

### OnboardingScreen (5-slide PageView)
Slides: Welcome, Add Vehicles, Get Fuel Pass, Weekly Quota, Top Up Wallet  
Each slide: icon hero + gradient title + body + bullet list card  
On finish: `TutorialService.markSeen(onboarding)` → `/home`

### HomeScreen
**State:** UserModel, List<VehicleModel>, WalletModel, List<FuelLogModel> (last 10), stats map  
**Sections:**
1. Top bar (logo, notifications icon, avatar → profile)
2. Welcome card (gradient emerald→ocean, shows fullName, NIC, email, greeting)
3. Stats row: Total Logs / Fuel Used / Total Spent (3 StatCards)
4. Wallet preview (purple→blue gradient, tap → topup)
5. Vehicles section (horizontal scroll chips, 150px wide each, +Add card)
6. Quick Actions grid (2x2): Fuel Log, Analytics (stub), Trips (stub), Top Up
7. Recent Fuel Logs (last 10, long-press to delete)

**Fuel Log Sheet (`_FuelLogSheet`):**
- DraggableScrollableSheet (initial 0.88)
- Vehicle dropdown (first selected by default)
- Loads week quota + grades
- Fuel grade selector (colored chips): Petrol 92 (Rs.317), Petrol 95 (Rs.365), Auto Diesel (Rs.303), Super Diesel (Rs.353), Kerosene (Rs.195)
- Grade availability: Petrol/Hybrid → petrol grades; Diesel/Hybrid → diesel grades; Kerosene → kerosene; Electric/LPG → empty (shows notice)
- Litres field with live progress bar (green→amber→red)
- Cost preview card (green if affordable, red if not)
- Max litres = min(quotaRemaining, walletBalance/pricePerLitre)
- Errors: -1 quota exceeded, -2 insufficient balance

**Home Tour:** SpotlightTour on 4 keys (welcome card, wallet, vehicles, quick actions)

### ProfileScreen
- Read-only display of all UserModel fields
- Sections: Personal Info, Address, Account, Preferences (stubs), Sign Out
- AvatarCard (initials, emerald→ocean gradient)
- Sign-out → clears stack, pushes `/login`

### VehiclesScreen
**Vehicle types:** Car, Motorcycle, Van, Truck, Bus, Three-Wheeler  
**Makes:** Toyota, Honda, Suzuki, Nissan, Mitsubishi, Mazda, Hyundai, Kia, BMW, Mercedes-Benz, VW, Ford, Bajaj, TVS, Hero, Yamaha, Kawasaki, Tata, Other  
**Fuel types:** Petrol, Diesel, Electric, Hybrid, LPG

**Vehicle Card states:**
- Unlocked: shows "Get Fuel Pass" button, Edit/GenerateQR in popup menu
- Locked (QR generated): green border, lock badge, "View Pass" button, ViewFuelPass in popup

**Fuel Pass generation:**
- Confirms with dialog (warns details locked permanently)
- Generates 8-char alphanumeric code (Random.secure), checks global uniqueness
- `setFuelPassCode` atomic: sets code + creates week quota
- Immediately shows `_FuelPassSheet`

**`_FuelPassSheet`:**
- Shows QR code (qr_flutter) with data: `FUELIX|{code}|{regNo}|{make} {model}|{year}|{fuelType}`
- 8-char code displayed with copy button
- Loads and shows `_QuotaCard` (week quota details)
- Gauge color: green (<50%), amber (<85%), red (≥85%)

**Vehicles Tour:** SpotlightTour on Add button, vehicle card, fuel pass button

### TopUpScreen
**Tabs:** Top Up | History

**Top Up Form:**
- Preset amounts: 500, 1000, 2000, 5000, 10000 LKR
- Custom amount input (min 100 LKR)
- Payment methods: Credit/Debit Card (ocean), Bank Transfer (emerald), Mobile Pay (amber)
- Info notice, "Top Up Now" button (purple→blue gradient)
- On success: `_SuccessSheet` modal + switches to History tab

**Transaction History:**
- `_TransactionTile`: method icon+color, date/time, reference, amount (+LKR), status badge

---

## Widgets

### custom_button.dart
- `GradientButton` — full-width, scale press animation, loading spinner
- `OutlinedAppButton` — bordered, optional leading icon
- `AppTextField` — handles obscure toggle, multi-line support, prefix icon alignment
- `StepIndicator` — animated segmented progress bar
- `showAppSnackbar(context, message, isError, isSuccess)` — floating snackbar

### tutorial_overlay.dart
- `SpotlightTour` — wraps a screen, steps through TourStep list
- `TourStep` — targetKey, title, body, icon, gradient, position (above/below)
- `_SpotlightOverlay` — dim layer + cutout + pulsing ring + positioned tooltip card
- `_TooltipCard` — step counter badge, progress dots, Skip + Next/Done buttons
- `_PulseRing` — animated border ring around target
- `_SpotlightPainter` — CustomPainter with BlendMode.clear cutout
- Arrow tip auto-aligns to center of target widget

---

## Fuel Grade Colors (used in HomeScreen tiles)
| Grade | Color |
|-------|-------|
| Petrol 95 | `#7C3AED` (purple) |
| Petrol 92 | ocean `#0A84FF` |
| Super Diesel | amber `#FF9F0A` |
| Auto Diesel | `#F97316` (orange) |
| Kerosene | `#6B7280` (gray) |

## Vehicle Type Colors
| Type | Color |
|------|-------|
| Car | ocean |
| Motorcycle | amber |
| Van | emerald |
| Truck | `#EF4444` |
| Bus | `#7C3AED` |
| Three-Wheeler | `#F97316` |

---

## Sri Lanka Geographic Data (signup_screen.dart)
9 provinces with their districts:
- Western: Colombo, Gampaha, Kalutara
- Central: Kandy, Matale, Nuwara Eliya
- Southern: Galle, Matara, Hambantota
- Northern: Jaffna, Kilinochchi, Mannar, Mullaitivu, Vavuniya
- Eastern: Ampara, Batticaloa, Trincomalee
- North Western: Kurunegala, Puttalam
- North Central: Anuradhapura, Polonnaruwa
- Uva: Badulla, Monaragala
- Sabaragamuwa: Kegalle, Ratnapura

---

## Key Design Patterns
1. **Screen entry animation:** `AnimationController` (500-700ms) with fade + slide (Offset 0, 0.06→0)
2. **Card style:** `borderRadius: 14-20`, `color: darkSurface/lightSurface`, `border: darkBorder/lightBorder`
3. **Gradient buttons/cards:** emerald→ocean or purple→blue (for wallet)
4. **User passed via route arguments:** `ModalRoute.of(context)?.settings.arguments as UserModel?`
5. **All screens load data in `didChangeDependencies`** with null guard on user.id
6. **Atomic DB operations** use `db.transaction()` for quota+wallet+log consistency
7. **Password:** SHA-256 hashed before storage, never stored plain
8. **Fuel pass code:** 8 chars from `[0-9A-Z]`, globally unique, generated with `Random.secure()`

---

## Stubs / Not Yet Implemented
- Analytics screen (action card exists, `onTap: () {}`)
- Trips screen (action card exists, `onTap: () {}`)
- Notifications (bell icon in home top bar, no action)
- Profile preferences: Notifications, Privacy & Security, Help & Support (all `onTap: () {}`)
- `topupTour` and `fuelPassTour` TutorialKeys exist but not triggered in code yet
- OTP in production needs real SMS/email gateway (currently demo via snackbar)