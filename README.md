# FreeBSD Petri Net Scheduler

This project implements a custom scheduler for the FreeBSD kernel using Petri nets, called `SCHED_PETRI`. It is based on the 4BSD scheduler.

## 📦 Repository Contents

- `src/`: Contains the source code for the new scheduler.
- `patches/`: Patches files in the FreeBSD source tree to integrate `SCHED_PETRI`.
- `orig/`: Original files that were modified to obtain the patches. This is kept to make updating files to newer versions of the kernel easier.
- `README.md`: This file
- `cli`: bash script that provides multiple commands to help with development (for an in-depth explanation you may read the source code):
  - `check`: checks if the needed files exist in the source tree, if they've changed, and if patches can be applied without problem
  - `install`: copies necessary files and applies patches
  - `generate-diff`: if a file was modified in the source tree, generates the `.patch` file and copies over the original file
  - `update`: updates patches and original files
- `cli-completion`: provides auto completion for the CLI

## ✅ Requirements

- FreeBSD (recommended: `main`)
- FreeBSD kernel source tree (`/usr/src`) available and clean (unmodified).
- Build tools (`buildworld`, `buildkernel`).

## 🚀 Installation

1. **Clone this repository:**
```sh
git clone https://github.com/project_scheduler/scheduler.git
cd scheduler
chmod +x ./cli
```

> [!NOTE]
> You can enable autocompletion for the CLI with `source ./cli-completion`

2.  **Verify status using CLI:**
```sh
./cli --src=path/to/source check
```

3.  **Install the custom scheduler:**
```sh
sudo ./cli --src=path/to/source install
```
    
4.  **Compile new kernel and reboot the system**
> The new kernel should now use `SCHED_PETRI` as its scheduler.

## 🔁 Updating with New FreeBSD Kernel Versions

> [!WARNING]
> TODO: Write this 

## 🛠️ Development and Contribution

> [!WARNING]
> TODO: Write this 

## 📄 License
This project is based on FreeBSD kernel code and inherits its BSD-2-Clause license.
