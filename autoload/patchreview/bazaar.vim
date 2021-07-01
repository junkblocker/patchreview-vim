" Author        : Manpreet Singh < junkblocker@yahoo.com >    " {{{
" Copyright     : 2006-2020 by Manpreet Singh
" Version       : 2.0.1
" License       : This file is placed in the public domain.
"                 No warranties express or implied. Use at your own risk.
" Initialization {{{
let s:driver = {}
let s:bazaar = {}
" }}}
function! s:bazaar.detect() " {{{
  return isdirectory('.bzr')
endfunction
" }}}
function! s:bazaar.get_diff() " {{{
  let l:diff = s:driver.generate_diff('bzr diff')
  return {'strip': 0, 'diff': l:diff}
endfunction
" }}}
function! patchreview#bazaar#register(remote) "{{{
  let s:driver = a:remote
  return s:bazaar
endfunction
" }}}
" vim: set et fdl=1 fdm=marker fenc= ff=unix ft=vim sts=0 sw=2 ts=2 tw=79 nowrap :
"}}}
