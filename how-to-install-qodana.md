# How to Install Qodana (Windows and macOS)

Qodana is a static code analysis tool from **JetBrains**.  
It runs analyzers inside Docker containers and is controlled via the Qodana CLI.

This guide explains how to install it properly on:

- Windows
- macOS

It also includes lessons learned from a real Windows installation.

## Prerequisite (Both Windows and macOS)

### 1. Install Docker Desktop

Qodana requires Docker because all analyzers run inside containers.

Download Docker Desktop:  
[https://www.docker.com/products/docker-desktop/](https://www.docker.com/products/docker-desktop/)

After installation:

- Start Docker Desktop at least once
- Make sure it is running before executing `qodana scan`

Verify installation:

```bash
docker --version
```

If this command works, Docker is ready.

## Installing Qodana on Windows

### Recommended Method: Using winget

Open **PowerShell (normal user, not Administrator)** and run:

```powershell
winget install JetBrains.QodanaCLI
```

#### Important: Restart PowerShell

After installation, close all PowerShell windows and open a new one.

This is necessary because Windows does not refresh the PATH variable automatically.

Then verify:

```powershell
qodana --version
```

If you see a version number, installation is successful.

### If `qodana` Is Not Recognized

If you get:

```text
qodana : The term 'qodana' is not recognized...
```

Do the following:

#### Step 1: Check if it is installed

```powershell
where.exe qodana
```

If a path appears, the installation succeeded.

#### Step 2: Refresh PATH manually (if needed)

```powershell
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
            [System.Environment]::GetEnvironmentVariable("Path","User")
```

Then try again:

```powershell
qodana --version
```

## Installing Qodana on macOS

### Recommended Method: Homebrew

If Homebrew is installed:

```bash
brew install jetbrains/utils/qodana
```

Verify:

```bash
qodana --version
```

macOS shells usually refresh PATH automatically, so no restart is needed.

## Initializing Qodana in a Project

Navigate to your project root:

```bash
cd my-project
```

Initialize configuration:

```bash
qodana init
```

This creates:

```text
.qodana.yaml
```

## Running Qodana

Run:

```bash
qodana scan
```

The first execution will download a large analyzer image (1-2 GB).  
This is normal.

After completion, results are stored in:

```text
./qodana/results/report/index.html
```

Open that file in your browser.

## Common Windows Issue

If you see:

```text
Cannot connect to Docker daemon
```

Make sure:

- Docker Desktop is running
- WSL2 integration is enabled

## Summary

| Step             | Windows                              | macOS                                 |
|------------------|--------------------------------------|---------------------------------------|
| Install Docker   | Docker Desktop                       | Docker Desktop                        |
| Install Qodana   | `winget install JetBrains.QodanaCLI` | `brew install jetbrains/utils/qodana` |
| Restart terminal | Required                             | Usually not required                  |
| Run analysis     | `qodana scan`                        | `qodana scan`                         |

Your environment is now ready to use Qodana consistently on both platforms.
