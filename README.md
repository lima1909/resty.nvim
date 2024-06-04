# resty.nvim

A small http/rest client plugin for neovim

<div align="center">

![image](https://github.com/lima1909/resty.nvim/blob/main/pic/resty.png)

</div>

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

## Example

```
###  
GET https://jsonplaceholder.typicode.com/comments

# headers
accept: application/json  

# query values
postId = 5
id=21

### 

# variable for the hostname
@hostname = httpbin.org

GET https://{{hostname}}/get

accept: application/json  
```

## Commands

```lua
vim.keymap.set("n", "<leader>rr", ":Resty run<CR>", { desc = "[R]esty [R]un" })
vim.keymap.set("n", "<leader>rl", ":Resty last<CR>", { desc = "[R]esty run [L]ast" })
```
