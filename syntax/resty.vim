" syntax for resty
if exists('b:current_syntax')
  finish
endif

" Some NOTE:
"
" get information of the syntax under the cursor:
" :echo synIDattr(synID(line("."), col("."), 1), "name")
"
"
" Structure  PreProc Identifier  Conditional
" Typedef  Statement Tag Title
" Underlined Delimiter
" Error Define Operator Label Character 


" --- define basic syntax comment and section ---
syntax match restyComment "#.*$"                                      
syntax match restySection "^###.*$"                                   

highlight link restyComment      Comment
highlight link restySection      Constant " Conditional


" --- define variable with replacement ---
syntax match restyReplace /\v\{\{.+\}\}/               contained 
syntax match restyVariableChar "^@"                    nextGroup=restyVariable 
syntax match restyVariableCharCfg "^@cfg."             nextGroup=restyVariable 
syntax match restyVariable /\v([A-Za-z-_])+\s*\=\s*.+/  contains=restyReplace,restyComment 

highlight link restyReplace         Function 
highlight link restyVariableChar    Function
highlight link restyVariableCharCfg Function
highlight link restyVariable        Tag 


" --- define the request: method URL HTTP-Version ---
syntax region restyRequest 
    \ start=/^\(GET\|POST\|PUT\|DELETE\|HEAD\|OPTIONS\|PATCH|TRACE\)/ 
    \ end=/\n/ 
    \ contains=restyUrl,restyVersion,restyComment 

syntax match restyUrl /http[s]\?:\/\/[A-Za-z0-9\/\-\=\._:?%&{}()\]\[]\+/  contained contains=restyUrlQuery,restyReplace
syntax match restyUrlQuery /[?&]/                                         contained 
syntax match restyVersion /HTTP\/[0-9]\.[0-9]/                            contained

highlight link restyRequest   Constant
highlight link restyUrlQuery  Error 
highlight link restyVersion   Tag 
" highlight link restyUrl       Structure
highlight  restyUrl       guifg=#F5E0DC gui=italic ",underline





" --- headers and query ---
syntax match restyHeader /\v^([A-Za-z-])+:\s*.+/       contains=restyReplace,restyComment 
syntax match restyQuery /\v^([A-Za-z-])+\s*\=\s*.+/    contains=restyReplace,restyComment

highlight link restyHeader       Delimiter 
highlight link restyQuery        Tag


" syn include @JSON syntax/json.vim
" syn region rJson start=+{+ end=+}+ contains=@JSON fold transparent 

syntax region restyJsonBody start=+{+ end=+}+ 
highlight link restyJsonBody String

syntax region restyScript start=+--{%+ end=+--%}+ 
highlight link restyScript Tag


" syntax for resty
let b:current_syntax = "resty"

