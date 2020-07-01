" Author        : Manpreet Singh < junkblocker@yahoo.com >    " {{{
" Copyright     : 2006-2020 by Manpreet Singh
" Version       : 2.0.0
" License       : This file is placed in the public domain.
"                 No warranties express or implied. Use at your own risk.
" Initialization {{{
let s:driver = {}
let s:git = {}
" }}}
function! s:git.detect() " {{{
  return isdirectory('.git') || filereadable('.git')
endfunction
" }}}
function! s:git.get_diff() " {{{
  if has('win16') || has('win32') || has('win64') || has('win95') || has('gui_win32') || has('gui_win32s')
    let l:diff = s:driver.generate_diff('git diff -p -U5 --no-color 2> NUL')
  else
    let l:diff = s:driver.generate_diff('git diff -p -U5 --no-color 2>/dev/null')
  endif
  return {'strip': 1, 'diff': l:diff}
endfunction
" }}}
function! patchreview#git#register(remote) "{{{
  let s:driver = a:remote
  return s:git
endfunction
" }}}
" vim: set et fdl=1 fdm=marker fenc= ff=unix ft=vim sts=0 sw=2 ts=2 tw=79 nowrap :
"}}}
