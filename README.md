# ASA 5505 RE-PURPOSING

## Purpose And Initial Premise

The purpose of this project is to see whether I could run Mikrotik's Router OS (or any custom code) on a locked-down ASA 5505. 

I originally had bought/acquired a whole bunch of Cisco equipment on EBay for CCNA studies and was going to re-sell it when I came across this article on Medium: https://medium.com/@DomPolizzi/install-opnsense-and-linux-on-cisco-asa-59995dd6d60f. 

As the article showed a pretty easy way of getting into the bootloader via VGA pin headers, I wondered if I could do the same with an ASA 5505 I had on hand. As I'm currently in the midst of upgrading my homelab with Mikrotik switches and came to be interested in RouterOS' capabilities, I wondered if I could re-purpose the device as a small travel firewall.

However, when opening up the device and doing some research online, I got to learn that the older ASA models (5505 included), don't expose VGA pins and I wanted to see if I could bypass it. This entire repository is the chaos that followed over the next several weeks.

**Note: While I'd like to organize all of this into a wiki once finished, I'm currently jotting everything here as I hadn't been keeping everything together
in one place and wanted to get it all down while it was still fresh.**

## SOFTWARE (DEVICE BOOT PROCESS)

**EMBEDDED BIOS -> ROMMON -> CISCO ASA**

While the Cisco ASA software itself drives the firewall, it isn't the only piece in the boot process. Cisco ASA is itself an OS in the form of a .bin (binary) file that's loaded by an on-chip firmware called **ROMMON**. This chip is responsible for both booting the OS and providing recovery in case the ASA OS is un-authentic or corrupted. The downside with this firmware though is that it is only designed to boot Cisco-provided firmware images and we can't overwrite it as a bootloader.

While delving into how I could find a way around ROMMON, I was able to track down some documentation regarding the BIOS in use (see included bios documentation). Specifically, it looks to be a piece of embedded software called, quite-literally, **EMBEDDED SOFTWARE** and it was produced by a company (General Software, Inc.) that has since been bought out. 

While the version on-board the device is much older [1.0(12)13] than the 4.1 or 4.3 documentation I found, it still pretty essential in that I'm not able to find anything else with regards to the BIOS software (or the included debugger).