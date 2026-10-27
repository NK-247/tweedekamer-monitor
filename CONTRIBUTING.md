# Contributing to Tweede Kamer Monitor

First off, thank you for taking the time to contribute!

This project uses `dlt` to load raw data into a DuckDB database and `dbt` to build the `silver` and `gold` tables. Exploratory notebooks are in `eda/`. The dashboard is built using `Streamlit` and can be found in `app/`.

## Getting Things Set Up

1. Fork and clone

Because you do not have direct edit access to this main repository, you need to make your own copy of it first.

On [GitHub](https://github.com/afvanwoudenberg/tweedekamer-monitor), click **Fork** to create your own copy. Replace `YOUR-GITHUB-NAME` below with your GitHub username.

Clone your fork:

```bash
git clone https://github.com/YOUR-GITHUB-NAME/tweedekamer-monitor.git
```

Enter the project folder:

```bash
cd tweedekamer-monitor
```

Connect your clone to the main project so you can get updates:

```bash
git remote add upstream https://github.com/afvanwoudenberg/tweedekamer-monitor.git
```

2. Create the Conda environment

Install Conda if needed. From the project folder, create the environment defined in `environment.yml`:

```bash
conda env create --file environment.yml
```

Activate it:

```bash
conda activate tweedekamer_monitor
```

If `environment.yml` changes later, you can update the environment like this:

```bash
conda env update --name tweedekamer_monitor --file environment.yml
```

3. Configure notebook output cleaning

Removing notebook outputs before staging `.ipynb` files keeps the version control history clean and prevents bloated repositories.

The following command installs a local Git filter to handle this automatically. Run this once in each clone, with the Conda environment active:

```bash
nbstripout --install --attributes .gitattributes
```

## Contributing

All contributions must be done on a separate branch. Follow these steps for each contribution you make.

1. Create a branch

Update your local `main` from the main project:

```bash
git switch main
git pull upstream main
```

Push the updated `main` to your fork:

```bash
git push origin main
```

Create a branch for your change:

```bash
git switch -c describe-your-change
```

Use a short name that describes your work, for example `fix-notebook-query`.

2. Make your contributions

Make sure all your contributions (feature implementations, bug fixes, etc) are saved into this branch. Stick to one contribution per branch.

3. Commit your work locally

Stage and commit your custom changes:

```bash
git status
git add .
git commit -m "Describe your changes clearly"
```

4. Update your branch with latest project changes

Before opening a pull request, get the latest changes from the main project:

```bash
git switch main
git pull upstream main
git push origin main
```

Return to your work branch and merge the latest `main` into it:

```bash
git switch describe-your-change
git merge main --no-edit
```

*Note: If you encounter merge conflicts, resolve them in your code editor, stage the resolved files with `git add .`, and run `git merge --continue`.*

5. Open a pull request

Push your branch to your fork:

```bash
git push -u origin describe-your-change
```

On GitHub, open your fork and click **Compare & pull request**. Describe what you changed and how you tested it, then submit the pull request to the main project. If changes are requested, commit and push them to the same branch; the pull request will update automatically.
