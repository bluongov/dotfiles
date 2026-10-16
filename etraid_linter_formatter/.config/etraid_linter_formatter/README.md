# ESLint Configuration

Global ESLint configuration for development across all projects.

## Prerequisites

- **Node.js 22** or higher is required
- npm (comes with Node.js)

## Installation

1. Clone the repository to your home configuration directory:

```bash
git clone <repository-url> $HOME/.config/etraid_linter_formatter
cd $HOME/.config/etraid_linter_formatter
```

2. Install dependencies:

```bash
npm i
```

## Visual Studio Code Setup

### ESLint Configuration

To ensure proper linting in Visual Studio Code, configure the ESLint extension to use this global configuration and runner.

#### 1. Install ESLint Extension and Prettier Extension

Install the [ESLint extension](https://marketplace.visualstudio.com/items?itemName=dbaeumer.vscode-eslint) from the VS Code marketplace.
Install the [Prettier extension](https://marketplace.visualstudio.com/items?itemName=esbenp.prettier-vscode) from the VS Code marketplace.

#### 2. Configure VS Code User Settings

Add the following settings to your **User Settings** (not workspace settings) to use this global ESLint configuration:

Press `Ctrl+Shift+P` (Linux) or `Cmd+Shift+P` (Mac), type "Preferences: Open Remote Settings (JSON) ", and add:

```json
{
  "[javascript]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode",
    "editor.formatOnSave": true
  },
  "[javascriptreact]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode",
    "editor.formatOnSave": true
  },
  "prettier.configPath": "/home/<your-username>/.config/etraid_linter_formatter/.prettierrc.json",
  "prettier.prettierPath": "/home/<your-username>/.config/etraid_linter_formatter/node_modules/prettier/index.cjs",

  "eslint.nodePath": "/home/<your-username>/.config/etraid_linter_formatter/node_modules",
  "eslint.options": {
    "overrideConfigFile": "/home/<your-username>/.config/etraid_linter_formatter/eslint.config.mjs"
  },
  "editor.codeActionsOnSave": {
    "source.fixAll.eslint": "always"
  },
  "eslint.workingDirectories": [
    {
      "mode": "auto"
    }
  ],
  "eslint.validate": ["javascript", "javascriptreact", "typescript", "typescriptreact", "json", "jsonc"]
}
```

**Important:** Replace `<your-username>` with your actual username.

## Neovim setup

Configure Neovim for linting and formatting using your **user-level ESLint and Prettier configs**—similar to a global VS Code setup.

### Prerequisites

- ESLint config: `/home/<your-username>/.config/etraid_linter_formatter/eslint.config.mjs`
- Prettier config: `/home/<your-username>/.config/etraid_linter_formatter/.prettierrc.json`
- ESLint CLI: `/home/<your-username>/.config/etraid_linter_formatter/node_modules/.bin/eslint`
- Prettier binary: `/home/<your-username>/.config/etraid_linter_formatter/node_modules/prettier/index.cjs`

> Replace `<your-username>` with your actual username.

---

## 1. Linting (nvim-lint)

**Plugin:** [mfussenegger/nvim-lint](https://github.com/mfussenegger/nvim-lint)

**Basic config:**

```lua
local lint = require 'lint'

lint.linters.eslint_d = {
  cmd = '/home/<your-username>/.config/etraid_linter_formatter/node_modules/.bin/eslint',
  args = {
    '--format', 'json',
    '--stdin',
    '--stdin-filename', function() return vim.api.nvim_buf_get_name(0) end,
    '--config', '/home/<your-username>/.config/etraid_linter_formatter/eslint.config.mjs',
  },
}

lint.linters_by_ft = {
  javascript = { 'eslint_d' },
  typescript = { 'eslint_d' },
}
```

**Lint on save:**

```lua
vim.api.nvim_create_autocmd('BufWritePost', {
  callback = function() require('lint').try_lint() end,
})
```

---

## 2. Formatting (conform.nvim)

**Plugin:** [stevearc/conform.nvim](https://github.com/stevearc/conform.nvim)

**Basic config:**

```lua
require('conform').setup {
  formatters = {
    prettier = {
      prepend_args = function()
        return { '--config', '/home/<your-username>/.config/etraid_linter_formatter/.prettierrc.json' }
      end,
    },
  },
  formatters_by_ft = {
    javascript = { 'prettier' },
    javascriptreact = { 'prettier' },
    typescript = { 'prettier' },
    typescriptreact = { 'prettier' },
  },
  format_on_save = function()
    return { timeout_ms = 500 }
  end,
}
```

---

### Keymaps (optional)

- **Lint manually:**  
  `vim.keymap.set('n', '<leader>ll', function() require('lint').try_lint() end)`

- **Format manually:**  
  `vim.keymap.set('n', '<leader>ff', function() require('conform').format() end)`

---

## Verify ESLint Setup

To verify ESLint is working correctly:

1. Open any JavaScript/TypeScript file in VS Code
2. Check the VS Code status bar for the ESLint indicator
3. You should see linting errors/warnings highlighted in the editor

Or run ESLint manually from the terminal:

```bash
$HOME/.config/etraid_linter_formatter/node_modules/.bin/eslint <path-to-file>
```

## Troubleshooting

### ESLint not working in VS Code

1. **Reload VS Code**: Press `Ctrl+Shift+P` / `Cmd+Shift+P` and run "Developer: Reload Window"
2. **Check ESLint Output**: Open the Output panel (`Ctrl+Shift+U` / `Cmd+Shift+U`) and select "ESLint" from the dropdown
3. **Verify Node version**: Run `node --version` to ensure Node.js 22 is installed
4. **Verify installation path**: Run `ls $HOME/.config/etraid_linter_formatter` to confirm files exist
5. **Check absolute paths**: Ensure all paths in VS Code settings use absolute paths with your correct username
6. **Reinstall dependencies**:
   ```bash
   cd $HOME/.config/etraid_linter_formatter
   npm ci
   ```

### Node version mismatch

If you have multiple Node versions installed, consider using a version manager:

- **nvm** (Node Version Manager):

  ```bash
  nvm install 22
  nvm use 22
  ```

- **fnm** (Fast Node Manager):
  ```bash
  fnm install 22
  fnm use 22
  ```
