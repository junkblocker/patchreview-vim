" Author        : Manpreet Singh < junkblocker@yahoo.com >    " {{{
" Copyright     : 2006-2017 by Manpreet Singh
" Version       : 1.3.0
" License       : This file is placed in the public domain.
"                 No warranties express or implied. Use at your own risk.
" Initialization {{{
let s:driver = {}
let s:cvs = {}
" }}}
function! s:cvs.detect() " {{{
  return isdirectory('CVS')
endfunction
" }}}
function! s:cvs.get_diff() " {{{
  return {'strip': 0, 'diff': s:driver.generate_diff('cvs diff -q -u')}
endfunction
" }}}
function! patchreview#cvs#register(remote) "{{{
  let s:driver = a:remote
  return s:cvs
endfunction
" }}}
" vim: set et fdl=1 fdm=marker fenc= ff=unix ft=vim sts=0 sw=2 ts=2 tw=79 nowrap :
"}}}
