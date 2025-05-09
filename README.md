# FreeBSD Petri Net Scheduler

This project implements a custom scheduler for the FreeBSD kernel using Petri nets, called `SCHED_PETRI`. It is based on the 4BSD scheduler.

## 📦 Repository Contents

- `src/`: Contains the source code for the new scheduler.
- `patches/`: Patches files in the FreeBSD source tree to integrate `SCHED_PETRI`.
- `install.sh`: Automated installation script that copies files, applies patches, and builds the kernel.

## ✅ Requirements

- FreeBSD (recommended: `main`)
- FreeBSD kernel source tree (`/usr/src`) available and clean (unmodified).
- Build tools (`buildworld`, `buildkernel`).

## 🚀 Installation

1. **Clone this repository:**
```sh
git clone https://github.com/project_scheduler/scheduler.git
cd scheduler
```

2.  **Verify that the FreeBSD source tree is present:**
```sh
ls /usr/src
```

3.  **Install the custom scheduler:**
```sh
sudo ./install.sh
```

This script:

- Copies files from `src` to their appropriate destinations (following the structure of the source tree).
- Adds configuration for VMs.
- Applies patches to the necessary files.
- Compiles and installs the modified kernel.
    
4.  **Reboot the system with the new kernel:**
```sh
sudo reboot
```
> The new kernel should now use `SCHED_PETRI` as its scheduler.

## 🔁 Updating with New FreeBSD Kernel Versions

When updating your system to a new version of the FreeBSD kernel (e.g., when tracking `main`), follow these steps:

1.  **Update the official FreeBSD source tree:**
```sh
cd /usr/src
git pull origin main
```

2.  **Reapply the scheduler patches from your repository:**
```sh
cd /path/to/scheduler
sudo ./install.sh
```

3.  **Rebuild the kernel with the updated changes:**
```sh
cd /usr/src
sudo make buildkernel KERNCONF=SCHEDGRAPH
sudo make installkernel KERNCONF=SCHEDGRAPH
sudo reboot
```
> 📌 Make sure the patches are still compatible. If there are conflicts, you may need to update them using `git diff` or `diff -u` against the new version.


## 📂 Maintaining Changes via Manual Merging

Instead of using traditional patches, this project includes full modified files. This strategy is valid and simplifies out-of-tree development by:

* Giving you complete control over the modified source.
* Avoiding patch application errors due to context drift.
* Making manual merges straightforward when the upstream source changes.

### 🔁 When the `/usr/src` tree is updated:

1. **Update the official FreeBSD source tree:**

```sh
cd /usr/src
git pull origin main
```

2. **Check whether any files you override in `src/` have changed upstream.**

3. **Perform a manual merge between your version and the updated file.**

> If you've saved a copy of the original unmodified file in your repository (e.g., under `orig/`), you can perform a 3-way merge.

#### 🔧 Example using `git merge-file`:

```sh
git merge-file src/sys/kern/sched_petri.c \
  orig/sys/kern/sched_4bsd.c \
  /usr/src/sys/kern/sched_4bsd.c
```

* First argument: your modified file.
* Second argument: the original base version.
* Third argument: the new upstream file.

You can also use visual merge tools such as:

* `vimdiff`
* `meld`
* `kdiff3`

### 💡 Tip

Keep an `orig/` directory in your repository with the original (base) versions of any files you've modified. This makes future merges much easier:

```plaintext
orig/
└── sys/kern/sched_4bsd.c   # Original unmodified base file
```

By following this method, you can maintain your changes across kernel updates with less friction and better clarity than using raw patch files.

## 🛠️ Development and Contribution

This setup allows you to develop your scheduler without modifying the official source repository directly. If you make improvements or add instrumentation:

- Edit the files in `src/`.
- Copy the base version of any source tree files yo intend to modify to `orig/`
- Regenerate the patches if you modify source tree files:
    ```sh
    diff -u /usr/src/sys/conf/options.amd64 backups/options.amd64 > patches/patch-options.amd64
    ``` 

## 📄 License
This project is based on FreeBSD kernel code and inherits its BSD-2-Clause license.
