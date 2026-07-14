# Rapi Team - App Store Publishing Guide

## Prerequisites (Confirmed)
- [x] Apple Developer Account
- [x] Google Play Console Account
- [x] App Signing configured (keystore + certificates)
- [x] Privacy Policy URL: https://rapiteam.com/privacy
- [x] Support Email: facturacion.rapiteam@gmail.com

---

## PART 1: Screenshots Needed (6-8 per store)

Navigate to each screen in the simulator and run the screenshot command.

### Screenshots to capture (iPhone 17 Pro Max - Passenger):

| # | Screen | How to get there | Command |
|---|--------|-----------------|---------|
| 1 | Home Map (passenger) | Open app as passenger | Already captured |
| 2 | Destination Search | Tap "A donde y por cuanto?" | `xcrun simctl io 2BCAA6CA screenshot store_assets/screenshots/ios/02_search.png` |
| 3 | Price Negotiation | Select destination, see price sheet | `xcrun simctl io 2BCAA6CA screenshot store_assets/screenshots/ios/03_price.png` |
| 4 | Trip Tracking | During active trip | `xcrun simctl io 2BCAA6CA screenshot store_assets/screenshots/ios/04_tracking.png` |
| 5 | Chat | Open chat during trip | `xcrun simctl io 2BCAA6CA screenshot store_assets/screenshots/ios/05_chat.png` |
| 6 | Trip History | Menu > Trip History | `xcrun simctl io 2BCAA6CA screenshot store_assets/screenshots/ios/06_history.png` |
| 7 | Rating | After completing trip | `xcrun simctl io 2BCAA6CA screenshot store_assets/screenshots/ios/07_rating.png` |
| 8 | Profile | Menu > Profile | `xcrun simctl io 2BCAA6CA screenshot store_assets/screenshots/ios/08_profile.png` |

### Screenshots to capture (iPhone 17 Pro - Driver):

| # | Screen | How to get there | Command |
|---|--------|-----------------|---------|
| 1 | Driver Home | Switch to driver mode | `xcrun simctl io B24C7E10 screenshot store_assets/screenshots/ios/d01_home.png` |
| 2 | Ride Request | Receive a request | `xcrun simctl io B24C7E10 screenshot store_assets/screenshots/ios/d02_request.png` |
| 3 | Navigation | During active trip | `xcrun simctl io B24C7E10 screenshot store_assets/screenshots/ios/d03_nav.png` |
| 4 | Earnings | Menu > Earnings | `xcrun simctl io B24C7E10 screenshot store_assets/screenshots/ios/d04_earnings.png` |

### App Store Requirements:
- **iPhone 6.9" display** (Pro Max): REQUIRED - at least 3 screenshots
- **iPhone 6.3" display** (Pro): Recommended
- Resolution: Screenshots are automatically correct resolution from simulator
- Format: PNG
- Max: 10 screenshots per device size

### Google Play Requirements:
- Min resolution: 320px, Max: 3840px
- Aspect ratio: 16:9 or 9:16
- Min: 2 screenshots, Max: 8
- Format: PNG or JPEG
- Same screenshots work for both stores

---

## PART 2: Google Play Store Publishing

### Step 1: Build AAB (Already done)
```bash
cd app && flutter build appbundle --release
```
Output: `app/build/app/outputs/bundle/release/app-release.aab`

### Step 2: Go to Google Play Console
URL: https://play.google.com/console

### Step 3: Create App
1. Click "Create app"
2. App name: **Rapi Team**
3. Default language: **Spanish (Latin America) - es-419**
4. App or game: **App**
5. Free or paid: **Free**
6. Accept declarations

### Step 4: Store Listing (Main store listing)
1. **App name**: Rapi Team
2. **Short description**: (see store_metadata.md)
3. **Full description**: (see store_metadata.md)
4. **App icon**: 512x512 PNG (use `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png` resized to 512)
5. **Feature graphic**: 1024x500 PNG (needs to be created - use Canva or similar)
6. **Screenshots**: Upload from `store_assets/screenshots/`
7. **Video** (optional): YouTube URL of demo

### Step 5: Content Rating
1. Go to "Content rating" in left menu
2. Start questionnaire
3. Answer for a ride-hailing app:
   - Violence: No
   - Sexual content: No
   - Language: No
   - Controlled substances: No
   - Location sharing: **Yes** (core feature)
   - User-generated content: Yes (chat, ratings)
4. Expected rating: **Everyone** / PEGI 3

### Step 6: Data Safety
1. Go to "Data safety" in left menu
2. Declare data collected:
   - **Location**: Collected, shared with drivers, required for core functionality
   - **Personal info (name, email, phone)**: Collected, not shared
   - **Financial info (payment methods)**: Collected via MercadoPago, not stored locally
   - **Photos**: Optional (profile photo), not shared
   - **App activity**: Collected (trip history), not shared
   - **Device info**: Collected (FCM tokens for push notifications)
3. Data is encrypted in transit: **Yes**
4. Data deletion request mechanism: **Yes** (via support email)

### Step 7: Target Audience
- Target age: **18+** (ride-hailing requires adult users)
- Not designed for children

### Step 8: App Access
- If the app requires login, provide test credentials:
  - Passenger: (provide test account)
  - Driver: (provide test account)

### Step 9: Upload AAB
1. Go to "Production" > "Create new release"
2. Upload `app-release.aab`
3. Release name: 1.0.0
4. Release notes (Spanish):
```
Lanzamiento inicial de Rapi Team:
- Solicita viajes y negocia tu precio
- Seguimiento en tiempo real
- Chat con tu conductor
- Multiples metodos de pago
- Servicio Express, Ejecutivo y VIP
```

### Step 10: Review & Publish
1. Fix any warnings/errors
2. Click "Start rollout to Production"
3. Google review takes 1-7 days (first app usually 3-7 days)

---

## PART 3: App Store (iOS) Publishing

### Step 1: Build IPA
```bash
cd app && flutter build ipa --release
```
This creates an xcarchive that can be uploaded via Xcode or Transporter.

### Step 2: Upload to App Store Connect
Option A - Xcode:
1. Open `build/ios/archive/Runner.xcarchive` in Xcode
2. Click "Distribute App" > "App Store Connect"
3. Follow wizard

Option B - Transporter app:
1. Download "Transporter" from Mac App Store
2. Drag the .ipa file into Transporter
3. Click "Deliver"

### Step 3: Go to App Store Connect
URL: https://appstoreconnect.apple.com

### Step 4: Create App
1. Click "+" > "New App"
2. Platform: **iOS**
3. Name: **Rapi Team**
4. Primary Language: **Spanish (Mexico)** (or Spanish)
5. Bundle ID: **com.rapiteam.app**
6. SKU: **rapiteam-ios-v1**

### Step 5: App Information
1. **Category**: Travel (Primary), Navigation (Secondary)
2. **Content Rights**: Does not contain third-party content requiring rights
3. **Age Rating**: Fill questionnaire (similar to Google Play)
4. **Privacy Policy URL**: https://rapiteam.com/privacy

### Step 6: App Privacy (Data Collection)
Declare in App Store Connect:
1. **Location**: Used for ride-hailing core functionality
   - Linked to identity: Yes
   - Used for tracking: No
2. **Contact Info (email, phone)**: Used for account functionality
3. **Identifiers (user ID)**: Used for app functionality
4. **Usage Data**: Used for analytics
5. **Diagnostics (crash data)**: Used for app improvement

### Step 7: Prepare Submission
1. **Screenshots**: Upload for each device size
   - 6.9" (iPhone 16 Pro Max / 17 Pro Max)
   - 6.3" (iPhone 16 Pro / 17 Pro)
2. **Description**: (see store_metadata.md)
3. **Keywords**: (see store_metadata.md)
4. **Support URL**: https://rapiteam.com/support
5. **Marketing URL**: https://rapiteam.com
6. **Build**: Select the uploaded build

### Step 8: App Review Information
- **Demo Account**: Provide test credentials
  - Username: (test passenger email)
  - Password: (test password)
- **Notes for Reviewer**:
```
Rapi Team is a ride-hailing application for Peru and Latin America.
To test the app, please use the demo account provided.
The app requires location access to function as it connects
passengers with nearby drivers for transportation.
Key features: price negotiation, real-time tracking, in-app chat.
```

### Step 9: Submit for Review
1. Click "Add for Review"
2. Click "Submit to App Review"
3. Apple review takes 1-3 days typically

---

## PART 4: Required Permissions Justification

Both stores require justification for permissions used:

| Permission | Justification |
|-----------|---------------|
| Location (Always) | Required to track ride in real-time and show driver position |
| Location (When in Use) | Required to show pickup location and nearby drivers |
| Camera | Used for profile photo and driver document verification |
| Push Notifications | Trip status updates, driver arrival, chat messages |
| Microphone | Voice messages in chat (if implemented) |

### iOS Info.plist Keys (already configured):
- `NSLocationWhenInUseUsageDescription`
- `NSLocationAlwaysAndWhenInUseUsageDescription`
- `NSCameraUsageDescription`
- `NSPhotoLibraryUsageDescription`

---

## PART 5: Pre-Launch Checklist

- [ ] Screenshots captured for all required device sizes
- [ ] Store metadata reviewed and finalized (store_metadata.md)
- [ ] Feature graphic created (1024x500 for Google Play)
- [ ] Privacy policy live at rapiteam.com/privacy
- [ ] Test accounts created for store reviewers
- [ ] AAB uploaded to Google Play Console
- [ ] IPA/Archive uploaded to App Store Connect
- [ ] Content rating questionnaires completed
- [ ] Data safety / App Privacy forms filled
- [ ] Release notes written
- [ ] Support URL working
- [ ] App runs without crashes on release build
