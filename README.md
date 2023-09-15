# mocoapp-plugin

## Description

`mocoapp-plugin` is a Neovim plugin to interact with the Mocoapp API directly from your editor. It allows you to select projects and tasks, log time, and more, without leaving your development environment.

## Prerequisites

- Neovim (0.5 or higher)
- `curl` for API requests
- [dressing](https://github.com/stevearc/dressing.nvim): Enhanced input UI
- [notify](https://github.com/rcarriga/nvim-notify): Custom, more appealing, notifications

## Installation

### Using Plug

```
Plug 'pfinkbeiner/mocoapp-plugin'
```

### Using Packer

```
use {'pfinkebienr/mocoapp-plugin'}
```

### Manually

Clone this repository and copy the files to your Neovim plugin directory.

## Configuration

Set your Mocoapp API token and domain in your `init.vim` or `init.lua`:

```vim
let g:mocoapp_api_token = "your-api-token"
let g:mocoapp_api_domain = "your-domain"
```

or in Lua:

```lua
vim.g.mocoapp_api_token = "your-api-token"
vim.g.mocoapp_api_domain = "your-domain"
```

## Usage

Run `:Moco` to start the process. It will:

1. Fetch the list of projects and tasks.
2. Prompt you to select a project and task.
3. Prompt you to enter a date.
4. Prompt you to enter the time spent on the task.
5. Prompt you to enter a description for the task.
6. Save the time entry.

## Development

The plugin is written in Lua and uses Neovim's native Lua API for all operations. Keep in mind that this is also my very first Lua project, at all.
So, there are most likely some bugs. ;-)
