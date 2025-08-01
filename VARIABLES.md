List of variables usable in tests
=================================

This list contains variables that are possible to set/redefine in WebUI and get their values in tests.
This document merges relevant variables from
[official documentation](https://github.com/os-autoinst/os-autoinst/blob/master/doc/backend_vars.asciidoc)
(backend variables), variables that control flow through `main.pm` (test variables) and variables that
are specified when ISO is posted into OpenQA (run variables).

Backend variables
-----------------
These variables control settings of underlying virtual machine where tests runs on. Some of them (`ARCH`, `QEMURAM`, ...) should be set per machine, others (`HDD_$i`, `HDDMODEL`, ...) should be set per test and some of them (`KEEPHDDS`, `MAKETESTSNAPSHOTS`, `SKIPTO`) should be set only during development and debugging.

| Variable | Values allowed | Default value | Explanation |
| -------- | :------------: | :-----------: | ----------- |
| `ARCH` | `x86_64`, `i686`, `aarch64`, ... | depends on tested medium | architecture of VM |
| `ARCH_BASE_MACHINE` | `uefi`, `64bit`, `ARM`, ... | depends on machine | 'machine' value to be used for tests where we might want to start after a test run on a different machine. For instance, we run tests that produce x86_64 ISOs on the '64bit' machine, so `ARCH_BASE_MACHINE` for the 'uefi' machine is set to '64bit', so that we can run UEFI install tests on the 'uefi' machine with an image generated by a test run on the '64bit' machine |
| `BIOS` | filename | `ovmf-x86_64-ms.bin` for `x86_64` UEFI, not set otherwise | set different BIOS |
| `BOOTFROM` | characters (see man qemu, `-boot order=` option) | not set | boot from different medium than CD |
| `CDMODEL` | see `qemu-kvm -device help` | not set/Qemu default | type of device for CD |
| `HDDMODEL` | see `qemu-kvm -device help` (e. g. PATA = `id-hd`, SATA = `ide-hd,bus-ahci0.0`, SCSI = `virtio-scsi-pci`) | `virtio-blk` | type of device for HDD |
| `HDDSIZEGB` | integer | `10` | size (in GBs) for disks that are created automatically |
| `HDD_$i` (`HDD_1, HDD_2`, ...) | filename | not set | attach additional HDD to VM |
| `ISO` | filename | not set | attach CD drive with ISO inserted |
| `ISO_$i` (`ISO_1`, `ISO_2`, ...) | filename | not set | additional CD drives to by attached |
| `KEEPHDDS` | boolean | `false`/not set | don't delete HDD after test finishes |
| `LAPTOP` | boolean or filename | `false`/not set | if `true`, Dell E6330 DMI is used; if set to filename, that file is used for DMI |
| `MAKETESTSNAPSHOTS` | boolean | `false`/not set | save snapshot for each test |
| `NOVIDEO` | boolean | `false`/not set | don't create video output if set |
| `NUMDISKS` | integer | 1 | number of disks to be created and attached to VM |
| `PART_TABLE_TYPE` | `mbr`, `gpt` | not set | what type of partition table should attached HDD have |
| `PXEBOOT` | boolean | `false`/not set | boot VM from PXE (network) |
| `QEMU` | filename, path to Qemu binary | not set | filename of Qemu binary |
| `QEMUCPU` | see `qemu-kvm -cpu help` | not set | CPU to emulate |
| `QEMUCPUS` | integer | 1 | number of processor cores to use for Qemu |
| `QEMURAM` | integer | 1024 | size of RAM to use (in MiB) |
| `QEMUTHREADS` | integer | 0 | number of CPU threads to use for Qemu |
| `QEMUVGA` | `virtio`, `qxl`, `cirrus`, `std` | `std` (effectively) | display device to use for VM (deprecated, use `QEMU_VIDEO_DEVICE`) |
| `QEMU_COMPRESS_QCOW2` | boolean | `false`/not set | compress qcow2 images |
| `QEMU_VIDEO_DEVICE` | see `qemu-kvm -device help` and https://www.kraxel.org/blog/2019/09/display-devices-in-qemu/ | `VGA` (x86), `virtio-gpu-pci` (ARM), `virtio-gpu` (s390x) | display device to use for VM (passed as `-device X`) |
| `SKIPTO` | name of snapshot | not set | restore VM from given snapshot - better used with `MAKETESTSNAPSHOTS` |
| `UEFI` | boolean | `false`/not set | whether to use UEFI (UEFI BIOS files should be installed) |
| `UEFI_BIOS` | filename | `false`/not set, `ovmf-x86_64-ms.bin` when `UEFI` is set | filename of UEFI BIOS |
| `USBBOOT` | boolean | `false`/not set | if set, mount ISO as USB and boot from it |

For additional (kvm2usb, IPMI...) as well as for other Qemu variables, see
[official documentation](https://github.com/os-autoinst/os-autoinst/blob/master/doc/backend_vars.asciidoc).

Test variables
--------------
These variables control flow through `main.pm` - by setting them, you can alter what parts will be loaded.

There are certain tests that conflict each other. Note that conflict is always mutual, but for simplification
purposes, only one side of this conflict is shown (that means, if it's shown that `A` conflicts `B`,
it also means that `B` conflicts `A` even if not shown in the table).

| Variable | Values allowed | Default value/behavior | Conflicts | Explanation |
| -------- | :------------: | ---------------------- | :-------: | ----------- |
| `LIVE` | boolean | not set | technically `PACKAGE_SET`, `KICKSTART`, `MIRRORLIST_GRAPHICAL`, `REPOSITORY_GRAPHICAL`, `REPOSITORY_VARIATION` | specify that the test is running on Live system - additional steps are required (starting Anaconda...) |
| `PACKAGE_SET` | string (`minimal`, `default`, ...) | `minimal`; `default` when `LIVE` is set | nothing | sets packageset to install - you have to add appropriate needles, see `tests/_software_selection.pm` |
| `ENTRYPOINT` | filename | not set | N/A | set `ENTRYPOINT` to load specific test directly (bypass modular structure, mainly usable for testing). If you want to run more than one test, separate them with space. |
| `UPGRADE` | string (`minimal`, `desktop`, `encrypted`, ...) | not set | all except of `LIVE` and `USER_PASSWORD` | when set, do an upgrade test of specified type |
| `KICKSTART` | boolean | `false`/not set | all | when specified, do an kickstart installation (you should use `GRUB` variable to specify where kickstart file resides) |
| `MIRRORLIST_GRAPHICAL` | boolean | `false`/not set | `REPOSITORY_GRAPHICAL` | sets installation source to mirrorlist |
| `REPOSITORY_GRAPHICAL` | url to repository (without arch and `/os`, for example `http://dl.fedoraproject.org/pub/fedora/linux/development`) | not set | `MIRRORLIST_GRAPHICAL` | sets installation source to repository url in Anaconda |
| `REPOSITORY_VARIATION` | url to repository (without arch and `/os`, for example `http://dl.fedoraproject.org/pub/fedora/linux/development`) | not set | nothing | sets installation source to repository url in GRUB |
| `PARTITIONING` | string (`custom_software_raid`, `guided_delete_all`, ...) | `guided_empty` | nothing | load specified test for partitioning part (when `PARTITIONING=guided_delete_all`, `tests/disk_guided_delete_all.pm` is loaded) and optionally post-install partitioning check (if `tests/disk_guided_delete_all_postinstall.pm` exists, it will be loaded after login to the installed system). Also, if value starts with `custom_`, the `select_disks()` method will check the custom partitioning box |
| `ENCRYPT_PASSWORD` | string | not set | nothing | if set, encrypt disk with given password |
| `DESKTOP` | boolean | `false`/not set | nothing | set to indicate that Fedora is running with GUI (so for example OpenQA should expect graphical login screen) |
| `ROOT_PASSWORD` | string | `weakpassword` | nothing | root password is set to this value |
| `INSTALLER_NO_ROOT` | boolean | `false`/not set | nothing | if set, root password is not set via the anaconda spoke (but, for now, will be set by chrooting into the installed system at the end of installation) |
| `GRUB` | string | not set | nothing | when set, append this string to kernel line in GRUB |
| `GRUBADD` | string | not set | nothing | when set, append this string to kernel line in GRUB, after the `GRUB` string if that one is set too. This is never set by tests; instead it's provided as a way to e.g. run the normal tests with an `updates.img` to test some anaconda change (the scheduler CLI can help you use this feature) |
| `USER_LOGIN` | string | not set | should be used with `USER_PASSWORD` (unless `false`) | when set, user login is set to this value. If not set, default value `test` is used for console installs, no login is done for graphical installs. If set to `false`, no user login will be done |
| `USER_PASSWORD` | string | not set | should be used with `USER_LOGIN` | when set, user password is set to this value. If not set, default value `weakpassword` is used for console installs, no login is done for graphical installs |
| `TEST_UPDATES` | boolean | `false`/not set | set to indicate that this test checks updates.img loading, so we should check for the expected effect of the updates image used for this testing |
| `PREINSTALL` | string | not set | nothing | If set, specified module will be loaded before reboot and install; module supposed to be starting as rescue mode |
| `POSTINSTALL` | string | not set | `POSTINSTALL_PATH` | If set, `tests/(value)_postinstall.pm` will be loaded after install, boot, login, and other postinstall tests
| `POSTINSTALL_PATH` | boolean | not set | `POSTINSTALL` | If set, `all tests on this location will be loaded as postinstall tests after install, boot, login, and other postinstall tests |
| `UEFI` | boolean | `false`/not set | nothing | whether to use UEFI, this variable isn't usually set in test suites but in machine definition |
| `ANACONDA_TEXT` | boolean | `false`/not set | all | when specified, anaconda will run in text mode |
| `HELPCHECK` | boolean | `false`/not set | all | when specified, Anaconda Help will be called on each available pane. |
| `ANACONDA_STATIC` | string (IPv4 address) | not set | `ANACONDA_TEXT` | If set, will set up static networking using the chosen IP address during install |
| `POST_STATIC` | string (space-separated IPv4 address and hostname) | not set | nothing | If set, will set up static networking using the chosen IP address and hostname during early post-install |
| `NO_UEFI_POST` | boolean | `false`/not set | nothing | If set, `uefi_postinstall` test will not be loaded even if `UEFI` is set (can be useful for non-English tests to avoid `uefi_postinstall` running loadkeys) |
| `CRASH_REPORT` | boolean | not set | nothing | If set, Anaconda will perorm a simulated crash during installation, which will be used to create a report in the Bugzilla. Currently, this only affects Anaconda when it runs in text mode. |
| `BUGZILLA_LOGIN` | string | not set | used with `_SECRET_BUGZILLA_PASSWORD` | This is used to store a login string which does not get exposed in log files. |
| `_SECRET_BUGZILLA_PASSWORD` | string | not set | used with `BUGZILLA_LOGIN` | This is used to store a password string which does not get exposed in log files. |
| `_SECRET_BUGZILLA_APIKEY` | string | not set | used with other secrets | This is used to store an API key which does not get exposed in log files. |
| `USE_CUPS` | boolean | `false`/not set | if set, the desktop printing test will use cups-pdf instead of the generic method |
| `RDP_SERVER` | boolean | `false`/not set | set to identify an RDP server which will modify the script path for installation tests |
| `RDP_CLIENT` | boolean | `false`/not set | set to identify an RDP client which will modify the script path for installation tests |

Run variables
-------------
These variables should be set when tests are scheduled (when running `isos post`).

| Variable | Explanation |
| -------- | ----------- |
| `ISO` | contains filename of ISO that is used for booting. If `ISO_URL` is not set, file must exist in /var/lib/openqa/share/factory/iso. If `ISO_URL` is set, it will be downloaded to this name instead of its original name |
| `ISO_URL` | contains URL for ISO to boot, openQA will download it |
| `ADVISORY` | A Bodhi update ID. If set, the 'update testing' flow will be used: post-install tests will be run with the packages from the update, starting from the stable release base disk images |
| `KOJITASK` | A Koji task ID. If set, the modified 'update testing' flow for testing scratch builds will be used: post-install tests will be run with the packages from the update, starting from the stable release base disk images |
| `DISTRI` | contains distribution name (should be same as in WebUI, probably `fedora`) |
| `VERSION` | contains version of distribution |
| `FLAVOR` | indicates what type of distribution is used. Three Pungi properties, joined with `-`: `variant`, `type`, and `format`. e.g.: `Server-dvd-iso`. Special value `universal` is used to schedule the group of tests that should be run once each per arch per compose, against the 'best' available ISO |
| `ARCH` | is set to architecture that will be used (`x86_64`, `i686`) |
| `BUILD` | contains Pungi compose_id (something like `Fedora-24-20160121.n.3`) |
| `LABEL` | contains Pungi compose label, if it has one (otherwise should be unset) - e.g `RC-1.5` |
| `CURRREL` | the current stable Fedora release at the time of the test run |
| `PREVREL` | the previous stable Fedora release at the time of the test run |
| `UP1REL` | the source release for "1-release" upgrade tests (usually but not always same as `CURRREL`) |
| `UP2REL` | the source release for "2-release" upgrade tests (currently always same as `PREVREL`) |
| `LOCATION` | contains Pungi base compose location (something like `https://kojipkgs.fedoraproject.org/compose/branched/Fedora-25-20160901.n.0/compose/`) |
