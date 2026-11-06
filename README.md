# EFIs for Hackintosh 🍎

A curated, battle-tested archive of OpenCore EFI configurations for macOS Hackintosh installations. 

Maintained by **[dularacharith](https://github.com/dularacharith)** as a reliable backup and reference repository to safely restore, maintain, and duplicate working configurations across different macOS releases.

---

## 📂 Repository Structure

```text
EFIs-for-Hackintosh/
├── README.md                      # Main repository documentation & guide
├── .gitignore                     # Ignores macOS metadata, DS_Store, and temporary files
└── Ventura/                       # macOS Ventura (13.x) Configuration
    ├── README.md                  # Comprehensive documentation for Ventura EFI
    ├── EFI/
    │   ├── BOOT/
    │   │   └── BOOTx64.efi        # OpenCore bootloader entry point
    │   └── OC/
    │       ├── ACPI/              # Custom compiled DSDT/SSDT patches
    │       ├── Drivers/           # UEFI drivers (OpenRuntime, HfsPlus, OpenCanopy, etc.)
    │       ├── Kexts/             # Kernel extensions (Lilu, WhateverXe, AppleALC, etc.)
    │       ├── Resources/         # OpenCanopy graphical bootloader assets
    │       ├── Tools/             # Diagnostic tools
    │       ├── OpenCore.efi       # Main OpenCore EFI binary
    │       └── config.plist       # Working OpenCore configuration
    └── Utilities/
        └── clamshell-fix/         # Source code & installer for lid sleep/wake fix
```

---

## 💻 Supported Hardware & Configurations

| Directory | Target Machine | Processor & Graphics | macOS Version | Key Highlight |
| :--- | :--- | :--- | :--- | :--- |
| **[`Ventura/`](./Ventura)** | **Acer Swift 3 SF314-511** | Intel Core i7-1165G7 (Iris Xe GT2 `0x9A49`) | macOS Ventura (13.7.8+) | Fixed Iris Xe display sleep black screen deadlock, Realtek ALC255 clean audio (`alcid=3`), and clamshell lid wake fix. |

---

## ⚡ How to Deploy / Flash an EFI

### 1. Mount the EFI (ESP) Partition
On macOS, open Terminal and mount your physical EFI partition (typically `disk0s1` on internal storage):

```bash
# Identify your EFI disk identifier (usually disk0s1)
diskutil list

# Mount the EFI partition
diskutil mount disk0s1
```

### 2. Backup Your Existing EFI
Before making any changes, always backup your current EFI folder:
```bash
cp -r "/Volumes/EFI/EFI" ~/Desktop/EFI_Backup_$(date +%Y%m%d)
```

### 3. Copy the New EFI
Copy the `BOOT` and `OC` folders from the chosen OS directory to your mounted EFI partition:
```bash
# Example for Ventura
cp -r Ventura/EFI/BOOT /Volumes/EFI/EFI/
cp -r Ventura/EFI/OC /Volumes/EFI/EFI/
```

### 4. Reset NVRAM on First Boot (Crucial)
1. Restart your machine.
2. At the OpenCore boot picker menu, press the **Spacebar** to reveal auxiliary tools.
3. Select **Reset NVRAM** once.
4. Your computer will reboot automatically and load the fresh boot arguments and kernel configurations.

---

## ⚠️ Important Post-Install Notes

1. **SMBIOS Serials:**
   The `config.plist` includes a working generic SMBIOS structure (`MacBookPro16,2`). For Apple Services (iMessage, FaceTime, iCloud), generate your own unique serials using **GenSMBIOS** and insert them under `PlatformInfo -> Generic`:
   - `SystemSerialNumber`
   - `SystemUUID`
   - `MLB`
2. **FileVault & SIP:**
   Ensure SecureBootModel and CSR configurations in `config.plist` match your security requirements before enabling disk encryption.

---

## 📜 License
This repository is shared for educational and personal backup purposes. OpenCore, kexts, and ACPI patches are copyright their respective developers (Acidanthera, Dortania, DhinakG, b00t0x, etc.).
