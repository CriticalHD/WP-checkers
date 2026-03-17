# Write Protect Informational Script

This script includes multiple WP checks and confirmations

It is mostly an informational tool with the added exception of the payload menu

How do I run this script ?

````
curl -sSL https://raw.githubusercontent.com/CriticalHD/WP-checkers/refs/heads/main/CB-WP | bash
````

<img width="350" height="750" alt="image" src="https://github.com/user-attachments/assets/4832a477-f4af-42b8-9424-75a58fdcd7d2" />

**This is what it can look like**

## Latest Update V40-V43

- Fixed Log not downloading to downloads ***(You most likely need to be signed in)***
- Added several log details (HWID, MODEL, SERIAL, CHROMEOSVER, TPMKERNVER. And more)
- Added more details to the script itself
- Went through 23 revisions
- Fixed crossystem diagnostics not being true
- Added details to the crossystem dev_boot_usb (fixing and gbb)
