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
vim.keymap.set("n", "<leader>rr", ":Resty run<CR>", { desc = "[R]esty [R]un request under the cursor" })
vim.keymap.set("n", "<leader>rl", ":Resty last<CR>", { desc = "[R]esty run [L]ast" })
```
The idea is, to define all rest calls in a `*.http` file and execute the definition where the cursor is (with: `Resty run`).

But it is also possible to define and call a request which is included in any file.
The request must start and end with: `###`

```go
/*
Here is the rest call definition:

###
GET https://reqres.in/api/users/2

###
*/
func my_rest_call() {
 // ..
}

```

## Definitions

### Types

- `variables`      : `@[variable-name]=[value]` and reference to the variable `{{variable-replacement}}`
- `method url`     : `GET http://host` (`[method] [space] [URL]`)
- `headers`        : delimiter `:` (example: `accept: application/json`)
- `query`          : delimiter `=` (example: `id = 5`)
- `body`           : starts with (first column): `{` and ends with (first column): `}`, between is valid JSON
- `script`         : starts with (first column): `--{%` and ends with (first column): `--%}`, between is valid LUA script
- `###`            : delimiter, if more as one request definition, or text before and/or after exist
- `#`              : comments

- substitution 
  - variable             : `{{variable-name}}` -> `{{host}}`
  - environment variable : `{{$[variable-name]}}` -> `{{$USER}}`
  - shell-commnad        : `{{>[command]}}` : replace this with the result of the command: `{{> echo "my value"}}`
  - prompt               : `{{:[name]}}` : prompt for put an input value: `{{:Name}}`

### Grammar

```
start              : variables | method url
variables          : variables | method url
method_url         : headers or queries | body
headers or queries : headers or queries | body
body               : body | script | delimiter (end)
script             : body | script | delimiter (end)
```

## Examples

###  Simple get call

```http
GET https://reqres.in/api/users/2
```

### Using local and global variables 

```
# variable for the hostname
@hostname = httpbin.org
# @hostname = {{$HOSTNAME}}       # from environment variable (start symbol: '$')
# @hostname = {{> ./myscript.sh}} # from script (start symbol: '>')
# @hostname = {{:hostname}}       # with input prompt (start symbol: ':')

###  

GET https://{{hostname}}/get
# with header
accept: application/json  


###  

# local variable overwrites global variable
@hostname = jsonplaceholder.typicode.com

GET https://{{hostname}}/comments

# with query parameter
id={{$ID}} # set ID from a environment variable
```

### Call with query parameter

```
###
GET https://reqres.in/api/users

delay = 1

### not necessary, only for running from this file
```

### Post with body

```http
###
POST https://api.restful-api.dev/objects

accept: application/json  
Content-type: application/json; charset=UTF-8

# body, the starting '{' and ending '}' must be in first column
{
   "name": "MY Apple MacBook Pro 16",
   "data": {
      "year": 2019,
      "price": 1849.99,
      "CPU model": "Intel Core i9",
      "Hard disk size": "1 TB"
   }
}
### not necessary, only for running from this file
```

### Login and save the Token

```
###
POST https://reqres.in/api/login
accept: application/json  
Content-type: application/json ; charset=UTF-8

{
    "email": "eve.holt@reqres.in",
    "password": "cityslicka"
}

# response: { "token": "QpwL5tke4Pnpja7X4" }

--{%
  local response = ctx.json_body()
  ctx.set("token", response.token)
--%}
# using the token with variable: {{token}}

### not necessary, only for running from this file
```

In LUA scripts you can use an `ctx` table, which has access to the following properties and methods:

```lua
local ctx = {
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

__Hint:__ with `cc` can the curl call canceled.

