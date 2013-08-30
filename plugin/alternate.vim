" ============================================================================
" File:        alternate.vim
" Description: switch between alternate files
" Author:      Alexander Aksenov <facing-worlds@yandex.ru>
" License:     Vim license
" ============================================================================

if exists("loaded_alternate") && loaded_alternate
	finish
endif
let loaded_alternate = 1

" Init {{{
if exists('g:alternate_dict')
	let s:dict = g:alternate_dict
else
	" Directories {{{
	if exists('g:alternate_incdirs')
		let s:incdirs = g:alternate_incdirs
	else
		let s:incdirs = [
		              \   'reg:/src/include/',
		              \   'reg:/src/inc/',
		              \   'reg:/source/include/',
		              \   'rel:../inc',
		              \   'rel:../include',
		              \   '',
		              \ ]
	endif

	if exists('g:alternate_srcdirs')
		let s:srcdirs = g:alternate_srcdirs
	else
		let s:srcdirs = [
		              \   'reg:/include/src/',
		              \   'reg:/inc/src/',
		              \   'reg:/include/source/',
		              \   'rel:../src',
		              \   'rel:../source',
		              \   '',
		              \ ]
	endif
	" }}}

	" Names {{{
	if exists('g:alternate_incnames')
		let s:incnames = g:alternate_incnames
	else
		let s:incnames = [ '' ]
	endif

	if exists('g:alternate_srcnames')
		let s:srcnames = g:alternate_srcnames
	else
		let s:srcnames = [ '' ]
	endif
	" }}}

	let s:dict = {}

	" C, C++, Objective-C {{{
	let s:dict['h']   = [ [ 'c', 'cpp', 'm', 'mm' ], s:srcdirs, s:srcnames ]
	let s:dict['hh']  = [ [ 'cc'                  ], s:srcdirs, s:srcnames ]
	let s:dict['hpp'] = [ [ 'cpp'                 ], s:srcdirs, s:srcnames ]
	let s:dict['hxx'] = [ [ 'cxx'                 ], s:srcdirs, s:srcnames ]
	let s:dict['H']   = [ [ 'C'                   ], s:srcdirs, s:srcnames ]

	let s:dict['c']   = [ [ 'h'                   ], s:incdirs, s:incnames ]
	let s:dict['cc']  = [ [ 'hh'                  ], s:incdirs, s:incnames ]
	let s:dict['cpp'] = [ [ 'hpp', 'h'            ], s:incdirs, s:incnames ]
	let s:dict['cxx'] = [ [ 'hxx'                 ], s:incdirs, s:incnames ]
	let s:dict['m']   = [ [ 'h'                   ], s:incdirs, s:incnames ]
	let s:dict['mm']  = [ [ 'h'                   ], s:incdirs, s:incnames ]
	let s:dict['C']   = [ [ 'H'                   ], s:incdirs, s:incnames ]
	" }}}

	" Extensions {{{
	if exists('g:alternate_incexts')
		for [s:key, s:value] in items(g:alternate_incexts)
			let s:dict[s:key] = [ s:value, s:incdirs, s:incnames ]
		endfor
		unlet s:key s:value
	endif

	if exists('g:alternate_srcexts')
		for [s:key, s:value] in items(g:alternate_srcexts)
			let s:dict[s:key] = [ s:value, s:srcdirs, s:srcnames ]
		endfor
		unlet s:key s:value
	endif
	" }}}

	" Extend dictionary {{{
	if exists('g:alternate_extenddict')
		call extend(s:dict, g:alternate_extenddict)
	endif
	" }}}
endif

if exists('g:alternate_slash')
	let s:slash = g:alternate_slash
else
	let s:slash = &ssl == 0 &&
	            \ (has('win16') || has('win32') || has('win64')) ? '\' : '/'
endif
" }}}

" Helper functions {{{
function! s:Substitute(string, pattern)
	let sep = strpart(a:pattern, 0, 1)
	let patend = match(a:pattern, sep, 1)
	let pat = strpart(a:pattern, 1, patend - 1)
	let subend = match(a:pattern, sep, patend + 1)
	let sub = strpart(a:pattern, patend + 1, subend - patend - 1)
	let flags = strpart(a:pattern, strlen(a:pattern) - 2)
	if flags ==# sep
		let flags = ''
	endif
	return substitute(a:string, pat, sub, flags)
endfunction

function! s:HasBufferInTab(buffer, tab)
	let buffers = tabpagebuflist(a:tab)
	let index = 0
	let size = len(buffers)
	while index < size
		if a:buffer == buffers[index]
			return 1
		endif
		let index += 1
	endwhile
	return 0
endfunction

function! s:FindTabWithBuffer(buffer, curtab)
	let index = 0
	while index < a:curtab
		if s:HasBufferInTab(a:buffer, index)
			return index
		endif
		let index += 1
	endwhile
	let index = a:curtab + 1
	let size = tabpagenr('$')
	while index <= size
		if s:HasBufferInTab(a:buffer, index)
			return index
		endif
		let index += 1
	endwhile
	return 0
endfunction

function! s:FindtListItem(list, name, shift)
	let index = match(a:list, a:name)
	if index != -1
		let len = len(a:list)
		let index = (index + a:shift) % len
		if index < 0
			let index += len
		endif
	endif
	return index
endfunction
" }}}

" Core functions {{{
function! s:ExpandRoot(root, pattern)
	if empty(a:pattern)
		return a:root
	endif
	let prefix = strpart(a:pattern, 0, 4)
	if prefix ==# 'reg:'
		let pattern = strpart(a:pattern, 4)
		let root = s:Substitute(a:root, pattern)
		return root ==# a:root ? '' : root
	endif
	return ''
endfunction

function! s:ExpandDir(dir, pattern)
	let prefix = strpart(a:pattern, 0, 4)
	if prefix ==# 'reg:'
		let pattern = strpart(a:pattern, 4)
		let dir = s:Substitute(a:dir, pattern)
		return dir ==# a:dir ? '' : dir
	elseif prefix ==# 'rel:'
		return a:dir . s:slash . strpart(a:pattern, 4)
	elseif prefix ==# 'abs:'
		return strpart(a:pattern, 4)
	elseif empty(a:pattern)
		return a:dir
	endif
	return ''
endfunction

function! s:ExpandName(name, pattern)
	return s:ExpandRoot(a:name, a:pattern)
endfunction

function! s:FindExistingFile(root, exts)
	let dir = fnamemodify(a:root, ':h')
	if !isdirectory(dir)
		return
	endif
	let root = a:root . '.'
	for ext in a:exts
		let file = root . ext
		if filereadable(file)
			return fnamemodify(file, ':p')
		endif
	endfor
	return ''
endfunction

function! s:FindExistingFile1(root, roots, exts)
	for root in a:roots
		let root = s:ExpandRoot(a:root, root)
		if empty(root)
			continue
		endif
		let file = s:FindExistingFile(root, a:exts)
		if !empty(file)
			return file
		endif
	endfor
	return ''
endfunction

function! s:FindExistingFile2(dir, dirs, name, names, exts)
	for dir in a:dirs
		let dir = s:ExpandDir(a:dir, dir)
		if !isdirectory(dir)
			continue
		endif
		for name in a:names
			let name = s:ExpandName(a:name, name)
			if empty(name)
				continue
			endif
			let root = dir . s:slash . name
			let file = s:FindExistingFile(root, a:exts)
			if !empty(file)
				return file
			endif
		endfor
	endfor
	return ''
endfunction

function! s:FindAlternateFile(filename, dict)
	let altfile = ''
	let ext = fnamemodify(a:filename, ':e')
	if has_key(a:dict, ext)
		let patterns = a:dict[ext]
		let len = len(patterns)
		if len == 2
			let exts = patterns[0]
			let roots = patterns[1]
			let root = fnamemodify(a:filename, ':p:r')
			let altfile = s:FindExistingFile1(root, roots, exts)
		elseif len == 3
			let exts = patterns[0]
			let dirs = patterns[1]
			let names = patterns[2]
			let dir = fnamemodify(a:filename, ':p:h')
			let name = fnamemodify(a:filename, ':t:r')
			let altfile = s:FindExistingFile2(dir, dirs, name, names, exts)
		endif
	endif
	return altfile
endfunction

function! s:FindAllFiles(root, exts, mode, filehash, namehash, files)
	let dir = fnamemodify(a:root, ':h')
	if !isdirectory(dir)
		return
	endif
	let root = a:root . '.'
	let name = fnamemodify(root, ':t')
	for ext in a:exts
		let file = root . ext
		if !has_key(a:filehash, file)
			let filename = name . ext
			if filereadable(file) ||
			 \ a:mode == 2 ||
			 \ a:mode == 1 && !has_key(a:namehash, filename)
				let a:filehash[file] = 1
				let a:namehash[filename] = 1
				call add(a:files, file)
			endif
		endif
	endfor
endfunction

function! s:FindAllFiles1(root, roots, exts, mode, filehash, namehash)
	let files = []
	for root in a:roots
		let root = s:ExpandRoot(a:root, root)
		if empty(root)
			continue
		endif
		call s:FindAllFiles(root, a:exts, a:mode,
		                  \ a:filehash, a:namehash, files)
	endfor
	return files
endfunction

function! s:FindAllFiles2(dir, dirs, name, names, exts, mode,
                        \ filehash, namehash)
	let files = []
	for dir in a:dirs
		let dir = s:ExpandDir(a:dir, dir)
		if !isdirectory(dir)
			continue
		endif
		for name in a:names
			let name = s:ExpandName(a:name, name)
			if empty(name)
				continue
			endif
			let root = dir . s:slash . name
			let root = fnamemodify(root, ':p')
			call s:FindAllFiles(root, a:exts, a:mode,
			                  \ a:filehash, a:namehash, files)
		endfor
	endfor
	return files
endfunction

function! s:FindAllAlternateFiles(filename, dict, mode)
	let altlist = []
	let forlist = [ a:filename ]
	let hash = {}
	let filehash = {}
	let namehash = {}
	let mode = 0
	while 1
		let list = []
		for file in forlist
			if has_key(hash, file)
				continue
			endif
			let hash[file] = 1
			let ext = fnamemodify(file, ':e')
			if has_key(a:dict, ext)
				let patterns = a:dict[ext]
				let len = len(patterns)
				if len == 2
					let exts = patterns[0]
					let roots = patterns[1]
					let root = fnamemodify(a:filename, ':p:r')
					let list += s:FindAllFiles1(root, roots, exts,
					                          \ mode, filehash, namehash)
				elseif len == 3
					let exts = patterns[0]
					let dirs = patterns[1]
					let names = patterns[2]
					let dir = fnamemodify(file, ':p:h')
					let name = fnamemodify(file, ':t:r')
					let list += s:FindAllFiles2(dir, dirs, name, names, exts,
					                          \ mode, filehash, namehash)
				endif
			endif
		endfor
		if empty(list)
			if mode == 0 && a:mode != mode
				let mode = a:mode
				let hash = {}
				if !empty(altlist)
					let forlist = altlist
				endif
				continue
			endif
			break
		endif
		let altlist += list
		let forlist = list
	endwhile
	let altlist = sort(altlist)
	return altlist
endfunction
" }}}

" Interface functions {{{
function! s:SwitchFile(buffer, file, cmd)
	let file = fnamemodify(a:file, ':~:.')
	if a:cmd ==# 'g'
		if a:buffer == -1
			execute 'edit ' . escape(file, ' ')
		else
			let curtab = tabpagenr()
			if s:HasBufferInTab(a:buffer, curtab)
				execute bufwinnr(a:buffer) . 'wincmd w'
			else
				let tab = s:FindTabWithBuffer(a:buffer, curtab)
				if tab
					execute 'tabnext ' . tab
				else
					execute 'buffer ' . file
				endif
			endif
		endif
	elseif a:cmd ==# 'e'
		if a:buffer == -1
			execute 'edit ' . escape(file, ' ')
		else
			execute 'buffer ' . file
		endif
	elseif a:cmd ==# 's' || a:cmd ==# 'v'
		if a:buffer == -1
			execute (a:cmd ==# 'v' ? 'vertical ' : '' ) . 'split ' .
			       \ escape(file, ' ')
		elseif s:HasBufferInTab(a:buffer, tabpagenr())
			execute bufwinnr(a:buffer) . 'wincmd w'
		else
			execute (a:cmd ==# 'v' ? 'vertical ' : '' ) . 'sbuffer ' . a:buffer
		endif
	elseif a:cmd ==# 't'
		if a:buffer == -1
			execute 'tabedit ' . escape(file, ' ')
		else
			let curtab = tabpagenr()
			let tab = s:FindTabWithBuffer(a:buffer, curtab)
			if tab
				execute 'tabnext ' . tab
				execute bufwinnr(a:buffer) . 'wincmd w'
			else
				execute 'tabedit ' . escape(file, ' ')
			endif
		endif
	endif
endfunction

function! s:KeepAlternateFile(altfile, file)
	let altbuf = bufnr(a:altfile)
	call setbufvar(altbuf, 'alternate_file', a:file)
endfunction

function! s:KeepAlternateList(altfile, altlist)
	let altbuf = bufnr(a:altfile)
	call setbufvar(altbuf, 'alternate_list', a:altlist)
endfunction

function! s:GetAlternateDict(buffer)
	let dict = getbufvar(a:buffer, 'alternate_dict')
	return empty(dict) ? s:dict : dict
endfunction

function! s:GetAlternateFile(file)
	let buffer = bufnr(a:file)
	let altfile = getbufvar(buffer, 'alternate_file')
	if empty(altfile)
		let dict = s:GetAlternateDict(buffer)
		let altfile = s:FindAlternateFile(a:file, dict)
	endif
	return altfile
endfunction

function! s:GetAlternateList(file)
	let buffer = bufnr(a:file)
	let altlist = getbufvar('alternate_list', buffer)
	if empty(altlist)
		let dict = s:GetAlternateDict(buffer)
		unlet altlist
		let altlist = s:FindAllAlternateFiles(a:file, dict, 0)
		for file in altlist
			call s:KeepAlternateList(file, altlist)
		endfor
	endif
	return altlist
endfunction

function! s:AskAlternateFile(file, mode)
	if a:mode == 0
		let altlist = s:GetAlternateList(a:file)
	else
		let buffer = bufnr(a:file)
		let dict = s:GetAlternateDict(buffer)
		let altlist = s:FindAllAlternateFiles(a:file, dict, a:mode)
	endif
	if empty(altlist)
		echo 'No alternate files'
		return ''
	endif
	let prompt = [ 'Select file:' ]
	let index = 0
	let current = match(altlist, a:file)
	let size = len(altlist)
	while index < size
		let file = altlist[index]
		if index == current
			let line = '[' . (index + 1) . '] '
		else
			let line = (filereadable(file) ? '+' : ' ') . (index + 1) . ': '
		endif
		let line .= fnamemodify(file, ':~:.')
		call add(prompt, line)
		let index += 1
	endwhile
	let index = inputlist(prompt) - 1
	if index >= 0 && index < size
		return altlist[index]
	endif
	return ''
endfunction
" }}}

function! AlternateFile(cmd, count, ...)
	let file = a:0 ? a:1 : '%'
	let file = expand(file)
	let file = fnamemodify(file, ':p')
	let cmd = strpart(a:cmd, 0, 1)
	let bang = strpart(a:cmd, 2, 1)
	if cmd ==# 'g'
		if a:count
			let altlist = s:GetAlternateList(file)
			if empty(altlist)
				echo 'No alternate file'
				return
			endif
			if a:count < 1
				let altfile = altlist[0]
			elseif a:count > len(altlist)
				let altfile = altlist[-1]
			else
				let altfile = altlist[a:count - 1]
			endif
			if file ==# altfile
				return
			endif
		else
			let altfile = s:GetAlternateFile(file)
			if empty(altfile) || file ==# altfile
				echo 'No alternate file'
				return
			endif
		endif
	elseif cmd ==# 'a' || cmd ==# 'c'
		let mode = cmd ==# 'a' ? 0 : (bang == '!' ? 2 : 1)
		let altfile = s:AskAlternateFile(file, mode)
		if empty(altfile)
			return
		endif
	elseif cmd ==# 'n' || cmd ==# 'p'
		let altlist = s:GetAlternateList(file)
		let l:count = cmd ==# 'n' ? a:count : -a:count
		let index = s:FindtListItem(altlist, file, l:count)
		if index < 0
			echo 'No alternate file'
			return
		endif
		let altfile = altlist[index]
		if file ==# altfile
			return
		endif
	else
		return
	endif
	let altbuf = bufnr(altfile)
	let cmd = strpart(a:cmd, 1, 1)
	call s:SwitchFile(altbuf, altfile, cmd)
	call s:KeepAlternateFile(altfile, file)
	call s:KeepAlternateFile(file, altfile)
	if altbuf == -1 && exists('l:altlist')
		call s:KeepAlternateList(altfile, altlist)
	endif
endfunction

command! -nargs=? -complete=file -count=0 A  call AlternateFile('gg<bang>', <count>, <f-args>)
command! -nargs=? -complete=file -count=0 AE call AlternateFile('ge<bang>', <count>, <f-args>)
command! -nargs=? -complete=file -count=0 AS call AlternateFile('gs<bang>', <count>, <f-args>)
command! -nargs=? -complete=file -count=0 AV call AlternateFile('gv<bang>', <count>, <f-args>)
command! -nargs=? -complete=file -count=0 AT call AlternateFile('gt<bang>', <count>, <f-args>)
command! -nargs=? -complete=file -count=1 AN call AlternateFile('ng<bang>', <count>, <f-args>)
command! -nargs=? -complete=file -count=1 AP call AlternateFile('pg<bang>', <count>, <f-args>)
command! -nargs=? -complete=file          AA call AlternateFile('ag<bang>',       0, <f-args>)
command! -nargs=? -complete=file -bang    AC call AlternateFile('cg<bang>',       0, <f-args>)

" vi:se ts=4 sw=4 noet fdm=marker:
