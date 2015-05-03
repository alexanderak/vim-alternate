" ============================================================================
" File:        plugin/alternate.vim
" Description: switch between alternate files
" Author:      Alexander Aksenov <facing-worlds@yandex.ru>
" License:     Vim license
" ============================================================================

if exists("loaded_alternate") && loaded_alternate
	finish
endif
let loaded_alternate = 1

" Go to file.
command! -nargs=? -complete=file -count=0 A call alternate#switch('%', <count>, '')

" Split, vertical split, tab.
command! -nargs=? -complete=file -count=0 -bang AS call alternate#switch('%', <count>, 's<bang>')
command! -nargs=? -complete=file -count=0 -bang AV call alternate#switch('%', <count>, 'v<bang>')
command! -nargs=? -complete=file -count=0 -bang AT call alternate#switch('%', <count>, empty('<bang>') ? 'Gt' : 't')

" Cycle throw files.
command! -nargs=? -complete=file -count=1 AN call alternate#next('%', <count>, 'e')
command! -nargs=? -complete=file -count=1 AP call alternate#next('%', <count>, 'e')

" List files.
command! -nargs=? -complete=file       AA call alternate#list('%', '', 1)
command! -nargs=? -complete=file -bang AC call alternate#list('%', 'v', empty('<bang>') ? 2 : 3)
