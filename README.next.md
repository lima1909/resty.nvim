<div align="center">

# resty.nvim 

[![Build Status](https://img.shields.io/github/actions/workflow/status/lima1909/resty.nvim/ci.yaml?style=for-the-badge)](https://github.com/lima1909/resty.nvim/actions)
[License](https://img.shields.io/github/license/lima1909/resty.nvim?style=for-the-badge)
[![Stars](https://img.shields.io/github/stars/lima1909/resty.nvim?style=for-the-badge)](https://github.com/lima1909/resty.nvim/stargazers)

A **fast** and **easy-to-use** HTTP-Rest-Client plugin for neovim, completely written in LUA.

[Features](#features) • [Install](#install) • [Syntax](#syntax) • [Examples](#examples)

![image](https://github.com/lima1909/resty.nvim/blob/main/pic/resty.png)


</div>

## Features

These are the features that contribute to this goal:

* meaningful error messages by editing the input file
* completion (if `hrsh7th/nvim-cmp` is installed) for mainly used headers and possible configurations
* different variables types: from environment variables, shell commands (with cache), input prompt or values
* executing from `LUA scripts` (post request hook)
* display the values of defined variables without executing the request (simple setting the cursor on the variable-replacement)
* further processing from json result with `jq`
* create your own favorite list with `nvim-telescope/telescope.nvim` (if installed) for finding often used request in a large input file
* write the request definition in which file you want (nearby to the code, where you have implement the rest service)

## Install

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

#### Supported Neovim versions:

- Latest nightly
- 0.10.x

#### Dependencies

- `curl` (_mandatory_) execute the request definition
- `jq` (_optional, but recommended_) query the response body
- `nvim-telescope/telescope.nvim` plugin (_optional_), for using a listing of available favorites 
- `hrsh7th/nvim-cmp` plugin (_optional_) for headers and configurations completion

## Syntax

- global and local variable definition (_optional_):
  - `@[variable-name]=[value]` or `@[variable-name]={{variable-replacement}}`
  - `variable-replacement`: shell command, environment variable or input prompt  
    - variable-replacement are supported in: url, variable-, header- and query-values, 
  - `configuration variables`: for curl (timeout, insecure, proxy, ...) or for resty (check_json_body)  
- request definition 
  - `method` (GET, POST, ...) (_mandatory_):
  - `url` (http://host, https://host:port, http://127.0.0.1:443?id=7) (_mandatory_):
  - `http version` (HTTP/1.0) (_optional_)
- headers and or query parameter (_optional_)
- json-body (_optional_), after the json-body must the request definition ends or an blank line follows
- LUA-script (post request hook) (_optional_), after the script must the request definition ends or an blank line follows
- other:
  - `#`: comments
  - `###`: delimiter, if more as one request definition, or text before and/or after exist
  - `### #my favorite` : delimiter, with defining a favorite ('my favorite') for the easy to finding the request definition

#### Syntax in action 

```http
# variable for the hostname
@hostname = httpbin.org          # variable with value
@hostname = {{$HOSTNAME}}        # from environment variable (start symbol: '$')
@hostname = {{>  ./myscript.sh}} # from script (start symbol: '>')
@hostname = {{>> ./myscript.sh}} # from script (start symbol: '>>'), the result will be cached
@hostname = {{:hostname}}        # with input prompt (start symbol: ':')

@cfg.timeout = 1000              # curl configuration for timeout (prefix: @cfg.)
@cfg.check_json_body = true      # resty configuration for validate the json body before execute (prefix: @cfg.)

###  #my favorite
GET https://{{hostname}}/get?id=7
# you can click (set the cursor) on {{hostname}} and get displayed the current value
accept: application/json  
# id = 7 this equivalent to ?id=7

### 
# local variable overwrites global variable
@hostname = jsonplaceholder.typicode.com

POST https://{{hostname}}/comments
accept: application/json  

{ "comment": "my comment" }
```

#### In LUA scripts you can use an `ctx` table, which has access to the following properties and methods:

```lua
local ctx = {
    -- result of the current request
    -- body = '{}', status = 200, headers = {}, exit = 0, global_variables = {}
    result = ...,
    -- set global variables with key and value
    set = function(key, value) end,
    -- parse the JSON body
    json_body = function() end,
    -- jq to the body
    jq_body = function(filter) end,
}
```

## Commands

| User command                      | Description                                                                           |
|-----------------------------------|---------------------------------------------------------------------------------------|
| `:Resty run`                      | run request under the cursor OR <br>in `visual mode` run the marked request rows      |
| `:Resty run [request definition]` | run request which is given by input, rows are seperated by `\n`<br> (you can simulate `\n` with &lt;C-v&gt;&lt;CR&gt; in `command mode`) |
| `:Resty last`                     | run last successfully executed request                                                |
| `:Resty favorite`                 | show a telescope view with all as favorite marked requests                            |
| `:Resty favorite [my favorite]`   | run marked request `my favorite`, independend, where the cursor is or in which buffer |

Examples for using a command with a keymap configuration:

```lua
vim.keymap.set({"n","v"},"<leader>rr", ":Resty run<CR>",{desc="[R]esty [R]un request under the cursor"})
vim.keymap.set({"n","v"},"<leader>rv", ":Resty favorite<CR>",{desc="[R]esty [V]iew favorites"})
```


## Response|Result view

There are four views for the result (the rest-call-response)

| view      | short cut | description                                  |
|-----------|-----------|----------------------------------------------|
| `body`    |   `b`     | response body                                |
| `headers` |   `h`     | response headers                             |
| `info`    |   `i`     | shows information from the call and response |
| `?`       |   `?`     | shows help information for keybindings       |


#### Short cuts for the view: body

`jq` must be installed!

| short cut | description                   | 
|-----------|-------------------------------|
| `p`       | json pretty print             |
| `q`       | jq query                      |
| `r`       | reset to the origininal json  |

__Hint:__ with `cc` can the curl call canceled.

## Examples

#### Give a star for this great project ;-)

```http
PUT https://api.github.com/user/starred/lima1909/resty.nvim
Authorization: Bearer {{my-token}}
Accept: application/vnd.github+json
```

#### Login with saving the result token

```http
POST https://reqres.in/api/login
accept: application/json  
Content-type: application/json ; charset=UTF-8

{
    "email": "eve.holt@reqres.in",
    "password": "cityslicka"
}

# response: { "token": "QpwL5tke4Pnpja7X4" }
# save the token into the variable: {{login.token}}

--{%
  local body = ctx.json_body()
  ctx.set("login.token", body.token)
--%}
```

#### Call with query parameter

```http
GET https://reqres.in/api/users
delay = 1

### both are the same
GET https://reqres.in/api/users?delay=1 
```

#### Post with body

```http
POST https://api.restful-api.dev/objects
accept: application/json  
Content-type: application/json; charset=UTF-8

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
