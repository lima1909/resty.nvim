" JSON String
syntax match jsonString /"\([^"]*\)"/
highlight link jsonString String

" JSON Number
syntax match jsonNumber /\v-?\d+(\.\d+)?([eE]-?\d+)?/
highlight link jsonNumber Number

" JSON Boolean
syntax keyword jsonBoolean true false
highlight link jsonBoolean Boolean

" JSON Null
syntax keyword jsonNull null
highlight link jsonNull Constant

" JSON Objects and Arrays
syntax match jsonBraces /[{}]/
syntax match jsonBrackets /[\[\]]/
highlight link jsonBraces Delimiter
highlight link jsonBrackets Delimiter

" JSON Key
syntax match jsonKey /"\([^"]*\)":/
highlight link jsonKey Identifier

