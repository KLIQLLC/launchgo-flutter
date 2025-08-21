# Setup Build Phase for Google Service Info

## Steps to add the build phase in Xcode:

1. Open `ios/Runner.xcworkspace` in Xcode

2. Select the **Runner** project in the navigator

3. Select the **Runner** target

4. Go to the **Build Phases** tab

5. Click the **+** button at the top left

6. Select **New Run Script Phase**

7. Rename it to "Copy GoogleService-Info"

8. Drag it to be **BEFORE** the "Compile Sources" phase

9. In the script field, add:
```bash
"${PROJECT_DIR}/Scripts/copy_google_service_info.sh"
```

10. Make sure "Based on dependency analysis" is UNCHECKED

11. Save the project (Cmd+S)

## What this does:
- When building with `com.launchgo.stage` → uses `GoogleService-Info-stage.plist`
- When building with `com.launchgo.app` → uses `GoogleService-Info-prod.plist`

## Next Steps:
1. Download the GoogleService-Info.plist for `com.launchgo.app` from Firebase
2. Save it as `ios/Runner/GoogleService-Info-prod.plist`
3. Build and test both configurations