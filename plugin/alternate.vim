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
		              \   '',
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
		              \   '',
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
function! s:ExpandDir(dir, pattern)
	let prefix = strpart(a:pattern, 0, 4)
	if prefix ==# 'reg:'
		let pattern = strpart(a:pattern, 4)
		let dir = s:Substiture(a:dir, pattern)
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
	if empty(a:pattern)
		return a:name
	endif
	let prefix = strpart(a:pattern, 0, 4)
	if prefix ==# 'reg:'
		let pattern = strpart(a:pattern, 4)
		let name = s:Substiture(a:name, pattern)
		return name ==# a:name ? '' : name
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
			let root = fnamemodify(root, ':p') . '.'
			for ext in a:exts
				let file = root . ext
				if !has_key(a:filehash, file)
					let ext = name . '.' . ext
					if filereadable(file) ||
					 \ !a:existing && !has_key(a:namehash, ext)
						let a:filehash[file] = 1
						let a:namehash[ext] = 1
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
	let namehash = {}
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
				          \                existing, filehash, namehash)
			endif
		endfor
		if empty(list)
			if existing && !a:existing
				let existing = 0
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
		let altlist = s:FindAllAlternateFiles(a:file, dict, 1)
		for file in altlist
			call s:KeepAlternateList(file, altlist)
		endfor
	endif
	return altlist
endfunction

function! s:AskAlternateFile(file, existing)
	if a:existing
		let altlist = s:GetAlternateList(a:file)
	else
		let buffer = bufnr(a:file)
		let dict = s:GetAlternateDict(buffer)
		let altlist = s:FindAllAlternateFiles(a:file, dict, a:existing)
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

function! AlternateFile(filename, cmd, action, count)
	let file = empty(a:filename) ? '%' : a:filename
	let file = expand(file . ':p')
	if empty(a:action)
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
	elseif a:action ==# 'a' || a:action ==# 'c'
		let altfile = s:AskAlternateFile(file, a:action ==# 'a' ? 1 : 0)
		if empty(altfile)
			return
		endif
	elseif a:action ==# 'n' || a:action ==# 'p'
		let altlist = s:GetAlternateList(file)
		let l:count = a:action ==# 'n' ? a:count : -a:count
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
	call s:SwitchFile(altbuf, altfile, a:cmd)
	call s:KeepAlternateFile(altfile, file)
	call s:KeepAlternateFile(file, altfile)
	if altbuf == -1 && exists('l:altlist')
		call s:KeepAlternateList(altfile, altlist)
	endif
endfunction

command! -nargs=0 -count=0 A  call AlternateFile('%',  '',  '', <count>)
command! -nargs=0 -count=0 AE call AlternateFile('%', 'e',  '', <count>)
command! -nargs=0 -count=0 AS call AlternateFile('%', 's',  '', <count>)
command! -nargs=0 -count=0 AV call AlternateFile('%', 'v',  '', <count>)
command! -nargs=0 -count=0 AT call AlternateFile('%', 't',  '', <count>)
command! -nargs=0 -count=1 AN call AlternateFile('%',  '', 'n', <count>)
command! -nargs=0 -count=1 AP call AlternateFile('%',  '', 'p', <count>)
command! -nargs=0          AA call AlternateFile('%',  '', 'a', 0)
command! -nargs=0          AC call AlternateFile('%',  '', 'c', 0)

" vi:se ts=4 sw=4 noet fdm=marker:
