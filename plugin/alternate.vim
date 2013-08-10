" ============================================================================
" File:        alternate.vim
" Description: switch between alternate files
" Author:      Alexander Aksenov <facing-worlds@yandex.ru>
" License:     Vim license
" ============================================================================

if exists("loaded_alternate")
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
		              \   'rel:.',
		              \   'reg:/src/include/',
		              \   'reg:/src/inc/',
		              \   'reg:/source/include/',
		              \   'rel:../inc',
		              \   'rel:../include',
		              \ ]
	endif

	if exists('g:alternate_srcdirs')
		let s:srcdirs = g:alternate_srcdirs
	else
		let s:srcdirs = [
		              \   'rel:.',
		              \   'reg:/include/src/',
		              \   'reg:/inc/src/',
		              \   'reg:/include/source/',
		              \   'rel:../src',
		              \   'rel:../source',
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
function! s:Substiture(string, pattern)
	let sep = strpart(a:pattern, 0, 1)
	let patend = match(a:pattern, sep, 1)
	let pat = strpart(a:pattern, 1, patend - 1)
	let subend = match(a:pattern, sep, patend + 1)
	let sub = strpart(a:pattern, patend + 1, subend - patend - 1)
	let flags = strpart(a:pattern, strlen(a:pattern) - 2)
	if flags == sep
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
		let index = index + 1
	endwhile
	return 0
endfunction

function! s:FindTabWithBuffer(buffer, curtab)
	let index = 0
	while index < a:curtab
		if s:HasBufferInTab(a:buffer, index)
			return index
		endif
		let index = index + 1
	endwhile
	let index = a:curtab + 1
	let size = tabpagenr('$')
	while index <= size
		if s:HasBufferInTab(a:buffer, index)
			return index
		endif
		let index = index + 1
	endwhile
	return 0
endfunction

function! s:ShiftList(list, name, direction)
	let index = match(a:list, a:name)
	if index != -1
		let index = index + (a:direction == 'n' ? 1 : -1)
		if index != 0
			let len = len(a:list)
			if index < 0
				let index = len + index
			endif
		endif
		call extend(a:list, remove(a:list, 0, index - 1))
	endif
endfunction
" }}}

" Core functions {{{
function! s:ExpandDir(dir, pattern)
	let prefix = strpart(a:pattern, 0, 4)
	if prefix == 'reg:'
		let pattern = strpart(a:pattern, 4)
		let dir = s:Substiture(a:dir, pattern)
		return dir == a:dir ? '' : dir
	elseif prefix == 'rel:'
		return a:dir . s:slash . strpart(a:pattern, 4)
	elseif prefix == 'abs:'
		return strpart(a:pattern, 4)
	elseif empty(pattern)
		return a:dir
	endif
	return ''
endfunction

function! s:ExpandName(name, pattern)
	if empty(a:pattern)
		return a:name
	endif
	let prefix = strpart(a:pattern, 0, 4)
	if prefix == 'reg:'
		let pattern = strpart(a:pattern, 4)
		let name = s:Substiture(a:name, pattern)
		return name == a:name ? '' : name
	endif
	return ''
endfunction

function! s:FindExistingFile(dir, dirs, name, names, exts)
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
			let root = dir . s:slash . name . '.'
			for ext in a:exts
				let file = root . ext
				if filereadable(file)
					return fnamemodify(file, ':p')
				endif
			endfor
		endfor
	endfor
	return ''
endfunction

function! s:FindAlternateFile(filename, dict)
	let altfile = ''
	let ext = fnamemodify(a:filename, ':e')
	if has_key(a:dict, ext)
		let patterns = a:dict[ext]
		let exts = patterns[0]
		let dirs = patterns[1]
		let names = patterns[2]
		let dir = fnamemodify(a:filename, ':p:h')
		let name = fnamemodify(a:filename, ':t:r')
		let altfile = s:FindExistingFile(dir, dirs, name, names, exts)
	endif
	return altfile
endfunction

function! s:FindAllFiles(dir, dirs, name, names, exts, existing,
                       \ filehash, exthash)
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
			let root = fnamemodify(root, ':p') . '.'
			for ext in a:exts
				let file = root . ext
				if !has_key(a:filehash, file)
					if filereadable(file) ||
					 \ !a:existing && !has_key(a:exthash, ext)
						let a:filehash[file] = 1
						let a:exthash[ext] = 1
						call add(files, file)
					endif
				endif
			endfor
		endfor
	endfor
	return files
endfunction

function! s:FindAllAlternateFiles(filename, dict, existing)
	let altlist = []
	let forlist = [ a:filename ]
	let hash = {}
	let filehash = {}
	let exthash = {}
	let existing = 1
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
				let exts = patterns[0]
				let dirs = patterns[1]
				let names = patterns[2]
				let dir = fnamemodify(file, ':p:h')
				let name = fnamemodify(file, ':t:r')
				let list += s:FindAllFiles(dir, dirs, name, names, exts,
				          \                existing, filehash, exthash)
			endif
		endfor
		if empty(list)
			if existing && !a:existing
				let existing = 0
				let hash = {}
				let forlist = altlist
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
	if empty(a:cmd)
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
	elseif a:cmd == 'e'
		if a:buffer == -1
			execute 'edit ' . escape(file, ' ')
		else
			execute 'buffer ' . file
		endif
	elseif a:cmd == 's' || a:cmd == 'v'
		if a:buffer == -1
			execute (a:cmd == 'v' ? 'vertical ' : '' ) . 'split ' .
			       \ escape(file, ' ')
		elseif s:HasBufferInTab(a:buffer, tabpagenr())
			execute bufwinnr(a:buffer) . 'wincmd w'
		else
			execute (a:cmd == 'v' ? 'vertical ' : '' ) . 'sbuffer ' . a:buffer
		endif
	elseif a:cmd == 't'
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

function! s:KeepAlternateFile(altfile, file)
	let altbuf = bufnr(a:altfile)
	call setbufvar(altbuf, 'alternate_file', a:file)
endfunction

function! s:KeepAlternateList(altfile, altlist)
	let altbuf = bufnr(a:altfile)
	call setbufvar(altbuf, 'alternate_list', a:altlist)
endfunction

function! s:GetNextAlternateFile(file, direction)
	let buffer = bufnr(a:file)
	let altlist = getbufvar('alternate_list', buffer)
	if empty(altlist)
		let dict = s:GetAlternateDict(buffer)
		unlet altlist
		let altlist = s:FindAllAlternateFiles(a:file, dict, 1)
		for file in altlist
			let buffer = bufnr(file)
			if buffer != -1
				call setbufvar(buffer, 'alternate_list', altlist)
			endif
		endfor
	endif
	call s:ShiftList(altlist, a:file, a:direction)
	return altlist
endfunction

function! s:AskAlternateFile(file)
	let buffer = bufnr(a:file)
	let dict = s:GetAlternateDict(buffer)
	let altlist = s:FindAllAlternateFiles(a:file, dict, 0)
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
		let line .= file
		call add(prompt, line)
		let index = index + 1
	endwhile
	let index = inputlist(prompt) - 1
	if index >= 0 && index < size
		return altlist[index]
	endif
	return ''
endfunction
" }}}

function! AlternateFile(filename, cmd, action)
	let file = empty(a:filename) ? '%' : a:filename
	let file = expand(file . ':p')
	if empty(a:action)
		let altfile = s:GetAlternateFile(file)
	elseif a:action == 'n' || a:action == 'p'
		let altlist = []
		let altlist = s:GetNextAlternateFile(file, a:action)
		let altfile = empty(altlist) ? '' : altlist[0]
	elseif a:action == 'a'
		let altfile = s:AskAlternateFile(file)
	endif
	if empty(altfile) || altfile == file
		if a:action != 'a'
			echo 'No alternate file'
		endif
		return
	endif
	let altbuf = bufnr(altfile)
	call s:SwitchFile(altbuf, altfile, a:cmd)
	call s:KeepAlternateFile(altfile, file)
	call s:KeepAlternateFile(file, altfile)
	if a:action == 'n' || a:action == 'p'
		call s:KeepAlternateList(altfile, altlist)
	endif
endfunction

command! -nargs=0 A  call AlternateFile('%', '', '')
command! -nargs=0 AE call AlternateFile('%', 'e', '')
command! -nargs=0 AS call AlternateFile('%', 's', '')
command! -nargs=0 AV call AlternateFile('%', 'v', '')
command! -nargs=0 AT call AlternateFile('%', 't', '')
command! -nargs=0 AN call AlternateFile('%', '', 'n')
command! -nargs=0 AP call AlternateFile('%', '', 'p')
command! -nargs=0 AA call AlternateFile('%', '', 'a')

" vi:se ts=4 sw=4 noet fdm=marker:
