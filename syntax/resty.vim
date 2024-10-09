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
syntax match   restyComment "#.*$" 
syntax match   restySection "^###"                      contained              
syntax match   restyFavorite /\v\s#.*/                  contained              
syntax region  restyReplace start=/\v\{\{/ end=/\v\}\}/ contained

highlight link restyComment      Comment
highlight link restySection      Constant 
highlight      restyFavorite     guifg=DarkYellow  gui=italic
highlight      restyReplace      guifg=DarkCyan    gui=NONE 


" --- define variable with replacement ---
syntax match restyValue /\v\s*.+/                       contained contains=restyReplace,restyComment 
syntax match restyKey /\v^([A-Za-z-_])+/                contained 
syntax match restyVarChar "^@"                          contained
syntax match restyVarCharCfg "^@cfg."                   contained 
syntax match restyVarKey /\v^\@([A-Za-z-_])+/           contained contains=restyVarChar
syntax match restyVarKeyCfg /\v^\@cfg\.([A-Za-z-_])+/   contained contains=restyVarCharCfg
syntax match restyColon /\v\s*:\s*/                     contained      
syntax match restyEqual /\v\s*\=\s*/                    contained  

highlight      restyColon        guifg=#F5E0DC     gui=NONE
highlight      restyEqual        guifg=#F5E0DC     gui=NONE
highlight link restyValue        Delimiter
highlight link restyKey          Delimiter
highlight      restyVarChar      guifg=LightGray   gui=bold 
highlight      restyVarCharCfg   guifg=LightGray   gui=bold  
highlight link restyVarKey       Delimiter
highlight link restyVarKeyCfg    Delimiter


" --- section, headers, query and variable ---
syntax region restySectionFavorite  start=/\v^###(\s#)?.*/                       end=/\n/  contains=restySection,restyFavorite
syntax region restyHeader           start=/\v^([A-Za-z-_])+\s*:\s*.+/            end=/\n/  contains=restyKey,restyColon,restyValue
syntax region restyQuery            start=/\v^([A-Za-z-_])+\s*\=\s*.+/           end=/\n/  contains=restyKey,restyEqual,restyValue
syntax region restyVariable         start=/\v^\@([A-Za-z-_])+\s*\=\s*.+/         end=/\n/  contains=restyVarChar,restyVarKey,restyEqual,restyValue
syntax region restyVariableCfg      start=/\v^\@cfg\.([A-Za-z-_])+\s*\=\s*.+/    end=/\n/  contains=restyVarCharCfg,restyVarKeyCfg,restyEqual,restyValue


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
highlight link restyVersion   Tag 
highlight link restyUrl       Constant


" syntax match restyHeader /\v^([A-Za-z-])+:\s*.+/       contains=restyReplace,restyComment 
" syntax match restyQuery /\v^([A-Za-z-])+\s*\=\s*.+/    contains=restyReplace,restyComment

" highlight link restyHeader       Delimiter 
" highlight link restyQuery        Tag


" syn include @JSON syntax/json.vim
" syn region rJson start=+{+ end=+}+ contains=@JSON fold transparent 

syntax region restyJsonBody start=+{+ end=+}+ 
highlight link restyJsonBody String

syntax region restyScript start=+--{%+ end=+--%}+ 
highlight link restyScript Tag


" syntax for resty
let b:current_syntax = "resty"

