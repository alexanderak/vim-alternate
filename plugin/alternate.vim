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
command! -nargs=? -complete=file -count=0 A  call alternate#switch('%', <count>, 'g')

" Edit file.
command! -nargs=? -complete=file -count=0 AE call alternate#switch('%', <count>, 'e')

" Split, vertical split, new tab.
command! -nargs=? -complete=file -count=0 -bang AS call alternate#switch('%', <count>, 's<bang>')
command! -nargs=? -complete=file -count=0 -bang AV call alternate#switch('%', <count>, 'v<bang>')
command! -nargs=? -complete=file -count=0 -bang AT call alternate#switch('%', <count>, 't<bang>')

" Cycle throw files.
command! -nargs=? -complete=file -count=1 AN call alternate#next('%', <count>, 'e')
command! -nargs=? -complete=file -count=1 AP call alternate#next('%', <count>, 'e')

" List files.
command! -nargs=? -complete=file       AA call alternate#list('%', 'e', 1)
command! -nargs=? -complete=file -bang AC call alternate#list('%', 's', empty('<bang>') ? 2 : 3)

" Usefull mappings.
nnoremap <silent> ga :<C-U>call alternate#switch('%', v:count, 'e')<CR>
nnoremap <silent> [a :<C-U>call alternate#next('%', -v:count1, 'e')<CR>
nnoremap <silent> ]a :<C-U>call alternate#next('%', v:count1, 'e')<CR>
