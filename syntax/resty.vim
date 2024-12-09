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
" Directory " WarningMsg

" --- CURL command syntax highlighting
syntax match restyCurlStart    ">curl"                contained
syntax match restyCurlMethod   /\v\-X\s+[\'A-Za-z]+/  contained 
syntax region restyCurlCmd 
    \ start=+>curl+ 
    \ end=/\v^(\s)*$/
    \ contains=restyCurlStart,restyUrl,restyCurlMethod

highlight link restyCurlStart        Constant
highlight link restyCurlMethod       Function
highlight link restyCurlCmd     Delimiter


" --- define basic syntax comment and section ---
syntax match   restyComment "#.*$" 
syntax match   restySection "^###"                      contained              
syntax match   restyFavorite /\v\s#.*/                  contained              
syntax region  restyReplace start=/\v\{\{/ end=/\v\}\}/ contained

highlight link restyComment      Comment
highlight link restySection      WarningMsg " Constant 
highlight link restyFavorite     Function 
" highlight link restyReplace      FoldColumn 
highlight      restyReplace      guifg=DarkGray    gui=NONE


" --- define variable with replacement ---
syntax match restyValue /\v\s*.+/                       contained contains=restyReplace,restyComment 
syntax match restyKey /\v^([A-Za-z-_])+/                contained 
syntax match restyVarChar "^@"                          contained
syntax match restyVarCharCfg "^@cfg."                   contained 
syntax match restyVarKey /\v^\@([A-Za-z-_])+/           contained contains=restyVarChar
syntax match restyVarKeyCfg /\v^\@cfg\.([A-Za-z-_])+/   contained contains=restyVarCharCfg
syntax match restyColon /\v\s*:\s*/                     contained      
syntax match restyEqual /\v\s*\=\s*/                    contained  

highlight link restyColon        Function 
highlight link restyEqual        Constant
highlight link restyKey          Keyword
" highlight      restyValue        guifg=DarkCyan    gui=italic
highlight link restyVarChar      Delimiter
highlight link restyVarCharCfg   Keyword
highlight link restyVarKey       Delimiter
highlight link restyVarKeyCfg    Delimiter


" --- section, headers, query and variable ---
syntax region restySectionFavorite  start=/\v^###(\s#)?.*/                     end=/\n/  contains=restySection,restyFavorite
syntax region restyHeader           start=/\v^[A-Za-z-_]+\s*:\s*.+/            end=/\n/  contains=restyKey,restyColon,restyValue
syntax region restyQuery            start=/\v^[A-Za-z-_]+\s*\=\s*.+/           end=/\n/  contains=restyKey,restyEqual,restyValue
syntax region restyVariable         start=/\v^\@([A-Za-z-_])+\s*\=\s*.+/       end=/\n/  contains=restyVarChar,restyVarKey,restyEqual,restyValue
syntax region restyVariableCfg      start=/\v^\@cfg\.([A-Za-z-_])+\s*\=\s*.+/  end=/\n/  contains=restyVarCharCfg,restyVarKeyCfg,restyEqual,restyValue


" --- define the request: method URL HTTP-Version ---
syntax region restyRequest 
    \ start=/^\(GET\|POST\|PUT\|DELETE\|HEAD\|OPTIONS\|PATCH|TRACE\)\s\s*h/ 
    \ end=/\n/ 
    \ contains=restyUrl,restyVersion,restyComment 

syntax match restyUrl /http[s]\?:\/\/[A-Za-z0-9\/\-\=\._:?%&{}()\]\[]\+/  contained contains=restyUrlQuery,restyReplace
syntax match restyUrlQuery /[?&]/                                         contained 
syntax match restyVersion /HTTP\/[0-9]\.[0-9]/                            contained

highlight link restyRequest   Function 
highlight link restyUrlQuery  Error 
highlight link restyVersion   Delimiter
highlight link restyUrl       WarningMsg 




" syntax match restyHeader /\v^([A-Za-z-])+:\s*.+/       contains=restyReplace,restyComment 
" syntax match restyQuery /\v^([A-Za-z-])+\s*\=\s*.+/    contains=restyReplace,restyComment

" highlight link restyHeader       Delimiter 
" highlight link restyQuery        Tag


" syn include @JSON syntax/json.vim
" syn region rJson start=+{+ end=+}+ contains=@JSON fold transparent 

syntax region restyJsonBody  start=+{+ end=+}+     contains=restyJsonBody
highlight link restyJsonBody String

syntax match restyJsonBodyFile   /\v^\<.*/ 
highlight link restyJsonBodyFile String

syntax region restyScript start=+--{%+ end=+--%}+ 
highlight link restyScript Tag

syntax region restyScriptHttp start=+> {%+ end=+%}+ 
highlight link restyScriptHttp Tag

" syntax for resty
let b:current_syntax = "resty"

