# ASA 5505 RE-PURPOSING

## Purpose And Initial Premise

The purpose of this project is to see whether I could run Mikrotik's Router OS (or any custom code) on a locked-down ASA 5505. 

I originally had bought/acquired a whole bunch of Cisco equipment on EBay for CCNA studies and was going to re-sell it when I came across this article on [Medium](https://medium.com/@DomPolizzi/install-opnsense-and-linux-on-cisco-asa-59995dd6d60f).

As the article showed a pretty easy way of getting into the bootloader via VGA pin headers, I wondered if I could do the same with an ASA 5505 I had on hand. As I'm currently in the midst of upgrading my homelab with Mikrotik switches and came to be interested in RouterOS' capabilities, I wondered if I could re-purpose the device as a small travel firewall.

However, when opening up the device and doing some research online, I got to learn that the older ASA models (5505 included), don't expose VGA pins and I wanted to see if I could bypass it. This entire repository is the chaos that followed over the next several weeks.

**Note: While I'd like to organize all of this into a wiki once finished, I'm currently jotting everything here as I hadn't been keeping everything together
in one place and wanted to get it all down while it was still fresh.**

## SOFTWARE (DEVICE BOOT PROCESS)

**EMBEDDED BIOS -> ROMMON -> CISCO ASA**

While the Cisco ASA software itself drives the firewall, it isn't the only piece in the boot process. Cisco ASA is itself an OS in the form of a .bin (binary) file that's loaded by an on-chip firmware called **ROMMON**. This chip is responsible for both booting the OS and providing recovery in case the ASA OS is un-authentic or corrupted. The downside with this firmware though is that it is only designed to boot Cisco-provided firmware images and we can't overwrite it as a bootloader.

While delving into how I could find a way around ROMMON, I was able to track down some documentation regarding the BIOS in use. Specifically, it looks to be a piece of embedded software called, quite-literally, **EMBEDDED SOFTWARE** and it was produced by a company (General Software, Inc.) that has since been bought out. 

While the version on-board the device is much older [1.0(12)13] than the 4.1 or 4.3 documentation I found, it still pretty essential in that I'm not able to find anything else with regards to the BIOS software (or the included debugger).

## POTENTIAL WEAKSPOTS AND PREVIOUS ATTEMPTS

### BOARD INTERFACES

#### DISCOVERED JTAG INTERFACE?

While disassembling the device, I came across a series of pins (curiously hidden under a barcode) that I thought was originally a place where I could solder VGA pins. (At the time, I was thinking this model just didn't have them like the others did). 

However, upon further research, I determined that it was actually a [**JTAG**](/board_layout/board_layout.png) interface (see #3), an interface standard that came out in the late 80s/early 90s to simplfy board testing. While used for board testing, the interface also had the benefit in it provided access to all of the signals on all traces on the device's motherboard.

#### UNIDENTIFIED INTERFACES (POTENTIAL UART?)

At the same time, following the quick hardware hacking introduction included [here](/hardware_hacking_references/Hardware.Hacking.Methodology-Jeremy.Brun-v1.0.pdf), I also did various voltage tests against a manner of many other pins located around the JTAG interface and main CPU (in an attempt to look for a UART interface). However, I wasn't able to find any voltage that would've indicated transmit, receive, or Vcc pins. Even on bootup, none of the other interfaces produced a fluctuating voltage that would've indicated the movement of data (logging specifically). See [here](/board_layout/board_pins.txt) for a rough notepad logging of results.

I also tested the JTAG interface and tried to match it using an, admittedly, older guide found [here]("http://www.jtagtest.com/pinouts/") but I wasn't able to find a matching format. It was no surprise that I couldn't match it up as this was Cisco and, as I learned, x86 JTAG interfaces were harder to access. I would've potentially needed an expensive and specialized device but I didn't research that far into it for reasons listed below.

#### PUSHING IT ASIDE

While I had looked into the possibility of utilizing hardware hacking techniques to access the device (even just to pull firmware at least), I've stayed away from it roughly due to not wanting to break or damage the hardware. I don't have a lot of experience when it comes to hardware hacking and I've had a tendency in the past to break hardware pretty easily doing just doing repairs on stuff. 

While I could find another ASA 5505 to purpose, I'd rather still have the original device as finding a purpose for that specific device was the goal of the project. This was just due to me having it on-hand at the time.

With that in mind, this became a last resort. At the same time, I read online that a lot of JTAG interfaces are disabled and I have a feeling that Cisco's done this as well given how locked down everything else of their's is. 

However, curiously, they did have a barcode placed over the pinholes and ... it doesn't make sense to cover up something that doesn't allow access to anything....

### SUBVERTING THE BOOT PROCESS

While looking online initially to see if others had done something similar, I came across the following articles: 

- https://www.rapid7.com/blog/post/2016/06/14/asa-hack/
- https://www.nccgroup.com/us/research-blog/cisco-asa-series-part-one-intro-to-the-cisco-asa/

#### MODIFYING ASA FIRMWARE IMAGES FOR ROOT SHELL

The first article caught my eye as it showcased how easy it would be to modify an ASA OS image to boot into a root shell. All you had to do was load the firmware image in a hex editor, update some linux kernel parameters (it used linux?), load the firmware on the device, and power it on. In doing so, you were able to access a root shell that provided access to the system before the Lina binary was able to take over.

However, I wasn't able to find much use here as I was only gaining access to the rootfs image (essentially looking at the base for a ramdisk). Busybox provided a lot of utilities for use there (and Lina was accessible) but I couldn't really find much else there. 

#### DISCOVERING A DEBUG SCREEN

In finding that article, I was able to find the second article and pull up the NCC Group and research they had done into the ASA Lina binary close to 10 years before. While most of it is irrelevant from the point of view of this project (they to modify the firmware image to introduce debugging facilities for Lina and I was looking to subvert the boot process entirely), I did come across a very minor comment (in the **Convenience Tips** section) that opened another avenue:

> While replacing a CF card that was malfunctioning, we noticed that the ASA 5505 (and likely other models as well) appears to have an 8GB size limit for CF cards. Inserting a 16GB CF card will simply cause the BIOS to fail POST. This size limit doesn’t appear to be well documented and we didn’t investigate further. Interestingly this drops you to an extended BIOS debug (EBDEBUG) shell (which doesn’t seem to be well documented).

In wanting to try and replicate this, I purchased a 16 GB CF card, inserted it into the ASA, and was quickly able to force the system to boot to a BIOS-level debugger. Evidently, the larger card would cause some bootup code to throw a divide-by-zero error and the firmware was programmed to drop into a debug shell for handling. A quick Google search of the prompt for the shell (called **EBDEBUG**) led me to the [BIOS documentation](bios_documentation/) that's listed in this repo.

With reading into the documentation and utilizing [OSDev.com](https://wiki.osdev.org/Expanded_Main_Page) to get an better understanding of real-mode, interrupts, and the low-memory model, I realized that the debugger provided me with everything I could use for potentially kicking off custom code. This included the ability to execute instructions directly, moving across memory by adjusting the EIP register, and even with reading/writing to flash storage.

As of currently, I'm still looking into utilizing the BIOS debugger for loading and I've even followed a [tutorial](https://medium.com/@g33konaut/writing-an-x86-hello-world-boot-loader-with-assembly-3e4c5bdd96cf) to build a 16-bit Hello World bootloader to test it. It looks like the venture might be possible but it wouldn't be entirely feasible as the code would have to be re-executed on every bootup. This led me to another option that I'm looking at concurrently (listed below).