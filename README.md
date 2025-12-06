# git-repo-setup-from-url
PowerShell scripts to clone GitHub repositories from a URL and set up worktrees.

Each script uses its own location as the base folder, creates (or reuses if empty) a subfolder named after the repository, and then performs the requested Git operation.

## Scripts

### `clone-repo-from-url.ps1`
Clones a GitHub repository into a single working folder.

- Prompts for an HTTPS GitHub repository URL (with or without `.git`).
- Uses the script directory as the base path.
- Creates (or reuses if empty) a subfolder named after the repository.
- Runs a normal `git clone` into that folder.

### `init-repoworktrees-from-url.ps1`
Initializes worktrees for all remote branches of a GitHub repository.

- Prompts for an HTTPS GitHub repository URL (with or without `.git`).
- Uses the script directory as the base path.
- Creates (or reuses if empty) a subfolder named after the repository.
- Performs a bare clone into `.repo` and adds a worktree per remote `origin` branch, setting each local branch to track its corresponding `origin/<branch>`.
