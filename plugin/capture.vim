" vim:foldmethod=marker:fen:
scriptencoding utf-8

" Load Once {{{
if (exists('g:loaded_capture') && g:loaded_capture) || &cp
    finish
endif
let g:loaded_capture = 1
" }}}
" Saving 'cpoptions' {{{
let s:save_cpo = &cpo
set cpo&vim
" }}}


let s:is_mswin = has('win16') || has('win95') || has('win32') || has('win64')
let g:capture_open_command = get(g:, 'capture_open_command', 'belowright new')


function! s:cmd_capture(q_args, createbuf) "{{{
    " Get rid of cosmetic characters.
    let q_args = a:q_args
    let q_args = substitute(q_args, '^[\t :]+', '', '')
    let q_args = substitute(q_args, '\s+$', '', '')

    if q_args !=# '' && q_args[0] ==# '!'
        let args   = substitute(q_args, '^[ :]*!', '', '')
        let output = system(args)
    else
        redir => output
        silent execute q_args
        redir END
        let output = substitute(output, '^\n\+', '', '')
    endif

    let capture_winnr = s:get_capture_winnr()
    if !a:createbuf && capture_winnr ># 0
        " Jump to existing capture window.
        execute capture_winnr 'wincmd w'
        " Format existing buffer.
        if len(b:capture_commands) is 1
            " NOTE:
            " '1put! =b:capture_commands[0].":"'
            " caused
            " 'E15: Invalid expression: b:capture_commands[0].'
            " on Vim version 7.3.729
            let line = b:capture_commands[0].":"
            1put! =line
            " Rename buffer name.
            call s:name_append_bufname(b:capture_commands + [q_args])
        endif
        " Append new output.
        let lines = ["", q_args.":"] + split(output, '\n')
        call setline(line('$') + 1, lines)
    else
        " Create new capture buffer & window.
        call s:create_capture_buffer(q_args)
        " Set command output.
        call setline(1, split(output, '\n'))
    endif
    " Save executed commands.
    if exists('b:capture_commands')
        call add(b:capture_commands, q_args)
    else
        let b:capture_commands = [q_args]
    endif
endfunction "}}}

function! s:get_capture_winnr()
    for nr in range(1, winnr('$'))
        if getwinvar(nr, '&filetype') ==# 'capture'
            return nr
        endif
    endfor
    return -1
endfunction

function! s:create_capture_buffer(q_args)
    try
        silent execute g:capture_open_command
    catch
        return
    endtry
    call s:name_first_bufname(a:q_args)
    setlocal buftype=nofile bufhidden=unload noswapfile nobuflisted
    setfiletype capture
endfunction

function! s:name_first_bufname(q_args)
    " Get rid of invalid characters of buffer name on MS Windows.
    let q_args = a:q_args
    if s:is_mswin
        let q_args = substitute(q_args, '[?*\\]', '_', 'g')
    endif
    " Generate a unique buffer name.
    let bufname = s:generate_unique_bufname(q_args)
    let b:capture_bufnamenr = bufname.nr
    silent file `=bufname.bufname`
endfunction

function! s:name_append_bufname(commands)
    let firstcmd = '^[a-zA-Z][a-zA-Z0-9_]\+\ze'
    let cmdlist = ''
    for cmd in a:commands[:1]
        let cmdlist .=
        \   (cmdlist ==# '' ? '' : ',') .
        \   matchstr(cmd, firstcmd)
    endfor
    let cmdlist .= ',...'
    " Generate a unique buffer name.
    let bufname = s:generate_unique_bufname(cmdlist)
    let b:capture_bufnamenr = bufname.nr
    silent file `=bufname.bufname`
endfunction

function! s:generate_unique_bufname(string)
    let nr = get(b:, 'capture_bufnamenr', 0)
    let bufname = '[Capture #'.nr.': "'.a:string.'"]'
    while bufexists(bufname)
        let nr += 1
        let bufname = '[Capture #'.nr.': "'.a:string.'"]'
    endwhile
    return {'nr': nr, 'bufname': bufname}
endfunction


command!
\   -nargs=+ -complete=command -bang
\   Capture
\   call s:cmd_capture(<q-args>, <bang>0)


" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}
