" ============================================================================
" File:        autoload/alternate.vim
" Description: switch between alternate files
" Author:      Alexander Aksenov <facing-worlds@yandex.ru>
" License:     Vim license
" ============================================================================

let s:groups = [
             \   [ '{include|inc}/**/{}.h', '{src|source}/**/{}.{cpp|mm}' ],
             \   [ '{include|inc}/**/{}.h', '{src|source}/**/{}.{c|m}' ],
             \   [ '{include|inc}/**/{}.hpp', '{src|source}/**/{}.cpp' ],
             \   [ '{include|inc}/**/{}.hxx', '{src|source}/**/{}.cxx' ],
             \   [ '{include|inc}/**/{}.hh', '{src|source}/**/{}.cc' ],
             \   [ '{include|inc}/**/{}.H', '{src|source}/**/{}.C' ],
             \   [ '{}.h', '{}.{cpp|mm}' ],
             \   [ '{}.h', '{}.{c|m}' ],
             \   [ '{}.hpp', '{}.cpp' ],
             \   [ '{}.hxx', '{}.cxx' ],
             \   [ '{}.hh', '{}.cc' ],
             \   [ '{}.H', '{}.C' ],
             \   [ 'doc/{}.txt', 'plugin/{}.vim', 'autoload/{}.vim' ],
             \   [ '.bash_profile', '.bashrc', '.bash_logout' ],
             \   [ '.zprofile', '.zshrc', '.zlogin', '.zlogout', '.zshenv' ],
             \ ]

" Core {{{
function! s:backslash()
	return exists('+shellslash') && !&shellslash
endfunction

function! s:star2re(str)
	if a:str[0] ==# '/'
		if a:str[len(a:str) - 1] ==# '/'
			return a:str =~# '\*\*\+' ? '\(/\|/\.\+/\)' : '\(/\|/\[^/]\+/\)'
		endif
		return a:str =~# '\*\*\+' ? '\(/\.\*\)' : '\(/\[^/]\*\)'
	elseif a:str[len(a:str) - 1] ==# '/'
		return a:str =~# '\*\*\+' ? '\(\.\*/\)' : '\(\[^/]\*/\)'
	else
		return a:str =~# '\*\*\+' ? '\(\.\*\)' : '\(\[^/]\*\)'
	endif
endfunction

function! s:glob2re(str)
	if a:str[0] !=# '{'
		return s:star2re(a:str)
	elseif a:str ==# '{}'
		return '\[^/]\+'
	endif
	let str = escape(strpart(a:str, 1, len(a:str) - 2), '\')
	return '\%(' . substitute(str, '|', '\\|', 'g') . '\)'
endfunction

function! s:match_templates(templates, filename)
	let backslash = s:backslash()
	let i = 0
	let N = len(a:templates)
	while i < N
		let template = substitute(a:templates[i], '\(/\?\*\+/\?\)\|\({[^{}]*}\)', '\=s:glob2re(submatch(0))', 'g')
		if backslash
			let template = substitute(template, '/', '\\\\', 'g')
		endif
		let template = '\V\C' . template . '\$'
		if match(a:filename, template) >= 0
			return i
		endif
		let i += 1
	endwhile
	return -1
endfunction

function! s:split_template(template)
	let result = []
	let template = a:template
	let pat = '\(/\?\*\+/\?\)\|\({[^{}]*}\)'
	while !empty(template)
		let pos = match(template, pat)
		if pos < 0
			call add(result, template)
			break
		elseif pos > 0
			call add(result, strpart(template, 0, pos))
			let template = strpart(template, pos)
		endif
		let str = matchstr(template, pat)
		let len = len(str)
		if str[0] !=# '{' || str ==# '{}'
			call add(result, str)
		else
			call add(result, split(strpart(str, 1, len - 2), '|', 1))
		endif
		let template = strpart(template, len)
	endwhile
	return result
endfunction

function! s:walk_matches_component(components, num, path, glob, parts, result, component)
	let comp = '\V\C' . escape(a:component, '\')
	if s:backslash()
		let comp = substitute(comp, '/', '\\\\', 'g')
	endif
	let counter = 1
	let pos = match(a:path, comp, 0, counter)
	while pos >= 0
		if !empty(a:glob) && !strpart(a:path, 0, pos) =~# '\V\C\^' . a:glob . '\$'
			break
		endif
		if a:num == 0 || !empty(a:glob)
			call add(a:parts, strpart(a:path, 0, pos))
		endif
		let n = matchend(a:path, comp, pos)
		call s:walk_matches(a:components, a:num + 1, strpart(a:path, n), '', a:parts, a:result)
		if a:num == 0 || !empty(a:glob)
			call remove(a:parts, -1)
		endif
		let counter += 1
		let pos = match(a:path, comp, 0, counter)
	endwhile
endfunction

function! s:walk_matches(components, num, path, glob, parts, result)
	if a:num >= len(a:components)
		if empty(a:path)
			call add(a:result, copy(a:parts))
		endif
		return
	endif
	if type(a:components[a:num]) == 3
		for comp in a:components[a:num]
			if empty(comp)
				call s:walk_matches(a:components, a:num + 1, a:path, a:glob, a:parts, a:result)
			else
				call s:walk_matches_component(a:components, a:num, a:path, a:glob, a:parts, a:result, comp)
			endif
		endfor
		return
	endif
	let comp = a:components[a:num]
	if comp =~# '/\?\*\+/\?'
		let glob = s:star2re(comp)
		if s:backslash()
			let glob = substitute(glob, '/', '\\\\', 'g')
		endif
		call s:walk_matches(a:components, a:num + 1, a:path, a:glob . glob, a:parts, a:result)
	else
		if comp ==# '{}'
			let comp = fnamemodify(a:path, ':t:r')
		endif
		call s:walk_matches_component(a:components, a:num, a:path, a:glob, a:parts, a:result, comp)
	endif
endfunction

function! s:expand_wildcards(list, filename, parts)
	let p = 1
	let i = 0
	let N = len(a:list)
	let backslash = s:backslash()
	while i < N
		if type(a:list[i]) != 3
			if a:list[i] ==# '{}'
				let str = substitute(a:list[i], '{}', escape(a:filename, '\'), 'g')
				let a:list[i] = backslash ? substitute(str, '/', '\\', 'g') : str
			elseif a:list[i] =~# '\*' && p < len(a:parts)
				let a:list[i] = a:parts[p]
				let p += 1
			elseif backslash
				let a:list[i] = substitute(a:list[i], '/', '\\', 'g')
			endif
		elseif backslash
			let j = 0
			let M = len(a:list[i])
			while j < M
				let a:list[i][j] = substitute(a:list[i][j], '/', '\\', 'g')
				let j += 1
			endwhile
		endif
		let i += 1
	endwhile
	if !empty(a:list) && !empty(a:parts)
		if type(a:list[0]) != 3
			let a:list[0] = a:parts[0] . a:list[0]
		else
			call insert(a:list, a:parts[0])
		endif
	endif
endfunction

function! s:walk_components(components, visitor, num, path)
	if a:num >= len(a:components)
		return a:visitor.visit(a:path)
	endif
	if type(a:components[a:num]) == 3
		for component in a:components[a:num]
			let result = s:walk_components(a:components, a:visitor, a:num + 1, a:path . component)
			if result
				return result
			endif
		endfor
		return 0
	endif
	return s:walk_components(a:components, a:visitor, a:num + 1, a:path . a:components[a:num])
endfunction

function! s:common_visitor(path, mode)
	let visitor = {}
	let visitor.orig = a:path
	let visitor.mode = a:mode
	let visitor.result = []
	let visitor.found = 0
	let visitor.existing = 0

	function visitor.begin(multiparts) dict
		let self.found = 0
	endfunction

	function visitor.end() dict
		if self.mode == 0 || self.mode == 1
			let self.existing = self.found
			return self.found
		endif
		return self.mode == 2 ? self.existing : 0
	endfunction

	if visitor.mode == 0 " first existing file
		function visitor.visit(expr) dict
			if a:expr !=# self.orig && filereadable(a:expr)
				call add(self.result, a:expr)
				let self.found += 1
				return 1
			endif
			return 0
		endfunction
	elseif visitor.mode == 1 " all existing files
		function visitor.visit(expr) dict
			if filereadable(a:expr)
				call add(self.result, a:expr)
				if a:expr !=# self.orig
					let self.found += 1
				endif
			endif
			return 0
		endfunction
	else " existing + possible files
		function visitor.visit(expr) dict
			if isdirectory(fnamemodify(a:expr, ':h'))
				call add(self.result, a:expr)
				if a:expr !=# self.orig
					let self.found += 1
					if filereadable(a:expr)
						let self.existing += 1
					endif
				endif
			endif
		endfunction
	endif
	return visitor
endfunction

function! s:base_glob_visitor(path, mode)
	let visitor = {}
	let visitor.orig = a:path
	let visitor.mode = a:mode ? 1 : 0
	let visitor.result = []
	let visitor.found = 0
	let visitor.existing = 0

	let visitor.glob_cache = {}
	function visitor.glob(expr) dict
		if !has_key(self.glob_cache, a:expr)
			let self.glob_cache[a:expr] = self.glob_func(a:expr)
		endif
		return self.glob_cache[a:expr]
	endfunction

	function visitor.begin(multiparts) dict
		for parts in a:multiparts
			if len(parts) > 1
				call remove(parts, 1, -1)
			endif
		endfor
		let self.found = 0
	endfunction

	function visitor.end() dict
		let self.existing = self.found
		return self.found
	endfunction

	if visitor.mode == 0 " first existing file
		function visitor.visit(expr) dict
			for file in self.glob(a:expr)
				if file !=# self.orig
					call add(self.result, file)
					let self.found += 1
					return 1
				endif
			endfor
			return 0
		endfunction
	else " all existing files
		function visitor.visit(expr) dict
			let list = self.glob(a:expr)
			for file in list
				if file !=# self.orig
					let self.found += 1
				endif
			endfor
			call extend(self.result, list)
			return 0
		endfunction
	endif
	return visitor
endfunction

function! s:glob_visitor(path, mode)
	let visitor = s:base_glob_visitor(a:path, a:mode)
	function visitor.glob_func(expr) dict
		return glob(a:expr, 0, 1)
	endfunction
	return visitor
endfunction

function! s:fugitive_glob2re(str)
	return a:str ==# '*' ? '\(\[^/]\*\)' : '\(\.\*\)'
endfunction

function! s:fugitive_visitor(path, mode, buffer)
	let visitor = s:base_glob_visitor(a:path, a:mode)
	let visitor.backslash = s:backslash()
	let visitor.start = len(a:path) - len(fugitive#buffer(a:buffer).path())
	let visitor.prefix = strpart(a:path, 0, visitor.start)

	let commit = fugitive#buffer(a:buffer).commit()
	let command = fugitive#buffer(a:buffer).repo().git_command() . ' ls-tree --name-only --full-tree -r ' . commit
	let visitor.filelist = systemlist(command)

	function visitor.glob_func(expr) dict
		let result = []
		let expr = strpart(a:expr, self.start)
		if self.backslash
			let expr = substitute(expr, '\\', '/', 'g')
		endif
		let expr = substitute(expr, '*\+', '\=s:fugitive_glob2re(submatch(0))', 'g')
		let expr = '\V\C' . expr . '\$'
		for file in self.filelist
			if file =~# expr
				if self.backslash
					let file = substitute(file, '/', '\\', 'g')
				endif
				call add(result, self.prefix . file)
			endif
		endfor
		return result
	endfunction

	return visitor
endfunction

function! s:find_algo(groups, path, visitor)
	let filename = fnamemodify(a:path, ':t:r')
	for templates in a:groups
		let num = s:match_templates(templates, a:path)
		if num >= 0
			let multiparts = []
			let components = s:split_template(templates[num])
			call s:walk_matches(components, 0, a:path, '', [], multiparts)
			call a:visitor.begin(multiparts)
			for parts in multiparts
				let range = range(len(templates))
				call remove(range, num)
				call add(range, num)
				for i in range
					let components = s:split_template(templates[i])
					call s:expand_wildcards(components, filename, parts)
					if s:walk_components(components, a:visitor, 0, '')
						if a:visitor.end()
							return templates
						endif
						break
					endif
				endfor
			endfor
			if a:visitor.end()
				return templates
			endif
		endif
	endfor
	return []
endfunction

function! s:find_files(groups, path, mode)
	if a:path =~# '^fugitive:'
		let buffer = bufnr(a:path)
		if buffer < 0
			let result = []
		else
			let visitor = s:fugitive_visitor(a:path, a:mode, buffer)
			call s:find_algo(a:groups, a:path, visitor)
			let result = visitor.result
		endif
	else
		let visitor = s:common_visitor(a:path, a:mode)
		call s:find_algo(a:groups, a:path, visitor)
		if visitor.existing
			let result = visitor.result
		else
			let glob_visitor = s:glob_visitor(a:path, a:mode)
			let templates = s:find_algo(a:groups, a:path, glob_visitor)
			if glob_visitor.existing
				if a:mode > 1
					call uniq(glob_visitor.result)
					let result = []
					let groups = a:mode == 2 ? [ templates ] : a:groups
					for file in glob_visitor.result
						let visitor = s:common_visitor(file, a:mode)
						call s:find_algo(groups, file, visitor)
						call extend(result, visitor.result)
					endfor
				else
					let result = glob_visitor.result
				endif
			else
				let result = visitor.result
			endif
		endif
	endif
	call sort(result)
	call uniq(result)
	return result
endfunction
" }}}

" Interface {{{
function! s:find_buffer_tab(buffer, curtab)
	let i = 1
	while i < a:curtab
		if index(tabpagebuflist(i), a:buffer) >= 0
			return i
		endif
		let i += 1
	endwhile
	let i = a:curtab + 1
	let N = tabpagenr('$')
	while i <= N
		if index(tabpagebuflist(i), a:buffer) >= 0
			return i
		endif
		let i += 1
	endwhile
	return 0
endfunction

function! s:switch_file(buffer, file, cmd)
	let file = fnamemodify(a:file, ':~:.')
	if a:cmd[0] ==# 'g'
		if a:buffer == -1
			execute 'edit' escape(file, ' ')
		else
			let curtab = tabpagenr()
			if index(tabpagebuflist(curtab), a:buffer) >= 0
				execute bufwinnr(a:buffer) . 'wincmd w'
			else
				let tab = s:find_buffer_tab(a:buffer, curtab)
				if tab
					execute 'tabnext' tab
				else
					execute 'buffer' file
				endif
			endif
		endif
	elseif a:cmd[0] ==# 'e'
		if a:buffer == -1
			execute 'edit' escape(file, ' ')
		else
			execute 'buffer' file
		endif
	elseif a:cmd[0] ==# 's' || a:cmd[0] ==# 'v'
		if a:buffer == -1
			execute (a:cmd[0] ==# 'v' ? 'vertical ' : '' ) . 'split' escape(file, ' ')
		elseif a:cmd[1] != '!' && index(tabpagebuflist(tabpagenr()), a:buffer) >= 0
			execute bufwinnr(a:buffer) . 'wincmd w'
		else
			execute (a:cmd[0] ==# 'v' ? 'vertical ' : '' ) . 'sbuffer' a:buffer
		endif
	elseif a:cmd[0] ==# 't'
		if a:buffer == -1
			execute 'tabedit' escape(file, ' ')
		elseif a:cmd[1] == '!'
			execute 'tabedit' escape(file, ' ')
		else
			let curtab = tabpagenr()
			let tab = s:find_buffer_tab(a:buffer, curtab)
			if tab
				execute 'tabnext' tab
				execute bufwinnr(a:buffer) . 'wincmd w'
			else
				execute 'tabedit' escape(file, ' ')
			endif
		endif
	else
		if a:buffer != -1
			if empty(&switchbuf) || &switchbuf =~# 'useopen'
				if index(tabpagebuflist(tabpagenr()), a:buffer) >= 0
					execute bufwinnr(a:buffer) . 'wincmd w'
					return
				endif
			elseif &switchbuf =~ 'usetab'
				let tab = s:find_buffer_tab(a:buffer, tabpagenr())
				if tab
					execute 'tabnext' tab
					return
				endif
			endif
		endif
		if &switchbuf =~# 'split'
			call s:switch_file(a:buffer, a:file, 's!')
		elseif &switchbuf =~# 'newtab'
			call s:switch_file(a:buffer, a:file, 't!')
		else
			call s:switch_file(a:buffer, a:file, 'e')
		endif
	endif
endfunction

function! s:keep_alt(altfile, stuff)
	let altbuf = bufnr(a:altfile)
	call setbufvar(altbuf, type(a:stuff) == 3 ? 'alternate_list' : 'alternate_file', a:stuff)
endfunction

function! s:groups(buffer)
	let list = getbufvar(a:buffer, 'alternate_groups')
	if !empty(list)
		return list
	endif
	let list = getbufvar(a:buffer, 'alternate_templates')
	return empty(list) ? s:groups : [ list ]
endfunction

function! s:alternate_file(file)
	let buffer = bufnr(a:file)
	let altfile = getbufvar(buffer, 'alternate_file')
	if empty(altfile)
		let list = s:find_files(s:groups(buffer), a:file, 0)
		let altfile = empty(list) ? '' : list[0]
	endif
	return altfile
endfunction

function! s:alternate_list(file)
	let buffer = bufnr(a:file)
	let altlist = getbufvar(buffer, 'alternate_list')
	if empty(altlist)
		unlet altlist
		let altlist = s:find_files(s:groups(buffer), a:file, 1)
		for file in altlist
			call s:keep_alt(file, altlist)
		endfor
	endif
	return altlist
endfunction

function! s:ask_file(file, mode)
	if a:mode == 1
		let altlist = s:alternate_list(a:file)
	else
		let altlist = s:find_files(s:groups(bufnr(a:file)), a:file, a:mode)
	endif
	if empty(altlist)
		echo 'No alternate files'
		return ''
	endif
	let prompt = [ 'Select file:' ]
	let i = 0
	let N = len(altlist)
	let current = index(altlist, a:file)
	while i < N
		let file = altlist[i]
		if i == current
			let line = '[' . (i + 1) . '] '
		else
			let line = (filereadable(file) ? '+' : ' ') . (i + 1) . ': '
		endif
		let line .= fnamemodify(file, ':~:.')
		call add(prompt, line)
		let i += 1
	endwhile
	let i = inputlist(prompt) - 1
	return i >= 0 && i < N ? altlist[i] : ''
endfunction
" }}}

function! alternate#switch(file, count, action)
	let file = expand(a:file)
	let file = fnamemodify(file, ':p')

	if a:count
		let altlist = s:alternate_list(file)
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
		let altfile = s:alternate_file(file)
		if empty(altfile) || file ==# altfile
			echo 'No alternate file'
			return
		endif
	endif

	let altbuf = bufnr(altfile)
	call s:switch_file(altbuf, altfile, a:action)
	call s:keep_alt(altfile, file)
	call s:keep_alt(file, altfile)
	if altbuf == -1 && exists('l:altlist')
		call s:keep_alt(altfile, altlist)
	endif
endfunction

function! alternate#next(file, count, action)
	let file = expand(a:file)
	let file = fnamemodify(file, ':p')

	let altlist = s:alternate_list(file)
	let index = index(altlist, file)
	if index >= 0
		let len = len(altlist)
		let index = (index + a:count) % len
		if index < 0
			let index += len
		endif
	endif
	if index < 0
		echo 'No alternate file'
		return
	endif
	let altfile = altlist[index]
	if file ==# altfile
		return
	endif

	let altbuf = bufnr(altfile)
	call s:switch_file(altbuf, altfile, a:action)
	call s:keep_alt(altfile, file)
	call s:keep_alt(file, altfile)
	if altbuf == -1
		call s:keep_alt(altfile, altlist)
	endif
endfunction

function! alternate#list(file, action, mode)
	let file = expand(a:file)
	let file = fnamemodify(file, ':p')

	let altfile = s:ask_file(file, a:mode)
	if empty(altfile)
		return
	endif

	let altbuf = bufnr(altfile)
	call s:switch_file(altbuf, altfile, a:action)
	call s:keep_alt(altfile, file)
	call s:keep_alt(file, altfile)
endfunction

" vim:ts=4 sw=4 noet:
