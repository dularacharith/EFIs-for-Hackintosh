# OpenCore EFI for Acer Swift 3 (SF314-511) - macOS Ventura 13.x

A fully tuned, battle-tested OpenCore configuration for the **Acer Swift 3 SF314-511** running **macOS Ventura (13.7.8+)**.

---

## 💻 Hardware Specifications

| Component | Hardware Details | Status |
| :--- | :--- | :--- |
| **Laptop Model** | Acer Swift 3 SF314-511 | Supported |
| **Processor (CPU)** | Intel Core i7-1165G7 (4 Cores / 8 Threads, up to 4.70 GHz) | ✅ Working (Native PM) |
| **Integrated Graphics** | Intel Iris Xe Graphics G7 96EUs (`0x9A498086`) | ✅ Working (Metal 3D Acceleration via WhateverXe) |
| **Audio Codec** | Realtek ALC255 (`0x10EC0255`) | ✅ Working (Layout ID `3`, Clean Stereo) |
| **Microphone** | Intel Tiger Lake Digital Mic Array | ✅ Working (via `TGLDmic.kext`) |
| **Storage (NVMe)** | Micron 3400 PCIe 4.0 NVMe SSD (`MTFDKBA512TFH`) | ✅ Working (via `NVMeFix.kext`) |
| **Wi-Fi** | Intel Wi-Fi 6 AX201 160MHz (CNVi) | ✅ Working (via `AirportItlwm.kext`) |
| **Bluetooth** | Intel Wireless Bluetooth 5.2 | ✅ Working (via `IntelBluetoothFirmware` + `BlueToolFixup`) |
| **Trackpad** | I2C HID Multitouch Trackpad | ✅ Working (Native macOS Gestures) |
| **Keyboard** | Internal PS/2 Keyboard with Backlight | ✅ Working |
| **Display Panel** | 14" Full HD (1920x1080) 60Hz eDP IPS Panel | ✅ Working (Smooth Brightness Control) |
| **Battery Management** | Smart Battery Controller | ✅ Working (Percentage & Health Tracking) |
| **USB Ports** | Custom Mapped XHCI + Type-C | ✅ Working (via `UTBMap.kext`) |
| **Fingerprint Reader**| EgisTec EH575 (`0x1c7a:0x0575`) | ❌ Unsupported (Requires Apple T2/M-series Secure Enclave) |

---

## 🚀 Boot Arguments Explained

Below is the complete list of boot arguments injected in `NVRAM -> Add -> 7C436110-AB2A-4BBB-A880-FE41995C9F82 -> boot-args`:

```text
-v -dbgenhdbg debug=0x100 keepsyms=1 -allow3d -disablegfxfirmware -igfxdvmt -vi2c-force-polling npci=0x2000 -tgldmic -tgldmickeep darkwake=0 -nodisplaysleepDC6 -noDC9 dc6config=0 alcid=3
```

### Detailed Breakdown

| Boot Argument | Component | Exact Technical Purpose |
| :--- | :--- | :--- |
| **`-nodisplaysleepDC6`** | `AppleIntelTGLGraphicsFramebuffer` | **Critical Display Sleep Fix:** Sets internal driver offset `0xc29 = 0`. Prevents the Tiger Lake display controller from requesting hardware DC6 power gating when the display sleeps. |
| **`-noDC9`** | `AppleIntelTGLGraphicsFramebuffer` | **Critical Display Sleep Fix:** Sets internal driver offset `0xc2a = 0`. Prevents `clientNotify` from shutting off display power wells (`overridePowerWellsState(false)`) and cutting interrupts (`hwDisableInterrupts()`), which Apple's driver never properly re-enabled on wake, causing permanent black screens. |
| **`dc6config=0`** | `AppleIntelTGLGraphicsFramebuffer` | **Critical Display Sleep Fix:** Sets internal driver offset `0xb48 = 0`. Permanently neutralizes all 16 `enableHWDC6` call sites across the graphics stack, preventing firmware hangs. |
| **`alcid=3`** | `AppleALC` | **Audio Fix:** Selects Realtek ALC255 Layout ID 3 (`Mirone Laptop Patch`). Directly routes clean 2-channel stereo to speakers and headphones, eliminating the hollow/reverb phase cancellation caused by layout 23 and 30. |
| **`-allow3d`** | `WhateverXe` | Unlocks Metal 3D hardware acceleration for Intel Iris Xe GT2 graphics in macOS Ventura. |
| **`-disablegfxfirmware`** | `WhateverXe` | Disables loading Intel GuC/HuC/DMC graphics firmware. Prevents the boot hang caused by macOS attempting to initialize non-existent firmware blobs on Tiger Lake. |
| **`-igfxdvmt`** | `WhateverXe` | Bypasses DVMT pre-allocated memory size assertion checks in the driver, ensuring boot succeeds even if laptop BIOS has locked DVMT to 32MB or 64MB. |
| **`-vi2c-force-polling`** | `VoodooI2C` | Forces polling mode for I2C HID trackpad, resolving interrupt storm timeouts and stuttering on Intel Tiger Lake LPSS I2C controllers. |
| **`npci=0x2000`** | macOS Kernel | Prevents PCI configuration space mapping deadlocks during PCI root bridge enumeration. |
| **`-tgldmic`** | `TGLDmic` | Enables the digital microphone audio pipeline on Intel Tiger Lake platforms. |
| **`-tgldmickeep`** | `TGLDmic` | **Critical VoIP & Mic Retention Fix:** Keeps the Intel Smart Sound (cAVS 2.5) DSP core running and keeps the Sound Open Firmware (SOF) DMA ring buffers permanently mapped in memory below 4GB. Without this, TGLDmic powers down the DSP after boot; subsequent on-demand DSP wake attempts fail contiguous physical DMA allocation (`FAIL DMA alloc (<4GB contiguous)`) due to macOS memory fragmentation, completely breaking CoreAudio `AUVoiceProcessingIO` and causing silent/dropped audio in WhatsApp and FaceTime calls. |
| **`darkwake=0`** | Power Management | Forces immediate full display wake upon any system wake event. |
| **`-v`** | macOS Kernel | Verbose boot output (displays startup log on screen for troubleshooting). |
| **`debug=0x100`** | macOS Kernel | Disables auto-reboot on kernel panic, keeping panic details visible on screen. |
| **`keepsyms=1`** | macOS Kernel | Preserves debug symbols during crashes for complete, readable call stack traces. |
| **`-dbgenhdbg`** | `DebugEnhancer` | Directs extended kernel debug messages to the console log. |

---

## 🛠️ OpenCore Quirks Breakdown

### Kernel Quirks
* **`AppleXcpmCfgLock = True`**: Bypasses MSR `0xE2` lock on Acer laptop BIOS, enabling native XCPM CPU power management.
* **`ProvideCurrentCpuInfo = True`**: Injects correct CPU frequency scaling tables for 11th Gen Tiger Lake (`Core i7-1165G7`).
* **`DisableRtcChecksum = True`**: Prevents CMOS checksum reset errors on reboot by avoiding RTC memory offsets `0x58–0x59`.
* **`DisableIoMapper = True`**: Bypasses VT-d I/O mapping conflicts when VT-d is enabled in the BIOS.
* **`PanicNoKextDump = True`**: Prevents kext list spam from scrolling panic logs off screen.
* **`PowerTimeoutKernelPanic = True`**: Catches device driver power management timeouts during sleep/wake.

### Booter Quirks
* **`RebuildAppleMemoryMap = True`**: Rebuilds the memory map to comply with macOS kernel expectations.
* **`SyncRuntimePermissions = True`**: Fixes UEFI runtime permissions for proper memory handoff.
* **`SetupVirtualMap = True`**: Maps virtual memory regions for UEFI services.
* **`ProtectUefiServices = True`**: Protects UEFI runtime memory regions from being overwritten by macOS.
* **`AvoidRuntimeDefrag = True`**: Prevents runtime memory fragmentation during boot services.

---

## 🧩 ACPI SSDTs Overview

Located in `EFI/OC/ACPI/`:

| SSDT | Functionality |
| :--- | :--- |
| **`SSDT-PLUG.aml`** | Injects `plugin-type = 1` into the first CPU core (`PR.CPU0`) for native Intel XCPM power management. |
| **`SSDT-EC.aml`** | Injects an Apple-compatible Embedded Controller (`EC`) while keeping the OEM ACPI EC intact. |
| **`SSDT-USBX.aml`** | Injects USB power properties (`kUSBSleepPowerSupply`, `kUSBWakePowerSupply`) for USB port charging. |
| **`SSDT-RTCAWAC.aml`** | Enables the legacy RTC device by setting `STAS = 1` for `_OSI("Darwin")`. |
| **`SSDT-PNLF.aml`** | Injects backlight control device `PNLF` for smooth internal display brightness adjustment. |
| **`SSDT-GPI0.aml`** | Enables the Intel GPIO controller for VoodooI2C trackpad communication. |
| **`SSDT-XOSI.aml`** | Routes `_OSI` calls to modern Windows versions, ensuring Acer EC provides full hardware feature sets. |
| **`SSDT-ALS0.aml`** | Provides dummy Ambient Light Sensor for backlight level saving. |
| **`SSDT-SBUS.aml`** | Injects System Management Bus (`SBUS`) controller for accurate SMBus device detection. |
| **`SSDT-MCHC.aml`** | Fixes Intel DRAM controller device detection. |
| **`SSDT-USB-Reset.aml`**| Resets USB controller hub ports on boot. |

---

## 💤 Sleep & Clamshell Management (Tiger Lake & Micron 3400 NVMe)

### The Hardware Context
Intel 11th Gen Tiger Lake laptops do not support legacy ACPI S3 sleep in their UEFI firmware; they rely exclusively on **Modern Standby (S0ix)**. Additionally, the **Micron 3400 NVMe SSD** drops PCIe bus communication when forced into legacy S3 sleep, causing `Sleep Wake failure in EFI (0x0000001f)` reboots.

### The Solution Included
1. **Power Management (`pmset`) Settings:**
   ```bash
   sudo pmset -a sleep 0 displaysleep 5 standby 0 autopoweroff 0 powernap 0 proximitywake 0 tcpkeepalive 0 womp 0
   ```
2. **`clamshell-fix` Daemon (Located in `Utilities/clamshell-fix/`):**
   - Asserts `PreventSystemSleep` while allowing `PreventDisplaySleep = 0`.
   - **Lid Close:** Display turns off completely and locks the session. CPU idles in deep C-states ($<1\text{ W}$, fans off).
   - **15-Second Timeout:** Blocks macOS `powerd` from triggering the broken `Clamshell Sleep`.
   - **Lid Open:** Display powers back on **instantly to your Lock Screen** with **zero reboots or crashes**.

To install or reinstall the clamshell fix on a fresh setup:
```bash
cd Utilities/clamshell-fix
./install.sh
```

---

## 🔊 Audio & Microphone Configuration

* **Codec:** Realtek ALC255 (`0x10EC0255`)
* **Selected Layout:** **`alcid=3`** (Mirone Laptop Patch)
* **Pin Configuration:** Pure 2-channel stereo to internal speakers and 3.5mm combo jack.
* **Why Layout 3?** Layout 30 (Xiaomi Air) has muted speaker routing on Acer laptops. Layout 23 configures a differential subwoofer pin that causes an out-of-phase "hollow/reverb" effect. Layout 3 provides clean, balanced, phase-accurate stereo audio.
* **Internal Digital Microphone:** Intel Tiger Lake Smart Sound Technology (SST) Digital Microphone Array via `TGLDmic.kext` and CoreAudio HAL plugin `TGLDmic.driver`.
* **VoIP Calling & Low-Memory DMA Retention (`-tgldmickeep`):**
  - **The Root Cause:** WhatsApp, FaceTime, and WebRTC apps use `AUVoiceProcessingIO` (Apple's full-duplex echo cancellation audio unit). Without `-tgldmickeep`, `TGLDmic` powers down the Intel SST DSP core after idle. When WhatsApp initiates a call, TGLDmic attempts to re-boot the DSP by allocating 512 KB of contiguous physical memory below 4 GB (`IOMallocContiguous`). Because macOS memory fragments over normal uptime, this allocation fails (`FAIL DMA alloc (<4GB contiguous)`), returning `kIOReturnNoDevice` (`0xe00002c0`). This aborts CoreAudio's `AUVoiceProcessingIO` work loop with error `2003329396` ('what'), leaving WhatsApp's sound port as `nullptr` so neither party can hear anything.
  - **The Fix:** Injecting `-tgldmickeep` keeps the DSP core running and the early-boot DMA buffers mapped permanently. Voice calls connect immediately with two-way audio.
* **Virtual Audio Routing & Volume Sync (Boom 3D / eqMac):**
  - **The Problem:** When running virtual audio enhancers like **Boom 3D**, macOS volume keys (F11/F12) and Control Center sliders adjust only the virtual driver (`BoomAudio`). Boom 3D locks the physical speakers (`Built-in Output`) at a fixed high volume. Because WhatsApp and FaceTime bypass virtual audio drivers for hardware echo cancellation, call audio plays directly through `Built-in Output`, remaining permanently stuck at maximum volume regardless of key presses.
  - **The Workaround (`boom-volume-sync`):** We developed an ultra-lightweight, 0.0% CPU CoreAudio daemon located in `Utilities/boom-volume-sync/`. It listens to real-time CoreAudio property changes on `BoomAudio` (`kAudioHardwareServiceDeviceProperty_VirtualMainVolume` and `kAudioDevicePropertyMute`) and instantly mirrors them to the hardware DAC (`Built-in Output`). Whenever you adjust volume keys or the slider, both Boom 3D and WhatsApp calls change volume in perfect sync.
  - **Installation:**
    ```bash
    cd Utilities/boom-volume-sync
    chmod +x install.sh
    ./install.sh
    ```

---

## 🔒 Display Sleep & GPU Stability (Tiger Lake eDP & Background Compute)

### 1. Display Sleep & Instant Wake (`displaysleep 5`)
* **The Problem:** By default on Tiger Lake Iris Xe graphics, when the display goes to sleep, the display controller enters DC6/DC9 power gating and shuts off display power wells. On wake, Apple's driver never properly re-arms the panel link, leaving the monitor permanently black.
* **The Solution:** We patched the kernel boot arguments:
  ```text
  -nodisplaysleepDC6 -noDC9 dc6config=0
  ```
  These boot arguments prevent the display controller from entering the un-wakeable DC6/DC9 sleep states. Combined with `clamshell-fix` (which asserts `PreventSystemSleep`), the display backlight powers down completely after 5 minutes of idle time (`displaysleep 5`), and wakes up **instantly to your Lock Screen** upon touching any key or the trackpad.

### 2. MediaAnalysis Background GPU Hang & Watchdog Panic
* **The Problem:** Background daemons `mediaanalysisd` and `photoanalysisd` submit Metal compute analysis passes that hang the Intel Iris Xe GPU command ring (`Hardware context ID 733`), generating repeated `Kernel.gpuRestart` events. WindowServer freezes waiting for the GPU, and after 120 seconds `watchdogd` panics the kernel with:
  `userspace watchdog timeout: no successful checkins from WindowServer in 120 seconds`.
* **The Solution:** Permanently disable these background visual analysis daemons from running Metal compute kernels:
  ```bash
  launchctl disable gui/$(id -u)/com.apple.mediaanalysisd
  launchctl disable gui/$(id -u)/com.apple.photoanalysisd
  launchctl bootout gui/$(id -u)/com.apple.mediaanalysisd 2>/dev/null || true
  launchctl bootout gui/$(id -u)/com.apple.photoanalysisd 2>/dev/null || true
  ```

---

## 🎹 Bitwig Studio on Intel Iris Xe

* **Bitwig 5.2+ and 6.x:** Switched to Google Skia with a mandatory Metal backend (`skia-metal`). On Intel Tiger Lake Iris Xe graphics, the Apple Metal driver (`AppleIntelTGLGraphicsMTLDriver`) fails to handle Skia's stencil attachment views and path covers, causing the main window to render as an empty/unresponsive grey canvas.
* **Recommended & Working Version:** **Bitwig Studio 5.0.4**. This version natively uses **Cairo and Pixman CPU 2D vector rasterization** (`libcairo-graphics.jnilib`), completely bypassing Metal shader/stencil driver bugs. It runs smoothly with 100% functional UI on Intel Iris Xe graphics.

---

## 📹 Camera & WhatsApp / WebRTC Video Calling Fix

### The Problem
When using **WhatsApp Desktop** (or other WebRTC-based video calling apps), the application crashed instantly upon initiating a video call or camera preview with:
```text
Crashed Thread: cmio.figcapturestream.emitsamplebuffer.queue
Exception Type: EXC_BAD_ACCESS (SIGSEGV)
Exception Codes: KERN_INVALID_ADDRESS at 0x0000000000000008
```

* **Why FaceTime Worked:** FaceTime natively accepts raw camera video frames (`NV12 / 420v`) and renders them directly via Metal 3D textures (`AppleIntelTGLGraphicsMTLDriver`).
* **Why WhatsApp Crashed:** WhatsApp requires 32-bit `BGRA` frames. macOS delegates the live camera color-space conversion (`FigCaptureVideoConverter`) to the hardware video acceleration bundle: `/Library/GPUBundles/AppleIntelTGLGraphicsVADriver.bundle`. Because Tiger Lake video acceleration was never officially finished by Apple, this driver dereferences a NULL pointer (`0x0000000000000008`) in `AVD_DestroyAVDAccelerator`.

### The Solution
Disable the crashing Video Acceleration bundle so macOS automatically falls back to CPU software pixel format conversion (which is rock-solid and takes practically zero CPU on the Core i7-1165G7):

```bash
sudo mv /Library/GPUBundles/AppleIntelTGLGraphicsVADriver.bundle /Library/GPUBundles/AppleIntelTGLGraphicsVADriver.bundle.disabled
sudo killall -9 VTDecoderXPCService VDCAssistant UVCAssistant 2>/dev/null || true
```

* Metal 3D acceleration (`AppleIntelTGLGraphicsMTLDriver.bundle`), desktop animations, and FaceTime remain **100% active**.
* WhatsApp video calls work smoothly with the webcam.

A 1-click script is provided in `Utilities/camera-fix/fix-camera-crash.sh`.

