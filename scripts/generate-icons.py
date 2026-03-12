#!/usr/bin/env python3
"""
FlowGroove Icon Generator
Generates complete icon sets for all platforms from logo
"""

import os
import sys
import subprocess
from pathlib import Path

# Check if Pillow is available
try:
    from PIL import Image
    PILLOW_AVAILABLE = True
except ImportError:
    PILLOW_AVAILABLE = False
    print("⚠️  Pillow not installed. Install with: pip3 install Pillow")

def run_command(cmd, description=""):
    """Run a shell command"""
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        if result.returncode == 0:
            if description:
                print(f"   ✅ {description}")
            return True
        else:
            if description:
                print(f"   ❌ {description}: {result.stderr.strip()}")
            return False
    except Exception as e:
        if description:
            print(f"   ❌ {description}: {str(e)}")
        return False

def resize_image(input_path, output_path, size):
    """Resize image using Pillow"""
    if not PILLOW_AVAILABLE:
        return False
    
    try:
        with Image.open(input_path) as img:
            # Convert to RGBA if necessary
            if img.mode != 'RGBA':
                img = img.convert('RGBA')
            
            # Resize with high quality
            img_resized = img.resize((size, size), Image.Resampling.LANCZOS)
            
            # Ensure output directory exists
            os.makedirs(os.path.dirname(output_path), exist_ok=True)
            
            # Save
            img_resized.save(output_path, 'PNG')
            return True
    except Exception as e:
        print(f"   Error resizing {output_path}: {e}")
        return False

def main():
    print("🎨 FlowGroove Icon Generator")
    print("=" * 60)
    print()
    
    # Paths
    project_dir = Path(__file__).parent.parent
    logo_path = project_dir / "assets" / "logo_bckgrnd.png"
    
    # Check if logo exists
    if not logo_path.exists():
        print(f"❌ Logo not found: {logo_path}")
        print("Please ensure assets/logo_bckgrnd.png exists")
        sys.exit(1)
    
    print(f"✅ Logo found: {logo_path}")
    
    # Get logo dimensions
    if PILLOW_AVAILABLE:
        try:
            with Image.open(logo_path) as img:
                width, height = img.size
                print(f"   Size: {width}x{height} pixels")
        except Exception as e:
            print(f"   ⚠️  Could not read dimensions: {e}")
    print()
    
    # Check Pillow
    if not PILLOW_AVAILABLE:
        print("❌ Pillow library required but not installed")
        print("💡 Install with: pip3 install Pillow")
        sys.exit(1)
    
    # Create directories
    print("📁 Creating directories...")
    dirs_to_create = [
        project_dir / "android" / "app" / "src" / "main" / "res" / "mipmap-mdpi",
        project_dir / "android" / "app" / "src" / "main" / "res" / "mipmap-hdpi",
        project_dir / "android" / "app" / "src" / "main" / "res" / "mipmap-xhdpi",
        project_dir / "android" / "app" / "src" / "main" / "res" / "mipmap-xxhdpi",
        project_dir / "android" / "app" / "src" / "main" / "res" / "mipmap-xxxhdpi",
        project_dir / "android" / "app" / "src" / "main" / "res" / "mipmap-anydpi-v26",
        project_dir / "android" / "app" / "src" / "main" / "res" / "values",
        project_dir / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset",
        project_dir / "web" / "icons",
        project_dir / "assets" / "app_icons",
    ]
    
    for dir_path in dirs_to_create:
        dir_path.mkdir(parents=True, exist_ok=True)
    print("   ✅ Directories created")
    print()
    
    # Generate Android icons
    print("🤖 Generating Android icons...")
    android_sizes = {
        "mdpi": 48,
        "hdpi": 72,
        "xhdpi": 96,
        "xxhdpi": 144,
        "xxxhdpi": 192,
    }
    
    for density, size in android_sizes.items():
        output_path = project_dir / f"android/app/src/main/res/mipmap-{density}/ic_launcher.png"
        if resize_image(logo_path, output_path, size):
            print(f"   ✅ {density}: {size}x{size}")
    
    # Generate adaptive icons (Android 8.0+)
    print()
    print("📱 Generating Android adaptive icons...")
    
    # Create foreground (108x108 for safe zone)
    fg_path = project_dir / "android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_foreground.png"
    if resize_image(logo_path, fg_path, 108):
        print(f"   ✅ Foreground: 108x108")
    
    # Create adaptive icon XML
    adaptive_xml = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
"""
    adaptive_path = project_dir / "android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml"
    with open(adaptive_path, 'w') as f:
        f.write(adaptive_xml)
    print(f"   ✅ Adaptive icon XML created")
    
    # Create colors.xml
    colors_xml = """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#1A1A2E</color>
</resources>
"""
    colors_path = project_dir / "android/app/src/main/res/values/colors.xml"
    with open(colors_path, 'w') as f:
        f.write(colors_xml)
    print(f"   ✅ Background color created (#1A1A2E)")
    
    # Generate iOS icons
    print()
    print("🍎 Generating iOS icons...")
    ios_sizes = [20, 29, 40, 58, 60, 76, 83, 1024, 120, 167, 180]
    
    for size in ios_sizes:
        output_path = project_dir / f"ios/Runner/Assets.xcassets/AppIcon.appiconset/icon-{size}x{size}.png"
        if resize_image(logo_path, output_path, size):
            print(f"   ✅ {size}x{size}")
    
    # Create iOS Contents.json
    contents_json = {
        "images": [
            {"size": "20x20", "idiom": "iphone", "filename": "icon-20x20.png", "scale": "2x"},
            {"size": "20x20", "idiom": "iphone", "filename": "icon-40x40.png", "scale": "3x"},
            {"size": "29x29", "idiom": "iphone", "filename": "icon-58x58.png", "scale": "2x"},
            {"size": "29x29", "idiom": "iphone", "filename": "icon-87x87.png", "scale": "3x"},
            {"size": "40x40", "idiom": "iphone", "filename": "icon-80x80.png", "scale": "2x"},
            {"size": "40x40", "idiom": "iphone", "filename": "icon-120x120.png", "scale": "3x"},
            {"size": "60x60", "idiom": "iphone", "filename": "icon-120x120.png", "scale": "2x"},
            {"size": "60x60", "idiom": "iphone", "filename": "icon-180x180.png", "scale": "3x"},
            {"size": "20x20", "idiom": "ipad", "filename": "icon-20x20.png", "scale": "1x"},
            {"size": "20x20", "idiom": "ipad", "filename": "icon-40x40.png", "scale": "2x"},
            {"size": "29x29", "idiom": "ipad", "filename": "icon-58x58.png", "scale": "1x"},
            {"size": "29x29", "idiom": "ipad", "filename": "icon-87x87.png", "scale": "2x"},
            {"size": "40x40", "idiom": "ipad", "filename": "icon-40x40.png", "scale": "1x"},
            {"size": "40x40", "idiom": "ipad", "filename": "icon-80x80.png", "scale": "2x"},
            {"size": "76x76", "idiom": "ipad", "filename": "icon-76x76.png", "scale": "1x"},
            {"size": "76x76", "idiom": "ipad", "filename": "icon-152x152.png", "scale": "2x"},
            {"size": "83.5x83.5", "idiom": "ipad", "filename": "icon-167x167.png", "scale": "2x"},
            {"size": "1024x1024", "idiom": "ios-marketing", "filename": "icon-1024x1024.png", "scale": "1x"},
        ],
        "info": {
            "version": 1,
            "author": "xcode"
        }
    }
    
    import json
    contents_path = project_dir / "ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json"
    with open(contents_path, 'w') as f:
        json.dump(contents_json, f, indent=2)
    print(f"   ✅ Contents.json created")
    
    # Generate Web icons
    print()
    print("🌐 Generating Web icons...")
    web_sizes = [16, 32, 96, 192, 512]
    
    for size in web_sizes:
        if size in [16, 32]:
            output_path = project_dir / f"web/icons/favicon-{size}x{size}.png"
        elif size == 96:
            output_path = project_dir / f"web/icons/favicon-{size}x{size}.png"
        else:
            output_path = project_dir / f"web/icons/icon-{size}x{size}.png"
        
        if resize_image(logo_path, output_path, size):
            print(f"   ✅ {size}x{size}")
    
    # Update web manifest
    print()
    print("📝 Updating web manifest...")
    manifest = {
        "name": "FlowGroove - Band Repertoire Manager",
        "short_name": "FlowGroove",
        "start_url": ".",
        "display": "standalone",
        "background_color": "#1A1A2E",
        "theme_color": "#1A1A2E",
        "description": "FlowGroove - Band Repertoire Management for Cover Bands",
        "orientation": "portrait-primary",
        "prefer_related_applications": False,
        "icons": [
            {"src": "icons/icon-192x192.png", "sizes": "192x192", "type": "image/png"},
            {"src": "icons/icon-512x512.png", "sizes": "512x512", "type": "image/png"},
            {"src": "icons/favicon-96x96.png", "sizes": "96x96", "type": "image/png"},
        ]
    }
    
    manifest_path = project_dir / "web" / "manifest.json"
    with open(manifest_path, 'w') as f:
        json.dump(manifest, f, indent=4)
    print(f"   ✅ manifest.json updated")
    
    # Create backup copies
    print()
    print("💾 Creating backup copies in assets/...")
    backup_copies = [
        ("android/app/src/main/res/mipmap-hdpi/ic_launcher.png", "android_hdpi.png"),
        ("ios/Runner/Assets.xcassets/AppIcon.appiconset/icon-1024x1024.png", "ios_1024.png"),
        ("web/icons/icon-512x512.png", "web_512.png"),
    ]
    
    for src, dst in backup_copies:
        src_path = project_dir / src
        dst_path = project_dir / "assets" / "app_icons" / dst
        if src_path.exists():
            import shutil
            shutil.copy2(src_path, dst_path)
            print(f"   ✅ {dst}")
    
    # Summary
    print()
    print("=" * 60)
    print("✅ Icon generation COMPLETE!")
    print()
    print("📊 Generated icons:")
    print(f"   Android: {len(android_sizes)} densities + adaptive icons")
    print(f"   iOS: {len(ios_sizes)} sizes")
    print(f"   Web: {len(web_sizes)} icons (including favicons)")
    print()
    print("📁 Output directories:")
    print("   - android/app/src/main/res/mipmap-*/")
    print("   - ios/Runner/Assets.xcassets/AppIcon.appiconset/")
    print("   - web/icons/")
    print("   - assets/app_icons/ (backup)")
    print()
    print("📝 Next steps:")
    print("   1. ✅ Icons generated for all platforms")
    print("   2. Test on devices")
    print("   3. Update AndroidManifest.xml if needed")
    print()
    print("🎨 Icons ready for deployment!")

if __name__ == "__main__":
    main()
