# resty.nvim


[![Build Status]][Build Action]

[Build Status]: https://github.com/lima1909/resty.nvim/actions/workflows/ci.yaml/badge.svg
[Build Action]: https://github.com/lima1909/resty.nvim/actions


A small http/rest client plugin for neovim

<div align="center">

![image](https://github.com/lima1909/resty.nvim/blob/main/pic/resty.png)

</div>

## Supported Neovim versions:

- Latest nightly
- 0.10.x

## Installation

- packer.nvim:

  ```lua
  use {
    "lima1909/resty.nvim",
    requires = { "nvim-lua/plenary.nvim" },
  }
  ```

- lazy.nvim:

  ```lua
  {
    "lima1909/resty.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
  },
  ```

## Dependencies

- `curl` execute the rest definition
- `jq` (optional) query the body

## Commands

```lua
vim.keymap.set("n", "<leader>rr", ":Resty run<CR>", { desc = "[R]esty [R]un" })
vim.keymap.set("n", "<leader>rl", ":Resty last<CR>", { desc = "[R]esty run [L]ast" })
```

## Definitions

- variables: definition: `@[variable-name]=[value]` and reference to the variable `{{variable-replacement}}`
- `###` delimiter between several rest calls
- first row after `###` is the rest call: `[method] [space] [URL]`
- headers: delimiter `:`
- query: delimiter `=`

## Example

```
# global variables
@hostname = httpbin.org

### 
GET https://{{hostname}}/get

# headers
accept: application/json  

###  
GET https://jsonplaceholder.typicode.com/comments

# query
postId = 5
id=21
```

