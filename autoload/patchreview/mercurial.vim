" Author        : Manpreet Singh < junkblocker@yahoo.com >    " {{{
" Copyright     : 2006-2016 by Manpreet Singh
" License       : This file is placed in the public domain.
"                 No warranties express or implied. Use at your own risk.
" Initialization {{{
let s:driver = {}
let s:mercurial = {}
"}}}
function! s:mercurial.detect() " {{{
  return isdirectory('.hg')
endfunction
" }}}
function! s:mercurial.get_diff() " {{{
  let l:diff = s:driver.generate_diff('hg diff')
  return {'strip': 1, 'diff': l:diff}
endfunction
" }}}
function! patchreview#mercurial#register(remote) "{{{
  let s:driver = a:remote
  return s:mercurial
endfunction
" }}}
" vim: set et fdl=1 fdm=marker fenc= ff=unix ft=vim sts=0 sw=2 ts=2 tw=79 nowrap :
"}}}
