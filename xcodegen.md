# XcodeGen setup

This project uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the `.xcodeproj` file from `project.yml`.

## Setup

### Prerequisites

```bash
# Install xcodegen (already installed on your machine)
brew install xcodegen
```

## Daily workflow

### Adding new files

1. Create your `.swift` file anywhere in the project folders:
   - `Murmur/` for app code
   - `MurmurTests/` for tests
   - `MurmurWidgets/` for widget code

2. Regenerate the project:
   ```bash
   xcodegen generate
   ```

3. Open in Xcode (it will reload automatically if already open)

### Making project changes

Edit `project.yml` instead of using Xcode project settings. Common changes:

**Update version:**
```yaml
settings:
  base:
    MARKETING_VERSION: "1.4"  # ← Change this
```

**Add a new target:**
```yaml
targets:
  MyNewTarget:
    type: application
    platform: iOS
    sources:
      - path: MyNewTarget
```

**Add SPM packages:**
```yaml
packages:
  Alamofire:
    url: https://github.com/Alamofire/Alamofire
    version: 5.8.0
```

Then regenerate:
```bash
xcodegen generate
```

## Git workflow

The `.gitignore` is configured to:
- Ignore `.xcodeproj/project.pbxproj` (auto-generated)
- Commit `project.yml` (source of truth)
- Commit workspace settings (shared schemes, breakpoints)

## Project structure

```
project.yml          ← Project definition (commit this)
Murmur.xcodeproj/    ← Generated (ignored in git)
Murmur/              ← App source files
MurmurTests/         ← Test files
MurmurWidgets/       ← Widget extension
```

## Advanced

### Custom build settings per target

```yaml
targets:
  Murmur:
    settings:
      base:
        CUSTOM_SETTING: value
      configs:
        Debug:
          CUSTOM_SETTING: debug_value
        Release:
          CUSTOM_SETTING: release_value
```