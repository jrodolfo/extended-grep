To run **Qodana** on this project, you have three main options depending on whether you want to run it locally or in your CI/CD pipeline.

### 1. Run Locally via CLI (Recommended)

If you have the [Qodana CLI](https://www.jetbrains.com/help/qodana/qodana-cli-installation.html) installed, you can simply run the following command in the project root:

```bash
qodana scan --show-report
```

This command will:
1. Pull the necessary Docker linter (specified in your `qodana.yaml` as `jetbrains/qodana-jvm-community:2025.3`).
2. Analyze the Shell and PowerShell scripts.
3. Start a local web server to display the analysis report once finished.

### 2. Run Locally via Docker

If you don't have the CLI but have **Docker** installed, you can run Qodana directly using:

```bash
docker run --rm -v "$(pwd):/data/project" \
  -v "$(pwd)/.qodana/results:/data/results" \
  -v "$(pwd)/.qodana/cache:/data/cache" \
  jetbrains/qodana-jvm-community:2025.3
```

- Results will be saved in the `.qodana/results` folder.
- You can view them by opening the generated `index.html` in that folder or using the CLI's `qodana show` command.

### 3. Run in GitHub Actions (CI/CD)

The project already has a GitHub Action configured in `.github/workflows/qodana_code_quality.yml`. It is set to run automatically on:
- Every **push** to the `master` branch.
- Every **pull request**.
- **Manual triggers** via the "Actions" tab in GitHub.

To see the results in GitHub:
1. Go to the **Actions** tab of your repository.
2. Select the **Qodana** workflow.
3. Check the **Checks** or **Security** tab in your Pull Requests to see the Qodana annotations directly on your code.

### Configuration Note

Your project is currently using the `jetbrains/qodana-jvm-community:2025.3` linter. Although this is a JVM-focused linter, it includes the **Shell Script** plugin from JetBrains, which allows it to effectively analyze the `.sh` and `.ps1` files in this repository.

#### Current `qodana.yaml` Highlights:
- **Linter**: `jetbrains/qodana-jvm-community:2025.3`
- **Profile**: `qodana.starter` (a basic set of inspections)
- **JDK**: `25` (pre-configured for the linter environment)

If you want to customize which inspections are run, you can modify the `include` and `exclude` sections in your `qodana.yaml` file.