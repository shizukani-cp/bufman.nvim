" syntax/bufman.vim
if exists("b:current_syntax")
  finish
endif

" 行頭の数字とそれに続くスペースを隠す
syntax match BufManBufNr /^\d\+\s/ conceal

let b:current_syntax = "bufman"
