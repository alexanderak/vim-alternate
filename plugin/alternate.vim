" ============================================================================
" File:        plugin/alternate.vim
" Description: switch between alternate files
" Author:      Alexander Aksenov <facing-worlds@yandex.ru>
" License:     Vim license
" ============================================================================

if exists("g:loaded_alternate") && g:loaded_alternate
	finish
endif
let g:loaded_alternate = 1

" Go to file.
command! -nargs=0 -bar -count=0 A call alternate#switch('%', <count>, '')

" Split, vertical split, tab.
command! -nargs=0 -bar -count=0 -bang AS call alternate#switch('%', <count>, 's<bang>')
command! -nargs=0 -bar -count=0 -bang AV call alternate#switch('%', <count>, 'v<bang>')
command! -nargs=0 -bar -count=0 -bang AT call alternate#switch('%', <count>, empty('<bang>') ? 'Gt' : 't')

" Cycle throw files.
command! -nargs=0 -bar -count=1 AN call alternate#next('%', <count>, 'e')
command! -nargs=0 -bar -count=1 AP call alternate#next('%', <count>, 'e')

" List files.
command! -nargs=0 -bar AA call alternate#list('%', '', 1)
command! -nargs=0 -bar -bang AC call alternate#list('%', 'v', empty('<bang>') ? 2 : 3)
