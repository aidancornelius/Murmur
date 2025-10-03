# Murmur

A gentle iOS companion for tracking symptoms and daily patterns.

[![Download on the App Store](https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg)](https://apps.apple.com/us/app/murmur/id6753282722)

## What it does

Murmur helps you notice and understand patterns in how you feel. Whether you're managing a chronic condition, tracking symptoms, or just trying to understand what affects your wellbeing, it offers a simple way to log what's happening and see connections over time.

### Key features

- **Timeline view** - Browse your symptom history day by day
- **Quick logging** - Record symptoms with a 1-5 severity scale
- **Activity tracking** - Note events that might influence how you feel
- **Pattern analysis** - Visualise trends and potential connections
- **Reminders** - Gentle prompts to log entries when you need them
- **Manual cycle tracking** - Track menstrual cycles alongside other symptoms
- **HealthKit integration** - Connect with Apple Health data
- **Accessibility** - Voice commands, switch control, and audio graphs
- **Privacy first** - Your data stays on your device, with optional backup
- **Export options** - Share data with healthcare providers as PDFs

## Why it exists

Living with symptoms that come and go can be isolating. Murmur was built to make tracking less of a chore and more of a helpful practice. No medical jargon, no overwhelming features - just what you need to notice patterns and have better conversations with your healthcare team.

## Getting started

1. Clone this repository
2. Open `Murmur.xcodeproj` in Xcode
3. Build and run on your iOS device or simulator

The app includes an onboarding flow that will guide you through initial setup.

## Technical details

- Built with SwiftUI and Core Data
- Supports iOS 16 and later
- Integrates with HealthKit, Location Services, and Calendar
- Includes StoreKit configuration for optional tip jar support

## Privacy and data

All symptom data is stored locally using Core Data. HealthKit integration is optional and always under your control. The app includes backup and export features, but you choose when and where your data goes.

## Contributing

This is a personal health tool, but suggestions and improvements are welcome. If you've found it helpful or have ideas to make it better, please open an issue or submit a pull request.

## License

MIT License - see LICENSE file for details.

## Support

If you find Murmur helpful, the app includes an optional tip jar. There's no pressure and all features work regardless.

---

*Remember: Murmur is a tracking tool, not medical advice. Always consult with healthcare professionals about your symptoms and treatment.*
