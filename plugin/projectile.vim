if exists('g:loaded_projectile')
    finish
endif
let g:loaded_projectile = 1

if !exists('g:projectile_rooter_patterns')
    let g:projectile_rooter_patterns = ['.git/', '_darcs/', '.hg/', '.bzr/', '.svn/', 'Cargo.toml', 'package.json', '.clang', '.pom.xml', 'build.sbt']
endif

if !exists('g:projectile_rooter_automatically')
    let g:projectile_rooter_automatically = 1
endif

if g:projectile_rooter_automatically
    augroup projectile_rooter
        autocmd!
        autocmd VimEnter,BufEnter * call projectile#current_root()
        autocmd BufWritePost * :call setbufvar('%', 'rootDir', '') | call projectile#current_root()
    augroup END
endif

" fzf menu command
command! -nargs=* -complete=custom,projectile#fzf_complete_menu FzfMenu call <SID>menu(<q-args>)
function! s:menu_action(e) abort
    let action = get(s:menu_action, a:e, '')
    exe action
endfunction
function! s:menu(name) abort
    let s:source = 'menu'
    let s:menu_name = a:name
    let s:menu_action = {}
    function! s:menu_content() abort
        let menu = get(g:unite_source_menu_menus, s:menu_name, {})
        if has_key(menu, 'command_candidates')
            let rt = []
            for item in menu.command_candidates
                call add(rt, item[0])
                call extend(s:menu_action, {item[0] : item[1]}, 'force')
            endfor
            return rt
        else
            return []
        endif
    endfunction
    call fzf#run(fzf#wrap('menu', {
                \   'source':  reverse(<sid>menu_content()),
                \   'sink':    function('s:menu_action'),
                \   'options': '+m',
                \   'down': '40%'
                \ }))
endfunction

command! -nargs=+ -complete=custom,projectile#complete_project OpenProject :call projectile#OpenProject(<f-args>)
