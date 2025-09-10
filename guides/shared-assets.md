# Shared Assets Directory

## Overview
The `~/FoundryVTT-Data/shared-assets/` directory contains media files (images, audio, PDFs, etc.) that are shared across all Foundry VTT versions. This eliminates the need to duplicate large asset libraries when upgrading or testing different Foundry versions.

## How It Works
- **Docker Mount**: Each Foundry container mounts `shared-assets/` as `/data/Data/assets/` inside the container
- **Version Independence**: All Foundry versions (v12, v13, future versions) see the same asset library
- **Automatic**: No symlinks or manual copying required—handled entirely by Docker

## Usage
- **Add assets**: Place files directly in `~/FoundryVTT-Data/shared-assets/` and subdirectories
- **Organization**: Organize however you prefer (by campaign, type, source, etc.)
- **Access**: Assets appear in Foundry's file browser under the normal `/assets/` path
- **Backup**: Assets are included in all backup scripts automatically

## Benefits
- **Space Efficient**: No duplicate asset files across Foundry versions
- **Easy Upgrades**: New Foundry versions instantly have access to your entire asset library
- **Single Management**: Update/organize assets in one place for all versions