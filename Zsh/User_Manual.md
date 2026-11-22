# MarkitdownRecursive — Zsh User Manual

[![Shell](https://img.shields.io/badge/Shell-Zsh-4EAA25?style=flat-square)](https://www.zsh.org/)
[![Python](https://img.shields.io/badge/Python-3.10--3.14-3776AB?style=flat-square)](https://www.python.org/)
[![Download](https://img.shields.io/badge/Download-Single%20file-blue?style=flat-square)](https://github.com/LionnyRdguez/markitdown-recursive/releases/latest/download/MarkitdownRecursive.zsh)

**Install the dependencies, download one file, and run the script.**

You do **not** need to clone the repository, install Git, or download the complete project. The standalone script is all you need, together with its external dependencies.

---

## Get started

1. Install the system dependencies for your operating system.
2. Install Python and MarkItDown.
3. Download `MarkitdownRecursive.zsh` into `~/scripts/`.
4. Run it on a folder.

> **Recommended environment:** Ubuntu on WSL2 or a native Linux distribution with GNU Findutils and GNU Coreutils. macOS setup instructions are also provided below.

## 1. Install system dependencies

Choose the instructions for your operating system.

<details>
<summary><strong>Windows — WSL2 with Ubuntu (recommended)</strong></summary>

### Step 1 — Install WSL2

Open PowerShell as Administrator:

```powershell
wsl --install
```

Restart Windows if requested. Open Ubuntu from the Start menu and complete its first-time setup.

If WSL is already installed, check the distribution and WSL version:

```powershell
wsl --list --verbose
```

Make sure Ubuntu uses WSL version 2.

### Step 2 — Install the packages

In the Ubuntu terminal:

```bash
sudo apt update

sudo apt install -y \
    zsh \
    findutils \
    coreutils \
    python3 \
    python3-venv \
    curl
```

### Step 3 — Check Python

```bash
python3 --version
```

MarkItDown currently supports Python **3.10 through 3.14**. Python 3.15 is not supported. If Ubuntu's default Python is outside the supported range, install a compatible version before continuing.

Continue to [Install Python and MarkItDown](#2-install-python-and-markitdown).

[Microsoft: Install WSL](https://learn.microsoft.com/windows/wsl/install/)

</details>

<details>
<summary><strong>Linux — Ubuntu / Debian</strong></summary>

```bash
sudo apt update

sudo apt install -y \
    zsh \
    findutils \
    coreutils \
    python3 \
    python3-venv \
    curl
```

Check the Python version:

```bash
python3 --version
```

It must be **Python 3.10–3.14**. Python 3.15 is not supported by the current MarkItDown release.

</details>

<details>
<summary><strong>Linux — Fedora</strong></summary>

```bash
sudo dnf install -y \
    zsh \
    findutils \
    coreutils \
    python3 \
    curl
```

Check the system Python version:

```bash
python3 --version
```

If it reports Python **3.10–3.14**, you can use `python3` in the virtual-environment instructions below.

**Fedora 45 users:** Fedora 45 uses Python 3.15 as its default `python3`, which is outside MarkItDown's supported range. Install the compatible Python 3.14 interpreter:

```bash
sudo dnf install -y python3.14
python3.14 --version
```

Use `python3.14` when creating the virtual environment. Do not change Fedora's system-wide `python3` command.

For more information, see [Fedora's Python 3.14 package](https://packages.fedoraproject.org/pkgs/python3.14/python3.14/) and [the Fedora 45 Python 3.15 package](https://packages.fedoraproject.org/pkgs/python3.15/python3/).

</details>

<details>
<summary><strong>Linux — Arch Linux</strong></summary>

```bash
sudo pacman -Syu --needed \
    zsh \
    findutils \
    coreutils \
    python \
    python-pip \
    curl
```

Check that Python is compatible:

```bash
python --version
```

It must be **Python 3.10–3.14**. Python 3.15 is not supported by the current MarkItDown release.

</details>

<details>
<summary><strong>macOS — Homebrew</strong></summary>

### Step 1 — Install Homebrew

If Homebrew is not installed, follow its official instructions: [brew.sh](https://brew.sh/).

### Step 2 — Install Python and GNU utilities

```bash
brew update

brew install \
    zsh \
    python@3.14 \
    findutils \
    coreutils
```

### Step 3 — Put GNU utilities first in PATH

macOS includes BSD versions of some commands. MarkitdownRecursive needs GNU versions of `find`, `sort`, `mv` and other utilities.

Add Homebrew's GNU command directories to your Zsh configuration:

```bash
echo 'export PATH="$(brew --prefix findutils)/libexec/gnubin:$(brew --prefix coreutils)/libexec/gnubin:$PATH"' >> "$HOME/.zshrc"
```

Reload the configuration:

```bash
source "$HOME/.zshrc"
```

If you launch the script from Bash or another shell, make sure the same GNU directories are in that shell's `PATH` too. The script inherits the environment of the shell that launches it.

### Step 4 — Verify GNU utilities

```bash
find --version
sort --version
mv --version
```

They must report GNU implementations.

References: [Homebrew Findutils](https://formulae.brew.sh/formula/findutils) · [Homebrew Coreutils](https://formulae.brew.sh/formula/coreutils).

</details>

### Required utility features

The script uses GNU-specific options:

| Command | Required options |
|---|---|
| `find` | `-samefile`, `-print0` |
| `sort` | `-z` |
| `mv` | `-nT` |

The script checks for `sort -z` at startup. You can check it yourself with:

```bash
sort -z </dev/null
```

On macOS, verify that `find`, `sort` and `mv` resolve to the GNU versions, not the default BSD versions.

## 2. Install Python and MarkItDown

MarkItDown provides the `markitdown` command used by the script. Its current package metadata requires **Python >=3.10 and <3.15** (Python 3.10–3.14). A virtual environment is recommended to keep its dependencies separate from system Python packages.

### Step 1 — Create a virtual environment

On WSL2, Ubuntu/Debian, and Linux distributions whose default `python3` is within the supported range, use:

```bash
mkdir -p "$HOME/.venvs"
python3 -m venv "$HOME/.venvs/markitdown-recursive"
```

On Fedora 45, use the compatible Python 3.14 interpreter installed in the previous section:

```bash
mkdir -p "$HOME/.venvs"
python3.14 -m venv "$HOME/.venvs/markitdown-recursive"
```

On other Fedora releases, use `python3` only if its version is within the supported range:

```bash
mkdir -p "$HOME/.venvs"
python3 -m venv "$HOME/.venvs/markitdown-recursive"
```

On macOS with Homebrew Python 3.14:

```bash
mkdir -p "$HOME/.venvs"
python3.14 -m venv "$HOME/.venvs/markitdown-recursive"
```

### Step 2 — Activate it

```bash
source "$HOME/.venvs/markitdown-recursive/bin/activate"
```

### Step 3 — Install MarkItDown

For the broadest available format support:

```bash
python -m pip install --upgrade pip
python -m pip install 'markitdown[all]'
```

You can instead install only the optional dependencies for formats you need. For example:

```bash
python -m pip install 'markitdown[pdf,docx,pptx,xlsx,xls]'
```

The available extras and supported formats can change. Check the [official MarkItDown documentation](https://github.com/microsoft/markitdown) before choosing a smaller set.

### Step 4 — Verify the installation

```bash
python --version
command -v markitdown
markitdown --help
```

All three commands should work. Keep the virtual environment activated whenever you use the script. In a new terminal, activate it again:

```bash
source "$HOME/.venvs/markitdown-recursive/bin/activate"
```

To leave the environment:

```bash
deactivate
```

## 3. Download the script

You only need this one file:

`MarkitdownRecursive.zsh`

Create a `scripts` folder in your home directory:

```bash
mkdir -p "$HOME/scripts"
```

### Option A — Download from your browser

[**⬇️ Download MarkitdownRecursive.zsh**](https://github.com/LionnyRdguez/markitdown-recursive/releases/latest/download/MarkitdownRecursive.zsh)

This download link targets the **`main` branch**, which is intended for stable user-facing versions. It requests the file as a download rather than opening the source view.

Save the downloaded file here:

```text
~/scripts/MarkitdownRecursive.zsh
```

**WSL users downloading from a Windows browser:** the browser usually saves files to Windows Downloads, not directly to the Linux home directory. From Ubuntu, copy the downloaded file into `~/scripts/`. For example (replace the Windows account name):

```bash
cp "/mnt/c/Users/<WindowsUser>/Downloads/MarkitdownRecursive.zsh" \
   "$HOME/scripts/MarkitdownRecursive.zsh"
chmod +x "$HOME/scripts/MarkitdownRecursive.zsh"
```

If your browser displays a GitHub page instead of downloading the file:

1. [Open the script on GitHub](https://github.com/LionnyRdguez/markitdown-recursive/blob/main/Zsh/MarkitdownRecursive.zsh).
2. Use **Download raw file** in the file toolbar.
3. Save the downloaded file in your `scripts` folder.

### Option B — Download from the terminal

Run:

```bash
curl -fL \
    "https://raw.githubusercontent.com/LionnyRdguez/markitdown-recursive/main/Zsh/MarkitdownRecursive.zsh" \
    -o "$HOME/scripts/MarkitdownRecursive.zsh"
```

`curl -fL` follows GitHub's redirect and fails on an HTTP error; `-o` saves the file at the specified location.

### Make the script executable

Use this command regardless of which download method you chose:

```bash
chmod +x "$HOME/scripts/MarkitdownRecursive.zsh"
```

Your installation should now look like this:

```text
Home directory
└── scripts/
    └── MarkitdownRecursive.zsh
```

Typical locations are:

- Linux / WSL2: `/home/your-username/scripts/MarkitdownRecursive.zsh`
- macOS: `/Users/your-username/scripts/MarkitdownRecursive.zsh`

> **You are ready to run the script.**

## 4. Run the script

Make sure the MarkItDown virtual environment is active.

### Display help

```bash
"$HOME/scripts/MarkitdownRecursive.zsh" --help
```

You can also use `-h`:

```bash
"$HOME/scripts/MarkitdownRecursive.zsh" -h
```

### Process a specific folder

For example, to process your Documents folder:

```bash
"$HOME/scripts/MarkitdownRecursive.zsh" "$HOME/Documents"
```

Or process Downloads:

```bash
"$HOME/scripts/MarkitdownRecursive.zsh" "$HOME/Downloads"
```

You can process any existing directory that your user account can access. Quote paths containing spaces or special characters.

### Process the current folder

Move to the folder you want to process:

```bash
cd "$HOME/Documents"
```

Run the script without a folder argument:

```bash
"$HOME/scripts/MarkitdownRecursive.zsh"
```

The current working directory is used as the source.

### Available arguments

| Argument | Description |
|---|---|
| `folder` | Optional source directory. |
| `-h` | Display help. |
| `--help` | Display help. |

Only one source directory can be supplied. The script does not currently provide a custom destination argument or an overwrite option.

## 5. Optional — Run it without typing the full path

You can add `~/scripts` to your `PATH`. This lets you run the script by filename from any directory. Add the line to the startup file for the shell you use.

**For Zsh**, run:

```zsh
touch "$HOME/.zshrc"
grep -qxF 'export PATH="$HOME/scripts:$PATH"' "$HOME/.zshrc" || \
    printf '\nexport PATH="$HOME/scripts:$PATH"\n' >> "$HOME/.zshrc"

source "$HOME/.zshrc"
```

**For Bash**, run:

```bash
touch "$HOME/.bashrc"
grep -qxF 'export PATH="$HOME/scripts:$PATH"' "$HOME/.bashrc" || \
    printf '\nexport PATH="$HOME/scripts:$PATH"\n' >> "$HOME/.bashrc"

source "$HOME/.bashrc"
```

Then you can run:

```bash
MarkitdownRecursive.zsh "$HOME/Documents"
```

This step is optional. Using the full path from Section 4 works without changing `PATH`.

## 6. Understand the output

The output folder is created **inside the source folder**. Its name is the source folder's name followed by ` Markdown`. Visible subdirectories are reproduced with the same suffix.

**Before**

```text
Documents/
├── report.pdf
├── notes.md
└── Projects/
    └── presentation.pptx
```

**After**

```text
Documents/
├── report.pdf
├── notes.md
├── Projects/
│   └── presentation.pptx
└── Documents Markdown/
    ├── report.md
    ├── notes.md
    └── Projects Markdown/
        └── presentation.md
```

The original source files are not modified or deleted.

### File handling rules

| Source entry | What happens |
|---|---|
| Visible regular non-Markdown file | Sent to MarkItDown for conversion. |
| Existing `.md` file | Copied byte-for-byte without conversion. |
| `.MD` and other case variants | Copied and normalized to `.md`. |
| Hidden file or directory | Skipped, including the contents of hidden directories. |
| Symbolic link | Skipped; the target is not processed through the link. |
| Special filesystem entry | Skipped. |
| Existing destination file | Never overwritten. |
| Filename collision | The first successful result is kept; later collisions are skipped. |

Only the final extension is removed:

```text
report.pdf       → report.md
data.v2.xlsx     → data.v2.md
README           → README.md
```

The script sends visible regular **non-Markdown** files to MarkItDown without filtering by extension. Existing Markdown files are copied directly. Actual conversion depends on the installed MarkItDown version and the optional dependencies you installed.

### Existing results and filename collisions

The script never overwrites an existing destination file. This applies both to files left by earlier runs and to collisions within the same run.

For example, `report.docx` and `report.pdf` both target `report.md`. Files are processed in deterministic lexical order; the first successful result is preserved and a later file with the same destination is skipped.

If you need to regenerate a file, inspect and back up the existing result before removing or moving it.

## 7. Exit codes

| Code | Meaning |
|---:|---|
| `0` | Processing completed successfully. |
| `1` | Processing completed with one or more file, directory, traversal or cleanup errors. |
| `2` | Invalid arguments, source path, missing dependency or invalid output directory prevented startup. |
| `130` | Interrupted with Ctrl+C (SIGINT). |
| `143` | Terminated with SIGTERM. |

A conversion error does not necessarily stop the rest of the files from being processed. Check the final terminal summary when the exit code is non-zero.

## 8. Troubleshooting

<details>
<summary><strong>markitdown: command not found</strong></summary>

Activate the virtual environment:

```bash
source "$HOME/.venvs/markitdown-recursive/bin/activate"
```

Then check:

```bash
command -v markitdown
```

</details>

<details>
<summary><strong>sort: invalid option -- z</strong></summary>

The script needs GNU Coreutils. Install it and make sure the GNU version of `sort` is first in `PATH`. On macOS, check the Homebrew `gnubin` configuration.

</details>

<details>
<summary><strong>find: unknown predicate -samefile</strong></summary>

The script needs GNU Findutils. Install it and verify:

```bash
find --version
```

</details>

<details>
<summary><strong>mv does not recognize -nT</strong></summary>

The script needs GNU Coreutils. Verify that `mv --version` reports GNU Coreutils, not BSD `mv`.

</details>

<details>
<summary><strong>A document could not be converted</strong></summary>

The format may not be supported by your installed MarkItDown version, or the optional dependencies for that format may be missing. Check the terminal error and the [official MarkItDown documentation](https://github.com/microsoft/markitdown).

</details>

<details>
<summary><strong>An existing file was skipped</strong></summary>

This is intentional: existing destination files are never overwritten. Inspect and back up the existing output before removing or moving it.

</details>

<details>
<summary><strong>The output directory was rejected</strong></summary>

The output root cannot be a symbolic link or a non-directory file. Nested destination directories are checked too. Inspect the reported path before changing it.

</details>

## 9. Update the script

To replace your installed copy with the latest version published on **`main`**, run:

```bash
curl -fL \
    "https://raw.githubusercontent.com/LionnyRdguez/markitdown-recursive/main/Zsh/MarkitdownRecursive.zsh" \
    -o "$HOME/scripts/MarkitdownRecursive.zsh" \
    && chmod +x "$HOME/scripts/MarkitdownRecursive.zsh"
```

The `main` branch is the download source for users. Development work in `develop` is not intended for regular installations.

## Additional resources

- [MarkitdownRecursive repository](https://github.com/LionnyRdguez/markitdown-recursive)
- [MarkItDown — installation and supported formats](https://github.com/microsoft/markitdown)
- [Microsoft — Install WSL](https://learn.microsoft.com/windows/wsl/install/)
- [Homebrew](https://brew.sh/)
- [GNU Findutils](https://www.gnu.org/software/findutils/)
- [GNU Coreutils](https://www.gnu.org/software/coreutils/)

**For contributors:** The complete repository contains the source tree, automated tests, fixtures and reference results. They are not needed to use the standalone script.
