# Korean Input Testing Guide

## Issue
Korean input may not work properly in iOS Simulator or Android Emulator during testing.

## Solutions

### iOS Simulator
1. Open iOS Simulator
2. Go to Device > Keyboard menu
3. Enable "Connect Hardware Keyboard" (toggle it if already enabled)
4. Go to Settings app in the simulator
5. General > Keyboard > Keyboards > Add New Keyboard
6. Select Korean keyboard
7. When testing, use Globe key or Command+Space to switch input methods

### Android Emulator
1. Open Android Emulator
2. Go to Settings > System > Languages & input
3. Virtual keyboard > Gboard
4. Languages > Add Korean
5. When testing, long press spacebar or use the language switch key

### Alternative Testing Methods
1. **Use Physical Device**: Best option for testing Korean input
2. **Copy-Paste Method**: Copy Korean text from elsewhere and paste into fields
3. **Programmatic Input in Tests**: Use `enterText()` with Korean strings directly

### Test Example
```dart
// In your test files, you can directly input Korean text:
await tester.enterText(find.byType(TextField).first, '테스트 상품명');
await tester.enterText(find.byType(TextField).at(1), '이것은 한국어 설명입니다');
```

### Flutter App Configuration
The app already supports Korean input properly with:
- No input formatters blocking Korean characters
- UTF-8 encoding support
- No character restrictions on title/description fields

## Note
The issue is typically with the simulator/emulator keyboard configuration, not the Flutter app itself. The app will work correctly with Korean input on real devices.