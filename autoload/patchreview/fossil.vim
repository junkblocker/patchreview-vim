" Author        : Manpreet Singh < junkblocker@yahoo.com >    " {{{
" Copyright     : 2006-2020 by Manpreet Singh
" Version       : 2.0.1
" License       : This file is placed in the public domain.
"                 No warranties express or implied. Use at your own risk.
" Initialization {{{
let s:driver = {}
let s:fossil = {}
" }}}
function! s:fossil.detect() " {{{
  if ! executable('fossil')
    return 0
  endif
  call system('fossil info > /dev/null 2>&1')
  return ! v:shell_error
endfunction
" }}}
function! s:fossil.get_diff() " {{{
  let l:diff = s:driver.generate_diff('fossil diff --unified -v --')
  return {'strip': 0, 'diff': l:diff}
endfunction
" }}}
function! patchreview#fossil#register(remote) "{{{
  let s:driver = a:remote
  return s:fossil
endfunction
" }}}
" vim: set et fdl=1 fdm=marker fenc= ff=unix ft=vim sts=0 sw=2 ts=2 tw=79 nowrap :
"}}}
