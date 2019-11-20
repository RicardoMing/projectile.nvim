"=============================================================================
" projectmanager.vim --- project manager for SpaceVim
" Copyright (c) 2016-2019 Shidong Wang & Contributors
" Author: Shidong Wang < wsdjeg at 163.com >
" URL: https://spacevim.org
" License: GPLv3
"=============================================================================

" project item:
" {
"   "path" : "path/to/root",
"   "name" : "name of the project, by default it is name of root directory",
"   "type" : "git maven or svn",
" }
"


let s:projectile_rooter_patterns = copy(g:projectile_rooter_patterns)

let s:project_paths = {}

function! s:cache_project(prj) abort
    if !has_key(s:project_paths, a:prj.path)
        let s:project_paths[a:prj.path] = a:prj
        let desc = '[' . a:prj.name . '] ' . a:prj.path
        let cmd = "call projectile#open('" . a:prj.path . "')"
        call add(g:unite_source_menu_menus.Projects.command_candidates, [desc,cmd])
        call writefile([a:prj.path], g:projectile_cache, "a")
    endif
endfunction

function! s:load_projects() abort
    let l:project_lists = readfile(g:projectile_cache)
    for item in l:project_lists
        let l:project = {
                    \ 'path' : item,
                    \ 'name' : fnamemodify(item, ':t')
                    \ }
        let s:project_paths[l:project.path] = l:project
        let desc = '[' . l:project.name . '] ' . l:project.path
        let cmd = "call projectile#open('" . l:project.path . "')"
        call add(g:unite_source_menu_menus.Projects.command_candidates, [desc,cmd])
    endfor
endfunction

let g:unite_source_menu_menus =
            \ get(g:,'unite_source_menu_menus',{})
let g:unite_source_menu_menus.Projects = {'description':
            \ 'Custom mapped keyboard shortcuts                   [SPC] p p'}
let g:unite_source_menu_menus.Projects.command_candidates =
            \ get(g:unite_source_menu_menus.Projects,'command_candidates', [])

if !filereadable(g:projectile_cache)
    call writefile([], g:projectile_cache)
endif
call s:load_projects()

" this function will use fuzzy finder, now only fzf is supported.
function! projectile#list() abort
    if exists('g:loaded_fzf')
        FzfMenu Projects
    else
        echoerr 'Fzf is needed to find project!'
    endif
endfunction

function! projectile#open(project) abort
    let path = s:project_paths[a:project]['path']
    exe 'lcd ' . path
    Files
    call feedkeys('i')
endfunction

function! projectile#current_name() abort
    return get(b:, '_projectile_project_name', '')
endfunction

" this func is called when vim-rooter change the dir, That means the project
" is changed, so will call call the registered function.
function! projectile#RootchandgeCallback() abort
    let project = {
                \ 'path' : getcwd(),
                \ 'name' : fnamemodify(getcwd(), ':t')
                \ }
    call s:cache_project(project)
    let g:_projectile_project_name = project.name
    let b:_projectile_project_name = g:_projectile_project_name
    for Callback in s:project_callback
        call call(Callback, [])
    endfor
endfunction

let s:project_callback = []
function! projectile#reg_callback(func) abort
    if type(a:func) == 2
        call add(s:project_callback, a:func)
    else
        echoerr '[projectile] can not register the project callback: ' . string(a:func)
    endif
endfunction

function! projectile#current_root() abort
    " if rooter patterns changed, clear cache.
    " https://github.com/SpaceVim/SpaceVim/issues/2367
    if join(g:projectile_rooter_patterns, ':') !=# join(s:projectile_rooter_patterns, ':')
        call setbufvar('%', 'rootDir', '')
        let s:projectile_rooter_patterns = copy(g:projectile_rooter_patterns)
    endif
    let rootdir = getbufvar('%', 'rootDir', '')
    if empty(rootdir)
        let rootdir = s:find_root_directory()
        if empty(rootdir)
            let rootdir = getcwd()
        endif
        call setbufvar('%', 'rootDir', rootdir)
    endif
    if !empty(rootdir)
        call s:change_dir(rootdir)
        call projectile#RootchandgeCallback()
    endif
    return rootdir
endfunction

function! s:change_dir(dir) abort
    exe 'cd ' . fnameescape(fnamemodify(a:dir, ':p'))

    try
        " FIXME: change the git dir when the path is changed.
        let b:git_dir = fugitive#extract_git_dir(expand('%:p'))
    catch
    endtry
    " let &l:statusline = SpaceVim#layers#core#statusline#get(1)
endfunction

function! s:buffer_filter_do(expr) abort
    let buffers = range(1, bufnr('$'))
    for f_expr in a:expr.expr
        let buffers = filter(buffers, f_expr)
    endfor
    for b in buffers
        exe printf(a:expr.do, b)
    endfor
endfunction

function! projectile#kill_project() abort
    let name = get(b:, '_projectile_project_name', '')
    if name !=# ''
        call s:buffer_filter_do(
                    \ {
                    \ 'expr' : [
                    \ 'buflisted(v:val)',
                    \ 'getbufvar(v:val, "_projectile_project_name") == "' . name . '"',
                    \ ],
                    \ 'do' : 'bd %d'
                    \ }
                    \ )
    endif
endfunction

function! projectile#remove_project() abort
    let l:project_lists = readfile(g:projectile_cache)
    call uniq(sort(l:project_lists))
    call filter(l:project_lists, {idx, val -> isdirectory(val)})
    call writefile(l:project_lists, g:projectile_cache)
    let s:project_paths = {}
    let g:unite_source_menu_menus.Projects.command_candidates = []
    call s:load_projects()
endfunction

function! s:findDirInParent(what, where) abort
    let old_suffixesadd = &suffixesadd
    let &suffixesadd = ''
    let dir = finddir(a:what, escape(a:where, ' ') . ';')
    let &suffixesadd = old_suffixesadd
    return dir
endfunction

function! s:findFileInParent(what, where) abort
    let old_suffixesadd = &suffixesadd
    let &suffixesadd = ''
    let file = findfile(a:what, escape(a:where, ' ') . ';')
    let &suffixesadd = old_suffixesadd
    return file
endfunction

function! s:find_root_directory() abort
    let fd = expand('%:p')
    let dirs = []
    " call SpaceVim#logger#info('Start to find root for: ' . fd)
    for pattern in g:projectile_rooter_patterns
        if stridx(pattern, '/') != -1
            let dir = s:findDirInParent(pattern, fd)
        else
            let dir = s:findFileInParent(pattern, fd)
        endif
        let ftype = getftype(dir)
        if ftype ==# 'dir' || ftype ==# 'file'
            let dir = fnamemodify(dir, ':p')
            if dir !=# expand('~/.SpaceVim.d/')
                " call SpaceVim#logger#info('        (' . pattern . '):' . dir)
                call add(dirs, dir)
            endif
        endif
    endfor
    return s:sort_dirs(deepcopy(dirs))
endfunction


function! s:sort_dirs(dirs) abort
    let dir = get(sort(a:dirs, function('s:compare')), 0, '')
    let bufdir = getbufvar('%', 'rootDir', '')
    if bufdir ==# dir
        return ''
    else
        if isdirectory(dir)
            let dir = fnamemodify(dir, ':p:h:h')
        else
            let dir = fnamemodify(dir, ':p:h')
        endif
        return dir
    endif
endfunction

function! s:compare(d1, d2) abort
    return len(split(a:d2, '/')) - len(split(a:d1, '/'))
endfunction

function! projectile#complete_project(ArgLead, CmdLine, CursorPos) abort
    let dir = get(g:,'projectile_src_root', '~')
    "return globpath(dir, '*')
    let result = split(globpath(dir, '*'), "\n")
    let ps = []
    for p in result
        if isdirectory(p) && isdirectory(p . '/' . '.git')
            call add(ps, fnamemodify(p, ':t'))
        endif
    endfor
    return join(ps, "\n")
endfunction

function! projectile#OpenProject(p) abort
    let dir = get(g:, 'projectile_src_root', '~') . a:p
    exe 'Files '. dir
endfunction

function! projectile#fzf_complete_menu(ArgLead, CmdLine, CursorPos) abort
    return join(keys(g:unite_source_menu_menus), "\n")
endfunction
