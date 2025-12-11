# Testing on Your iPhone Before App Store

This guide explains how to test your LunaReading iOS app on your physical iPhone before publishing to the App Store.

## Prerequisites

1. **Apple ID** (free or paid developer account)
2. **iPhone** with iOS 15.0 or later
3. **USB cable** to connect iPhone to Mac
4. **Xcode** installed on your Mac

## Option 1: Free Apple Developer Account (Recommended for Testing)

You can test on your iPhone for free using your personal Apple ID. No paid developer account needed for basic testing.

### Step 1: Connect Your iPhone

1. Connect your iPhone to your Mac using a USB cable
2. Unlock your iPhone
3. If prompted, tap **"Trust This Computer"** on your iPhone
4. Enter your iPhone passcode if asked

### Step 2: Configure Xcode Project

1. **Open your project** in Xcode
2. **Select your project** in the Project Navigator (blue icon at the top)
3. **Select the target** "LunaReadingApp" (under TARGETS)
4. Click on **"Signing & Capabilities"** tab
5. Check **"Automatically manage signing"**
6. **Select your Team:**
   - Click the dropdown under "Team"
   - Select your Apple ID (or click "Add an Account..." to add it)
   - If you see a warning, click "Try Again" or "Add Account"

### Step 3: Select Your iPhone as Destination

1. At the top of Xcode, next to the Play button, you'll see a device selector
2. Click the dropdown (it probably says "iPhone 15 Pro" or similar simulator)
3. Select your **physical iPhone** from the list (it will show your iPhone's name)

### Step 4: Build and Run

1. Click the **Play button** (▶️) or press **⌘R**
2. Xcode will:
   - Build the app
   - Install it on your iPhone
   - Launch it automatically

### Step 5: Trust Developer Certificate on iPhone

**First time only:**

1. On your iPhone, go to **Settings → General → VPN & Device Management** (or **Device Management**)
2. Tap on your Apple ID/Developer account
3. Tap **"Trust [Your Name]"**
4. Tap **"Trust"** in the confirmation dialog

### Step 6: Run the App

1. The app should now launch on your iPhone
2. If it doesn't, find the LunaReading app icon on your home screen and tap it

## Option 2: Paid Apple Developer Account ($99/year)

If you have a paid Apple Developer account, the process is the same, but you get:
- No 7-day certificate expiration (free accounts expire after 7 days)
- Ability to distribute via TestFlight
- Ability to publish to App Store

## Troubleshooting

### "No devices found"

**Solution:**
- Make sure iPhone is unlocked
- Check USB cable connection
- Try a different USB port
- Restart Xcode
- In Xcode: Window → Devices and Simulators → Check if iPhone appears

### "Failed to code sign"

**Solution:**
1. Go to Signing & Capabilities
2. Uncheck "Automatically manage signing"
3. Check it again
4. Select your Team again
5. Clean build folder: Product → Clean Build Folder (⌘ShiftK)
6. Build again

### "Untrusted Developer"

**Solution:**
- Go to Settings → General → VPN & Device Management
- Trust your developer certificate (see Step 5 above)

### "App installation failed"

**Solution:**
- Make sure your iPhone iOS version is 15.0 or later
- Check that the deployment target matches (should be iOS 15.0)
- Delete the app from iPhone and try again
- Restart both iPhone and Xcode

### Certificate Expired (Free Account)

**Solution:**
- Free accounts have 7-day certificates
- After 7 days, you need to rebuild and reinstall
- Or upgrade to paid developer account ($99/year)

## Testing Checklist

Before testing on device, make sure:

- [ ] App builds successfully in simulator first
- [ ] All API endpoints are accessible from your network
- [ ] Backend URL is correct (not localhost)
- [ ] iPhone is on the same network as backend (or backend is publicly accessible)
- [ ] iPhone has internet connection

## Network Configuration

### If Backend is on Local Network

If your backend runs on `localhost:5001` or a local IP:

1. **Find your Mac's IP address:**
   ```bash
   ifconfig | grep "inet " | grep -v 127.0.0.1
   ```
   Example: `192.168.1.100`

2. **Update APIService.swift:**
   ```swift
   private let baseURL = "http://192.168.1.100:5001"
   ```

3. **Make sure iPhone and Mac are on same Wi-Fi network**

### If Backend is Deployed (Recommended)

Your backend is already deployed at:
```
https://lunareading-backend-bkumsoprkq-uc.a.run.app
```

This should work from anywhere, so no changes needed!

## Advanced: Wireless Debugging (iOS 15+)

You can debug wirelessly after the first USB connection:

1. Connect iPhone via USB first (one time setup)
2. In Xcode: Window → Devices and Simulators
3. Select your iPhone
4. Check **"Connect via network"**
5. Disconnect USB cable
6. iPhone will appear in device list wirelessly

## Next Steps After Testing

Once you've tested on your device:

1. **Fix any bugs** you find
2. **Test all features:**
   - Login/Register
   - Create sessions
   - Answer questions
   - View history
3. **Test on different devices** (if available)
4. **Prepare for App Store** (if ready to publish)

## Publishing to App Store

When ready to publish:

1. **Upgrade to paid developer account** ($99/year) if not already
2. **Configure App Store Connect:**
   - Create app listing
   - Set up screenshots
   - Write description
3. **Archive the app:**
   - Product → Archive
4. **Upload to App Store Connect:**
   - Window → Organizer
   - Distribute App
   - Follow the wizard

## Resources

- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [TestFlight Beta Testing](https://developer.apple.com/testflight/)

---

**Note:** Free Apple Developer accounts are perfect for testing. You only need the paid account ($99/year) when you're ready to publish to the App Store or use TestFlight for beta testing.
