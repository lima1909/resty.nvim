# resty.nvim

[![Build Status]][Build Action][![License]]

[Build Status]: https://github.com/lima1909/resty.nvim/actions/workflows/ci.yaml/badge.svg
[Build Action]: https://github.com/lima1909/resty.nvim/actions
[License]:      https://img.shields.io/github/license/lima1909/resty.nvim?style=for-the-badge

The main goal of _resty_ is to build a fast and easy-to-use http-rest-client for neovim complete written in LUA.

<div align="center">

![image](https://github.com/lima1909/resty.nvim/blob/main/pic/resty.png)

</div>

## These are the features that contribute to this goal:

* meaningful error messages by editing the input file
* completion (if `hrsh7th/nvim-cmp` is installed) for mainly used headers and possible configurations
* different variables types: from environment variables, commands (with cache) or values
* display the values of defined variables without executing the request
* executing from `lua scripts` (post-request hook)
* further processing from json result with `jq`
* create your own favorite list with `nvim-telescope/telescope.nvim` (if installed) for finding often used request in a large input file
* write the request definition in which file you want (directly to the place where they are used)

## Dependencies

- `curl` execute the request definition
- `jq` (_optional_, but recommended) query the body
- `nvim-telescope/telescope.nvim` plugin (_optional_), for using a listing of available favorites 
- `hrsh7th/nvim-cmp` plugin (_optional_) for headers and configurations completion

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

## Syntax

- variable definition (_optional_):
  - `@[variable-name]=[value]` or `@[variable-name]={{variable-replacement}}`
  - `variable-replacement`: shell command, environment variable or prompt  
  - `configuration variables`: for curl (timeout, insecure, proxy, ...) or for resty (check_json_body )  
- request definition (_mandatory_):
  - `method` (GET, POST, ...)
  - `url` (http://host, https://host:port, http://127.0.0.1:443?id=7)
  - `http version` (HTTP/1.0) (_optional_)
- headers and or query parameter (_optional_)
- json body (optional)
- lua script (post-request hook) (_optional_)
- other:
  - `#`: comments
  - `###`: delimiter, if more as one request definition, or text before and/or after exist
  - `### #my favorite` : delimiter, with defining a favorite ('my favorite') for the following request definition

## Example

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

