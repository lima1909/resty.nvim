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

### Types

- `variables`      : `@[variable-name]=[value]` and reference to the variable `{{variable-replacement}}`
- `method url`     : `GET http://host` (`[method] [space] [URL]`)
- `headers`        : delimiter `:` (example: `accept: application/json`)
- `query`          : delimiter `=` (example: `id = 5`)
- `body`           : starts with: first row `{` and ends with: first row `}`, between is valid JSON
- `###`            : delimiter, if more as one request definition, or text before and/or after exist
- `#`              : comments
- `{{>[command]}}` : replace this with the result of the command: for user: root `{{> echo $USER}}` -> `root`

### Grammar

```
start              : variables | method url
variables          : variables | method url
method_url         : headers or queries | body
headers or queries : headers or queries | body
body               : body | delimiter (end)
```

## Example

```http
# global variables
@hostname = httpbin.org

### 
GET https://{{hostname}}/get

# headers
accept: application/json  


###  

# local variable overwrites global variable
@hostname = jsonplaceholder.typicode.com

GET https://{{hostname}}/comments

# query
postId = 5
id={{> echo $ID}} # execute the 'echo' command and replace it with the environment variable ($ID)


###
POST https://api.restful-api.dev/objects

accept: application/json  
Content-type: application/json; charset=UTF-8

# body
{
   "name": "MY Apple MacBook Pro 16",
   "data": {
      "year": 2019,
      "price": 1849.99,
      "CPU model": "Intel Core i9",
      "Hard disk size": "1 TB"
   }
}
```

## Response|Result view

There are three views for the result (the rest-call-response)

| view      | short cut | hint                                         |
|-----------|-----------|----------------------------------------------|
| `body`    |   `b`     | response body                                |
| `headers` |   `h`     | response headers                             |
| `info`    |   `i`     | shows information from the call and response |


### Short cuts for the body-view

Hint: `jq` must be installed

| key | description                   | command/example  |
|-----|-------------------------------|------------------|
| `p` | json pretty print             | `jq .`           |
| `q` | jq query                      | `jq .id`         |
| `r` | reset to the origininal json  | -                |

